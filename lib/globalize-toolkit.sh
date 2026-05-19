#!/usr/bin/env bash
# AIPS v7.0 — globalize toolkit scripts to ~/.local/bin/aips-*
# Symlinks the 9 templates/tmp-igbkp/*.sh scripts so per-project copies are unneeded.
# Called from install.sh during global setup and from /aips:upgrade --to v7.0.
#
# Usage:
#   bash globalize-toolkit.sh            # symlink/relink as needed
#   bash globalize-toolkit.sh --dry-run  # print actions, no FS changes
#   bash globalize-toolkit.sh --unlink   # remove all aips-* symlinks (clean uninstall)

set -euo pipefail

# ---------- color / logging ----------
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_RESET="$(tput sgr0)"; C_BLUE="$(tput setaf 4)"; C_GREEN="$(tput setaf 2)"
  C_YELLOW="$(tput setaf 3)"; C_RED="$(tput setaf 1)"
else
  C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi
log()  { printf "%s[globalize]%s %s\n" "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf "%s[ok]%s %s\n"        "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf "%s[warn]%s %s\n"      "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf "%s[error]%s %s\n"     "$C_RED"    "$C_RESET" "$*" >&2; }

# ---------- flags ----------
DRY_RUN=0
UNLINK=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --unlink)  UNLINK=1 ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) err "unknown flag: $arg"; exit 1 ;;
  esac
done

run() {
  if [ "$DRY_RUN" = "1" ]; then printf "  [dry-run] %s\n" "$*"; return 0; fi
  eval "$@"
}

# ---------- canonical script list ----------
SCRIPTS=(archive restore purge-history verify-setup uninstall smoke-test-hooks secret-guard automode-validate setup-worktree)
BIN_DIR="${HOME}/.local/bin"
TS="$(date +%Y%m%d-%H%M%S)"

# ---------- unlink mode (clean uninstall) ----------
if [ "$UNLINK" = "1" ]; then
  log "Removing aips-* symlinks from ${BIN_DIR}"
  removed=0
  for name in "${SCRIPTS[@]}"; do
    target="${BIN_DIR}/aips-${name}"
    if [ -L "$target" ]; then
      run "rm -f \"$target\"" && { ok "unlinked aips-${name}"; removed=$((removed+1)); }
    elif [ -e "$target" ]; then
      warn "aips-${name} exists but is not a symlink — skipping (manual review)"
    fi
  done
  ok "Removed ${removed}/${#SCRIPTS[@]} aips-* symlinks"
  exit 0
fi

# ---------- pre-check: ensure ~/.local/bin exists ----------
if [ ! -d "$BIN_DIR" ]; then
  log "Creating ${BIN_DIR}"
  run "mkdir -p \"$BIN_DIR\""
fi

# PATH warning
case ":${PATH}:" in
  *":${BIN_DIR}:"*) : ;;
  *) warn "${BIN_DIR} not in \$PATH — add: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

# ---------- source resolution ----------
# Prefer installed plugin location, fallback to CLAUDE_PLUGIN_ROOT, fallback to script-relative.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

resolve_source() {
  local name="$1"
  local candidates=(
    "${HOME}/.claude/plugins/cache/AIPS/AIPS/templates/tmp-igbkp/${name}.sh"
    "${CLAUDE_PLUGIN_ROOT:-}/templates/tmp-igbkp/${name}.sh"
    "${REPO_ROOT}/templates/tmp-igbkp/${name}.sh"
  )
  for c in "${candidates[@]}"; do
    [ -n "$c" ] && [ -f "$c" ] && { printf "%s" "$c"; return 0; }
  done
  return 1
}

# ---------- symlink loop ----------
log "Globalizing toolkit scripts to ${BIN_DIR}/aips-*"
linked=0
for name in "${SCRIPTS[@]}"; do
  src="$(resolve_source "$name" || true)"
  if [ -z "$src" ]; then
    warn "source not found for ${name}.sh — skipping"
    continue
  fi
  target="${BIN_DIR}/aips-${name}"

  if [ -L "$target" ]; then
    current="$(readlink "$target")"
    if [ "$current" = "$src" ]; then
      ok "aips-${name} -> ${src} (already linked)"
      linked=$((linked+1))
      continue
    fi
    # symlink points elsewhere — back up old link then relink
    run "mv \"$target\" \"${target}.bak.${TS}\""
  elif [ -e "$target" ]; then
    # real file — back up before replacing
    run "mv \"$target\" \"${target}.bak.${TS}\""
  fi

  run "ln -s \"$src\" \"$target\""
  ok "aips-${name} -> ${src}"
  linked=$((linked+1))
done

echo
ok "Globalized ${linked}/${#SCRIPTS[@]} toolkit scripts to ${BIN_DIR}/aips-*"

# Also link the statusline to a stable path so per-project settings.json can
# reference $HOME/.local/bin/aips-statusline (version-independent) instead of
# the version-pinned plugin cache path.
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATUSLINE_SRC="$PLUGIN_ROOT/statusline"
STATUSLINE_TARGET="${BIN_DIR}/aips-statusline"
if [ -f "$STATUSLINE_SRC" ]; then
  if [ -L "$STATUSLINE_TARGET" ]; then
    cur="$(readlink -f "$STATUSLINE_TARGET" 2>/dev/null || readlink "$STATUSLINE_TARGET")"
    if [ "$cur" = "$STATUSLINE_SRC" ] || [ "$cur" = "$(readlink -f "$STATUSLINE_SRC" 2>/dev/null)" ]; then
      ok "aips-statusline -> ${STATUSLINE_SRC} (already current)"
    else
      run "mv \"$STATUSLINE_TARGET\" \"${STATUSLINE_TARGET}.bak.${TS}\""
      run "ln -s \"$STATUSLINE_SRC\" \"$STATUSLINE_TARGET\""
      ok "aips-statusline -> ${STATUSLINE_SRC}"
    fi
  elif [ -e "$STATUSLINE_TARGET" ]; then
    run "mv \"$STATUSLINE_TARGET\" \"${STATUSLINE_TARGET}.bak.${TS}\""
    run "ln -s \"$STATUSLINE_SRC\" \"$STATUSLINE_TARGET\""
    ok "aips-statusline -> ${STATUSLINE_SRC}"
  else
    run "ln -s \"$STATUSLINE_SRC\" \"$STATUSLINE_TARGET\""
    ok "aips-statusline -> ${STATUSLINE_SRC}"
  fi
else
  warn "statusline source not found at $STATUSLINE_SRC — skipping aips-statusline symlink"
fi
