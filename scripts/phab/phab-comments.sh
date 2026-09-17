#!/usr/bin/env bash
# List non-inline (general) review comments on a revision.
#
# Output (raw): JSON array of transaction objects of type "comment" that
# carry a non-empty body. Sorted oldest-first.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  cat >&2 <<EOF
Usage: phab-comments.sh <D123|PHID-DREV-xxx> [options]
  --limit <n>     transactions per page (default 100)
  --raw           print raw JSON array (default; kept for symmetry)
EOF
  exit 1
}

[ $# -ge 1 ] || usage
ID="$1"; shift

LIMIT=100
# Always raw; flag accepted for symmetry with phab-inline-comments.sh.
while [ $# -gt 0 ]; do
  case "$1" in
    --limit) LIMIT="$2"; shift 2;;
    --raw) shift;;
    -h|--help) usage;;
    *) echo "phab-comments: unknown flag: $1" >&2; exit 1;;
  esac
done

AFTER=""
ALL="[]"
while :; do
  if [ -n "$AFTER" ]; then
    PARAMS="$(jq -n --arg o "$ID" --argjson l "$LIMIT" --arg a "$AFTER" '{objectIdentifier:$o, limit:$l, after:$a}')"
  else
    PARAMS="$(jq -n --arg o "$ID" --argjson l "$LIMIT" '{objectIdentifier:$o, limit:$l}')"
  fi
  PAGE="$("$SCRIPT_DIR/conduit.sh" transaction.search "$PARAMS")"
  ALL="$(jq -n --argjson a "$ALL" --argjson b "$(echo "$PAGE" | jq '.data')" '$a + $b')"
  AFTER="$(echo "$PAGE" | jq -r '.cursor.after // empty')"
  [ -n "$AFTER" ] || break
done

# Keep only "comment" transactions with a non-empty body. Sort oldest-first.
echo "$ALL" | jq '
  [ .[]
    | select(.type == "comment")
    | select(((.comments // [])[0].content.raw // "") | length > 0)
  ]
  | sort_by(.dateCreated)
'
