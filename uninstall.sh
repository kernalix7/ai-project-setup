#!/usr/bin/env bash
# AIPS v7.0 uninstaller — user-level, no sudo, interactive by default.
#
# SAFE BY DESIGN:
#   - Default: only removes the AIPS plugin + aips-* toolkit symlinks.
#   - Dep plugins (codex-plugin-cc, caveman, agentmemory, RTK) are KEPT
#     unless --purge is passed.
#   - User data (sessions, memory, agentmemory db) is KEPT unless
#     --remove-data is passed.
#   - Every destructive action asks per-category with the exact paths
#     shown. Default answer is N (no). --yes skips prompts (automation).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/uninstall.sh | bash
#   bash uninstall.sh [--purge] [--remove-data] [--all] [--dry-run] [--yes] [--quiet]
#
# Flags:
#   --purge        Also remove: gitignore block, systemd unit, dep plugins, RTK binary
#   --remove-data  Also remove: sessions mirror, memory store, agentmemory db (USER DATA — DANGER)
#   --all          --purge + --remove-data (full nuke, still asks per category)
#   --dry-run      Print plan, do not execute any rm/unlink/systemctl
#   --yes          Skip all interactive prompts (assume y for in-scope categories)
#   --quiet        Suppress detail lines
#   -h, --help     Show this header

set -euo pipefail

# ---------- color / logging ----------
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_RESET="$(tput sgr0)"; C_BLUE="$(tput setaf 4)"; C_GREEN="$(tput setaf 2)"
  C_YELLOW="$(tput setaf 3)"; C_RED="$(tput setaf 1)"; C_DIM="$(tput dim 2>/dev/null || echo '')"
  C_BOLD="$(tput bold)"; C_CYAN="$(tput setaf 6)"
else
  C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_BOLD=""; C_CYAN=""
fi
log()    { printf "%s[uninstall]%s %s\n" "$C_BLUE"   "$C_RESET" "$*"; }
ok()     { printf "%s[ok]%s %s\n"        "$C_GREEN"  "$C_RESET" "$*"; }
skip()   { printf "%s[skip]%s %s\n"      "$C_DIM"    "$C_RESET" "$*"; }
warn()   { printf "%s[warn]%s %s\n"      "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()    { printf "%s[error]%s %s\n"     "$C_RED"    "$C_RESET" "$*" >&2; }
detail() { [ "$QUIET" = "1" ] || printf "  %s%s%s\n" "$C_DIM" "$*" "$C_RESET"; }
banner() { printf "\n%s═══ %s%s\n" "$C_BOLD" "$1" "$C_RESET"; }

# ---------- defaults / flags ----------
PURGE=0
REMOVE_DATA=0
DRY_RUN=0
ASSUME_YES=0
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --purge)       PURGE=1; shift ;;
    --remove-data) REMOVE_DATA=1; shift ;;
    --all)         PURGE=1; REMOVE_DATA=1; shift ;;
    --dry-run)     DRY_RUN=1; shift ;;
    --yes|-y)      ASSUME_YES=1; shift ;;
    --quiet)       QUIET=1; shift ;;
    -h|--help)     sed -n '2,28p' "$0"; exit 0 ;;
    *)             err "unknown flag: $1"; exit 1 ;;
  esac
done

# ---------- helpers ----------
human_size() {
  # Best-effort directory size. Returns "-" if path missing.
  if [ -e "$1" ]; then
    du -sh "$1" 2>/dev/null | awk '{print $1}' || echo "?"
  else
    printf "-"
  fi
}

count_files() {
  if [ -d "$1" ]; then
    find "$1" -type f 2>/dev/null | wc -l | tr -d ' '
  else
    echo 0
  fi
}

# Run a destructive command (or print under dry-run). Always logs the action.
do_rm() {
  if [ "$DRY_RUN" = "1" ]; then printf "  %s[dry-run]%s %s\n" "$C_DIM" "$C_RESET" "$*"; return 0; fi
  eval "$@"
}

