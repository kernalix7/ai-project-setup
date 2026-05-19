#!/usr/bin/env bash
# AIPS v6.0 — verify-init.sh
# Project-local post-init verification. Reports PASS / FAIL / WARN per check.
# Exits 0 if zero FAILs (any number of WARNs is OK), 1 otherwise.
#
# Usage:
#   bash lib/verify-init.sh [PROJECT_ROOT]    # default: $PWD

set -euo pipefail

ROOT="${1:-$PWD}"
ROOT="${ROOT%/}"
if [ ! -d "$ROOT" ]; then echo "[error] PROJECT_ROOT not a directory: $ROOT" >&2; exit 1; fi

# ---------- color ----------
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_RESET="$(tput sgr0)"; C_GREEN="$(tput setaf 2)"; C_YELLOW="$(tput setaf 3)"; C_RED="$(tput setaf 1)"
else
  C_RESET=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi

PASS_N=0; FAIL_N=0; WARN_N=0
pass() { PASS_N=$((PASS_N+1)); printf "  %sPASS%s %s\n" "$C_GREEN"  "$C_RESET" "$*"; }
fail() { FAIL_N=$((FAIL_N+1)); printf "  %sFAIL%s %s\n" "$C_RED"    "$C_RESET" "$*"; }
warn() { WARN_N=$((WARN_N+1)); printf "  %sWARN%s %s\n" "$C_YELLOW" "$C_RESET" "$*"; }
section() { printf "\n== %s ==\n" "$*"; }

# ---------- 1. .priv-storage skeleton ----------
section "1. .priv-storage skeleton"
if [ -d "$ROOT/.priv-storage" ]; then
  pass ".priv-storage/ exists"
else
  fail ".priv-storage/ missing"
fi
for sub in memory sessions; do
  if [ -d "$ROOT/.priv-storage/$sub" ]; then pass ".priv-storage/$sub/ exists"; else fail ".priv-storage/$sub/ missing"; fi
done

# ---------- 2. CLAUDE.md content sanity ----------
section "2. CLAUDE.md content"
CFILE="$ROOT/.priv-storage/CLAUDE.md"
if [ -f "$CFILE" ]; then
  pass "CLAUDE.md exists"
  for n in 1 2 3 4 5 6 7 11; do
    if grep -qE "^## ${n}\. " "$CFILE"; then
      pass "Section $n present"
    else
      fail "Section $n missing"
    fi
  done
  for n in 8 9 10 12 13; do
    if grep -qE "^## ${n}\. " "$CFILE"; then
      warn "Section $n still present (v6.0 expects it globalized)"
    fi
  done
else
  fail "CLAUDE.md missing"
fi

# ---------- 3. root symlinks ----------
section "3. root symlinks"
check_symlink() {
  local target="$1" expect_substr="$2"
  if [ -L "$ROOT/$target" ]; then
    local dest; dest="$(readlink "$ROOT/$target")"
    if printf "%s" "$dest" | grep -q "$expect_substr"; then
      pass "$target -> $dest"
    else
      warn "$target -> $dest (expected to contain '$expect_substr')"
    fi
  elif [ -e "$ROOT/$target" ]; then
    warn "$target exists but is not a symlink"
  else
    fail "$target missing"
  fi
}
check_symlink "CLAUDE.md"             ".priv-storage/CLAUDE.md"
check_symlink "AGENTS.md"             ".priv-storage/CLAUDE.md"
check_symlink ".cursorrules"          ".priv-storage/.cursorrules"
check_symlink ".vscode/settings.json" ".priv-storage/.vscode/settings.json"

# ---------- 4. .mcp.json ----------
section "4. .mcp.json"
if [ -f "$ROOT/.mcp.json" ]; then pass ".mcp.json exists"; else fail ".mcp.json missing"; fi

# ---------- 5. .gitignore AIPS block ----------
section "5. .gitignore"
if [ -f "$ROOT/.gitignore" ]; then
  if grep -qE '\.priv-storage/?' "$ROOT/.gitignore" && grep -qE 'tmp-igbkp/?' "$ROOT/.gitignore"; then
    pass ".gitignore contains AIPS block (.priv-storage, tmp-igbkp)"
  else
    fail ".gitignore missing AIPS entries"
  fi
else
  fail ".gitignore missing"
fi

# ---------- 6. tmp-igbkp toolkit (9 scripts, NO codex-relay-*) ----------
section "6. tmp-igbkp toolkit"
EXPECTED=(archive.sh restore.sh purge-history.sh verify-setup.sh uninstall.sh smoke-test-hooks.sh secret-guard.sh automode-validate.sh setup-worktree.sh)
MISSING=0
for s in "${EXPECTED[@]}"; do
  if [ -f "$ROOT/tmp-igbkp/$s" ]; then pass "tmp-igbkp/$s"; else fail "tmp-igbkp/$s missing"; MISSING=$((MISSING+1)); fi
done
if compgen -G "$ROOT/tmp-igbkp/codex-relay-*.sh" >/dev/null 2>&1; then
  warn "tmp-igbkp/codex-relay-*.sh still present (v6.0 removed these)"
fi
if [ "$MISSING" -eq 0 ]; then pass "all 9 toolkit scripts present"; fi

# ---------- 7. global plugin install ----------
section "7. global AIPS plugin"
PLUG_DIR="$HOME/.claude/plugins/cache/AIPS/AIPS"
if [ -d "$PLUG_DIR" ]; then
  pass "global AIPS plugin installed at $PLUG_DIR"
else
  fail "global AIPS plugin NOT installed (expected $PLUG_DIR) — run install.sh"
fi

# ---------- 8. dep plugins (warn-only) ----------
section "8. dependency plugins (warn-only)"
for dep in openai-codex caveman agentmemory; do
  if [ -d "$HOME/.claude/plugins/cache/$dep" ]; then
    pass "$dep plugin present"
  else
    warn "$dep plugin not found — run install.sh --with $dep"
  fi
done

# ---------- 9. RTK (warn-only) ----------
section "9. RTK (warn-only)"
if command -v rtk >/dev/null 2>&1; then
  pass "rtk on PATH ($(rtk --version 2>/dev/null || echo present))"
else
  warn "rtk not on PATH — install via install.sh --with rtk (token savings disabled)"
fi

# ---------- summary ----------
printf "\n── summary ── %sPASS=%d%s  %sWARN=%d%s  %sFAIL=%d%s\n" \
  "$C_GREEN" "$PASS_N" "$C_RESET" \
  "$C_YELLOW" "$WARN_N" "$C_RESET" \
  "$C_RED" "$FAIL_N" "$C_RESET"

if [ "$FAIL_N" -eq 0 ]; then
  printf "%sverify: PASS%s\n" "$C_GREEN" "$C_RESET"
  exit 0
else
  printf "%sverify: FAIL%s — see above\n" "$C_RED" "$C_RESET"
  exit 1
fi
