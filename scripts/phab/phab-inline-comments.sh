#!/usr/bin/env bash
# List inline review comments on a revision.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  cat >&2 <<EOF
Usage: phab-inline-comments.sh <D123|PHID-DREV-xxx> [options]
  --status incomplete|done|all   (default: incomplete)
  --limit <n>                    transactions per page (default 100)
  --no-resolve                   don't resolve author PHIDs
  --raw                          print raw JSON array and exit
EOF
  exit 1
}

[ $# -ge 1 ] || usage
ID="$1"; shift

STATUS=incomplete
LIMIT=100
RESOLVE=1
RAW=0

while [ $# -gt 0 ]; do
  case "$1" in
    --status) STATUS="$2"; shift 2;;
    --limit)  LIMIT="$2"; shift 2;;
    --no-resolve) RESOLVE=0; shift;;
    --raw) RAW=1; shift;;
    --resolve) shift;;
    -h|--help) usage;;
    *) echo "phab-inline-comments: unknown flag: $1" >&2; exit 1;;
  esac
done

case "$STATUS" in
  incomplete|done|all) ;;
  *) echo "phab-inline-comments: --status must be incomplete|done|all" >&2; exit 1;;
esac

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

FILTER='.[] | select(.type == "inline")'
case "$STATUS" in
  incomplete) FILTER="$FILTER"' | select((.fields.isDone // false) == false)';;
  done)       FILTER="$FILTER"' | select((.fields.isDone // false) == true)';;
  all)        ;;
esac

INLINES="$(echo "$ALL" | jq "[ $FILTER ]")"

if [ "$RAW" = "1" ]; then
  printf '%s\n' "$INLINES"
  exit 0
fi

N="$(echo "$INLINES" | jq 'length')"
if [ "$N" = "0" ]; then
  echo "No ${STATUS} inline comments on ${ID}."
  exit 0
fi

OUT="[${N} ${STATUS} inline comment(s) on ${ID}]"$'\n'
OUT+="$(echo "$INLINES" | jq -r '
  .[] |
  (if (.fields.isDone // false) then "DONE" else "INCOMPLETE" end) as $s
  | (.dateCreated | if . then (. | todate) else "" end) as $d
  | "[\($s)] \(.fields.path // "?"):\(.fields.line // 0) by:\(.authorPHID // "none") (\($d))\n  \((.comments // [])[0].content.raw // "")"
')"

if [ "$RESOLVE" = "1" ]; then
  printf '%s\n' "$OUT" | "$SCRIPT_DIR/phab-resolve.sh"
  echo
else
  printf '%s\n' "$OUT"
fi
