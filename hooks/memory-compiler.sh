#!/bin/bash
# hooks/memory-compiler.sh — Stop hook
# Memory Compiler: scores, indexes, and garbage-collects memory files.
#
# Pipeline:
#   1. Increment session counter
#   2. Score each memory entry: base_weight + recency_bonus + usage_count - age_penalty
#   3. Generate context-index.md (sorted index with topic clusters)
#   4. Enforce 200-line cap on MEMORY.md (overflow → topic files)
#   5. Generational GC: young/mature/old/permanent
#      - Old [AUTO] entries without references → gc-archive.md
#      - [USER] entries are NEVER auto-deleted
#
# Env vars:
#   MEMORY_COMPILER_DRY_RUN=1  — print actions without executing
#   MEMORY_COMPILER_GC_AGE=20  — sessions without use before GC (default: 20)

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT_KEY=$(echo "$PROJECT_DIR" | tr '/' '-')
MEMORY_DIR_DEFAULT="$HOME/.claude/projects/$PROJECT_KEY/memory"
MEMORY_DIR="${SMART_CONTEXT_MEMORY_DIR:-$MEMORY_DIR_DEFAULT}"
[ -d "$MEMORY_DIR" ] || exit 0

DRY_RUN="${MEMORY_COMPILER_DRY_RUN:-0}"
GC_AGE_THRESHOLD="${MEMORY_COMPILER_GC_AGE:-20}"
MAX_MEMORY_LINES=200

SESSION_COUNTER="$MEMORY_DIR/.session-counter"
GC_ARCHIVE="$MEMORY_DIR/gc-archive.md"
CONTEXT_INDEX="$MEMORY_DIR/context-index.md"
USAGE_LOG="$MEMORY_DIR/.usage-log"

# --- Step 1: Increment session counter ---
CURRENT_SESSION=0
if [ -f "$SESSION_COUNTER" ]; then
    CURRENT_SESSION=$(cat "$SESSION_COUNTER" 2>/dev/null || echo 0)
    [[ "$CURRENT_SESSION" =~ ^[0-9]+$ ]] || CURRENT_SESSION=0
fi
CURRENT_SESSION=$((CURRENT_SESSION + 1))
if [ "$DRY_RUN" = "0" ]; then
    echo "$CURRENT_SESSION" > "$SESSION_COUNTER"
fi

# --- Step 2: Score memory entries ---
# Score format in usage-log: filename<TAB>last_used_session<TAB>use_count<TAB>tag
# tag is USER or AUTO

update_usage() {
    local filename="$1" tag="$2"
    local tmp
    tmp=$(mktemp)
    local found=0

    if [ -f "$USAGE_LOG" ]; then
        while IFS=$'\t' read -r fname last_sess count entry_tag; do
            if [ "$fname" = "$filename" ]; then
                printf '%s\t%s\t%s\t%s\n' "$fname" "$CURRENT_SESSION" "$((count + 1))" "$tag" >> "$tmp"
                found=1
            else
                printf '%s\t%s\t%s\t%s\n' "$fname" "$last_sess" "$count" "$entry_tag" >> "$tmp"
            fi
        done < "$USAGE_LOG"
    fi

    if [ "$found" -eq 0 ]; then
        printf '%s\t%s\t%s\t%s\n' "$filename" "$CURRENT_SESSION" "1" "$tag" >> "$tmp"
    fi

    mv "$tmp" "$USAGE_LOG"
}

score_entry() {
    local filename="$1"
    local base_weight=5
    local recency_bonus=0
    local age_penalty=0
    local last_sess=0
    local use_count=0
    local tag="AUTO"

    # Read usage data
    if [ -f "$USAGE_LOG" ]; then
        local line
        line=$(grep "^${filename}	" "$USAGE_LOG" 2>/dev/null | head -1)
        if [ -n "$line" ]; then
            last_sess=$(echo "$line" | cut -f2)
            use_count=$(echo "$line" | cut -f3)
            tag=$(echo "$line" | cut -f4)
        fi
    fi

    # Check file content for [USER] tag
    local filepath="$MEMORY_DIR/$filename"
    if [ -f "$filepath" ] && grep -q '\[USER\]' "$filepath" 2>/dev/null; then
        tag="USER"
        base_weight=10
    fi

    # Recency bonus
    local sessions_ago=$((CURRENT_SESSION - last_sess))
    if [ "$sessions_ago" -le 3 ]; then
        recency_bonus=3
    elif [ "$sessions_ago" -le 10 ]; then
        recency_bonus=1
    fi

    # Age penalty for old entries
    if [ "$sessions_ago" -gt "$GC_AGE_THRESHOLD" ] && [ "$tag" = "AUTO" ]; then
        age_penalty=5
    fi

    local score=$((base_weight + recency_bonus + use_count - age_penalty))
    [ "$score" -lt 0 ] && score=0
    echo "$score"
}

