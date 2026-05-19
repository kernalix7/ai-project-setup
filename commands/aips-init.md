---
description: Auto-detect project state and initialize / migrate / repair as AIPS v6.0.
allowed-tools: ["Bash", "Read", "Write", "Edit", "Glob", "Grep"]
---

# /aips:init

Auto-detect current directory state and run the correct v6.0 initialization path. Idempotent and safe to re-run.

## Detection

Walk up from `$PWD` to the nearest `.git` root (that becomes `PROJECT_ROOT`). Then classify into one of 4 cases:

| Case | Signal | Action |
|------|--------|--------|
| **A — Fresh** | `.priv-storage/` does NOT exist | Full fresh init |
| **B — v5.x legacy** | `.priv-storage/AI_PROJECT_SETUP.md` exists | Migration plan + confirm + `lib/migrate-from-md.sh` |
| **C — v6.0 re-init** | `.priv-storage/` exists, NO `AI_PROJECT_SETUP.md` inside, root `CLAUDE.md` symlink valid | Idempotent re-init (non-destructive sync of global templates) |
| **D — Repair** | `.priv-storage/` partially present, OR root `CLAUDE.md` exists but `.priv-storage/` missing, OR broken symlinks | Detect missing files, restore from templates only — never overwrite user content |

## CASE A — Fresh project

1. Run `lib/detect-project.sh` → capture `LANG`, `FRAMEWORK`, `PKG_MGR`.
2. Render `templates/CLAUDE.md.tmpl` → `.priv-storage/CLAUDE.md` (Section 1-7 + 11 only) via `lib/render-claude-md.sh`.
3. Copy `templates/WORK_STATUS.md.tmpl` → `.priv-storage/WORK_STATUS.md`.
4. Copy `templates/memory/` → `.priv-storage/memory/` (MEMORY.md index + starter category files).
5. Create root symlinks: `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `.vscode/settings.json` → into `.priv-storage/`.
6. Copy `templates/tmp-igbkp/` (9 toolkit scripts) → `tmp-igbkp/`, `chmod +x` them.
7. Patch `.gitignore` idempotently (append AIPS block only if marker absent).
8. Run `lib/verify-init.sh` for PASS/FAIL summary.

Output: `init: fresh — <lang>/<framework> — <N> files written — verify: PASS`

## CASE B — v5.x migration

1. Print the REMOVE / EDIT / PRESERVE plan:
   - **REMOVE**: `.priv-storage/AI_PROJECT_SETUP.md`; `.priv-storage/.claude/{hooks,skills,output-styles,statusline}/*`; `.priv-storage/.claude/agents/{explorer,code-reviewer,log-analyzer}.md`; `.priv-storage/.claude/commands/{status,recover,ship,health,save,clean,codex-brief,codex-review,codex-fix,codex-relay-status}.md`; `tmp-igbkp/codex-relay-{check,run}.sh`; `.priv-storage/sessions/{codex-brief,codex-report,claude-review}.md` and `.priv-storage/sessions/codex-relay/`.
   - **EDIT**: `.priv-storage/CLAUDE.md` → slim to Section 1-7 + 11 only.
   - **PRESERVE**: `WORK_STATUS.md`, `memory/`, `sessions/{current,recovery,handoff-*}.md`, `.mcp.json`, `.gitignore`, `tmp-igbkp/{archive,restore,purge-history,verify-setup,uninstall,smoke-test-hooks,secret-guard,automode-validate,setup-worktree}.sh`, `.priv-storage/.claude/agents/tech-lead.md` + any `agents/*-team.md`.
2. Prompt `Proceed? [Y/n]` — default Y on Enter, abort on `n`.
3. Run `lib/migrate-from-md.sh "$PROJECT_ROOT"`.
4. Run `lib/verify-init.sh` after migration.

Output: `init: migrated v5.x → v6.0 — removed <N>, preserved <M> — verify: PASS`

## CASE C — v6.0 re-init (idempotent)

1. Compute diff: global `templates/` vs project `.priv-storage/` for managed files only.
2. Apply non-destructive updates (template files like skeleton `MEMORY.md` headers, toolkit scripts in `tmp-igbkp/`). NEVER overwrite `WORK_STATUS.md` body, `memory/*.md` content, or `sessions/*`.
3. Re-validate symlinks and `.gitignore` block.

Output: `init: re-init — <N> templates updated, <M> preserved — verify: PASS`

## CASE D — Repair

1. Enumerate missing/broken: symlinks, required template files, toolkit scripts, `.gitignore` block.
2. Restore each from `templates/` without touching existing user files.

Output: `init: repaired — restored <N> files (<list>) — verify: PASS`

## Rules

- Never delete content outside `.priv-storage/`, `tmp-igbkp/`, root symlinks.
- Never overwrite `WORK_STATUS.md` body, `memory/*.md` user content, `sessions/*`.
- All file writes are idempotent and re-runnable.
