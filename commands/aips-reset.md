---
description: DESTRUCTIVE — back up and wipe per-project AIPS state, then fresh-init (CASE A).
allowed-tools: ["Bash", "Read", "Write", "Edit", "Glob", "Grep"]
---

# /aips:reset

**Destructive.** Wipes the current project's `.priv-storage/` and root AIPS symlinks, then runs a fresh init (CASE A) from scratch. Always creates a timestamped backup first. Global plugin install is not touched.

## What it does

1. **Locate `PROJECT_ROOT`** — walk up from `$PWD` to nearest `.git`.
2. **Confirm — REQUIRED EXPLICIT `y`** — prompt:
   ```
   This will reset all per-project AIPS state.
   Backup will be at tmp-igbkp/reset-backup-<ts>/.
   Proceed? [y/N]
   ```
   Any input other than literal `y` aborts immediately. Empty input (Enter) aborts.
3. **Backup** — create `tmp-igbkp/reset-backup-<YYYYMMDD-HHMMSS>/` and move into it:
   - `.priv-storage/` (entire dir)
   - root symlinks if they resolve into `.priv-storage/`: `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `.vscode/settings.json`
4. **Verify backup succeeded** — confirm the new backup directory contains every moved item before proceeding. If backup is incomplete, abort and leave the partial backup in place for the user to inspect.
5. **Wipe** — after the backup `mv` succeeds, the originals are already gone (mv, not copy). Double-check nothing remains.
6. **Fresh init (CASE A)** — invoke the `/aips:init` CASE A flow on the now-empty project:
   - `lib/detect-project.sh`
   - render `templates/CLAUDE.md.tmpl` → `.priv-storage/CLAUDE.md`
   - copy `templates/WORK_STATUS.md.tmpl`, `templates/memory/`
   - create root symlinks
   - copy `templates/tmp-igbkp/` and `chmod +x`
   - patch `.gitignore` idempotently
   - run `lib/verify-init.sh`

## Output

```
[reset] backup created       tmp-igbkp/reset-backup-20260519-143012/
[reset] wiped                .priv-storage/, root symlinks
[reset] fresh init           <lang>/<framework>
[reset] verify               PASS
note: previous state preserved at tmp-igbkp/reset-backup-20260519-143012/
```

## Rules

- Never proceed without explicit `y` confirmation.
- Never delete without a successful backup first.
- Never touch global plugin install (`~/.claude/plugins/AIPS/`).
- Never touch project source code, `.git/`, or any path outside `.priv-storage/` + the four root symlinks.
- Never delete prior `tmp-igbkp/reset-backup-*` directories — leave them for the user.
