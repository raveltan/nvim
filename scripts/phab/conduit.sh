#!/usr/bin/env bash
# Low-level Conduit API client. Single HTTP call, prints .result to stdout.
set -euo pipefail

usage() {
  echo "Usage: conduit.sh <method> [json_params]" >&2
  exit 1
}

[ $# -ge 1 ] || usage
METHOD="$1"
PARAMS="${2-}"
[ -n "$PARAMS" ] || PARAMS='{}'

# Resolve credentials.
URL="${PHABRICATOR_URL:-}"
TOKEN="${PHABRICATOR_API_TOKEN:-}"

if [ -z "$URL" ] || [ -z "$TOKEN" ]; then
  ARCRC="${HOME}/.arcrc"
  if [ ! -f "$ARCRC" ]; then
    echo "phab: no PHABRICATOR_URL/PHABRICATOR_API_TOKEN env and no ~/.arcrc" >&2
    exit 1
  fi
  HOSTKEY="$(jq -r '.hosts | keys[0] // empty' < "$ARCRC")"
  if [ -z "$HOSTKEY" ]; then
    echo "phab: ~/.arcrc has no hosts entry" >&2
    exit 1
  fi
  TOKEN="$(jq -r --arg h "$HOSTKEY" '.hosts[$h].token // empty' < "$ARCRC")"
  if [ -z "$TOKEN" ]; then
    echo "phab: ~/.arcrc host '$HOSTKEY' has no token" >&2
    exit 1
  fi
  # Strip trailing /api/ or /api from URL.
  URL="$(echo "$HOSTKEY" | sed -E 's#/api/?$##')"
fi

# Validate params is JSON.
if ! echo "$PARAMS" | jq -e . >/dev/null 2>&1; then
  echo "phab: params is not valid JSON: $PARAMS" >&2
  exit 1
fi

# Inject token into params.
PARAMS_WITH_TOKEN="$(echo "$PARAMS" | jq --arg t "$TOKEN" '. + {__conduit__: {token: $t}}')"

ENDPOINT="${URL%/}/api/${METHOD}"

TMP_BODY="$(mktemp)"
trap 'rm -f "$TMP_BODY"' EXIT

HTTP_CODE="$(curl -sS -o "$TMP_BODY" -w '%{http_code}' \
  --data-urlencode "params=${PARAMS_WITH_TOKEN}" \
  --data-urlencode "output=json" \
  --data-urlencode "__conduit__=true" \
  "$ENDPOINT" || true)"

if [ -z "$HTTP_CODE" ]; then
  echo "phab: curl failed contacting $ENDPOINT" >&2
  exit 1
fi

if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
  echo "phab: HTTP error $HTTP_CODE from $ENDPOINT" >&2
  cat "$TMP_BODY" >&2
  echo >&2
  exit 1
fi

if ! jq -e . >/dev/null 2>&1 < "$TMP_BODY"; then
  echo "phab: non-JSON response from $ENDPOINT" >&2
  cat "$TMP_BODY" >&2
  echo >&2
  exit 1
fi

ERR_CODE="$(jq -r '.error_code // empty' < "$TMP_BODY")"
if [ -n "$ERR_CODE" ]; then
  ERR_INFO="$(jq -r '.error_info // ""' < "$TMP_BODY")"
  echo "phab: Conduit error [$ERR_CODE]: $ERR_INFO" >&2
  exit 1
fi

jq '.result' < "$TMP_BODY"
