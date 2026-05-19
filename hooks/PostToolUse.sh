#!/usr/bin/env bash
# PostToolUse.sh — Appends one line per tool call to sessions/current.md.
# AIPS v6.0 plugin-distributed hook. No-op if .priv-storage/ absent.
set -u

[[ "${HOOKS_DISABLED:-0}" == "1" ]] && exit 0

HOOK_ERRORS="$HOME/.claude/hook-errors.log"
trap 'rc=$?; [[ $rc -ne 0 ]] && printf "%s\tPostToolUse.sh\trc=%d\tcmd=%s\n" "$(date -Iseconds 2>/dev/null || date)" "$rc" "${BASH_COMMAND:-?}" >> "$HOOK_ERRORS" 2>/dev/null; exit $rc' ERR

if [[ -f "$HOOK_ERRORS" ]] && (( RANDOM % 100 == 0 )); then
    SIZE=$(stat -c %s "$HOOK_ERRORS" 2>/dev/null || stat -f %z "$HOOK_ERRORS" 2>/dev/null || echo 0)
    if [[ "$SIZE" -gt 1048576 ]]; then
        tail -c 204800 "$HOOK_ERRORS" > "$HOOK_ERRORS.tmp" && mv "$HOOK_ERRORS.tmp" "$HOOK_ERRORS"
    fi
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT" 2>/dev/null || true

# Graceful degradation: AIPS not initialized in this project.
[[ -d "$PROJECT_ROOT/.priv-storage" ]] || exit 0

SESSIONS_DIR="$PROJECT_ROOT/.priv-storage/sessions"
CURRENT="$SESSIONS_DIR/current.md"

[[ -d "$SESSIONS_DIR" ]] || exit 0

PAYLOAD=$(cat 2>/dev/null || echo "{}")

if command -v jq >/dev/null 2>&1; then
    TOOL=$(echo "$PAYLOAD" | jq -r '.tool_name // "unknown"')
    SUMMARY=$(echo "$PAYLOAD" | jq -r '
        if .tool_input.file_path then .tool_input.file_path
        elif .tool_input.command then (.tool_input.command | .[0:80])
        elif .tool_input.pattern then (.tool_input.pattern | .[0:80])
        else "" end
    ')
else
    TOOL="tool"
    SUMMARY=""
fi

TIMESTAMP=$(date -Iseconds 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S%z")

if [[ ! -f "$CURRENT" ]]; then
    {
        echo "# Live Session Log — $(date +%Y-%m-%d)"
        echo "# Updated by PostToolUse.sh after every tool call"
        echo
    } > "$CURRENT"
fi

printf '%s\t%s\t%s\n' "$TIMESTAMP" "$TOOL" "$SUMMARY" >> "$CURRENT"

if [[ $(wc -l < "$CURRENT") -gt 5000 ]]; then
    tail -4000 "$CURRENT" > "$CURRENT.tmp" && mv "$CURRENT.tmp" "$CURRENT"
fi

case "$TOOL" in
    Read|Edit|Write|NotebookEdit)
        if [[ -n "$SUMMARY" && -f "$SUMMARY" ]]; then
            READ_LOG="$SESSIONS_DIR/read-log.tsv"
            EPOCH=$(date +%s)
            MTIME=$(stat -c %Y "$SUMMARY" 2>/dev/null || stat -f %m "$SUMMARY" 2>/dev/null || echo 0)
            EVENT="$TOOL"
            if [[ "$TOOL" == "Read" ]] && command -v jq >/dev/null 2>&1; then
                OFF=$(echo "$PAYLOAD" | jq -r '.tool_input.offset // empty')
                LIM=$(echo "$PAYLOAD" | jq -r '.tool_input.limit // empty')
                if [[ -n "$OFF" || -n "$LIM" ]]; then
                    EVENT="Read[${OFF:-0},${LIM:-end}]"
                fi
            fi
            printf '%s\t%s\t%s\t%s\n' "$EPOCH" "$EVENT" "$MTIME" "$SUMMARY" >> "$READ_LOG"
            if [[ $(wc -l < "$READ_LOG") -gt 1000 ]]; then
                tail -800 "$READ_LOG" > "$READ_LOG.tmp" && mv "$READ_LOG.tmp" "$READ_LOG"
            fi
        fi
        ;;
esac

GLOBAL_MEM="$HOME/.claude/projects/$(echo "$PROJECT_ROOT" | tr '/' '-')/memory"
if [[ -d "$PROJECT_ROOT/.priv-storage/memory" ]]; then
    mkdir -p "$GLOBAL_MEM"
    for f in "$PROJECT_ROOT"/.priv-storage/memory/*.md; do
        [[ -f "$f" ]] || continue
        target="$GLOBAL_MEM/$(basename "$f")"
        if [[ ! -f "$target" ]] || [[ "$f" -nt "$target" ]]; then
            cp "$f" "$target" 2>/dev/null || true
        fi
    done
fi

if [[ "$TOOL" == "Edit" || "$TOOL" == "Write" || "$TOOL" == "NotebookEdit" ]]; then
    case "$SUMMARY" in
        *CLAUDE.md|*.priv-storage/CLAUDE.md|CLAUDE.md)
            SRC="$PROJECT_ROOT/.priv-storage/CLAUDE.md"
            DST="$PROJECT_ROOT/.priv-storage/.cursorrules"
            if [[ -f "$SRC" && -f "$DST" ]]; then
                if ! diff -q "$SRC" "$DST" >/dev/null 2>&1; then
                    cp "$SRC" "$DST" 2>/dev/null && \
                        echo "[PostToolUse] auto-synced .cursorrules <- CLAUDE.md (drift detected)" >&2
                fi
            fi
            ;;
    esac
fi

if [[ -f "$CURRENT" ]]; then
    LINE_COUNT=$(wc -l < "$CURRENT")
    if (( LINE_COUNT % 50 == 0 && LINE_COUNT > 0 )); then
        RECOVERY="$SESSIONS_DIR/recovery.md"
        {
            echo "# Recovery Snapshot — $TIMESTAMP (auto, every 50 tool calls)"
            echo
            echo "## Last 100 tool calls"
            echo '```'
            tail -100 "$CURRENT"
            echo '```'
            echo
            echo "## Git state"
            echo '```'
            (cd "$PROJECT_ROOT" && git status --short 2>/dev/null | head -20) || true
            echo '```'
        } > "$RECOVERY" 2>/dev/null || true
    fi
fi

exit 0