# Interactive per-category prompt.
# Args: category-name, prompt-question (default answer is N).
# Returns 0 if user confirmed, 1 if declined.
confirm() {
  local cat="$1" q="$2"
  if [ "$ASSUME_YES" = "1" ]; then
    log "$cat: --yes flag → auto-confirm"
    return 0
  fi
  # Read from /dev/tty when stdin is piped (curl | bash safety)
  local reply
  if [ -t 0 ]; then
    printf "  %s? [y/N]: %s" "$q" "$C_RESET"
    read -r reply || reply=""
  elif [ -r /dev/tty ]; then
    printf "  %s? [y/N]: %s" "$q" "$C_RESET"
    read -r reply </dev/tty || reply=""
  else
    warn "no tty for prompt — assuming NO ($cat skipped). Use --yes for automation."
    return 1
  fi
  case "$(echo "${reply:-N}" | tr '[:upper:]' '[:lower:]')" in
    y|yes) return 0 ;;
    *)     return 1 ;;
  esac
}

# ---------- banner ----------
cat <<BANNER

${C_BOLD}${C_CYAN}╔════════════════════════════════════════════════════════════════╗
║  AIPS uninstaller — user-level, no sudo                        ║
║  Interactive per-category. Defaults to safest (smallest blast) ║
╚════════════════════════════════════════════════════════════════╝${C_RESET}

Mode:
BANNER
[ "$DRY_RUN"      = "1" ] && echo "  ${C_YELLOW}DRY RUN${C_RESET}   — no changes will be made"
[ "$ASSUME_YES"   = "1" ] && echo "  ${C_YELLOW}--yes${C_RESET}     — skip prompts, assume yes for in-scope categories"
[ "$PURGE"        = "1" ] && echo "  ${C_YELLOW}--purge${C_RESET}   — also remove configs (gitignore block, systemd unit, dep plugins, RTK)"
[ "$REMOVE_DATA"  = "1" ] && echo "  ${C_RED}--remove-data${C_RESET} — also remove USER DATA (sessions, memory, agentmemory db)"
[ "$PURGE" = "0" ] && [ "$REMOVE_DATA" = "0" ] && echo "  ${C_GREEN}safe default${C_RESET} — only AIPS plugin + aips-* symlinks. Dep plugins + data preserved."

echo
log "Scanning installed components..."

# ---------- inventory ----------
AIPS_PLUGIN_DIR="$HOME/.claude/plugins/cache/AIPS/AIPS"
AIPS_PLUGIN_SIZE="$(human_size "$AIPS_PLUGIN_DIR")"
AIPS_SYMLINKS=()
for f in "$HOME/.local/bin"/aips-*; do
  [ -e "$f" ] && AIPS_SYMLINKS+=("$f")
done
GIT_IGNORE_PATH="$(git config --global core.excludesfile 2>/dev/null || echo "$HOME/.config/git/ignore")"
SYSTEMD_UNIT="$HOME/.config/systemd/user/agentmemory.service"
DEP_CODEX="$HOME/.claude/plugins/cache/openai-codex/codex"
DEP_CAVEMAN="$HOME/.claude/plugins/cache/caveman/caveman"
DEP_AGENTMEM="$HOME/.claude/plugins/cache/agentmemory/agentmemory"
RTK_BIN="$HOME/.local/bin/rtk"
DATA_SESSIONS="$HOME/.claude/sessions"
DATA_PROJECTS="$HOME/.claude/projects"
DATA_AM_DB="$HOME/.local/share/aips"

# ---------- 1. AIPS plugin (always in scope) ----------
banner "1. AIPS plugin"
detail "Path:    $AIPS_PLUGIN_DIR"
detail "Size:    $AIPS_PLUGIN_SIZE"
detail "Action:  /plugin uninstall AIPS@AIPS (via claude CLI)"
if [ -d "$AIPS_PLUGIN_DIR" ]; then
  if confirm "AIPS plugin" "Remove AIPS plugin from ~/.claude/plugins/cache/AIPS/AIPS"; then
    if command -v claude >/dev/null 2>&1; then
      do_rm "claude --print '/plugin uninstall AIPS@AIPS' >/dev/null 2>&1 || true"
      do_rm "rm -rf '$AIPS_PLUGIN_DIR'"
      ok "AIPS plugin removed"
    else
      warn "claude CLI not found — falling back to rm -rf"
      do_rm "rm -rf '$AIPS_PLUGIN_DIR'"
      ok "AIPS plugin dir removed (rm fallback)"
    fi
  else
    skip "AIPS plugin kept"
  fi
else
  skip "AIPS plugin not installed"
fi

