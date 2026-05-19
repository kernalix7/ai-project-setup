---
description: Update the global AIPS plugin and re-sync this project's local files.
allowed-tools: ["Bash", "Read", "Write", "Edit", "Glob", "Grep"]
---

# /aips:update

Pull the latest global plugin release and reconcile the current project's per-project files against the new templates. Non-destructive — preserves user content.

## What it does

1. **Global plugin update** — invoke the plugin update flow:
   ```bash
   claude --print "/plugin update AIPS@AIPS"
   ```
   Capture the new version reported by `cat ~/.claude/plugins/AIPS/.claude-plugin/plugin.json | grep version`.

2. **Per-project re-init (CASE C)** — re-run `/aips:init` semantics in idempotent-sync mode:
   - Diff global `templates/` against project `.priv-storage/` managed files.
   - Apply non-destructive updates only (skeleton headers, toolkit scripts, symlinks, `.gitignore` block).
   - Re-render `.priv-storage/CLAUDE.md` from `templates/CLAUDE.md.tmpl` ONLY if the template version is newer AND the project CLAUDE.md has no local edits beyond Section 1-7 + 11 placeholders. Otherwise skip and emit a WARN telling the user to merge manually.
   - Refresh `tmp-igbkp/*.sh` toolkit scripts that match the shipped versions verbatim.

3. **Memory sync** — if agentmemory plugin is installed and the service is reachable, run a one-shot sync pass so per-project `.priv-storage/memory/*.md` and the global agentmemory store stay aligned (dual-write reconciliation).

4. **Report** — emit one line per change:
   - `update: plugin AIPS v<old> → v<new>`
   - `update: templates synced — <N> files updated, <M> preserved`
   - `update: CLAUDE.md re-rendered` OR `update: CLAUDE.md skipped (local edits — merge manually)`
   - `update: memory synced — <N> entries reconciled` (if agentmemory present)

## Rules

- Never overwrite `WORK_STATUS.md`, `memory/*.md` content, `sessions/*`.
- Never touch project source code.
- If global plugin update fails, abort and surface the error — do not run per-project sync against stale templates.
