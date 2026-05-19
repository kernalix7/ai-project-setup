---
description: Remove AIPS per-project state (.priv-storage + symlinks). Global plugin stays.
allowed-tools: ["Bash", "Read", "Write", "Glob"]
---

# /aips:uninstall

Tear down per-project AIPS state in the current `PROJECT_ROOT`. Global plugin install in `~/.claude/plugins/AIPS/` is **not** touched.

## What it does

1. **Locate `PROJECT_ROOT`** — walk up from `$PWD` to nearest `.git` directory.
2. **Confirm** — prompt:
   ```
   This will remove .priv-storage/ and AIPS root symlinks from <PROJECT_ROOT>.
   A backup will be created at tmp-igbkp/uninstall-backup-<ts>/.
   Global plugin install will NOT be removed.
   Proceed? [y/N]
   ```
   Require explicit `y`; any other input aborts.
3. **Backup** — create `tmp-igbkp/uninstall-backup-<YYYYMMDD-HHMMSS>/` and move into it:
   - `.priv-storage/` (entire dir)
   - root symlinks: `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `.vscode/settings.json` (only if they resolve into `.priv-storage/`; never touch unrelated files of the same name)
4. **Remove** — delete the originals after the backup `mv` succeeds. Use `mv`, not `cp + rm`, so it is atomic per-file.
5. **Leave alone** — do NOT touch:
   - Global `~/.claude/plugins/AIPS/` install
   - Project source code, git history, `.git/`
   - `tmp-igbkp/` (other than creating the new backup subdir)
   - `.gitignore` (leave the AIPS block in place so re-init stays clean)

## Output

```
[uninstall] backup created   tmp-igbkp/uninstall-backup-20260519-143012/
[uninstall] removed          .priv-storage/, CLAUDE.md, AGENTS.md, .cursorrules, .vscode/settings.json
[uninstall] global plugin    untouched
note: global plugins still installed; run
      claude --print '/plugin uninstall AIPS@AIPS'
      to fully remove AIPS from this machine.
```

## Rules

- Never delete without a successful backup first.
- Never touch the global plugin or any path outside `PROJECT_ROOT`.
- Abort cleanly on any non-`y` response.
