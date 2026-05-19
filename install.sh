#!/usr/bin/env bash
# AIPS installer — user-level, idempotent, no sudo.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/install.sh | bash
#   bash install.sh [--no-plugin-update] [--with codex,caveman,agentmemory,rtk] [--local-source <path>] [--dry-run] [--quiet]
#
# After plugin install, globalizes templates/tmp-igbkp/*.sh as ~/.local/bin/aips-*
# symlinks so per-project copies are no longer needed. Backup output stays per-project.

set -euo pipefail

# Resolve the AIPS plugin version dynamically (never hardcoded).
# Order: local clone (when --local-source) → installed cache → GitHub raw.
read_plugin_version() {
  local v=""
  # 1. Local source clone (passed via --local-source).
  if [ -n "${LOCAL_SOURCE:-}" ] && [ -f "$LOCAL_SOURCE/.claude-plugin/plugin.json" ]; then
    v="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$LOCAL_SOURCE/.claude-plugin/plugin.json" | head -1)"
    [ -n "$v" ] && { printf '%s' "$v"; return; }
  fi
  # 2. Already-installed cache (find highest version dir).
  local cache_root="$HOME/.claude/plugins/cache/AIPS/AIPS"
  if [ -d "$cache_root" ]; then
    local latest_manifest
    latest_manifest="$(find "$cache_root" -maxdepth 3 -name plugin.json 2>/dev/null | sort -V | tail -1)"
    if [ -n "$latest_manifest" ] && [ -f "$latest_manifest" ]; then
      v="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$latest_manifest" | head -1)"
      [ -n "$v" ] && { printf '%s' "$v"; return; }
    fi
  fi
  # 3. GitHub raw URL (network).
  if command -v curl >/dev/null 2>&1; then
    v="$(curl -fsSL --max-time 10 'https://raw.githubusercontent.com/kernalix7/AIPS/main/.claude-plugin/plugin.json' 2>/dev/null \
      | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    [ -n "$v" ] && { printf '%s' "$v"; return; }
  fi
  printf 'unknown'
}

# ---------- color / logging ----------
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_RESET="$(tput sgr0)"; C_BLUE="$(tput setaf 4)"; C_GREEN="$(tput setaf 2)"
  C_YELLOW="$(tput setaf 3)"; C_RED="$(tput setaf 1)"; C_DIM="$(tput dim 2>/dev/null || echo '')"
  C_BOLD="$(tput bold)"; C_CYAN="$(tput setaf 6)"
else
  C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_BOLD=""; C_CYAN=""
fi
log()    { printf "%s[install]%s %s\n" "$C_BLUE"   "$C_RESET" "$*"; }
ok()     { printf "%s[ok]%s %s\n"      "$C_GREEN"  "$C_RESET" "$*"; }
warn()   { printf "%s[warn]%s %s\n"    "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()    { printf "%s[error]%s %s\n"   "$C_RED"    "$C_RESET" "$*" >&2; }
step()   { printf "\n%s═══ Step %s/%s: %s%s\n" "$C_BOLD" "$1" "$2" "$3" "$C_RESET"; }
detail() { [ "$QUIET" = "1" ] || printf "  %s%s%s\n" "$C_DIM" "$*" "$C_RESET"; }

# ---------- defaults / flags ----------
NO_PLUGIN_UPDATE=0
WITH_DEPS="codex,caveman,agentmemory,rtk"
LOCAL_SOURCE=""
DRY_RUN=0
QUIET=0
FAILED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --no-plugin-update) NO_PLUGIN_UPDATE=1; shift ;;
    --with)             WITH_DEPS="${2:-}"; shift 2 ;;
    --with=*)           WITH_DEPS="${1#--with=}"; shift ;;
    --local-source)     LOCAL_SOURCE="${2:-}"; shift 2 ;;
    --local-source=*)   LOCAL_SOURCE="${1#--local-source=}"; shift ;;
    --dry-run)          DRY_RUN=1; shift ;;
    --quiet)            QUIET=1; shift ;;
    -h|--help)
      sed -n '2,8p' "$0"; exit 0 ;;
    *) err "unknown flag: $1"; exit 1 ;;
  esac
