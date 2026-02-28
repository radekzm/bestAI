#!/bin/bash
# tools/permit.sh — Human-in-the-Loop Permit Manager (v8.0)
# Usage: bestai permit <file_path> --duration [5m|1h|1d]

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bestai permit <file_path> [--duration <time>]

Examples:
  bestai permit package.json --duration 10m
  bestai permit src/auth.ts --duration 1h
EOF
}

parse_duration_seconds() {
    local raw="$1"
    local amount unit

    if ! printf '%s' "$raw" | grep -Eq '^[0-9]+[mhd]$'; then
        return 1
    fi

    amount="${raw%[mhd]}"
    unit="${raw##*[0-9]}"

    case "$unit" in
        m) printf '%s' "$(( amount * 60 ))" ;;
        h) printf '%s' "$(( amount * 3600 ))" ;;
        d) printf '%s' "$(( amount * 86400 ))" ;;
        *) return 1 ;;
    esac
}

PERMIT_DB=".bestai/permits.json"
mkdir -p .bestai

if [ ! -f "$PERMIT_DB" ]; then
    echo "{}" > "$PERMIT_DB"
fi

FILE_PATH=""
DURATION="10m"

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --duration)
            [ "$#" -ge 2 ] || { echo "Error: missing value for --duration" >&2; exit 1; }
            DURATION="$2"
            shift 2
            ;;
        --duration=*)
            DURATION="${1#*=}"
            shift
            ;;
        --*)
            echo "Error: unknown option '$1'" >&2
            usage >&2
            exit 1
            ;;
        *)
            if [ -z "$FILE_PATH" ]; then
                FILE_PATH="$1"
            else
                echo "Error: unexpected argument '$1'" >&2
                usage >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$FILE_PATH" ]; then
    usage >&2
    exit 1
fi

SECONDS="$(parse_duration_seconds "$DURATION" || true)"
if [ -z "$SECONDS" ] || [ "$SECONDS" -le 0 ]; then
    echo "Error: invalid duration '$DURATION' (expected: <number>[m|h|d])" >&2
    exit 1
fi

EXPIRY=$(( $(date +%s) + SECONDS ))

# Store permit atomically
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

if ! jq --arg file "$FILE_PATH" --argjson exp "$EXPIRY" '.[$file] = $exp' "$PERMIT_DB" > "$TMP"; then
    echo "Error: failed to write permit DB" >&2
    exit 1
fi

mv "$TMP" "$PERMIT_DB"
trap - EXIT

echo -e "\033[0;32m✅ PERMIT GRANTED\033[0m"
echo "File: $FILE_PATH"
echo "Expires in: $DURATION ($(date -d @$EXPIRY))"
