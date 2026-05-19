#!/usr/bin/env bash
# PreToolUse.sh — Blocks high-risk commands. Runs before every Bash tool call.
# AIPS v6.0 plugin-distributed hook. Always active (blocks dangerous commands even when .priv-storage/ absent).
set -u

[[ "${HOOKS_DISABLED:-0}" == "1" ]] && exit 0

PAYLOAD=$(cat 2>/dev/null || echo "{}")

if command -v jq >/dev/null 2>&1; then
    TOOL=$(echo "$PAYLOAD" | jq -r '.tool_name // ""')
    CMD=$(echo "$PAYLOAD" | jq -r '.tool_input.command // ""')
    FILE_PATH=$(echo "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.path // ""')
else
    TOOL=$(echo "$PAYLOAD" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    CMD=$(echo "$PAYLOAD" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -1)
    FILE_PATH=$(echo "$PAYLOAD" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    [[ -z "$FILE_PATH" ]] && FILE_PATH=$(echo "$PAYLOAD" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT" 2>/dev/null || true
TOGGLE="$PROJECT_ROOT/.priv-storage/.allow-setup-reread"

HOOK_ERRORS="$HOME/.claude/hook-errors.log"
trap 'rc=$?; [[ $rc -ne 0 && $rc -ne 2 ]] && printf "%s\tPreToolUse.sh\trc=%d\tcmd=%s\n" "$(date -Iseconds 2>/dev/null || date)" "$rc" "${BASH_COMMAND:-?}" >> "$HOOK_ERRORS" 2>/dev/null; exit $rc' ERR

block() {
    echo "BLOCKED by PreToolUse.sh: $1" >&2
    [[ -n "${CMD:-}" ]] && echo "Command: $CMD" >&2
    [[ -n "${FILE_PATH:-}" ]] && echo "File: $FILE_PATH" >&2
    exit 2
}

warn() {
    echo "WARNING from PreToolUse.sh: $1" >&2
}

if [[ "$TOOL" == "Read" && -n "$FILE_PATH" && -f "$FILE_PATH" ]]; then
    OFFSET="" LIMIT=""
    if command -v jq >/dev/null 2>&1; then
        OFFSET=$(echo "$PAYLOAD" | jq -r '.tool_input.offset // empty')
        LIMIT=$(echo "$PAYLOAD" | jq -r '.tool_input.limit // empty')
    fi
    if [[ -z "$OFFSET" && -z "$LIMIT" ]]; then
        LINES=$(wc -l < "$FILE_PATH" 2>/dev/null || echo 0)
        case "$FILE_PATH" in
            *.ts|*.tsx|*.js|*.jsx|*.py|*.rs|*.go|*.java|*.cpp|*.c|*.h|*.hpp|*.sh|*.rb|*.swift|*.kt|*.cs|*.php) THRESHOLD=1000 ;;
            *.md|*.csv|*.json|*.log|*.txt|*.yml|*.yaml|*.xml|*.toml|*.ini|*.conf) THRESHOLD=2000 ;;
            *) THRESHOLD=1500 ;;
        esac
        if [[ "$LINES" -gt "$THRESHOLD" ]]; then
            block "Read of $FILE_PATH ($LINES lines, threshold $THRESHOLD) without offset/limit. Per Rule #20: use offset/limit or delegate to explorer subagent."
        fi
    fi
fi

case "$TOOL" in
    Read|Edit|Write|NotebookEdit)
        case "$FILE_PATH" in
            *AI_PROJECT_SETUP.md|*.priv-storage/AI_PROJECT_SETUP.md)
                if [[ -f "$TOGGLE" ]]; then
                    rm -f "$TOGGLE"
                    echo "[PreToolUse] AI_PROJECT_SETUP.md access ALLOWED (toggle consumed)" >&2
                    exit 0
                fi
                block "AI_PROJECT_SETUP.md is large (~25k tokens). Read POST_SETUP_INDEX.md instead. To allow one-time access: touch .priv-storage/.allow-setup-reread"
                ;;
        esac
        ;;
esac

[[ -n "$TOOL" && "$TOOL" != "Bash" ]] && exit 0
[[ -z "$CMD" ]] && exit 0

case "$CMD" in
    *AI_PROJECT_SETUP.md*)
        case "$CMD" in
            *"head -1"*|*"head -n 1"*|*"wc -l"*|*"ls "*|*"test -"*|*"[ -e "*|*"[ -f "*) exit 0 ;;
        esac
        if [[ -f "$TOGGLE" ]]; then
            rm -f "$TOGGLE"
            echo "[PreToolUse] AI_PROJECT_SETUP.md Bash access ALLOWED (toggle consumed)" >&2
            exit 0
        fi
        block "Bash command touches AI_PROJECT_SETUP.md. Use specific line range. To allow: touch .priv-storage/.allow-setup-reread"
        ;;
esac