done

want() { case ",$WITH_DEPS," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

run() {
  if [ "$DRY_RUN" = "1" ]; then printf "  %s[dry-run]%s %s\n" "$C_DIM" "$C_RESET" "$*"; return 0; fi
  eval "$@"
}

# Count total steps based on enabled deps
TOTAL_STEPS=3   # pre-flight, AIPS plugin, globalize
want codex      && TOTAL_STEPS=$((TOTAL_STEPS+1))
want caveman    && TOTAL_STEPS=$((TOTAL_STEPS+1))
want agentmemory && TOTAL_STEPS=$((TOTAL_STEPS+1))
want rtk        && TOTAL_STEPS=$((TOTAL_STEPS+1))
[ "$(uname -s 2>/dev/null)" = "Linux" ] && want agentmemory && TOTAL_STEPS=$((TOTAL_STEPS+1))

CUR_STEP=0
next_step() { CUR_STEP=$((CUR_STEP+1)); step "$CUR_STEP" "$TOTAL_STEPS" "$1"; }

# ---------- banner ----------
PLUGIN_VERSION="$(read_plugin_version)"
printf "\n%s%s╔════════════════════════════════════════════════════════════════╗%s\n" "$C_BOLD" "$C_CYAN" "$C_RESET"
printf "%s%s║  AIPS v%-7s installer — Claude Code plugin distribution     ║%s\n" "$C_BOLD" "$C_CYAN" "$PLUGIN_VERSION" "$C_RESET"
printf "%s%s║  Repo: https://github.com/kernalix7/AIPS                       ║%s\n" "$C_BOLD" "$C_CYAN" "$C_RESET"
printf "%s%s║  License: MIT                                                  ║%s\n" "$C_BOLD" "$C_CYAN" "$C_RESET"
printf "%s%s╚════════════════════════════════════════════════════════════════╝%s\n\n" "$C_BOLD" "$C_CYAN" "$C_RESET"

printf "Selected dependencies: %s%s%s\n" "$C_GREEN" "$WITH_DEPS" "$C_RESET"
[ "$DRY_RUN" = "1" ] && printf "Mode: %sDRY RUN%s (no changes will be made)\n" "$C_YELLOW" "$C_RESET"

# Detect pipe vs TTY (curl | bash leaves stdin = pipe)
PIPED_INPUT=0
if [ ! -t 0 ]; then
  PIPED_INPUT=1
  if [ -r /dev/tty ]; then
    detail "stdin is piped — interactive prompts will read from /dev/tty"
  else
    warn "stdin is piped and /dev/tty unavailable — interactive prompts will fail. Consider downloading install.sh and running locally."
  fi
fi

# ---------- Step 1: pre-flight ----------
next_step "Pre-flight checks"

# bash >= 4.0
if [ -z "${BASH_VERSINFO:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  err "bash >= 4.0 required (found: ${BASH_VERSION:-unknown})"; exit 1
fi
ok "bash ${BASH_VERSION%%[^0-9.]*}"

for bin in git curl; do
  if ! command -v "$bin" >/dev/null 2>&1; then err "missing required: $bin"; exit 1; fi
done
ok "git, curl present"

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
  ok "node v${NODE_V} (required by agentmemory npx)"
fi

if ! command -v claude >/dev/null 2>&1; then
  err "claude CLI not found — install Claude Code first: https://claude.com/claude-code"; exit 1
fi
CLAUDE_V="$(claude --version 2>&1 | head -1 | awk '{print $NF}' 2>/dev/null || echo present)"
ok "claude CLI present (${CLAUDE_V})"

UNAME="$(uname -s 2>/dev/null || echo unknown)"
case "$UNAME" in
  Linux)  command -v systemctl >/dev/null 2>&1 && ok "systemctl present (Linux user services)" || warn "systemctl not found (agentmemory service step will be skipped)" ;;
  Darwin) command -v launchctl >/dev/null 2>&1 && ok "launchctl present (macOS, manual agentmemory)" || warn "launchctl not found" ;;
  *)      warn "unknown OS: $UNAME — service auto-start not supported" ;;
