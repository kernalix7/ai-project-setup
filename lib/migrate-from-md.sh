#!/usr/bin/env bash
# AIPS v6.0 — migrate-from-md.sh
# Migrate a v5.x project (single-file AI_PROJECT_SETUP.md model) to v6.0
# (plugin model). Idempotent. All deletions are backed up first.
#
# Usage:
#   bash lib/migrate-from-md.sh [PROJECT_ROOT] [--dry-run] [--auto-confirm]
#
# Flags:
#   --dry-run        Print actions without executing.
#   --auto-confirm   Skip the [Y/n] prompt (used by /aips:init CASE B after
#                    the user already confirmed at the command level).

set -euo pipefail

# ---------- color ----------
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_RESET="$(tput sgr0)"; C_BLUE="$(tput setaf 4)"; C_GREEN="$(tput setaf 2)"
  C_YELLOW="$(tput setaf 3)"; C_RED="$(tput setaf 1)"
else
  C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi
log()  { printf "%s[migrate]%s %s\n" "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf "%s[ok]%s %s\n"      "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf "%s[warn]%s %s\n"    "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf "%s[error]%s %s\n"   "$C_RED"    "$C_RESET" "$*" >&2; }

# ---------- arg parse ----------
ROOT=""
DRY_RUN=0
AUTO_CONFIRM=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)      DRY_RUN=1; shift ;;
    --auto-confirm) AUTO_CONFIRM=1; shift ;;
    -h|--help)
      sed -n '2,15p' "$0"; exit 0 ;;
    -*)
      err "unknown flag: $1"; exit 1 ;;
    *)
      [ -z "$ROOT" ] && ROOT="$1" || { err "extra positional arg: $1"; exit 1; }
      shift ;;
  esac
done
ROOT="${ROOT:-$PWD}"
ROOT="${ROOT%/}"

if [ ! -d "$ROOT" ]; then err "PROJECT_ROOT not a directory: $ROOT"; exit 1; fi

# ---------- run helper ----------
run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf "  [dry-run] %s\n" "$*"
    return 0
  fi
  eval "$@"
}

# ---------- detect v5.x ----------
is_v5=0
[ -f "$ROOT/.priv-storage/AI_PROJECT_SETUP.md" ] && is_v5=1
[ -f "$ROOT/.priv-storage/.claude/commands/codex-brief.md" ] && is_v5=1
[ -f "$ROOT/tmp-igbkp/codex-relay-check.sh" ]    && is_v5=1
[ -f "$ROOT/tmp-igbkp/codex-relay-run.sh" ]      && is_v5=1

if [ "$is_v5" = "0" ]; then
  warn "no v5.x markers found in $ROOT — nothing to migrate."
  exit 0
fi

# ---------- build removal list (only files actually present) ----------
declare -a REMOVE_FILES=(
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

declare -a REMOVE_DIRS=(
  ".priv-storage/.claude/hooks"
  ".priv-storage/.claude/skills"
  ".priv-storage/.claude/output-styles"
  ".priv-storage/.claude/statusline"
  ".priv-storage/sessions/codex-relay"
)

# ---------- PLAN ----------
log "AIPS v5.x → v6.0 migration plan for: $ROOT"
echo
echo "REMOVE (files):"
for f in "${REMOVE_FILES[@]}"; do
  if [ -e "$ROOT/$f" ]; then printf "  - %s\n" "$f"; fi
done
echo
echo "REMOVE (dirs):"
for d in "${REMOVE_DIRS[@]}"; do
  if [ -e "$ROOT/$d" ]; then printf "  - %s/\n" "$d"; fi
done
echo
echo "EDIT:"
echo "  - .priv-storage/CLAUDE.md  (delete Sections 8, 9, 10, 12, 13 — globalized in v6.0)"
echo
echo "PRESERVE:"
echo "  - .priv-storage/WORK_STATUS.md"
echo "  - .priv-storage/memory/**"
echo "  - .priv-storage/sessions/{current,recovery,handoff-*}.md"
echo "  - .priv-storage/.mcp.json, .gitignore (root)"
echo "  - .priv-storage/.claude/agents/tech-lead.md, *-team.md"
echo "  - tmp-igbkp/{archive,restore,purge-history,verify-setup,uninstall,smoke-test-hooks,secret-guard,automode-validate,setup-worktree}.sh"
echo

# ---------- confirm ----------
if [ "$AUTO_CONFIRM" = "0" ] && [ "$DRY_RUN" = "0" ]; then
  printf "Proceed? [Y/n] "
  read -r ans || ans=""
  case "${ans:-Y}" in
    n|N|no|NO) err "aborted by user."; exit 1 ;;
  esac