case "$CMD" in
    *"touch .priv-storage/.allow-setup-reread"*|*"> .priv-storage/.allow-setup-reread"*)
        warn "AI is creating the setup-reread toggle. Bypasses Rule #18. Expected only for explicit 'update AI_PROJECT_SETUP' requests." ;;
esac

case "$CMD" in
    *"rm -rf /"*|*"rm -rf /*"*|*"rm -rf ~"*|*"rm -rf \$HOME"*) block "rm -rf on root/home" ;;
    *"rm -fr /"*|*"rm -fr /*"*|*"rm -fr ~"*) block "rm -fr on root/home" ;;
    *":(){ :|:& };:"*|*":(){:|:&};:"*) block "fork bomb" ;;
    *"dd if=/dev/zero of=/"*|*"dd if=/dev/random of=/"*) block "dd to root device" ;;
    *"mkfs"*) block "mkfs" ;;
    *"shred /"*|*"shred -u /"*) block "shred on root" ;;
esac

case "$CMD" in
    *"curl"*"|"*"sh"*|*"curl"*"|"*"bash"*|*"curl"*"|"*"zsh"*) block "curl piped to shell" ;;
    *"wget"*"|"*"sh"*|*"wget"*"|"*"bash"*) block "wget piped to shell" ;;
    *"base64 -d"*"|"*"sh"*|*"base64 --decode"*"|"*"sh"*|*"base64 -d"*"|"*"bash"*) block "base64 piped to shell" ;;
    *"eval \$("*|*"eval \`"*) block "eval \$(...)" ;;
esac

case "$CMD" in
    *"sudo "*)
        if echo "$CMD" | grep -qE '^[[:space:]]*sudo[[:space:]]+(-n[[:space:]]|--non-interactive)'; then
            warn "sudo -n — confirm intent"
        else
            block "sudo without -n — would prompt for password"
        fi ;;
    *"su -"*|*"su root"*) block "su" ;;
    *"chmod 777"*|*"chmod -R 777"*) block "chmod 777" ;;
    *"chmod -R 666"*|*"chmod 666 -R"*) block "chmod -R 666" ;;
esac

case "$CMD" in
    *"git push --force"*|*"git push -f"*|*"git push origin --force"*)
        if ! echo "$CMD" | grep -q -- "--force-with-lease"; then
            block "force push without --force-with-lease"
        fi ;;
    *"git reset --hard"*) warn "git reset --hard — confirm intent" ;;
    *"--no-verify"*) block "--no-verify skips git hooks" ;;
    *"git filter-branch"*|*"git filter-repo"*) warn "history rewrite — notify collaborators" ;;
esac

case "$CMD" in
    *"cat .env"*|*"cat .env."*|*".env."*"credentials"*|*"cat ~/.aws/credentials"*) warn "reading .env/credentials" ;;
    *"cat ~/.ssh/id_"*|*"cat ~/.ssh/*key"*|*"cat /root/.ssh/"*) block "reading SSH private keys" ;;
    *"cat ~/.gnupg/"*|*"cat ~/.password-store/"*) block "reading password manager state" ;;
esac

GIT_ADD_RE='(^|[[:space:]]*[;&|]+[[:space:]]*)git[[:space:]]+add[[:space:]]+([^|;&]*[[:space:]]+)?'
GIT_COMMIT_RE='(^|[[:space:]]*[;&|]+[[:space:]]*)git[[:space:]]+commit[[:space:]]'

if echo "$CMD" | grep -qE "${GIT_ADD_RE}(\.|--?[Aa]l*|-u\b)([[:space:]]|$)"; then
    warn "git add . / -A / -u sweeps everything — verify no AI tooling staged. See Rule #19."
fi

if echo "$CMD" | grep -qE "${GIT_ADD_RE}([^|;&]*[[:space:]])?(\.priv-storage|tmp-igbkp|\.mcp\.json|CLAUDE\.local\.md|AGENTS\.md|WORK_STATUS\.md|\.cursorrules|\.claude(/|[[:space:]]|$)|\.vscode|CLAUDE\.md)"; then
    block "git add of an AI-tooling file. All gitignored by design. See Rule #19."
fi

if echo "$CMD" | grep -qE "${GIT_COMMIT_RE}.*(statusline|AI_PROJECT_SETUP|\.mcp\.json|\.priv-storage|hooks/|chore[(:][[:space:]]*setup|fix[(:][[:space:]]*setup)"; then
    warn "Commit message contains AI-tooling keyword. Per Rule #19, AI setup work must NOT enter project git history."
fi

case "$CMD" in
    *"rm -rf .priv-storage"*|*"rm -rf tmp-igbkp"*|*"rm -fr .priv-storage"*|*"rm -fr tmp-igbkp"*)
        block "rm -rf on .priv-storage/ or tmp-igbkp/ — use ./tmp-igbkp/uninstall.sh instead." ;;
esac

exit 0