esac

# ---------- helpers ----------
# Run claude plugin subcommands non-interactively with a hard timeout.
# These subcommands (claude plugin marketplace add | claude plugin install)
# are the proper non-interactive entry points, unlike `claude --print
# "/plugin install ..."` which goes through the slash-command UI and
# may stall waiting for a confirm prompt.
claude_plugin() {
  if [ "$DRY_RUN" = "1" ]; then
    printf "  %s[dry-run]%s claude plugin %s\n" "$C_DIM" "$C_RESET" "$*"
    return 0
  fi
  local timeout_secs="${CLAUDE_CMD_TIMEOUT:-180}"
  if command -v timeout >/dev/null 2>&1; then
    timeout "${timeout_secs}s" claude plugin "$@" </dev/null 2>&1
  else
    claude plugin "$@" </dev/null 2>&1
  fi
}

# Plugin cache path for spec "name@marketplace" — used to verify installs.
plugin_cache_dir() {
  local spec="$1"
  local name="${spec%@*}"
  local market="${spec##*@}"
  printf "%s/.claude/plugins/cache/%s/%s" "$HOME" "$market" "$name"
}

# Marketplace registration. Uses `claude plugin marketplace add <src>`,
# then verifies via ~/.claude/plugins/known_marketplaces.json so the
# script always knows whether the marketplace is actually registered.
marketplace_add() {
  local src="$1" label="$2"
  detail "marketplace source: $src"
  if [ "$DRY_RUN" = "1" ]; then
    claude_plugin marketplace add "$src" >/dev/null
    ok "marketplace added: $label (dry-run)"
    return 0
  fi
  local out rc=0
  out="$(claude_plugin marketplace add "$src")" || rc=$?
  if printf "%s" "$out" | grep -qiE "already (added|registered)|exists"; then
    ok "marketplace already registered: $label"
    return 0
  fi
  if [ -f "$HOME/.claude/plugins/known_marketplaces.json" ] \
       && grep -qiF "$src" "$HOME/.claude/plugins/known_marketplaces.json" 2>/dev/null; then
    ok "marketplace registered: $label"
    return 0
  fi
  if [ "$rc" -eq 124 ]; then
    warn "marketplace add timed out after ${CLAUDE_CMD_TIMEOUT:-180}s ($label) — output: $(printf '%s' "$out" | tail -1)"
  else
    warn "marketplace add exit=$rc ($label) — output: $(printf '%s' "$out" | tail -1)"
  fi
  return 1
}

