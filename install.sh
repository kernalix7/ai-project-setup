#!/usr/bin/env bash
# AIPS v6.0 installer — user-level, idempotent, no sudo.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/install.sh | bash
#   bash install.sh [--no-plugin-update] [--with codex,caveman,agentmemory,rtk] [--local-source <path>] [--dry-run]

set -euo pipefail

# ---------- color / logging ----------
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_RESET="$(tput sgr0)"; C_BLUE="$(tput setaf 4)"; C_GREEN="$(tput setaf 2)"
  C_YELLOW="$(tput setaf 3)"; C_RED="$(tput setaf 1)"
else
  C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi
log()  { printf "%s[install]%s %s\n" "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf "%s[ok]%s %s\n"      "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf "%s[warn]%s %s\n"    "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf "%s[error]%s %s\n"   "$C_RED"    "$C_RESET" "$*" >&2; }

# ---------- defaults / flags ----------
NO_PLUGIN_UPDATE=0
WITH_DEPS="codex,caveman,agentmemory,rtk"
LOCAL_SOURCE=""
DRY_RUN=0
FAILED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --no-plugin-update) NO_PLUGIN_UPDATE=1; shift ;;
    --with)             WITH_DEPS="${2:-}"; shift 2 ;;
    --with=*)           WITH_DEPS="${1#--with=}"; shift ;;
    --local-source)     LOCAL_SOURCE="${2:-}"; shift 2 ;;
    --local-source=*)   LOCAL_SOURCE="${1#--local-source=}"; shift ;;
    --dry-run)          DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,6p' "$0"; exit 0 ;;
    *) err "unknown flag: $1"; exit 1 ;;
  esac
done

want() { case ",$WITH_DEPS," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

run() {
  if [ "$DRY_RUN" = "1" ]; then printf "  [dry-run] %s\n" "$*"; return 0; fi
  eval "$@"
}

# ---------- pre-checks ----------
log "AIPS v6.0 installer — pre-flight checks"

# bash >= 4.0
if [ -z "${BASH_VERSINFO:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  err "bash >= 4.0 required (found: ${BASH_VERSION:-unknown})"; exit 1
fi
ok "bash ${BASH_VERSION%%[^0-9.]*}"

for bin in git curl; do
  if ! command -v "$bin" >/dev/null 2>&1; then err "missing required: $bin"; exit 1; fi
done
ok "git, curl present"

# node >= 18.18 (for agentmemory npx) — only if agentmemory requested
if want agentmemory; then
  if ! command -v node >/dev/null 2>&1; then
    err "node >= 18.18 required for agentmemory (install nodejs or run --with without agentmemory)"; exit 1
  fi
  NODE_V="$(node -v 2>/dev/null | sed 's/^v//')"
  NODE_MAJOR="${NODE_V%%.*}"
  NODE_REST="${NODE_V#*.}"; NODE_MINOR="${NODE_REST%%.*}"
  if [ "${NODE_MAJOR:-0}" -lt 18 ] || { [ "${NODE_MAJOR}" -eq 18 ] && [ "${NODE_MINOR:-0}" -lt 18 ]; }; then
    err "node >= 18.18 required (found: v${NODE_V})"; exit 1
  fi
  ok "node v${NODE_V}"
fi

# claude CLI
if ! command -v claude >/dev/null 2>&1; then
  err "claude CLI not found — install Claude Code first: https://claude.com/claude-code"; exit 1
fi
ok "claude CLI present"

# OS-specific service manager (informational only)
UNAME="$(uname -s 2>/dev/null || echo unknown)"
case "$UNAME" in
  Linux)  command -v systemctl >/dev/null 2>&1 && ok "systemctl present" || warn "systemctl not found (agentmemory service step will be skipped)" ;;
  Darwin) command -v launchctl >/dev/null 2>&1 && ok "launchctl present" || warn "launchctl not found" ;;
  *)      warn "unknown OS: $UNAME — service auto-start not supported" ;;
esac

