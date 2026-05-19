#!/usr/bin/env bash
# upgrade.sh — AIPS unified upgrade for a single project.
# Handles v5.x / v6.0 / any-pre-current → current plugin version in one pass.
# Replaces the old migrate-from-md.sh + upgrade-to-v7.sh pair (v7.1+).
#
# Usage:
#   bash lib/upgrade.sh [PROJECT_ROOT] [flags]
#
# Flags:
#   --dry-run               Print plan, do not execute any rm/cp/sed.
#   --force                 Skip pre-checks (unrecognized layout, version older
#                           than current).
#   --plan                  Print PLAN block only and exit 0.
#   --auto-confirm | -y     Skip the single confirmation prompt.
#   --keep-local-fallback   Lenient: keep per-project tmp-igbkp/*.sh and
#                           sessions/*.md after globalization (default = strict
#                           purge after global mirror verified).
#   --only-cleanup          Run only the v5.x REMOVE + CLAUDE.md trim + settings
#                           strip steps. Skip globalize + mirror + strict purge.
#                           Used by the migrate-from-md.sh backward-compat wrapper.
#   --skip-globals          Skip globalize-toolkit + gitignore globalization
#                           (per-project work only).
#   -h, --help              Show this header.

set -euo pipefail

# ---------------------------------------------------------------------------
# arg parse
# ---------------------------------------------------------------------------
PROJECT_ROOT=""
DRY_RUN=0
FORCE=0
PLAN_ONLY=0
AUTO_CONFIRM=0
STRICT=1            # default: result equals fresh install
ONLY_CLEANUP=0
SKIP_GLOBALS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)              DRY_RUN=1 ;;
    --force)                FORCE=1 ;;
    --plan)                 PLAN_ONLY=1 ;;
    --auto-confirm|-y)      AUTO_CONFIRM=1 ;;
    --keep-local-fallback)  STRICT=0 ;;
    --only-cleanup)         ONLY_CLEANUP=1 ;;
    --skip-globals)         SKIP_GLOBALS=1 ;;
    -h|--help)
      sed -n '2,22p' "$0"
      exit 0 ;;
    -*)
      printf '[upgrade] unknown flag: %s\n' "$1" >&2
      exit 2 ;;
    *)
      if [ -z "$PROJECT_ROOT" ]; then
        PROJECT_ROOT="$1"
      else
        printf '[upgrade] extra positional arg: %s\n' "$1" >&2
        exit 2
      fi ;;
  esac
  shift
done

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
if [ ! -d "$PROJECT_ROOT" ]; then
  printf '[upgrade] ERROR: PROJECT_ROOT not a directory: %s\n' "$PROJECT_ROOT" >&2
  exit 1
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT%/}"

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
PRIV="$PROJECT_ROOT/.priv-storage"
MARKER="$PRIV/.aips-version"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$PROJECT_ROOT/tmp-igbkp/upgrade-backup-$TS"

# ---------------------------------------------------------------------------
# colour + logging
# ---------------------------------------------------------------------------
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_RESET="$(tput sgr0)"; C_BLUE="$(tput setaf 4)"; C_GREEN="$(tput setaf 2)"
  C_YELLOW="$(tput setaf 3)"; C_RED="$(tput setaf 1)"
else
  C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi
log()  { printf '%s[upgrade]%s %s\n' "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf '%s[ok]%s %s\n'      "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf '%s[upgrade]%s WARN: %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf '%s[upgrade]%s ERROR: %s\n' "$C_RED"  "$C_RESET" "$*" >&2; }
run()  {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] %s\n' "$*"
  else
    eval "$@"
  fi
}

# ---------------------------------------------------------------------------
# helpers — version + path keys
# ---------------------------------------------------------------------------
path_hash()    { printf '%s' "$1" | md5sum | cut -c1-12; }
path_encoded() { printf '%s' "$1" | sed 's|/|-|g; s|^-||'; }