# Plugin install via `claude plugin install <spec> --scope user`.
# After the call, verify the cache directory has content. Falls back
# to /plugin update if the plugin was already installed.
plugin_install() {
  local spec="$1" label="$2"
  detail "plugin spec: $spec"
  local cache_dir
  cache_dir="$(plugin_cache_dir "$spec")"
  if [ "$DRY_RUN" = "1" ]; then
    claude_plugin install "$spec" --scope user >/dev/null
    ok "$label installed (dry-run)"
    return 0
  fi
  local out rc=0
  # Already installed? -> update path (subject to --no-plugin-update).
  if [ -d "$cache_dir" ] && [ -n "$(ls -A "$cache_dir" 2>/dev/null)" ]; then
    if [ "$NO_PLUGIN_UPDATE" = "1" ]; then
      warn "$label already installed at $cache_dir — skipping update (--no-plugin-update)"
      return 0
    fi
    detail "already installed at $cache_dir — running claude plugin update $spec"
    out="$(claude_plugin update "$spec")" || rc=$?
    if [ "$rc" -eq 0 ]; then
      ok "$label updated"
    else
      warn "$label update exit=$rc — continuing with existing install"
    fi
    return 0
  fi
  # Fresh install.
  out="$(claude_plugin install "$spec" --scope user)" || rc=$?
  if printf "%s" "$out" | grep -qiE "already installed"; then
    ok "$label already installed (per CLI)"
    return 0
  fi
  # Verify cache dir was populated.
  if [ -d "$cache_dir" ] && [ -n "$(ls -A "$cache_dir" 2>/dev/null)" ]; then
    ok "$label installed (verified at $cache_dir)"
    return 0
  fi
  if [ "$rc" -eq 124 ]; then
    warn "$label install timed out after ${CLAUDE_CMD_TIMEOUT:-180}s"
  elif [ "$rc" -ne 0 ]; then
    warn "$label install exit=$rc"
  else
    warn "$label install returned 0 but cache dir is empty"
  fi
  echo "    CLI output (last 5 lines):"
  printf "%s\n" "$out" | tail -5 | sed 's/^/      /'
  echo "    Manual fallback:"
  echo "        claude plugin install $spec --scope user"
  return 1
}

# ---------- Step 2: AIPS plugin ----------
next_step "AIPS plugin (kernalix7/AIPS)"
detail "Purpose: this plugin — 11 /aips:* slash commands, 5 hooks, statusline, agents"
detail "Provides: /aips:{init,update,health,uninstall,status,migrate-from-md,upgrade,repair,reset,rebind,scope}"

if [ -n "$LOCAL_SOURCE" ]; then
  if [ ! -d "$LOCAL_SOURCE/.claude-plugin" ]; then
    err "--local-source path missing .claude-plugin/: $LOCAL_SOURCE"; exit 1
  fi
  marketplace_add "$LOCAL_SOURCE" "AIPS (local: $LOCAL_SOURCE)"
else
  marketplace_add "kernalix7/AIPS" "AIPS"
fi
plugin_install "AIPS@AIPS" "AIPS" || FAILED=1

# ---------- Step 3+: Dep plugins ----------
if want codex; then
  next_step "codex-plugin-cc (OpenAI official)"
  detail "Source: github.com/openai/codex-plugin-cc"
  detail "Provides: /codex:exec, /codex:review, /codex:status, /codex:setup"
  detail "Purpose: Claude ↔ Codex implementation relay — offload codegen to OpenAI Codex CLI"
  detail "Requires: ChatGPT subscription (incl. Free) OR OpenAI API key"
  detail "First-use: run /codex:setup inside Claude to authenticate"
  marketplace_add "openai/codex-plugin-cc" "openai-codex"
  plugin_install "codex@openai-codex" "codex-plugin-cc" || warn "codex install failed (non-fatal)"
fi

if want caveman; then
  next_step "caveman (ultra-compressed mode)"
  detail "Source: github.com/JuliusBrussee/caveman"
  detail "Provides: /caveman, /caveman-help, /caveman-stats, /caveman-commit, etc."
  detail "Purpose: ultra-terse communication mode — ~75% token savings while keeping technical accuracy"
  detail "Levels: lite (~40%), full (~75%, default), ultra (~85%)"
  marketplace_add "JuliusBrussee/caveman" "caveman"
  plugin_install "caveman@caveman" "caveman" || warn "caveman install failed (non-fatal)"
fi

if want agentmemory; then
  next_step "agentmemory (persistent memory + web viewer)"
  detail "Source: github.com/rohitg00/agentmemory"
  detail "Provides: 51 MCP tools (memory_save/recall/search), 12 hooks, 4 skills"
  detail "Purpose: persistent tool-use memory across sessions + real-time web viewer"
  detail "Web viewer: http://localhost:3113"
  detail "REST API: http://localhost:3111"
  detail "Storage: ~/.local/share/aips/history.db (SQLite)"
  marketplace_add "https://github.com/rohitg00/agentmemory.git" "agentmemory"
  plugin_install "agentmemory@agentmemory" "agentmemory" || warn "agentmemory install failed (non-fatal)"
