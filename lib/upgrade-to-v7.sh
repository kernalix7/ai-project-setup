#!/usr/bin/env bash
# upgrade-to-v7.sh — v6.0 → v7.0 hybrid migration for a single project.
# Args: <project_root> [--dry-run] [--force] [--keep-local-fallback]
# Default (strict): result equals a fresh v7.0 install — per-project
# tmp-igbkp/*.sh scripts are deleted (global symlinks at ~/.local/bin/aips-*
# verified first), and .priv-storage/sessions/*.md is cleared after global
# mirror is confirmed. Pass --keep-local-fallback to retain both as
# fallback (v7.0 pre-strict behavior).
# Exits non-zero on pre-check failure (unless --force).
set -euo pipefail

# ---------------------------------------------------------------------------
# args
# ---------------------------------------------------------------------------
PROJECT_ROOT=""
DRY_RUN=0
FORCE=0
PLAN_ONLY=0
STRICT=1  # default: end state equals fresh v7.0 install
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1   ;;
    --plan)    PLAN_ONLY=1 ;;
    --keep-local-fallback) STRICT=0 ;;
    -*)        echo "[upgrade-v7] unknown flag: $a" >&2; exit 2 ;;
    *)         [ -z "$PROJECT_ROOT" ] && PROJECT_ROOT="$a" ;;
  esac
done
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$PROJECT_ROOT/tmp-igbkp/upgrade-v7-backup-$TS"
PRIV="$PROJECT_ROOT/.priv-storage"
MARKER="$PRIV/.aips-version"

# Path-keying for global mirrors (must match rebind.sh / scope.sh).
path_hash()    { printf '%s' "$1" | md5sum | cut -c1-12; }
path_encoded() { printf '%s' "$1" | sed 's|/|-|g; s|^-||'; }
PHASH="$(path_hash "$PROJECT_ROOT")"
PENC="$(path_encoded "$PROJECT_ROOT")"

GLOBAL_SESSIONS="$HOME/.claude/sessions/$PHASH"
GLOBAL_PROJECT="$HOME/.claude/projects/$PENC"
GLOBAL_MEMORY="$GLOBAL_PROJECT/memory"

# Lib dir (siblings of this script).
LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------------------------------------------------------------------------
# logging
# ---------------------------------------------------------------------------
log()  { printf '[upgrade-v7] %s\n' "$*"; }
warn() { printf '[upgrade-v7] WARN: %s\n' "$*" >&2; }
err()  { printf '[upgrade-v7] ERROR: %s\n' "$*" >&2; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then printf '[upgrade-v7] (dry) %s\n' "$*"; else eval "$@"; fi; }