fi

# ---------- backup ----------
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP="$ROOT/tmp-igbkp/migrate-backup-$TS"
log "backup destination: $BACKUP"

if [ "$DRY_RUN" = "0" ]; then
  mkdir -p "$BACKUP"
  if [ -d "$ROOT/.priv-storage" ]; then
    cp -a "$ROOT/.priv-storage" "$BACKUP/priv-storage" \
      && ok "backed up .priv-storage/ → $BACKUP/priv-storage"
  fi
  for f in tmp-igbkp/codex-relay-check.sh tmp-igbkp/codex-relay-run.sh; do
    if [ -f "$ROOT/$f" ]; then
      mkdir -p "$BACKUP/$(dirname "$f")"
      cp -a "$ROOT/$f" "$BACKUP/$f" && ok "backed up $f"
    fi
  done
else
  printf "  [dry-run] mkdir -p %s; cp -a .priv-storage/ tmp-igbkp/codex-relay-*.sh → backup\n" "$BACKUP"
fi

# ---------- REMOVE ----------
log "removing v5.x-only files"
N_REMOVED=0
for f in "${REMOVE_FILES[@]}"; do
  if [ -e "$ROOT/$f" ]; then
    run "rm -f \"$ROOT/$f\""
    N_REMOVED=$((N_REMOVED+1))
  fi
done
for d in "${REMOVE_DIRS[@]}"; do
  if [ -e "$ROOT/$d" ]; then
    run "rm -rf \"$ROOT/$d\""
    N_REMOVED=$((N_REMOVED+1))
  fi
done
ok "removed $N_REMOVED v5.x artifacts"

# ---------- EDIT CLAUDE.md ----------
CFILE="$ROOT/.priv-storage/CLAUDE.md"
if [ -f "$CFILE" ]; then
  log "trimming CLAUDE.md (deleting Sections 8/9/10/12/13)"
  if [ "$DRY_RUN" = "0" ]; then
    # Strategy: walk file; drop everything from any line matching ^## (8|9|10|12|13)\.
    # up to the next ^## N. where N is not in {8,9,10,12,13} (i.e. 11 or end-of-file).
    # Implemented with awk: track "skip" state and the next allowed header pattern.
    TMP="$(mktemp)"
    awk '
      BEGIN { skip = 0; emitted_ref = 0 }
      /^## [0-9]+\. / {
        # extract section number
        match($0, /^## ([0-9]+)\./, arr)
        n = arr[1] + 0
        if (n == 8 || n == 9 || n == 10 || n == 12 || n == 13) {
          if (!emitted_ref) {
            print "<!-- Sections 8/9/10/12/13 globalized in v6.0 — see ~/.claude/CLAUDE.md -->"
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
    printf "  [dry-run] awk-trim Sections 8/9/10/12/13 from %s\n" "$CFILE"
  fi
fi

# ---------- write version marker ----------
if [ "$DRY_RUN" = "0" ]; then
  mkdir -p "$ROOT/.priv-storage"
  printf '6.0\n' > "$ROOT/.priv-storage/.aips-version"
  ok "wrote .priv-storage/.aips-version (6.0)"
else
  printf "  [dry-run] echo 6.0 > .priv-storage/.aips-version\n"
fi

# ---------- count preserved (best-effort) ----------
N_PRESERVED=0
if [ -d "$ROOT/.priv-storage" ]; then
  N_PRESERVED="$(find "$ROOT/.priv-storage" -type f 2>/dev/null | wc -l | tr -d ' ')"
fi

echo
ok "Migrated: $N_REMOVED removed, $N_PRESERVED preserved, backup at $BACKUP"
[ "$DRY_RUN" = "1" ] && warn "(dry-run — no changes written)"
exit 0
