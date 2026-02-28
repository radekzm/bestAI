#!/bin/bash
# hooks/lib-project.sh — Unified project utilities for bestAI

_bestai_project_hash() {
    local target="${1:-.}"
    local abs_path
    abs_path=$(realpath "$target" 2>/dev/null || echo "$target")
    
    if command -v md5sum >/dev/null 2>&1; then
        printf '%s' "$abs_path" | md5sum | awk '{print substr($1,1,16)}'
    elif command -v md5 >/dev/null 2>&1; then
        printf '%s' "$abs_path" | md5 | awk '{print substr($1,1,16)}'
    else
        # Fallback for systems without md5
        printf '%s' "$abs_path" | cksum | awk '{print $1}'
    fi
}