fi

# ---------- RTK ----------
if want rtk; then
  next_step "RTK — Rust Token Killer"
  detail "Source: github.com/rtk-ai/rtk (curl installer)"
  detail "Purpose: token-optimized CLI proxy — 60–90% savings on dev operations"
  detail "Usage (after install): every shell command auto-rewritten via Claude Code hook"
  detail "Install location: ~/.local/bin/rtk"
  if command -v rtk >/dev/null 2>&1; then
    ok "RTK already installed: $(rtk --version 2>/dev/null || echo present)"
  else
    log "Downloading RTK installer..."
    if [ "$DRY_RUN" = "1" ]; then
      printf "  %s[dry-run]%s curl install.sh from rtk-ai/rtk\n" "$C_DIM" "$C_RESET"
    else
      curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh \
        && ok "RTK installed: $(rtk --version 2>/dev/null || echo present)" \
        || { warn "RTK install failed (non-fatal)"; }
    fi
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) : ;;
      *) warn "~/.local/bin not in PATH — add: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
    esac
  fi
fi

# Resolve a lib script across versioned cache subdirs.
# Plugin installs to ~/.claude/plugins/cache/AIPS/AIPS/<version>/lib/<name>.sh
aips_lib_script() {
  local name="$1"
  find "$HOME/.claude/plugins/cache/AIPS/AIPS" -maxdepth 3 -type f -name "$name" 2>/dev/null | sort -V | tail -1
}

# ---------- agentmemory service (Linux only) ----------
if want agentmemory && [ "$UNAME" = "Linux" ] && command -v systemctl >/dev/null 2>&1; then
  next_step "agentmemory systemd user service"
  detail "Unit: ~/.config/systemd/user/agentmemory.service"
  detail "Ports: 3111 (REST API), 3113 (web viewer)"
  detail "Restart policy: on-failure, 5-sec delay"
  detail "First-install: bilingual setup banner printed once"
  SVC_SCRIPT="$(aips_lib_script setup-agentmemory-service.sh)"
  if [ -n "$SVC_SCRIPT" ] && [ -f "$SVC_SCRIPT" ]; then
    detail "script: $SVC_SCRIPT"
    run "bash \"$SVC_SCRIPT\"" || warn "agentmemory service setup returned non-zero (continuing)"
  else
    warn "setup-agentmemory-service.sh not found under ~/.claude/plugins/cache/AIPS/AIPS/*/lib/ — skip"
  fi
fi

# ---------- Globalize toolkit ----------
next_step "Globalize toolkit (hybrid layout)"
detail "Symlinks 9 toolkit scripts → ~/.local/bin/aips-*"
detail "aips-archive, aips-restore, aips-purge-history, aips-verify-setup,"
detail "aips-uninstall, aips-smoke-test-hooks, aips-secret-guard,"
detail "aips-automode-validate, aips-setup-worktree"
detail "Per-project tmp-igbkp/ no longer needs script copies"
DRY_RUN_FLAG=""
[ "$DRY_RUN" = "1" ] && DRY_RUN_FLAG="--dry-run"
GLOBALIZE_SCRIPT="$(aips_lib_script globalize-toolkit.sh)"
if [ -n "$GLOBALIZE_SCRIPT" ] && [ -f "$GLOBALIZE_SCRIPT" ]; then
  detail "script: $GLOBALIZE_SCRIPT"
  bash "$GLOBALIZE_SCRIPT" $DRY_RUN_FLAG || warn "toolkit globalization failed (non-fatal)"
else
  warn "globalize-toolkit.sh not found under ~/.claude/plugins/cache/AIPS/AIPS/*/lib/ — skip"
fi