# ---------- 2. aips-* toolkit symlinks (always in scope) ----------
banner "2. AIPS toolkit symlinks"
if [ "${#AIPS_SYMLINKS[@]}" -gt 0 ]; then
  detail "Count: ${#AIPS_SYMLINKS[@]} symlinks at ~/.local/bin/"
  for s in "${AIPS_SYMLINKS[@]}"; do
    if [ -L "$s" ]; then
      target="$(readlink -f "$s" 2>/dev/null || readlink "$s")"
      detail "$(basename "$s") → ${target:-<unresolved>}"
    else
      detail "$(basename "$s") (regular file, not symlink — will be backed up not deleted)"
    fi
  done
  if confirm "aips-* symlinks" "Remove ${#AIPS_SYMLINKS[@]} aips-* entries from ~/.local/bin"; then
    for s in "${AIPS_SYMLINKS[@]}"; do
      if [ -L "$s" ]; then
        do_rm "rm -f '$s'"
      elif [ -f "$s" ]; then
        do_rm "mv '$s' '$s.uninstall.bak'"
        warn "$(basename "$s") was a real file — moved to $(basename "$s").uninstall.bak (not deleted)"
      fi
    done
    ok "aips-* toolkit symlinks removed"
  else
    skip "aips-* symlinks kept"
  fi
else
  skip "no aips-* symlinks found"
fi

# ---------- 3. AIPS gitignore block (purge) ----------
banner "3. AIPS .gitignore block (global)"
detail "Path:   $GIT_IGNORE_PATH"
GI_HAS_BLOCK=0
GI_BLOCK_LABEL=""
if [ -f "$GIT_IGNORE_PATH" ]; then
  # Match any AIPS vN.N block — version-agnostic.
  GI_BLOCK_LABEL="$(grep -oE '^# === AIPS v[0-9]+\.[0-9]+( \([a-z]+\))? ===' "$GIT_IGNORE_PATH" 2>/dev/null | head -1)"
  if [ -n "$GI_BLOCK_LABEL" ]; then
    GI_HAS_BLOCK=1
    detail "Found:  $GI_BLOCK_LABEL ($(grep -c '^' "$GIT_IGNORE_PATH") lines total in file)"
  fi
fi
if [ "$PURGE" = "1" ]; then
  if [ "$GI_HAS_BLOCK" = "1" ]; then
    if confirm "gitignore block" "Strip $GI_BLOCK_LABEL block from $GIT_IGNORE_PATH"; then
      # Strip any AIPS vN.N block — start marker is GI_BLOCK_LABEL, end is the matching /AIPS vN.N.
      do_rm "sed -i.uninstall.bak '/^# === AIPS v[0-9]\\+\\.[0-9]\\+\\( ([a-z]\\+)\\)\\? ===\$/,/^# === \\/AIPS v[0-9]\\+\\.[0-9]\\+\\( ([a-z]\\+)\\)\\? ===\$/d' '$GIT_IGNORE_PATH'"
      ok "gitignore block stripped (backup: $GIT_IGNORE_PATH.uninstall.bak)"
    else
      skip "gitignore block kept"
    fi
  else
    skip "no AIPS gitignore block found"
  fi
else
  if [ "$GI_HAS_BLOCK" = "1" ]; then
    skip "gitignore block kept (pass --purge to remove)"
  else
    skip "no AIPS gitignore block found"
  fi
fi

# ---------- 4. agentmemory systemd service (purge) ----------
banner "4. agentmemory systemd user service"
detail "Unit:   $SYSTEMD_UNIT"
SVC_ACTIVE=0
if [ "$(uname -s 2>/dev/null)" = "Linux" ] && command -v systemctl >/dev/null 2>&1; then
  if systemctl --user is-active agentmemory.service >/dev/null 2>&1; then
    SVC_ACTIVE=1
    detail "Status: active (running)"
  elif [ -f "$SYSTEMD_UNIT" ]; then
    detail "Status: present but inactive"
  fi
fi
if [ "$PURGE" = "1" ]; then
  if [ -f "$SYSTEMD_UNIT" ] || [ "$SVC_ACTIVE" = "1" ]; then
    if confirm "systemd service" "Stop + disable + remove agentmemory.service"; then
      do_rm "systemctl --user stop agentmemory.service 2>/dev/null || true"
      do_rm "systemctl --user disable agentmemory.service 2>/dev/null || true"
      do_rm "rm -f '$SYSTEMD_UNIT'"
      do_rm "systemctl --user daemon-reload 2>/dev/null || true"
      ok "agentmemory systemd service removed"
    else
      skip "systemd service kept"
    fi
  else
    skip "no agentmemory systemd service installed"
  fi
