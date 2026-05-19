#!/usr/bin/env bash
# render-settings-json.sh — render templates/settings.json.tmpl into a project's
# .priv-storage/.claude/settings.json. Preserves user-customizable top-level
# keys (model, effort, env, outputStyle, defaultTeamMode, teammateMode,
# attribution) if the file already exists; always overwrites statusLine with
# the resolved plugin path.
#
# Usage:
#   bash lib/render-settings-json.sh <project_root>
#
# Behaviour:
#   - statusLine.command always set to the stable global symlink
#     "$HOME/.local/bin/aips-statusline" when that exists; falls back to the
#     plugin's own statusline path when it doesn't.
#   - .hooks is never written (the plugin's hooks.json registers hooks).
#   - If settings.json already exists, jq merges: user keys win, plugin keys
#     for statusLine are overwritten. Without jq, the file is written from
#     template only if missing; otherwise the script reports and exits 0.
set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$LIB_DIR/.." && pwd)"
TEMPLATE="$PLUGIN_ROOT/templates/settings.json.tmpl"

if [ ! -f "$TEMPLATE" ]; then
  printf '[render-settings] ERROR: template not found at %s\n' "$TEMPLATE" >&2
  exit 1
fi

PROJECT_NAME="$(basename "$PROJECT_ROOT")"

# Resolve statusline path. Prefer the stable global symlink (created by
# globalize-toolkit.sh); fall back to the plugin's bundled statusline.
if [ -e "$HOME/.local/bin/aips-statusline" ]; then
  AIPS_STATUSLINE="$HOME/.local/bin/aips-statusline"
elif [ -f "$PLUGIN_ROOT/statusline" ]; then
  AIPS_STATUSLINE="$PLUGIN_ROOT/statusline"
else
  AIPS_STATUSLINE=""
fi

TARGET_DIR="$PROJECT_ROOT/.priv-storage/.claude"
TARGET="$TARGET_DIR/settings.json"
mkdir -p "$TARGET_DIR"

render_template() {
  sed -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
      -e "s|{{AIPS_STATUSLINE}}|${AIPS_STATUSLINE}|g" \
      "$TEMPLATE"
}

if [ ! -f "$TARGET" ]; then
  render_template > "$TARGET"
  printf '[render-settings] wrote %s (fresh)\n' "$TARGET"
  exit 0
fi

# File exists — merge.
if command -v jq >/dev/null 2>&1; then
  RENDERED="$(render_template)"
  # Drop any stale .hooks so the plugin's hooks.json is the sole hook source.
  jq -s '
    (.[1] // {}) as $tpl
    | (.[0] // {}) as $cur
    | $cur
      | del(.hooks)
      | .statusLine = $tpl.statusLine
      | .project = ($cur.project // $tpl.project)
      | .workingDirectory = ($cur.workingDirectory // $tpl.workingDirectory)
      | .attribution = ($cur.attribution // $tpl.attribution)
      | .model = ($cur.model // $tpl.model)
      | .effort = ($cur.effort // $tpl.effort)
      | .env = ($cur.env // $tpl.env)
      | .teammateMode = ($cur.teammateMode // $tpl.teammateMode)
      | .outputStyle = ($cur.outputStyle // $tpl.outputStyle)
      | .defaultTeamMode = ($cur.defaultTeamMode // $tpl.defaultTeamMode)
  ' "$TARGET" <(printf '%s' "$RENDERED") > "$TARGET.tmp" \
    && mv "$TARGET.tmp" "$TARGET" \
    && printf '[render-settings] merged %s (jq, statusLine refreshed, .hooks removed)\n' "$TARGET"
else
  printf '[render-settings] WARN: jq missing — leaving existing %s intact; statusLine may be stale\n' "$TARGET" >&2
fi
