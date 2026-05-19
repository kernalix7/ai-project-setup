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

# ---------- 5. AIPS ignore coverage (global ~/.config/git/ignore) ----------
section "5. ignore coverage"
GLOBAL_GI="$(git config --global core.excludesfile 2>/dev/null || true)"
case "$GLOBAL_GI" in
  "~/"*) GLOBAL_GI="$HOME/${GLOBAL_GI#~/}" ;;
esac
[ -z "$GLOBAL_GI" ] && GLOBAL_GI="$HOME/.config/git/ignore"

if [ -f "$GLOBAL_GI" ] \
     && grep -qE '\.priv-storage/?' "$GLOBAL_GI" \
     && grep -qE 'tmp-igbkp/?' "$GLOBAL_GI"; then
  pass "global $GLOBAL_GI covers .priv-storage + tmp-igbkp"
else
  warn "global $GLOBAL_GI missing AIPS entries — run: bash \$AIPS_ROOT/lib/setup-global-gitignore.sh"
fi

# Per-project .gitignore: should NOT carry AIPS lines (v7+ globalized them).
# A leftover marker block or raw line is only a warning — /aips:init strips it.
if [ -f "$ROOT/.gitignore" ]; then
  if grep -qE '^# === AIPS v[0-9]+\.[0-9]+' "$ROOT/.gitignore" 2>/dev/null \
       || grep -qFx '.priv-storage/' "$ROOT/.gitignore" 2>/dev/null \
       || grep -qFx 'tmp-igbkp/' "$ROOT/.gitignore" 2>/dev/null; then
    warn "per-project .gitignore still has AIPS lines (v6.x leftover) — run /aips:init to strip"
  else
    pass "per-project .gitignore is clean of AIPS lines"
  fi
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

# ---------- 10. v7.0 memory dual-write health ----------
section "10. v7.0 memory dual-write health"
LOCAL_MEM_DIR="$ROOT/.priv-storage/memory"
PATH_ENCODED="$(echo "$ROOT" | tr '/' '-')"
GLOBAL_MEM_DIR="$HOME/.claude/projects/$PATH_ENCODED/memory"

# Check 1: local memory files (warn if present in v7.0; should have been dropped on upgrade)
if [ -d "$LOCAL_MEM_DIR" ]; then
  LOCAL_FILES=$(find "$LOCAL_MEM_DIR" -maxdepth 2 -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$LOCAL_FILES" -gt 0 ]; then
    warn "local .priv-storage/memory/ has $LOCAL_FILES file(s) — v7.0 deprecates local; run lib/upgrade-to-v7.sh"
  else
    pass "local .priv-storage/memory/ empty (v7.0-clean)"
  fi
else
  pass "no local .priv-storage/memory/ (v7.0-clean)"
fi

# Check 2: global memory dir exists with files
if [ -d "$GLOBAL_MEM_DIR" ]; then
  GLOBAL_FILES=$(find "$GLOBAL_MEM_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$GLOBAL_FILES" -gt 0 ]; then
    pass "global memory present at $GLOBAL_MEM_DIR ($GLOBAL_FILES files)"
  else
    warn "global memory dir exists but empty: $GLOBAL_MEM_DIR"
  fi
else
  warn "global memory dir missing: $GLOBAL_MEM_DIR (will be created on first save)"
fi

# Check 3: backup helper available
HELPER_FOUND=""
for cand in \
    "$ROOT/lib/backup-global-memory.sh" \
    "$HOME/.claude/plugins/cache/AIPS/AIPS/lib/backup-global-memory.sh" \
    "$HOME/.local/share/aips/lib/backup-global-memory.sh"; do
  if [ -f "$cand" ]; then HELPER_FOUND="$cand"; break; fi
done
if [ -n "$HELPER_FOUND" ]; then
  pass "backup-global-memory.sh found at $HELPER_FOUND"
else
  warn "backup-global-memory.sh not found — archive.sh will skip global memory backup"
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