# Compare semver major.minor. Returns 0 if $1 == $2, 1 if $1 < $2, 2 if $1 > $2.
ver_cmp_mm() {
  local a_full="$1" b_full="$2"
  local a="${a_full%%.*}" b="${b_full%%.*}"
  local arest="${a_full#*.}" brest="${b_full#*.}"
  local a_min="${arest%%.*}" b_min="${brest%%.*}"
  [ -z "$a" ]     || ! [ "$a" -eq "$a" ]         2>/dev/null && a=0
  [ -z "$b" ]     || ! [ "$b" -eq "$b" ]         2>/dev/null && b=0
  [ -z "$a_min" ] || ! [ "$a_min" -eq "$a_min" ] 2>/dev/null && a_min=0
  [ -z "$b_min" ] || ! [ "$b_min" -eq "$b_min" ] 2>/dev/null && b_min=0
  if [ "$a" -lt "$b" ]; then return 1; fi
  if [ "$a" -gt "$b" ]; then return 2; fi
  if [ "$a_min" -lt "$b_min" ]; then return 1; fi
  if [ "$a_min" -gt "$b_min" ]; then return 2; fi
  return 0
}

# ---------------------------------------------------------------------------
# resolve target plugin version dynamically
# ---------------------------------------------------------------------------
PLUGIN_JSON="$(cd "$LIB_DIR/.." && pwd)/.claude-plugin/plugin.json"
PLUGIN_VER="unknown"
if [ -f "$PLUGIN_JSON" ]; then
  if command -v jq >/dev/null 2>&1; then
    PLUGIN_VER="$(jq -r '.version // "unknown"' "$PLUGIN_JSON")"
  else
    PLUGIN_VER="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN_JSON" | head -1)"
    [ -z "$PLUGIN_VER" ] && PLUGIN_VER="unknown"
  fi
fi
PLUGIN_MM="${PLUGIN_VER%.*}"   # major.minor (drop patch)

PHASH="$(path_hash "$PROJECT_ROOT")"
PENC="$(path_encoded "$PROJECT_ROOT")"
GLOBAL_SESSIONS="$HOME/.claude/sessions/$PHASH"
GLOBAL_PROJECT="$HOME/.claude/projects/$PENC"
GLOBAL_MEMORY="$GLOBAL_PROJECT/memory"

# ---------------------------------------------------------------------------
# detect current project version
# ---------------------------------------------------------------------------
detect_version() {
  if [ -f "$MARKER" ]; then
    tr -d '[:space:]' < "$MARKER"
    return
  fi
  if [ -f "$PRIV/CLAUDE.md" ] && grep -q '^## 11\.' "$PRIV/CLAUDE.md" 2>/dev/null \
     && ! grep -q '^## 13\.' "$PRIV/CLAUDE.md" 2>/dev/null; then
    echo "6.0"
  else
    echo "unknown"
  fi
}
CUR_VER="$(detect_version)"
CUR_MM="${CUR_VER%.*}"

# ---------------------------------------------------------------------------
# detect v5.x cruft (independent of marker)
# ---------------------------------------------------------------------------
V5_SIGNALS=(
  ".priv-storage/AI_PROJECT_SETUP.md"
  ".priv-storage/.claude/hooks"
  ".priv-storage/.claude/skills"
  ".priv-storage/.claude/output-styles"
  ".priv-storage/.claude/statusline"
  ".priv-storage/.claude/commands/codex-brief.md"
  "tmp-igbkp/codex-relay-check.sh"
  "tmp-igbkp/codex-relay-run.sh"
)
V5_DETECTED=0
for s in "${V5_SIGNALS[@]}"; do
  if [ -e "$PROJECT_ROOT/$s" ]; then V5_DETECTED=1; break; fi
done