# --- Step 3: Generate context-index.md ---
generate_index() {
    local index_tmp
    index_tmp=$(mktemp)

    {
        echo "# Context Index (auto-generated)"
        echo "# Session: $CURRENT_SESSION | Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo ""

        # Group files by topic cluster
        local -A clusters
        clusters[core]=""
        clusters[decisions]=""
        clusters[operational]=""
        clusters[other]=""

        while IFS= read -r mdfile; do
            [ -f "$mdfile" ] || continue
            local basename
            basename=$(basename "$mdfile")
            # Skip hidden files and this index itself
            [[ "$basename" == .* ]] && continue
            [ "$basename" = "context-index.md" ] && continue
            [ "$basename" = "gc-archive.md" ] && continue

            local file_score
            file_score=$(score_entry "$basename")

            # Update usage tracking
            [ "$DRY_RUN" = "0" ] && update_usage "$basename" "AUTO"

            # Classify into topic clusters
            case "$basename" in
                MEMORY.md|frozen-fragments.md)
                    clusters[core]+="- \`$basename\` (score=$file_score)"$'\n' ;;
                decisions.md|preferences.md)
                    clusters[decisions]+="- \`$basename\` (score=$file_score)"$'\n' ;;
                pitfalls.md|session-log.md|observations.md)
                    clusters[operational]+="- \`$basename\` (score=$file_score)"$'\n' ;;
                *)
                    clusters[other]+="- \`$basename\` (score=$file_score)"$'\n' ;;
            esac
        done < <(find "$MEMORY_DIR" -maxdepth 1 -type f -name '*.md' | sort)

        for cluster in core decisions operational other; do
            if [ -n "${clusters[$cluster]:-}" ]; then
                echo "## $cluster"
                echo "${clusters[$cluster]}"
            fi
        done
    } > "$index_tmp"

    if [ "$DRY_RUN" = "0" ]; then
        mv "$index_tmp" "$CONTEXT_INDEX"
    else
        echo "[DRY RUN] Would write context-index.md:"
        cat "$index_tmp"
        rm -f "$index_tmp"
    fi
}

# --- Step 4: Enforce 200-line cap on MEMORY.md ---
enforce_memory_cap() {
    local memory_file="$MEMORY_DIR/MEMORY.md"
    [ -f "$memory_file" ] || return 0

    local line_count
    line_count=$(wc -l < "$memory_file")
    [ "$line_count" -le "$MAX_MEMORY_LINES" ] && return 0

    if [ "$DRY_RUN" = "1" ]; then
        echo "[DRY RUN] MEMORY.md has $line_count lines (cap=$MAX_MEMORY_LINES), would trim"
        return 0
    fi

    # Move overflow lines to overflow topic file
    local overflow_file="$MEMORY_DIR/memory-overflow.md"
    local overflow_start=$((MAX_MEMORY_LINES + 1))

    {
        echo "# Memory Overflow (auto-generated)"
        echo "# Moved from MEMORY.md at session $CURRENT_SESSION"
        echo ""
        if [ -f "$overflow_file" ]; then
            cat "$overflow_file"
            echo ""
        fi
        sed -n "${overflow_start},\$p" "$memory_file"
    } > "${overflow_file}.tmp"
    mv "${overflow_file}.tmp" "$overflow_file"

    # Truncate MEMORY.md to cap
    head -n "$MAX_MEMORY_LINES" "$memory_file" > "${memory_file}.tmp"
    mv "${memory_file}.tmp" "$memory_file"
}

# --- Step 5: Generational GC ---
# Generations: young (0-3 sessions), mature (3-10), old (10+), permanent ([USER])
run_gc() {
    [ -f "$USAGE_LOG" ] || return 0

    local gc_tmp
    gc_tmp=$(mktemp)
    local archived=0

    while IFS=$'\t' read -r fname last_sess use_count tag; do
        local sessions_ago=$((CURRENT_SESSION - last_sess))
        local filepath="$MEMORY_DIR/$fname"

        # [USER] entries are NEVER auto-deleted
        if [ "$tag" = "USER" ]; then
            continue
        fi

        # Also check file content for [USER] tags
        if [ -f "$filepath" ] && grep -q '\[USER\]' "$filepath" 2>/dev/null; then
            continue
        fi

        # Old AUTO entries without recent use → archive
        if [ "$sessions_ago" -gt "$GC_AGE_THRESHOLD" ] && [ "$use_count" -lt 2 ]; then
            if [ "$DRY_RUN" = "1" ]; then
                echo "[DRY RUN] Would archive: $fname (age=$sessions_ago, uses=$use_count)"
            else
                # Append to gc-archive.md
                {
                    echo ""
                    echo "## Archived: $fname (session $CURRENT_SESSION)"
                    echo "- age: $sessions_ago sessions, uses: $use_count"
                    if [ -f "$filepath" ]; then
                        head -20 "$filepath"
                    fi
                } >> "$GC_ARCHIVE"
                archived=$((archived + 1))

                # Remove from usage log (will be filtered out below)
                echo "$fname" >> "$gc_tmp"
            fi
        fi
    done < "$USAGE_LOG"

    # Clean archived entries from usage log
    if [ -s "$gc_tmp" ] && [ "$DRY_RUN" = "0" ]; then
        local clean_tmp
        clean_tmp=$(mktemp)
        while IFS=$'\t' read -r fname rest; do
            if ! grep -qF "$fname" "$gc_tmp" 2>/dev/null; then
                printf '%s\t%s\n' "$fname" "$rest" >> "$clean_tmp"
            fi
        done < "$USAGE_LOG"
        mv "$clean_tmp" "$USAGE_LOG"
    fi

    rm -f "$gc_tmp"

    if [ "$archived" -gt 0 ]; then
        echo "memory-compiler: archived $archived old entries to gc-archive.md"
    fi
}

# --- Execute pipeline ---
# GC runs first (before generate_index updates usage timestamps)
run_gc
generate_index
enforce_memory_cap

exit 0