# ---------------------------------------------------------------------------
# PLAN block (printed for --plan and at start of full run)
# ---------------------------------------------------------------------------
print_plan() {
  local mode="STRICT (fresh-install equivalent)"
  [ "$STRICT" -eq 0 ] && mode="LENIENT (keep local fallback)"
  cat <<EOF
[plan] project   $PROJECT_ROOT
[plan] mode      $mode
[plan] backup    → $BACKUP_DIR
[plan] globalize → hooks, skills, output-styles, statusline → ~/.claude/
[plan] toolkit   → symlink tmp-igbkp/*.sh → ~/.local/bin/aips-* (via globalize-toolkit.sh)
EOF
  if [ "$STRICT" -eq 1 ]; then
    cat <<EOF
[plan] toolkit   → DELETE per-project tmp-igbkp/*.sh after symlink verification (strict)
EOF
  else
    cat <<EOF
[plan] toolkit   → keep per-project tmp-igbkp/*.sh as fallback (lenient)
EOF
  fi
  cat <<EOF
[plan] gitignore → strip per-project AIPS block, add to ~/.config/git/ignore
[plan] memory    → mirror .priv-storage/memory/* → $GLOBAL_MEMORY/, then prune
[plan] sessions  → mirror .priv-storage/sessions/* → $GLOBAL_SESSIONS/
EOF
  if [ "$STRICT" -eq 1 ]; then
    cat <<EOF
[plan] sessions  → DELETE .priv-storage/sessions/*.md after mirror verification (strict; dir kept for hook fast-write)
EOF
  else
    cat <<EOF
[plan] sessions  → keep .priv-storage/sessions/*.md as fallback (lenient)
EOF
  fi
  cat <<EOF
[plan] CLAUDE.md → trim Sections 8–13 ref comments (re-render via lib/render-claude-md.sh)
[plan] marker    → write $MARKER ← 7.0
EOF
}

if [ "$PLAN_ONLY" -eq 1 ]; then
  print_plan
  exit 0
fi

# ---------------------------------------------------------------------------
# 1. pre-check: must be v6.0
# ---------------------------------------------------------------------------
detect_version() {
  if [ -f "$MARKER" ]; then
    cat "$MARKER" | tr -d '[:space:]'
    return
  fi
  # No marker: assume v6.0 if Section 1-7+11 layout present.
  if [ -f "$PRIV/CLAUDE.md" ] && grep -q '^## 11\.' "$PRIV/CLAUDE.md" 2>/dev/null \
     && ! grep -q '^## 13\.' "$PRIV/CLAUDE.md" 2>/dev/null; then
    echo "6.0"
  else
    echo "unknown"
  fi
}

CUR_VER="$(detect_version)"
log "detected current version: $CUR_VER"

if [ "$CUR_VER" = "7.0" ]; then
  log "already on v7.0 — no-op"
  exit 0
fi
if [ "$CUR_VER" != "6.0" ] && [ "$FORCE" -ne 1 ]; then
  err "pre-check failed: expected v6.0, found '$CUR_VER'. Re-run with --force to override."
  exit 1
fi

print_plan
log "starting migration (dry-run=$DRY_RUN force=$FORCE)"

# ---------------------------------------------------------------------------
# 2. backup
# ---------------------------------------------------------------------------
BACKUP_COUNT=0
run "mkdir -p '$BACKUP_DIR'"
for src in "$PRIV/memory" "$PRIV/sessions" "$PRIV/.claude" "$PROJECT_ROOT/.gitignore"; do
  if [ -e "$src" ]; then
    run "cp -a '$src' '$BACKUP_DIR/' 2>/dev/null || true"
    BACKUP_COUNT=$((BACKUP_COUNT + 1))
  fi
done
if [ -d "$PROJECT_ROOT/tmp-igbkp" ]; then
  # back up only the shell scripts (avoid recursive backup of backups)
  for sh in "$PROJECT_ROOT"/tmp-igbkp/*.sh; do
    [ -e "$sh" ] || continue
    run "cp -a '$sh' '$BACKUP_DIR/'"
    BACKUP_COUNT=$((BACKUP_COUNT + 1))
  done
fi
log "backup     $BACKUP_DIR ($BACKUP_COUNT items)"

# ---------------------------------------------------------------------------
# 3. globalize toolkit (delegate to P1 deliverable)
# ---------------------------------------------------------------------------
GLOBALIZED=0
if [ -x "$LIB_DIR/globalize-toolkit.sh" ] || [ -f "$LIB_DIR/globalize-toolkit.sh" ]; then
  run "bash '$LIB_DIR/globalize-toolkit.sh' '$PROJECT_ROOT'"
  GLOBALIZED=1
  log "globalized toolkit (via globalize-toolkit.sh)"
else
  warn "globalize-toolkit.sh not found in $LIB_DIR — skipped"
fi

# 3-strict: delete per-project tmp-igbkp/*.sh after verifying global symlinks
if [ "$STRICT" -eq 1 ] && [ "$GLOBALIZED" -eq 1 ] && [ -d "$PROJECT_ROOT/tmp-igbkp" ]; then
  PURGED=0
  KEPT=0
  for sh in "$PROJECT_ROOT"/tmp-igbkp/*.sh; do
    [ -e "$sh" ] || continue
    name="$(basename "$sh" .sh)"
    target="$HOME/.local/bin/aips-$name"
    if [ -L "$target" ] || [ -x "$target" ]; then
      run "rm -f '$sh'"
      PURGED=$((PURGED + 1))
    else
      warn "global aips-$name missing — keeping $sh as fallback"
      KEPT=$((KEPT + 1))
    fi
  done
  log "toolkit    strict purge: deleted $PURGED per-project scripts (kept $KEPT as fallback)"
fi

# ---------------------------------------------------------------------------
# 4. globalize gitignore (delegate to P4 deliverable) + strip per-project block
# ---------------------------------------------------------------------------
if [ -f "$LIB_DIR/setup-global-gitignore.sh" ]; then
  run "bash '$LIB_DIR/setup-global-gitignore.sh' '$PROJECT_ROOT'"
  log "globalized gitignore (via setup-global-gitignore.sh)"
else
  warn "setup-global-gitignore.sh not found in $LIB_DIR — skipped"
fi

GI="$PROJECT_ROOT/.gitignore"
if [ -f "$GI" ] && grep -q '^# === AIPS v6.0 ===' "$GI" 2>/dev/null; then
  if [ "$DRY_RUN" -eq 1 ]; then
    log "(dry) would strip '# === AIPS v6.0 ===' … '# === /AIPS v6.0 ===' from $GI"
  else
    # delete inclusive block
    sed -i '/^# === AIPS v6.0 ===$/,/^# === \/AIPS v6.0 ===$/d' "$GI"
    log "gitignore  stripped AIPS v6.0 block from $GI"
  fi
fi

# ---------------------------------------------------------------------------
# 5. memory: mirror first, then drop per-project copies
# ---------------------------------------------------------------------------
MEM_SRC="$PRIV/memory"
MEM_MIRROR_OK=0
if [ -d "$MEM_SRC" ]; then
  run "mkdir -p '$GLOBAL_MEMORY'"
  # copy each file; -n = no-clobber so existing global wins
  if [ "$DRY_RUN" -ne 1 ]; then
    cp -an "$MEM_SRC"/. "$GLOBAL_MEMORY"/ 2>/dev/null || true
  fi
  # verify all source files have a counterpart globally
  MISSING=0
  while IFS= read -r -d '' f; do
    rel="${f#$MEM_SRC/}"
    [ -e "$GLOBAL_MEMORY/$rel" ] || MISSING=$((MISSING + 1))
  done < <(find "$MEM_SRC" -type f -print0 2>/dev/null)
  if [ "$MISSING" -eq 0 ]; then
    MEM_MIRROR_OK=1
    log "memory     mirrored → $GLOBAL_MEMORY"
    # prune contents but keep dir (backwards compat)
    if [ "$DRY_RUN" -ne 1 ]; then
      find "$MEM_SRC" -mindepth 1 -delete 2>/dev/null || true
    fi
    log "memory     pruned $MEM_SRC/* (dir retained)"
  else
    warn "memory mirror incomplete ($MISSING missing) — keeping per-project copy intact"
  fi
fi

# ---------------------------------------------------------------------------
# 6. sessions: ensure global mirror exists; hooks will keep it up to date
# ---------------------------------------------------------------------------
SESS_SRC="$PRIV/sessions"
SESS_MIRROR_OK=0
if [ -d "$SESS_SRC" ]; then
  run "mkdir -p '$GLOBAL_SESSIONS'"
  if [ "$DRY_RUN" -ne 1 ]; then
    cp -an "$SESS_SRC"/. "$GLOBAL_SESSIONS"/ 2>/dev/null || true
  fi
  # verify each local *.md has a counterpart globally
  MISSING=0
  while IFS= read -r -d '' f; do
    rel="${f#$SESS_SRC/}"
    [ -e "$GLOBAL_SESSIONS/$rel" ] || MISSING=$((MISSING + 1))
  done < <(find "$SESS_SRC" -type f -name '*.md' -print0 2>/dev/null)
  if [ "$MISSING" -eq 0 ]; then
    SESS_MIRROR_OK=1
    log "sessions   mirrored → $GLOBAL_SESSIONS (hooks own ongoing sync)"
  else
    warn "sessions mirror incomplete ($MISSING missing) — keeping per-project copies intact"
  fi
fi

# 6-strict: delete per-project sessions/*.md after mirror verified.
# Keep the dir + .keep file so hooks (PostToolUse/Stop) can fast-write
# without mkdir overhead.
if [ "$STRICT" -eq 1 ] && [ "$SESS_MIRROR_OK" -eq 1 ]; then
  if [ "$DRY_RUN" -ne 1 ]; then
    find "$SESS_SRC" -mindepth 1 -type f -name '*.md' -delete 2>/dev/null || true
    find "$SESS_SRC" -mindepth 1 -type f -name '*.tsv' -delete 2>/dev/null || true
    find "$SESS_SRC" -mindepth 1 -type d -empty -delete 2>/dev/null || true
    mkdir -p "$SESS_SRC"
    touch "$SESS_SRC/.keep"
  fi
  log "sessions   strict purge: cleared $SESS_SRC/*.md+.tsv (dir kept for hook fast-write)"
fi

# ---------------------------------------------------------------------------
# 7. CLAUDE.md slim: re-render via P6 template, or fallback sed-delete
# ---------------------------------------------------------------------------
CMD_FILE="$PRIV/CLAUDE.md"
if [ -f "$LIB_DIR/render-claude-md.sh" ] && [ -f "$CMD_FILE" ]; then
  run "bash '$LIB_DIR/render-claude-md.sh' '$PROJECT_ROOT' || true"
  log "CLAUDE.md  re-rendered via render-claude-md.sh"
elif [ -f "$CMD_FILE" ]; then
  if [ "$DRY_RUN" -ne 1 ]; then
    # delete Section 8 through Section 13 headers (best-effort fallback)
    sed -i '/^## 8\. /,/^## 14\. /{/^## 14\. /!d;}' "$CMD_FILE" 2>/dev/null || true
  fi
  log "CLAUDE.md  trimmed Sections 8–13 (fallback sed)"
fi

# ---------------------------------------------------------------------------
# 8. write marker
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" -ne 1 ]; then
  mkdir -p "$PRIV"
  printf '7.0\n' > "$MARKER"
fi
log "marker     $MARKER = 7.0"

# ---------------------------------------------------------------------------
# 9. report
# ---------------------------------------------------------------------------
GLOBAL_FILES=$(find "$HOME/.claude/hooks" "$HOME/.claude/skills" "$HOME/.claude/output-styles" -type f 2>/dev/null | wc -l | tr -d ' ')
PRESERVED=$(find "$PRIV" -maxdepth 2 -type f 2>/dev/null | wc -l | tr -d ' ')

cat <<EOF
[upgrade-v7] backup     $BACKUP_DIR ($BACKUP_COUNT items)
[upgrade-v7] globalized $GLOBAL_FILES files → ~/.claude/
[upgrade-v7] preserved  $PRESERVED files (per-project AIPS bits)
[upgrade-v7] marker     $MARKER = 7.0
Upgraded to v7.0 — $GLOBAL_FILES files globalized, $PRESERVED files preserved, backup at $BACKUP_DIR
EOF
