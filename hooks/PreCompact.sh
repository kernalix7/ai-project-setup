#!/usr/bin/env bash
# PreCompact.sh — Snapshots full session state before Claude compacts the context.
# AIPS v6.0 plugin-distributed hook. No-op if .priv-storage/ absent.
set -u

[[ "${HOOKS_DISABLED:-0}" == "1" ]] && exit 0

HOOK_ERRORS="$HOME/.claude/hook-errors.log"
trap 'rc=$?; [[ $rc -ne 0 ]] && printf "%s\tPreCompact.sh\trc=%d\tcmd=%s\n" "$(date -Iseconds 2>/dev/null || date)" "$rc" "${BASH_COMMAND:-?}" >> "$HOOK_ERRORS" 2>/dev/null; exit $rc' ERR

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT" 2>/dev/null || true

# Graceful degradation: AIPS not initialized in this project.
[[ -d "$PROJECT_ROOT/.priv-storage" ]] || exit 0

SESSIONS_DIR="$PROJECT_ROOT/.priv-storage/sessions"
WORK_STATUS="$PROJECT_ROOT/.priv-storage/WORK_STATUS.md"
RECOVERY="$SESSIONS_DIR/recovery.md"
CURRENT="$SESSIONS_DIR/current.md"

[[ -d "$SESSIONS_DIR" ]] || exit 0

TIMESTAMP=$(date -Iseconds 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S%z")

{
    echo "# Pre-Compaction Recovery Snapshot"
    echo "# Saved: $TIMESTAMP"
    echo "# Reason: Claude Code is about to compact context — this file preserves full state."
    echo
    echo "## Open task list"
    cat 2>/dev/null || echo "(no task list payload received)"
    echo
    echo "## WORK_STATUS.md"
    [[ -f "$WORK_STATUS" ]] && cat "$WORK_STATUS"
    echo
    echo "## current.md tail (last 200 entries)"
    [[ -f "$CURRENT" ]] && tail -200 "$CURRENT"
    echo
    echo "## Recent git activity"
    (cd "$PROJECT_ROOT" && git status --short 2>/dev/null) || true
    echo
    (cd "$PROJECT_ROOT" && git log --oneline -10 2>/dev/null) || true
} > "$RECOVERY"

exit 0
