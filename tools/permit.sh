#!/bin/bash
# tools/permit.sh — Human-in-the-Loop Permit Manager (v8.0)
# Usage: bestai permit <file_path> --duration [5m|1h|1d]

set -euo pipefail

PERMIT_DB=".bestai/permits.json"
mkdir -p .bestai

if [ ! -f "$PERMIT_DB" ]; then
    echo "{}" > "$PERMIT_DB"
fi

FILE_PATH="${1:-}"
DURATION="${3:-10m}" # Default 10 minutes

if [ -z "$FILE_PATH" ]; then
    echo "Usage: bestai permit <file_path> --duration [time]"
    exit 1
fi

# Simple duration parser (to seconds)
case "$DURATION" in
    *m) SECONDS=$(( ${DURATION%m} * 60 )) ;;
    *h) SECONDS=$(( ${DURATION%h} * 3600 )) ;;
    *d) SECONDS=$(( ${DURATION%d} * 86400 )) ;;
    *) SECONDS=600 ;;
esac

EXPIRY=$(( $(date +%s) + SECONDS ))

# Store permit atomically
TMP=$(mktemp)
jq --arg file "$FILE_PATH" --arg exp "$EXPIRY" 
   '.[$file] = ($exp | tonumber)' "$PERMIT_DB" > "$TMP" && mv "$TMP" "$PERMIT_DB"

echo -e "\033[0;32m✅ PERMIT GRANTED\033[0m"
echo "File: $FILE_PATH"
echo "Expires in: $DURATION ($(date -d @$EXPIRY))"