else
  if [ -f "$SYSTEMD_UNIT" ]; then
    skip "systemd service kept (pass --purge to remove)"
  else
    skip "no agentmemory systemd service installed"
  fi
fi

# ---------- 5. Dependency plugins (purge) ----------
banner "5. Dependency plugins"
DEP_LIST=()
for entry in "codex-plugin-cc|$DEP_CODEX|codex@openai-codex" \
             "caveman|$DEP_CAVEMAN|caveman@caveman" \
             "agentmemory|$DEP_AGENTMEM|agentmemory@agentmemory"; do
  name="${entry%%|*}"
  rest="${entry#*|}"; path="${rest%%|*}"
  spec="${entry##*|}"
  if [ -d "$path" ]; then
    detail "$name: $path ($(human_size "$path"))"
    DEP_LIST+=("$name|$path|$spec")
  fi
done

if [ "$PURGE" = "1" ]; then
  if [ "${#DEP_LIST[@]}" -gt 0 ]; then
    for entry in "${DEP_LIST[@]}"; do
      name="${entry%%|*}"; rest="${entry#*|}"
      path="${rest%%|*}"; spec="${entry##*|}"
      if confirm "$name" "Uninstall $name ($spec)"; then
        if command -v claude >/dev/null 2>&1; then
          do_rm "claude --print '/plugin uninstall $spec' >/dev/null 2>&1 || true"
        fi
        do_rm "rm -rf '$path'"
        ok "$name removed"
      else
        skip "$name kept"
      fi
    done
  else
    skip "no dependency plugins installed"
  fi
else
  if [ "${#DEP_LIST[@]}" -gt 0 ]; then
    skip "${#DEP_LIST[@]} dependency plugins kept (pass --purge to remove)"
  else
    skip "no dependency plugins installed"
  fi
fi

# ---------- 6. RTK binary (purge) ----------
banner "6. RTK binary (Rust Token Killer)"
if [ -f "$RTK_BIN" ] || [ -L "$RTK_BIN" ]; then
  detail "Path:    $RTK_BIN"
  detail "Version: $(rtk --version 2>/dev/null || echo unknown)"
  detail "Note:    RTK is a general tool, not AIPS-specific. Removing affects other workflows."
  if [ "$PURGE" = "1" ]; then
    if confirm "RTK binary" "Remove $RTK_BIN (RTK general CLI, used outside AIPS too)"; then
      do_rm "rm -f '$RTK_BIN'"
      ok "RTK binary removed"
    else
      skip "RTK kept"
    fi
  else
    skip "RTK kept (pass --purge to remove)"
  fi
else
  skip "RTK not installed"
fi

# ---------- 7. User data — sessions mirror (remove-data) ----------
banner "7. Sessions mirror (USER DATA)"
SESS_COUNT=0
SESS_SIZE="-"
if [ -d "$DATA_SESSIONS" ]; then
  SESS_COUNT="$(find "$DATA_SESSIONS" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
  SESS_SIZE="$(human_size "$DATA_SESSIONS")"
fi
detail "Path:     $DATA_SESSIONS"
detail "Projects: $SESS_COUNT path-hash dirs"
detail "Size:     $SESS_SIZE"
detail "${C_RED}WARNING${C_RESET}: removing this loses session history for all globalized projects."
if [ "$REMOVE_DATA" = "1" ]; then
  if [ -d "$DATA_SESSIONS" ] && [ "$SESS_COUNT" -gt 0 ]; then
    if confirm "sessions mirror" "Remove ALL session history at $DATA_SESSIONS"; then
      do_rm "rm -rf '$DATA_SESSIONS'"
      ok "sessions mirror removed"
    else
      skip "sessions mirror kept"
    fi
  else
    skip "no sessions mirror data"
  fi
else
  if [ -d "$DATA_SESSIONS" ] && [ "$SESS_COUNT" -gt 0 ]; then
    skip "sessions mirror kept (pass --remove-data to remove)"
  else
    skip "no sessions mirror data"
  fi
fi

# ---------- 8. User data — memory store (remove-data) ----------
banner "8. Memory store (USER DATA)"
MEM_COUNT=0
MEM_SIZE="-"
if [ -d "$DATA_PROJECTS" ]; then
  MEM_COUNT="$(find "$DATA_PROJECTS" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
  MEM_SIZE="$(human_size "$DATA_PROJECTS")"