# ---------- Globalize AIPS gitignore block ----------
GLOBAL_GITIGNORE_SCRIPT="$(aips_lib_script setup-global-gitignore.sh)"
if [ -n "$GLOBAL_GITIGNORE_SCRIPT" ] && [ -f "$GLOBAL_GITIGNORE_SCRIPT" ]; then
  log "Installing AIPS .gitignore block at ~/.config/git/ignore..."
  detail "script: $GLOBAL_GITIGNORE_SCRIPT"
  bash "$GLOBAL_GITIGNORE_SCRIPT" $DRY_RUN_FLAG || warn "gitignore globalization failed (non-fatal)"
fi

# ---------- Final summary ----------
echo
# Re-resolve in case the cache was empty when the script started.
PLUGIN_VERSION="$(read_plugin_version)"
if [ "$FAILED" = "0" ]; then
  cat <<EOF

${C_BOLD}${C_GREEN}╔════════════════════════════════════════════════════════════════╗
║  AIPS v${PLUGIN_VERSION} install complete
╚════════════════════════════════════════════════════════════════╝${C_RESET}

${C_BOLD}Globals installed at:${C_RESET}
  ~/.claude/plugins/cache/AIPS/AIPS/                  ${C_DIM}(AIPS plugin)${C_RESET}
EOF
  want codex       && echo "  ~/.claude/plugins/cache/openai-codex/codex/         ${C_DIM}(codex-plugin-cc)${C_RESET}"
  want caveman     && echo "  ~/.claude/plugins/cache/caveman/caveman/            ${C_DIM}(caveman)${C_RESET}"
  want agentmemory && echo "  ~/.claude/plugins/cache/agentmemory/agentmemory/   ${C_DIM}(agentmemory)${C_RESET}"
  want rtk         && echo "  ~/.local/bin/rtk                                    ${C_DIM}(RTK binary)${C_RESET}"
  echo "  ~/.local/bin/aips-*                                 ${C_DIM}(9 toolkit symlinks)${C_RESET}"
  echo "  ~/.config/git/ignore                                ${C_DIM}(AIPS gitignore block)${C_RESET}"
  [ "$UNAME" = "Linux" ] && want agentmemory && echo "  ~/.config/systemd/user/agentmemory.service          ${C_DIM}(daemon, ports 3111/3113)${C_RESET}"
  cat <<EOF

${C_BOLD}Slash commands now available:${C_RESET}
  ${C_GREEN}/aips:${C_RESET} init, update, health, uninstall, status, migrate-from-md,
         upgrade, repair, reset, rebind, scope          ${C_DIM}(11 commands)${C_RESET}
EOF
  want codex       && echo "  ${C_GREEN}/codex:${C_RESET} exec, review, status, setup                ${C_DIM}(from codex-plugin-cc)${C_RESET}"
  want caveman     && echo "  ${C_GREEN}/caveman${C_RESET} + /caveman-help/stats/commit/review     ${C_DIM}(from caveman)${C_RESET}"
  want agentmemory && echo "  ${C_GREEN}/agentmemory:${C_RESET} (51 MCP tools, accessed by AI)      ${C_DIM}(from agentmemory)${C_RESET}"
  cat <<EOF

${C_BOLD}Next steps:${C_RESET}
  ${C_CYAN}cd${C_RESET} your-project && ${C_CYAN}claude${C_RESET}
  > ${C_GREEN}/aips:init${C_RESET}               ${C_DIM}# bootstrap project (~30 sec)${C_RESET}
  > ${C_GREEN}/aips:health${C_RESET}             ${C_DIM}# verify install${C_RESET}
  > ${C_GREEN}/aips:scope${C_RESET}              ${C_DIM}# see global vs per-project state${C_RESET}

${C_BOLD}To uninstall later:${C_RESET}
  curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/uninstall.sh | bash

${C_BOLD}Docs:${C_RESET} https://github.com/kernalix7/AIPS

EOF
  exit 0
else
  err "AIPS install completed with errors — review log above."
  exit 1
fi