# ---------------------------------------------------------------------------
# REMOVE lists (v5.x cleanup)
# ---------------------------------------------------------------------------
REMOVE_FILES=(
  ".priv-storage/AI_PROJECT_SETUP.md"
  ".priv-storage/.claude/agents/explorer.md"
  ".priv-storage/.claude/agents/code-reviewer.md"
  ".priv-storage/.claude/agents/log-analyzer.md"
  ".priv-storage/.claude/commands/status.md"
  ".priv-storage/.claude/commands/recover.md"
  ".priv-storage/.claude/commands/ship.md"
  ".priv-storage/.claude/commands/health.md"
  ".priv-storage/.claude/commands/save.md"
  ".priv-storage/.claude/commands/clean.md"
  ".priv-storage/.claude/commands/codex-brief.md"
  ".priv-storage/.claude/commands/codex-review.md"
  ".priv-storage/.claude/commands/codex-fix.md"
  ".priv-storage/.claude/commands/codex-relay-status.md"
  "tmp-igbkp/codex-relay-check.sh"
  "tmp-igbkp/codex-relay-run.sh"
  ".priv-storage/sessions/codex-brief.md"
  ".priv-storage/sessions/codex-report.md"
  ".priv-storage/sessions/claude-review.md"
)
REMOVE_DIRS=(
  ".priv-storage/.claude/hooks"
  ".priv-storage/.claude/skills"
  ".priv-storage/.claude/output-styles"
  ".priv-storage/.claude/statusline"
  ".priv-storage/sessions/codex-relay"
)

# ---------------------------------------------------------------------------
# pre-checks
# ---------------------------------------------------------------------------
if [ "$PLUGIN_VER" = "unknown" ]; then
  err "could not read plugin version from $PLUGIN_JSON"
  exit 1
fi

log "target plugin version: $PLUGIN_VER (major.minor=$PLUGIN_MM)"
log "detected current version: $CUR_VER"
log "v5.x cruft detected: $([ "$V5_DETECTED" -eq 1 ] && echo yes || echo no)"

# Already on the target major.minor AND no v5 cruft AND not --force → no-op.
if [ "$CUR_VER" != "unknown" ] && ver_cmp_mm "$CUR_VER" "$PLUGIN_VER"; then
  if [ "$V5_DETECTED" -eq 0 ] && [ "$FORCE" -ne 1 ] && [ "$ONLY_CLEANUP" -ne 1 ]; then
    log "already on target v$PLUGIN_MM (project marker v$CUR_VER) and no v5.x cruft — no-op"
    exit 0
  fi
fi

# Refuse downgrade.
if [ "$CUR_VER" != "unknown" ]; then
  ver_cmp_mm "$CUR_VER" "$PLUGIN_VER" || rc=$?
  rc="${rc:-0}"
  if [ "$rc" = "2" ]; then
    err "project marker v$CUR_VER is newer than plugin v$PLUGIN_VER. Refusing to downgrade. Update the plugin first."
    exit 1
  fi
  unset rc
fi

# Unknown layout requires --force or v5 cruft signal.
if [ "$CUR_VER" = "unknown" ] && [ "$V5_DETECTED" -eq 0 ] && [ "$FORCE" -ne 1 ]; then
  err "could not detect a known AIPS layout in $PROJECT_ROOT. Re-run with --force to override."
  exit 1
fi