fi
detail "Path:     $DATA_PROJECTS"
detail "Projects: $MEM_COUNT path-encoded dirs"
detail "Size:     $MEM_SIZE"
detail "${C_RED}WARNING${C_RESET}: this dir may contain non-AIPS Claude Code data too."
detail "${C_RED}WARNING${C_RESET}: removing this loses ALL memory (user, feedback, project, reference)."
if [ "$REMOVE_DATA" = "1" ]; then
  if [ -d "$DATA_PROJECTS" ] && [ "$MEM_COUNT" -gt 0 ]; then
    if confirm "memory store" "Remove ALL memory data at $DATA_PROJECTS (affects non-AIPS Claude Code data too)"; then
      do_rm "rm -rf '$DATA_PROJECTS'"
      ok "memory store removed"
    else
      skip "memory store kept"
    fi
  else
    skip "no memory store data"
  fi
else
  if [ -d "$DATA_PROJECTS" ] && [ "$MEM_COUNT" -gt 0 ]; then
    skip "memory store kept (pass --remove-data to remove)"
  else
    skip "no memory store data"
  fi
fi

# ---------- 9. agentmemory database (remove-data) ----------
banner "9. agentmemory database (USER DATA)"
AM_SIZE="-"
[ -d "$DATA_AM_DB" ] && AM_SIZE="$(human_size "$DATA_AM_DB")"
detail "Path: $DATA_AM_DB"
detail "Size: $AM_SIZE"
detail "${C_RED}WARNING${C_RESET}: SQLite db with ALL tool-use observations across ALL projects."
if [ "$REMOVE_DATA" = "1" ]; then
  if [ -d "$DATA_AM_DB" ]; then
    if confirm "agentmemory db" "Remove agentmemory SQLite db at $DATA_AM_DB"; then
      do_rm "rm -rf '$DATA_AM_DB'"
      ok "agentmemory db removed"
    else
      skip "agentmemory db kept"
    fi
  else
    skip "no agentmemory db"
  fi
else
  if [ -d "$DATA_AM_DB" ]; then
    skip "agentmemory db kept (pass --remove-data to remove)"
  else
    skip "no agentmemory db"
  fi
fi

# ---------- final summary ----------
echo
cat <<EOF

${C_BOLD}${C_GREEN}╔════════════════════════════════════════════════════════════════╗
║  AIPS uninstall complete                                       ║
╚════════════════════════════════════════════════════════════════╝${C_RESET}

${C_BOLD}What's left on your system:${C_RESET}
EOF

[ "$PURGE" = "0" ] && cat <<EOF
  ${C_DIM}(default mode — most things kept)${C_RESET}
  ${C_GREEN}KEPT${C_RESET}  ~/.config/git/ignore         ${C_DIM}(AIPS block; pass --purge to remove)${C_RESET}
  ${C_GREEN}KEPT${C_RESET}  ~/.config/systemd/user/...   ${C_DIM}(agentmemory; pass --purge to remove)${C_RESET}
  ${C_GREEN}KEPT${C_RESET}  ~/.claude/plugins/cache/{codex,caveman,agentmemory}  ${C_DIM}(deps; pass --purge to remove)${C_RESET}
  ${C_GREEN}KEPT${C_RESET}  ~/.local/bin/rtk             ${C_DIM}(RTK; pass --purge to remove)${C_RESET}
EOF
[ "$REMOVE_DATA" = "0" ] && cat <<EOF
  ${C_GREEN}KEPT${C_RESET}  ~/.claude/sessions/          ${C_DIM}(session history; pass --remove-data to remove)${C_RESET}
  ${C_GREEN}KEPT${C_RESET}  ~/.claude/projects/          ${C_DIM}(memory; pass --remove-data to remove)${C_RESET}
  ${C_GREEN}KEPT${C_RESET}  ~/.local/share/aips/         ${C_DIM}(agentmemory db; pass --remove-data to remove)${C_RESET}
EOF

cat <<EOF

${C_BOLD}Per-project state:${C_RESET}
  Each repo's .priv-storage/ (CLAUDE.md, WORK_STATUS.md, memory/, etc.)
  is UNTOUCHED. To clean up a project, run inside that repo:
    ${C_CYAN}claude${C_RESET}
    > ${C_GREEN}/aips:uninstall${C_RESET}   ${C_DIM}# project-local cleanup with backup${C_RESET}

${C_BOLD}To reinstall:${C_RESET}
  curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/install.sh | bash

EOF

exit 0
