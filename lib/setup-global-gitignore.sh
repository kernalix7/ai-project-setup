#!/usr/bin/env bash
# AIPS v7.0 — Global gitignore installer
# Installs the AIPS ignore block into git's global excludes file so per-project
# .gitignore files no longer need to repeat the standard AIPS patterns.
#
# Usage:
#   bash lib/setup-global-gitignore.sh            # install or update block
#   bash lib/setup-global-gitignore.sh --dry-run  # print plan, modify nothing
#   bash lib/setup-global-gitignore.sh --remove   # strip block (clean uninstall)
#
# Idempotent: re-running leaves the same end state.

set -euo pipefail

MODE="install"
for arg in "$@"; do
  case "$arg" in
    --dry-run) MODE="dry-run" ;;
    --remove)  MODE="remove" ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "[error] unknown flag: $arg" >&2
      exit 2
      ;;
  esac
done

# 1. Detect target file: respect existing core.excludesfile, else default.
EXCLUDES_FILE="$(git config --global --get core.excludesfile 2>/dev/null || true)"
if [ -z "${EXCLUDES_FILE}" ]; then
  EXCLUDES_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore"
fi
# Expand leading ~ if present.
case "$EXCLUDES_FILE" in
  "~/"*) EXCLUDES_FILE="$HOME/${EXCLUDES_FILE#~/}" ;;
esac

# Read plugin major.minor from the manifest next to this script — keeps the
# block marker stable across patch releases (v7.0.x all share "v7.0" marker).
PLUGIN_JSON="$(cd "$(dirname "$0")/.." && pwd)/.claude-plugin/plugin.json"
PLUGIN_FULL="unknown"
PLUGIN_MM="unknown"
if [ -f "$PLUGIN_JSON" ]; then
  if command -v jq >/dev/null 2>&1; then
    PLUGIN_FULL="$(jq -r '.version // "unknown"' "$PLUGIN_JSON")"
  else
    PLUGIN_FULL="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN_JSON" | head -1)"
    [ -z "$PLUGIN_FULL" ] && PLUGIN_FULL="unknown"
  fi
  if [ "$PLUGIN_FULL" != "unknown" ]; then
    PLUGIN_MM="${PLUGIN_FULL%.*}"
    [ -z "$PLUGIN_MM" ] && PLUGIN_MM="$PLUGIN_FULL"
  fi
fi

BEGIN_MARK="# === AIPS v${PLUGIN_MM} (global) ==="
END_MARK="# === /AIPS v${PLUGIN_MM} ==="

AIPS_BLOCK="$(cat <<BLOCK
${BEGIN_MARK}
.priv-storage/
tmp-igbkp/
.claude/
.codex/
.aider*
.continue/
.cline/
.roo/
.mcp.json
CLAUDE.local.md
AGENTS.md
.cursorrules
.vscode/settings.json
uninstall-backup-*/
migrate-backup-*/
reset-backup-*/
upgrade-v${PLUGIN_MM%.*}-backup-*/
*.bak
${END_MARK}
BLOCK
)"

if [ "$MODE" = "dry-run" ]; then
  echo "[plan] target excludes file: $EXCLUDES_FILE"
  if [ -f "$EXCLUDES_FILE" ] && grep -qF "$BEGIN_MARK" "$EXCLUDES_FILE"; then
    echo "[plan] action: REPLACE existing AIPS block"
  else
    echo "[plan] action: APPEND AIPS block (file may need creation)"
  fi
  if [ -z "$(git config --global --get core.excludesfile 2>/dev/null || true)" ]; then
    echo "[plan] git config: set core.excludesfile=$EXCLUDES_FILE"
  else
    echo "[plan] git config: core.excludesfile already set, leaving as-is"
  fi
  echo "[plan] block content:"
  printf '%s\n' "$AIPS_BLOCK"
  echo "[plan] (dry-run — no changes written)"
  exit 0
fi

# 2. Ensure parent dir + file exist.
mkdir -p "$(dirname "$EXCLUDES_FILE")"
touch "$EXCLUDES_FILE"

# 3. Set git config if unset.
if [ -z "$(git config --global --get core.excludesfile 2>/dev/null || true)" ]; then
  git config --global core.excludesfile "$EXCLUDES_FILE"
  echo "[ok] git config --global core.excludesfile -> $EXCLUDES_FILE"
fi

# Helper: rewrite file without the AIPS block (preserves everything else).
strip_block() {
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0 == b { skip = 1; next }
    skip && $0 == e { skip = 0; next }
    !skip { print }
  ' "$EXCLUDES_FILE"
}

if [ "$MODE" = "remove" ]; then
  if grep -qF "$BEGIN_MARK" "$EXCLUDES_FILE"; then
    TMP="$(mktemp)"
    strip_block > "$TMP"
    # Trim trailing blank lines for tidiness.
    sed -e :a -e '/^$/{$d;N;ba' -e '}' "$TMP" > "$EXCLUDES_FILE"
    rm -f "$TMP"
    echo "[ok] AIPS gitignore block removed from $EXCLUDES_FILE"
  else
    echo "[ok] no AIPS block present in $EXCLUDES_FILE (nothing to remove)"
  fi
  exit 0
fi

# 4. Install or update (idempotent).
if grep -qF "$BEGIN_MARK" "$EXCLUDES_FILE"; then
  TMP="$(mktemp)"
  strip_block > "$TMP"
  # Ensure single trailing newline before appending.
  if [ -s "$TMP" ] && [ "$(tail -c1 "$TMP" | wc -l)" -eq 0 ]; then
    printf '\n' >> "$TMP"
  fi
  printf '%s\n' "$AIPS_BLOCK" >> "$TMP"
  mv "$TMP" "$EXCLUDES_FILE"
  echo "[ok] AIPS gitignore block updated (already present) at $EXCLUDES_FILE"
else
  if [ -s "$EXCLUDES_FILE" ] && [ "$(tail -c1 "$EXCLUDES_FILE" | wc -l)" -eq 0 ]; then
    printf '\n' >> "$EXCLUDES_FILE"
  fi
  printf '%s\n' "$AIPS_BLOCK" >> "$EXCLUDES_FILE"
  echo "[ok] AIPS gitignore block installed at $EXCLUDES_FILE"
fi

echo "[note] Per-project .gitignore may now drop AIPS-specific entries — see /aips:upgrade --to v${PLUGIN_MM}."