# ---------------------------------------------------------------------------
# PLAN block
# ---------------------------------------------------------------------------
print_plan() {
  local mode="STRICT (fresh-install equivalent)"
  [ "$STRICT" -eq 0 ] && mode="LENIENT (keep local fallback)"
  local dryflag=""
  [ "$DRY_RUN" -eq 1 ] && dryflag=" (dry-run)"

  printf '[plan] project   %s\n'  "$PROJECT_ROOT"
  printf '[plan] from      v%s\n' "$CUR_VER"
  printf '[plan] to        v%s\n' "$PLUGIN_VER"
  printf '[plan] mode      %s%s\n' "$mode" "$dryflag"
  printf '[plan] backup    -> %s\n' "$BACKUP_DIR"
  printf '[plan] v5 cruft  %s\n' "$([ "$V5_DETECTED" -eq 1 ] && echo present || echo absent)"
  printf '[plan] cleanup   REMOVE %d v5 files + %d dirs (idempotent)\n' \
    "${#REMOVE_FILES[@]}" "${#REMOVE_DIRS[@]}"
  printf '[plan] CLAUDE.md trim Sections 8/9/10/12/13\n'
  printf '[plan] settings  reconstruct .priv-storage/.claude/settings.json (drop .hooks, set statusLine → ~/.local/bin/aips-statusline)\n'

  if [ "$ONLY_CLEANUP" -eq 1 ]; then
    printf '[plan] mode      --only-cleanup: skipping globalize + mirror + strict purge\n'
    return
  fi

  if [ "$SKIP_GLOBALS" -eq 1 ]; then
    printf '[plan] globalize SKIPPED (--skip-globals)\n'
  else
    printf '[plan] globalize -> hooks, skills, output-styles, statusline -> ~/.claude/\n'
    printf '[plan] toolkit   -> symlink tmp-igbkp/*.sh -> ~/.local/bin/aips-* (globalize-toolkit.sh)\n'
    printf '[plan] gitignore -> strip per-project AIPS block, add to ~/.config/git/ignore\n'
  fi

  printf '[plan] memory    -> mirror .priv-storage/memory/* -> %s/\n' "$GLOBAL_MEMORY"
  printf '[plan] sessions  -> mirror .priv-storage/sessions/* -> %s/\n' "$GLOBAL_SESSIONS"
  if [ "$STRICT" -eq 1 ]; then
    printf '[plan] strict    DELETE per-project tmp-igbkp/*.sh after symlink verification\n'
    printf '[plan] strict    DELETE .priv-storage/sessions/*.md|*.tsv after mirror verified (dir kept)\n'
    printf '[plan] strict    PRUNE  .priv-storage/memory/* after mirror verified (dir kept)\n'
  else
    printf '[plan] lenient   keep per-project tmp-igbkp/*.sh + sessions/*.md as fallback\n'
  fi
  printf '[plan] marker    write %s <- %s\n' "$MARKER" "$PLUGIN_VER"
}

print_plan

if [ "$PLAN_ONLY" -eq 1 ]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# single confirm
# ---------------------------------------------------------------------------
if [ "$AUTO_CONFIRM" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
  printf '\nRun all of the above without further prompts? [Y/n] '
  ans=""
  if [ -r /dev/tty ]; then
    read -r ans < /dev/tty || ans=""
  else
    read -r ans || ans=""
  fi
  case "${ans:-Y}" in
    n|N|no|NO) err "aborted by user."; exit 1 ;;
  esac
fi

log "starting upgrade (dry-run=$DRY_RUN force=$FORCE strict=$STRICT only-cleanup=$ONLY_CLEANUP skip-globals=$SKIP_GLOBALS)"

