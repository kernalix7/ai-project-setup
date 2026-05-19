#!/usr/bin/env bash
# SessionStart.sh — Loads prior session context so AI can resume seamlessly.
# AIPS v6.0 plugin-distributed hook. Gracefully degrades if .priv-storage/ absent.
set -u

[[ "${HOOKS_DISABLED:-0}" == "1" ]] && exit 0

HOOK_ERRORS="$HOME/.claude/hook-errors.log"
trap 'rc=$?; [[ $rc -ne 0 ]] && printf "%s\tSessionStart.sh\trc=%d\tcmd=%s\n" "$(date -Iseconds 2>/dev/null || date)" "$rc" "${BASH_COMMAND:-?}" >> "$HOOK_ERRORS" 2>/dev/null; exit $rc' ERR

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT" 2>/dev/null || true
SESSIONS_DIR="$PROJECT_ROOT/.priv-storage/sessions"
WORK_STATUS="$PROJECT_ROOT/.priv-storage/WORK_STATUS.md"

# Plugin-active banner: emitted regardless of per-project init state.
if [[ -d "$HOME/.claude/plugins/cache/AIPS/AIPS" ]] || [[ -d "$HOME/.claude/plugins/cache/AIPS" ]]; then
    echo "AIPS v6.0 active"
fi

# If per-project AIPS not initialized, no session context to load — exit cleanly.
[[ -d "$SESSIONS_DIR" ]] || exit 0

RECOVERY_HEAD=60
HANDOFF_HEAD=100
CURRENT_TAIL=30
WORK_STATUS_LIMIT=40

echo "==== SESSION RESUME CONTEXT (auto-loaded by SessionStart.sh, v4.1 budget cap ≤200 lines) ===="
echo

if [[ -f "$SESSIONS_DIR/recovery.md" ]]; then
    AGE=$(( $(date +%s) - $(stat -c %Y "$SESSIONS_DIR/recovery.md" 2>/dev/null || stat -f %m "$SESSIONS_DIR/recovery.md") ))
    if [[ "$AGE" -lt 86400 ]]; then
        TOTAL=$(wc -l < "$SESSIONS_DIR/recovery.md")
        echo "--- recovery.md (head -$RECOVERY_HEAD of $TOTAL lines; Read full file if needed) ---"
        head -$RECOVERY_HEAD "$SESSIONS_DIR/recovery.md"
        [[ "$TOTAL" -gt "$RECOVERY_HEAD" ]] && echo "[...truncated $((TOTAL-RECOVERY_HEAD)) more lines — Read .priv-storage/sessions/recovery.md for full]"
        echo
    fi
fi

LATEST_HANDOFF=$(ls -t "$SESSIONS_DIR"/handoff-*.md 2>/dev/null | head -1)
if [[ -n "$LATEST_HANDOFF" ]]; then
    TOTAL=$(wc -l < "$LATEST_HANDOFF")
    echo "--- $(basename "$LATEST_HANDOFF") (head -$HANDOFF_HEAD of $TOTAL lines) ---"
    head -$HANDOFF_HEAD "$LATEST_HANDOFF"
    [[ "$TOTAL" -gt "$HANDOFF_HEAD" ]] && echo "[...truncated $((TOTAL-HANDOFF_HEAD)) more lines — Read $LATEST_HANDOFF for full]"
    echo
fi

if [[ -f "$SESSIONS_DIR/current.md" ]]; then
    echo "--- current.md tail (last $CURRENT_TAIL entries) ---"
    tail -$CURRENT_TAIL "$SESSIONS_DIR/current.md"
    echo
fi

if [[ -f "$WORK_STATUS" ]]; then
    echo "--- WORK_STATUS.md (In Progress + Handoff Notes, ≤$WORK_STATUS_LIMIT lines) ---"
    awk '/^## In Progress|^## Session Handoff Notes/{flag=1; print; next} /^## /{flag=0} flag' "$WORK_STATUS" | head -$WORK_STATUS_LIMIT
    echo
fi

READ_LOG="$SESSIONS_DIR/read-log.tsv"
if [[ -f "$READ_LOG" ]]; then
    CUTOFF=$(( $(date +%s) - 86400 ))
    RECENT=$(awk -F'\t' -v c=$CUTOFF '
        $1 >= c { latest[$4]=$0 }
        END { for (p in latest) print latest[p] }
    ' "$READ_LOG" 2>/dev/null | sort -t$'\t' -k1,1nr | head -20)
    if [[ -n "$RECENT" ]]; then
        echo "--- files AI touched in last 24h (advisory — not guaranteed in current context) ---"
        echo "$RECENT"
        echo
    fi
fi

GIT_DIR_W=$(git rev-parse --git-dir 2>/dev/null || echo "")
GIT_COMMON_W=$(git rev-parse --git-common-dir 2>/dev/null || echo "$GIT_DIR_W")
if [[ -n "$GIT_DIR_W" && "$GIT_DIR_W" != "$GIT_COMMON_W" ]]; then
    if [[ ! -e "$PROJECT_ROOT/.claude" ]] || [[ -d "$PROJECT_ROOT/.claude" && -z "$(ls -A "$PROJECT_ROOT/.claude" 2>/dev/null)" ]]; then
        echo "--- WORKTREE WARNING ---"
        echo "Running in git worktree: $PROJECT_ROOT"
        echo ".claude/ is missing or empty — run: ./tmp-igbkp/setup-worktree.sh"
        echo
    fi
fi

if [[ -f "$HOOK_ERRORS" ]]; then
    CUTOFF=$(date -d '24 hours ago' -Iseconds 2>/dev/null || date -u -v-24H +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null || echo "")
    if [[ -n "$CUTOFF" ]]; then
        RECENT_ERRS=$(awk -F'\t' -v c="$CUTOFF" '$1 >= c' "$HOOK_ERRORS" 2>/dev/null | tail -5)
        if [[ -n "$RECENT_ERRS" ]]; then
            echo "--- HOOK ERRORS in last 24h ---"
            echo "$RECENT_ERRS"
            echo "Inspect: $HOOK_ERRORS"
            echo
        fi
    fi
fi

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

echo "==== END RESUME CONTEXT — proceed with the user's request ===="
