#!/usr/bin/env bash
# Stop.sh — Writes a handoff note when the session ends, and updates WORK_STATUS.md.
# AIPS v6.0 plugin-distributed hook. No-op if .priv-storage/ absent.
set -u

[[ "${HOOKS_DISABLED:-0}" == "1" ]] && exit 0

HOOK_ERRORS="$HOME/.claude/hook-errors.log"
trap 'rc=$?; [[ $rc -ne 0 ]] && printf "%s\tStop.sh\trc=%d\tcmd=%s\n" "$(date -Iseconds 2>/dev/null || date)" "$rc" "${BASH_COMMAND:-?}" >> "$HOOK_ERRORS" 2>/dev/null; exit $rc' ERR

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT" 2>/dev/null || true

# Graceful degradation: AIPS not initialized in this project.
[[ -d "$PROJECT_ROOT/.priv-storage" ]] || exit 0

SESSIONS_DIR="$PROJECT_ROOT/.priv-storage/sessions"
WORK_STATUS="$PROJECT_ROOT/.priv-storage/WORK_STATUS.md"
CURRENT="$SESSIONS_DIR/current.md"

[[ -d "$SESSIONS_DIR" ]] || exit 0

DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date -Iseconds 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S%z")
HANDOFF="$SESSIONS_DIR/handoff-$DATE.md"

{
    echo "# Session Handoff — $TIMESTAMP"
    echo
    if [[ -f "$CURRENT" ]]; then
        TOTAL_CALLS=$(grep -c '^[0-9]' "$CURRENT" 2>/dev/null || echo 0)
        echo "## Activity ($TOTAL_CALLS tool calls)"
        awk -F'\t' 'NR>2 && NF>=2 {print $2}' "$CURRENT" 2>/dev/null | sort | uniq -c | sort -rn | head -5
        echo
        echo "## Last 15 tool calls"
        echo '```'
        tail -15 "$CURRENT"
        echo '```'
    fi
    echo
    echo "## Git state"
    echo '```'
    (cd "$PROJECT_ROOT" && git status --short 2>/dev/null | head -20) || true
    (cd "$PROJECT_ROOT" && git diff --stat 2>/dev/null | head -10) || true
    echo '```'
    echo
    echo "Resume: SessionStart re-loads this (capped) + recovery.md head + WORK_STATUS.md."
} > "$HANDOFF"

if [[ -f "$WORK_STATUS" ]]; then
    if grep -q '^## Session Handoff Notes' "$WORK_STATUS"; then
        awk -v ts="$TIMESTAMP" -v handoff="$(basename "$HANDOFF")" '
            /^## Session Handoff Notes/ { print; print "- " ts " — auto-handoff written to sessions/" handoff; next }
            { print }
        ' "$WORK_STATUS" > "$WORK_STATUS.tmp" && mv "$WORK_STATUS.tmp" "$WORK_STATUS"
    fi
fi

ARCHIVE_DIR="$SESSIONS_DIR/archive"
mkdir -p "$ARCHIVE_DIR"
find "$SESSIONS_DIR" -maxdepth 1 -name "handoff-*.md" -mtime +7 -exec mv {} "$ARCHIVE_DIR/" \; 2>/dev/null || true
find "$ARCHIVE_DIR" -name "handoff-*.md" -mtime +90 -delete 2>/dev/null || true

GLOBAL_MEM="$HOME/.claude/projects/$(echo "$PROJECT_ROOT" | tr '/' '-')/memory"
if [[ -d "$PROJECT_ROOT/.priv-storage/memory" ]]; then
    mkdir -p "$GLOBAL_MEM"
    cp "$PROJECT_ROOT"/.priv-storage/memory/*.md "$GLOBAL_MEM/" 2>/dev/null || true
fi

exit 0