# ---------------------------------------------------------------------------
# 1. backup
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
  for sh in "$PROJECT_ROOT"/tmp-igbkp/*.sh; do
    [ -e "$sh" ] || continue
    run "cp -a '$sh' '$BACKUP_DIR/'"
    BACKUP_COUNT=$((BACKUP_COUNT + 1))
  done
fi
log "backup     $BACKUP_DIR ($BACKUP_COUNT items)"

# ---------------------------------------------------------------------------
# 2. v5.x cleanup (always — idempotent)
# ---------------------------------------------------------------------------
N_REMOVED=0
for f in "${REMOVE_FILES[@]}"; do
  if [ -e "$PROJECT_ROOT/$f" ]; then
    run "rm -f '$PROJECT_ROOT/$f'"
    N_REMOVED=$((N_REMOVED + 1))
  fi
done
for d in "${REMOVE_DIRS[@]}"; do
  if [ -e "$PROJECT_ROOT/$d" ]; then
    run "rm -rf '$PROJECT_ROOT/$d'"
    N_REMOVED=$((N_REMOVED + 1))
  fi
done
log "cleanup    removed $N_REMOVED v5.x artifacts"

# Reconstruct settings.json: keep user-tunable keys (model, outputStyle, env,
# etc.), drop .hooks (plugin's hooks.json owns it), set statusLine to the
# stable global symlink (~/.local/bin/aips-statusline) or the plugin path.
SETTINGS_JSON="$PRIV/.claude/settings.json"
RENDER_SCRIPT="$LIB_DIR/render-settings-json.sh"
if [ "$DRY_RUN" -eq 0 ]; then
  if [ -f "$SETTINGS_JSON" ]; then
    cp "$SETTINGS_JSON" "$SETTINGS_JSON.v5.bak"
  fi
  if [ -x "$RENDER_SCRIPT" ] || [ -f "$RENDER_SCRIPT" ]; then
    bash "$RENDER_SCRIPT" "$PROJECT_ROOT" \
      && ok "reconstructed $SETTINGS_JSON via render-settings-json.sh" \
      || warn "render-settings-json.sh exited non-zero"
  else
    warn "render-settings-json.sh not found at $RENDER_SCRIPT — settings.json left as-is"
  fi
else
  printf '  [dry-run] bash %s "%s"\n' "$RENDER_SCRIPT" "$PROJECT_ROOT"
fi

# CLAUDE.md trim — Sections 8/9/10/12/13
CFILE="$PRIV/CLAUDE.md"
if [ -f "$CFILE" ]; then
  log "CLAUDE.md  trimming Sections 8/9/10/12/13"
  if [ "$DRY_RUN" -eq 0 ]; then
    TMP="$(mktemp)"
    awk '
      BEGIN { skip = 0; emitted_ref = 0 }
      /^## [0-9]+\. / {
        match($0, /^## ([0-9]+)\./, arr)
        n = arr[1] + 0
        if (n == 8 || n == 9 || n == 10 || n == 12 || n == 13) {
          if (!emitted_ref) {
            print "<!-- Sections 8/9/10/12/13 globalized — see ~/.claude/CLAUDE.md -->"
            print ""
            emitted_ref = 1
          }
          skip = 1
          next
        } else {
          skip = 0
        }
      }
      { if (!skip) print }
    ' "$CFILE" > "$TMP"
    mv "$TMP" "$CFILE"
    ok "CLAUDE.md trimmed ($(wc -l <"$CFILE") lines remaining)"
  else
    printf '  [dry-run] awk-trim Sections 8/9/10/12/13 from %s\n' "$CFILE"
  fi
fi

# ---------------------------------------------------------------------------
# STOP HERE if --only-cleanup (backward-compat path for migrate-from-md.sh)
# ---------------------------------------------------------------------------
if [ "$ONLY_CLEANUP" -eq 1 ]; then
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$PRIV"
    printf '%s\n' "$PLUGIN_VER" > "$MARKER"
    ok "wrote $MARKER ($PLUGIN_VER)"
  else
    printf '  [dry-run] echo %s > %s\n' "$PLUGIN_VER" "$MARKER"
  fi
  N_PRESERVED=0
  [ -d "$PRIV" ] && N_PRESERVED="$( { find "$PRIV" -type f 2>/dev/null || true; } | wc -l | tr -d ' ')"
  printf '\n'
  ok "Cleanup done: $N_REMOVED removed, $N_PRESERVED preserved, backup at $BACKUP_DIR"
  [ "$DRY_RUN" -eq 1 ] && warn "(dry-run — no changes written)"
  exit 0
fi

# ---------------------------------------------------------------------------
# 3. globalize toolkit + gitignore
# ---------------------------------------------------------------------------
GLOBALIZED=0
if [ "$SKIP_GLOBALS" -eq 1 ]; then
  log "globalize  skipped (--skip-globals)"
else
  if [ -f "$LIB_DIR/globalize-toolkit.sh" ]; then
    GTK_FLAGS=""
    [ "$DRY_RUN" -eq 1 ] && GTK_FLAGS="--dry-run"
    run "bash '$LIB_DIR/globalize-toolkit.sh' $GTK_FLAGS"
    GLOBALIZED=1
    log "globalize  toolkit via globalize-toolkit.sh"
  else
    warn "globalize-toolkit.sh not found in $LIB_DIR — skipped"
  fi

  if [ -f "$LIB_DIR/setup-global-gitignore.sh" ]; then
    run "bash '$LIB_DIR/setup-global-gitignore.sh' '$PROJECT_ROOT'"
    log "globalize  gitignore via setup-global-gitignore.sh"
  else
    warn "setup-global-gitignore.sh not found in $LIB_DIR — skipped"
  fi

  # strip per-project AIPS vN.N block (version-agnostic)
  GI="$PROJECT_ROOT/.gitignore"
  if [ -f "$GI" ]; then
    if grep -qE '^# === AIPS v[0-9]+\.[0-9]+( \([a-z]+\))? ===$' "$GI" 2>/dev/null; then
      if [ "$DRY_RUN" -eq 1 ]; then
        log "(dry) would strip AIPS vN.N block from $GI"
      else
        sed -i -E '/^# === AIPS v[0-9]+\.[0-9]+( \([a-z]+\))? ===$/,/^# === \/AIPS v[0-9]+\.[0-9]+( \([a-z]+\))? ===$/d' "$GI"
        log "gitignore  stripped per-project AIPS block from $GI"
      fi
    fi
  fi
fi

# user-level settings.json heads-up
USER_SETTINGS="$HOME/.claude/settings.json"
if [ -f "$USER_SETTINGS" ] && grep -q '"hooks"' "$USER_SETTINGS" 2>/dev/null; then
  warn "user-level $USER_SETTINGS has a .hooks block. If hook-not-found errors persist:"
  warn "  cp ~/.claude/settings.json ~/.claude/settings.json.v5.bak"
  warn "  jq 'del(.hooks) | del(.statusLine)' ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json"
fi

# ---------------------------------------------------------------------------
# 4. memory mirror (+ strict prune)
# ---------------------------------------------------------------------------
MEM_SRC="$PRIV/memory"
MEM_MIRROR_OK=0
if [ -d "$MEM_SRC" ]; then
  run "mkdir -p '$GLOBAL_MEMORY'"
  if [ "$DRY_RUN" -ne 1 ]; then
    cp -an "$MEM_SRC"/. "$GLOBAL_MEMORY"/ 2>/dev/null || true
  fi
  MISSING=0
  while IFS= read -r -d '' f; do
    rel="${f#"$MEM_SRC/"}"
    [ -e "$GLOBAL_MEMORY/$rel" ] || MISSING=$((MISSING + 1))
  done < <(find "$MEM_SRC" -type f -print0 2>/dev/null)
  if [ "$MISSING" -eq 0 ]; then
    MEM_MIRROR_OK=1
    log "memory     mirrored -> $GLOBAL_MEMORY"
    if [ "$STRICT" -eq 1 ] && [ "$DRY_RUN" -ne 1 ]; then
      find "$MEM_SRC" -mindepth 1 -delete 2>/dev/null || true
      log "memory     pruned $MEM_SRC/* (dir retained)"
    fi
  else
    warn "memory mirror incomplete ($MISSING missing) — keeping per-project copy intact"
  fi
fi

# ---------------------------------------------------------------------------
# 5. sessions mirror (+ strict purge)
# ---------------------------------------------------------------------------
SESS_SRC="$PRIV/sessions"
SESS_MIRROR_OK=0
if [ -d "$SESS_SRC" ]; then
  run "mkdir -p '$GLOBAL_SESSIONS'"
  if [ "$DRY_RUN" -ne 1 ]; then
    cp -an "$SESS_SRC"/. "$GLOBAL_SESSIONS"/ 2>/dev/null || true
  fi
  MISSING=0
  while IFS= read -r -d '' f; do
    rel="${f#"$SESS_SRC/"}"
    [ -e "$GLOBAL_SESSIONS/$rel" ] || MISSING=$((MISSING + 1))
  done < <(find "$SESS_SRC" -type f -name '*.md' -print0 2>/dev/null)
  if [ "$MISSING" -eq 0 ]; then
    SESS_MIRROR_OK=1
    log "sessions   mirrored -> $GLOBAL_SESSIONS (hooks own ongoing sync)"
  else
    warn "sessions mirror incomplete ($MISSING missing) — keeping per-project copies intact"
  fi
fi

if [ "$STRICT" -eq 1 ] && [ "$SESS_MIRROR_OK" -eq 1 ]; then
  if [ "$DRY_RUN" -ne 1 ]; then
    find "$SESS_SRC" -mindepth 1 -type f -name '*.md'  -delete 2>/dev/null || true
    find "$SESS_SRC" -mindepth 1 -type f -name '*.tsv' -delete 2>/dev/null || true
    find "$SESS_SRC" -mindepth 1 -type d -empty -delete 2>/dev/null || true
    mkdir -p "$SESS_SRC"
    touch "$SESS_SRC/.keep"
  fi
  log "sessions   strict purge: cleared $SESS_SRC/*.md+.tsv (dir kept for hook fast-write)"
fi

# ---------------------------------------------------------------------------
# 6. toolkit strict purge
# ---------------------------------------------------------------------------
PURGED=0
KEPT=0
if [ "$STRICT" -eq 1 ] && [ "$GLOBALIZED" -eq 1 ] && [ -d "$PROJECT_ROOT/tmp-igbkp" ]; then
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
# 7. write marker
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" -ne 1 ]; then
  mkdir -p "$PRIV"
  printf '%s\n' "$PLUGIN_VER" > "$MARKER"
fi
log "marker     $MARKER = $PLUGIN_VER"

# ---------------------------------------------------------------------------
# 8. final report
# ---------------------------------------------------------------------------
GLOBAL_FILES=0
if [ "$SKIP_GLOBALS" -eq 0 ]; then
  GLOBAL_FILES=$( { find "$HOME/.claude/hooks" "$HOME/.claude/skills" "$HOME/.claude/output-styles" -type f 2>/dev/null || true; } | wc -l | tr -d ' ')
fi
PRESERVED=0
[ -d "$PRIV" ] && PRESERVED=$( { find "$PRIV" -maxdepth 2 -type f 2>/dev/null || true; } | wc -l | tr -d ' ')

MODE_LABEL="strict"
[ "$STRICT" -eq 0 ] && MODE_LABEL="lenient"

printf '\n'
printf '[upgrade] backup     %s (%d items)\n'      "$BACKUP_DIR"  "$BACKUP_COUNT"
printf '[upgrade] removed    %d v5.x artifacts\n'  "$N_REMOVED"
printf '[upgrade] globalized %d files -> ~/.claude/\n' "$GLOBAL_FILES"
printf '[upgrade] purged     %d local toolkit scripts (kept %d as fallback)\n' "$PURGED" "$KEPT"
printf '[upgrade] preserved  %d files (per-project AIPS bits)\n' "$PRESERVED"
printf '[upgrade] marker     %s = %s\n'           "$MARKER" "$PLUGIN_VER"
printf '[upgrade] mode       %s\n'                "$MODE_LABEL"
printf 'Upgraded to v%s (from v%s) — %d globalized, %d preserved, backup at %s\n' \
  "$PLUGIN_VER" "$CUR_VER" "$GLOBAL_FILES" "$PRESERVED" "$BACKUP_DIR"
[ "$DRY_RUN" -eq 1 ] && warn "(dry-run — no changes written)"
exit 0
