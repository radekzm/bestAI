#!/bin/bash
# modules/etag-cache-lib.sh — E-Tag cache library for memory file metadata
#
# Shared by:
#   - hooks/memory-compiler.sh (WRITE path: computes + persists cache)
#   - hooks/preprocess-prompt.sh (READ path: validates + reads cache)
#
# Cache files (in $MEMORY_DIR/):
#   .file-metadata   — TSV: filename, mtime, size, etag, has_user, trigram_file
#   .trigram-cache/   — pre-computed trigram files (one .tri per .md)
#
# Uses standard CLI tools: md5sum, stat, awk, sort, mktemp, mv

# --- Cache storage ---
# ETAG_CACHE is an associative array: ETAG_CACHE[filename]=<tab-separated fields>
# Fields: mtime<TAB>size<TAB>etag<TAB>has_user<TAB>trigram_file

declare -gA ETAG_CACHE
ETAG_METADATA_FILE=""
ETAG_TRIGRAM_DIR=""

# --- etag_init() ---
# Load .file-metadata into ETAG_CACHE associative array.
# Must be called before any other etag_* function.
# Requires MEMORY_DIR to be set.
etag_init() {
    ETAG_METADATA_FILE="$MEMORY_DIR/.file-metadata"
    ETAG_TRIGRAM_DIR="$MEMORY_DIR/.trigram-cache"
    ETAG_CACHE=()

    [ -f "$ETAG_METADATA_FILE" ] || return 0

    while IFS=$'\t' read -r fname mtime size etag has_user tri_file; do
        # Skip comments and empty lines
        [[ "$fname" == \#* ]] && continue
        [ -z "$fname" ] && continue
        ETAG_CACHE["$fname"]="${mtime}	${size}	${etag}	${has_user}	${tri_file}"
    done < "$ETAG_METADATA_FILE"
}

# --- etag_validate(basename, filepath) ---
# Compare file's current mtime+size with cached values.
# Returns: "valid", "stale", or "missing"
etag_validate() {
    local basename="$1"
    local filepath="${2:-$MEMORY_DIR/$basename}"

    # No cache entry -> missing
    [ -z "${ETAG_CACHE[$basename]+x}" ] && { echo "missing"; return; }

    local cached="${ETAG_CACHE[$basename]}"
    local cached_mtime cached_size
    cached_mtime=$(echo "$cached" | cut -f1)
    cached_size=$(echo "$cached" | cut -f2)

    # Get current file stat
    local cur_mtime cur_size
    cur_mtime=$(stat -c '%Y' "$filepath" 2>/dev/null || echo "0")
    cur_size=$(stat -c '%s' "$filepath" 2>/dev/null || echo "0")

    if [ "$cur_mtime" = "$cached_mtime" ] && [ "$cur_size" = "$cached_size" ]; then
        echo "valid"
    else
        echo "stale"
    fi
}

# --- etag_compute(basename, filepath) ---
# Compute all cached fields for a file and store in ETAG_CACHE + write .tri file.
# Called by memory-compiler.sh during the WRITE path.
etag_compute() {
    local basename="$1"
    local filepath="$2"

    [ -f "$filepath" ] || return 0

    # Ensure trigram cache directory exists
    mkdir -p "$ETAG_TRIGRAM_DIR"

    # mtime + size via stat (O(1))
    local mtime size
    mtime=$(stat -c '%Y' "$filepath" 2>/dev/null || echo "0")
    size=$(stat -c '%s' "$filepath" 2>/dev/null || echo "0")

    # etag via md5sum
    local etag
    etag=$(md5sum "$filepath" 2>/dev/null | awk '{print $1}')
    [ -z "$etag" ] && etag="none"

    # has_user flag: 1 if file contains [USER], 0 otherwise
    local has_user=0
    grep -q '\[USER\]' "$filepath" 2>/dev/null && has_user=1

    # Generate trigrams from first 100 lines and write to .tri file
    local tri_file=".trigram-cache/${basename}.tri"
    local tri_path="$MEMORY_DIR/$tri_file"
    local file_text
    file_text=$(head -100 "$filepath" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' ' ')

    # Generate trigrams: extract 3-char sequences from each word, sort unique
    {
        local word
        for word in $file_text; do
            local len=${#word}
            if [ "$len" -ge 3 ]; then
                local i=0
                while [ $((i + 3)) -le "$len" ]; do
                    echo "${word:$i:3}"
                    i=$((i + 1))
                done
            fi
        done
    } | sort -u > "$tri_path"

    # Store in associative array
    ETAG_CACHE["$basename"]="${mtime}	${size}	${etag}	${has_user}	${tri_file}"
}

# --- etag_get_field(basename, field) ---
# Return a specific cached field value.
# Fields: mtime, size, etag, has_user, trigram_file
etag_get_field() {
    local basename="$1"
    local field="$2"

    [ -z "${ETAG_CACHE[$basename]+x}" ] && return 1

    local cached="${ETAG_CACHE[$basename]}"
    case "$field" in
        mtime)        echo "$cached" | cut -f1 ;;
        size)         echo "$cached" | cut -f2 ;;
        etag)         echo "$cached" | cut -f3 ;;
        has_user)     echo "$cached" | cut -f4 ;;
        trigram_file) echo "$cached" | cut -f5 ;;
        *)            return 1 ;;
    esac
}

# --- etag_remove(basename) ---
# Remove a file's cache entry and its .tri file.
# Called when a file is GC'd/archived.
etag_remove() {
    local basename="$1"

    if [ -n "${ETAG_CACHE[$basename]+x}" ]; then
        local tri_file
        tri_file=$(etag_get_field "$basename" "trigram_file")
        [ -n "$tri_file" ] && rm -f "$MEMORY_DIR/$tri_file"
        unset 'ETAG_CACHE[$basename]'
    fi
}

# --- etag_persist() ---
# Write ETAG_CACHE back to .file-metadata atomically (mktemp + mv).
etag_persist() {
    [ -z "$ETAG_METADATA_FILE" ] && return 1

    local tmp
    tmp=$(mktemp "${ETAG_METADATA_FILE}.XXXXXX")

    {
        echo "# filename	mtime	size	etag	has_user	trigram_file"
        for fname in "${!ETAG_CACHE[@]}"; do
            printf '%s\t%s\n' "$fname" "${ETAG_CACHE[$fname]}"
        done
    } > "$tmp"

    mv "$tmp" "$ETAG_METADATA_FILE"
}
