---
description: Force repair mode (CASE D) — restore missing AIPS files from templates without touching user content.
allowed-tools: ["Bash", "Read", "Write", "Edit", "Glob", "Grep"]
---

# /aips:repair

Force the repair path of `/aips:init` (CASE D). Useful when `.priv-storage/` is partially present, root symlinks are broken, or the auto-detector would otherwise pick a different case. Non-destructive — only adds back what is missing.

## What it does

1. **Locate `PROJECT_ROOT`** — walk up from `$PWD` to nearest `.git`.
2. **Enumerate missing or broken** — check each managed asset and flag it as `missing`, `broken-symlink`, or `ok`:
   - `.priv-storage/CLAUDE.md`
   - `.priv-storage/WORK_STATUS.md`
   - `.priv-storage/memory/MEMORY.md` + starter category files
   - `.priv-storage/sessions/` directory
   - Root symlinks: `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `.vscode/settings.json` (must resolve into `.priv-storage/`)
   - `tmp-igbkp/*.sh` (the 9 toolkit scripts) — must exist and be `+x`
   - `.gitignore` AIPS block (marker comment + required entries)
3. **Restore missing items from `templates/`** — only items flagged `missing` or `broken-symlink`. Never overwrite an existing file with template content. For broken symlinks, remove the dangling link first, then recreate.
4. **Re-`chmod +x`** any toolkit script that exists but lost its executable bit.
5. **Patch `.gitignore`** idempotently if the AIPS block is missing.
6. **Verify** — run `lib/verify-init.sh` and report PASS/FAIL.

## What it never does

- Never overwrite `.priv-storage/CLAUDE.md`, `WORK_STATUS.md`, `memory/*.md` content, or `sessions/*` when they already exist.
- Never delete project source code or anything outside `.priv-storage/`, `tmp-igbkp/`, and the four root symlink paths.
- Never run the migration logic from CASE B (use `/aips:migrate-from-md` for that).
- Never run the fresh-init logic from CASE A — repair only restores what is missing.

## Output

```
[repair] target              <PROJECT_ROOT>
[repair] missing             3 items — .priv-storage/memory/MEMORY.md, root .cursorrules, tmp-igbkp/archive.sh
[repair] broken symlinks     1 item — root AGENTS.md (dangling)
[repair] restored            4 items
[repair] gitignore           ok (block present)
[repair] verify              PASS
```