# ---------- helpers ----------
claude_cmd() {
  # Run claude in print mode, swallow non-fatal output, return its exit code.
  if [ "$DRY_RUN" = "1" ]; then printf "  [dry-run] claude --print %q\n" "$1"; return 0; fi
  claude --print "$1" 2>&1 || return $?
}

marketplace_add() {
  local src="$1" label="$2"
  log "Registering marketplace: $label ($src)"
  if claude_cmd "/plugin marketplace add $src" | grep -qiE "already (added|registered)|exists"; then
    ok "marketplace already registered: $label"
  else
    ok "marketplace added: $label"
  fi
}

plugin_install() {
  local spec="$1" label="$2"
  log "Installing plugin: $label ($spec)"
  local out; out="$(claude_cmd "/plugin install $spec" || true)"
  if printf "%s" "$out" | grep -qiE "already installed"; then
    if [ "$NO_PLUGIN_UPDATE" = "1" ]; then
      warn "$label already installed — skipping update (--no-plugin-update)"
    else
      log "Updating $label"
      claude_cmd "/plugin update $spec" >/dev/null || warn "$label update returned non-zero (continuing)"
      ok "$label updated"
    fi
  else
    ok "$label installed"
  fi
}

# ---------- A. Register AIPS marketplace ----------
if [ -n "$LOCAL_SOURCE" ]; then
  if [ ! -d "$LOCAL_SOURCE/.claude-plugin" ]; then
    err "--local-source path missing .claude-plugin/: $LOCAL_SOURCE"; exit 1
  fi
  marketplace_add "$LOCAL_SOURCE" "AIPS (local: $LOCAL_SOURCE)"
else
  marketplace_add "kernalix7/AIPS" "AIPS"
fi

# ---------- B. Install/update AIPS ----------
plugin_install "AIPS@AIPS" "AIPS" || FAILED=1

# ---------- C. Dep plugins ----------
if want codex; then
  marketplace_add "openai/codex-plugin-cc" "openai-codex"
  plugin_install "codex@openai-codex" "codex-plugin-cc" || warn "codex install failed (non-fatal)"
fi

if want caveman; then
  marketplace_add "JuliusBrussee/caveman" "caveman"
  plugin_install "caveman@caveman" "caveman" || warn "caveman install failed (non-fatal)"
fi

if want agentmemory; then
  marketplace_add "https://github.com/rohitg00/agentmemory.git" "agentmemory"
  plugin_install "agentmemory@agentmemory" "agentmemory" || warn "agentmemory install failed (non-fatal)"
fi

# ---------- D. RTK ----------
if want rtk; then
  if command -v rtk >/dev/null 2>&1; then
    ok "RTK already installed: $(rtk --version 2>/dev/null || echo present)"
  else
    log "Installing RTK"
    if [ "$DRY_RUN" = "1" ]; then
      printf "  [dry-run] curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh\n"
    else
      curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh \
        && ok "RTK installed" \
        || { warn "RTK install failed (non-fatal)"; }
    fi
    # PATH guard
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) : ;;
      *) warn "~/.local/bin not in PATH — add: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
    esac
  fi
fi

# ---------- E. agentmemory service (Linux only) ----------
if want agentmemory && [ "$UNAME" = "Linux" ] && command -v systemctl >/dev/null 2>&1; then
  SVC_SCRIPT="$HOME/.claude/plugins/cache/AIPS/AIPS/lib/setup-agentmemory-service.sh"
  if [ -x "$SVC_SCRIPT" ] || [ -f "$SVC_SCRIPT" ]; then
    log "Configuring agentmemory systemd service"
    run "bash \"$SVC_SCRIPT\"" || warn "agentmemory service setup returned non-zero (continuing)"
  else
    warn "agentmemory service script not found at $SVC_SCRIPT — skip (will retry on next /aips:init)"
  fi
fi

# ---------- Post-install report ----------
echo
if [ "$FAILED" = "0" ]; then
  ok "AIPS v6.0 installed globally."
  ok "Dependency plugins: $WITH_DEPS"
  echo
  echo "In each project:"
  echo "  \$ cd your-project && claude"
  echo "  > /aips:init"
  exit 0
else
  err "AIPS install completed with errors — review log above."
  exit 1
fi
