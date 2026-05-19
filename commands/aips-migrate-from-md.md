---
description: Force v5.x .md → v6.0 plugin migration (CASE B) on this or a specified project.
allowed-tools: ["Bash", "Read", "Write", "Edit", "Glob", "Grep"]
---

# /aips:migrate-from-md

Force the v5.x `AI_PROJECT_SETUP.md` → v6.0 plugin migration on a project, even when the auto-detector in `/aips:init` would pick a different case. Use this when you know the legacy `.md` install is present (or buried) and you want migration regardless.

## Arguments

`$ARGUMENTS` — optional path to the v5.x project root. If omitted, walk up from `$PWD` to the nearest `.git` directory.

Usage:
```
/aips:migrate-from-md                       # migrate current project
/aips:migrate-from-md /path/to/v5x/project  # migrate the specified project
```

## What it does

Same logic as `/aips:init` CASE B, but always runs migration — does not consult the auto-detector.

1. **Resolve target** — use `$ARGUMENTS` if non-empty, else `PROJECT_ROOT` from cwd.
2. **Print plan** — REMOVE / EDIT / PRESERVE lists:
   - **REMOVE**: `.priv-storage/AI_PROJECT_SETUP.md`; `.priv-storage/.claude/{hooks,skills,output-styles,statusline}/*`; `.priv-storage/.claude/agents/{explorer,code-reviewer,log-analyzer}.md`; `.priv-storage/.claude/commands/{status,recover,ship,health,save,clean,codex-brief,codex-review,codex-fix,codex-relay-status}.md`; `tmp-igbkp/codex-relay-{check,run}.sh`; `.priv-storage/sessions/{codex-brief,codex-report,claude-review}.md` and `.priv-storage/sessions/codex-relay/`.
   - **EDIT**: `.priv-storage/CLAUDE.md` slimmed to Section 1-7 + 11 only.
   - **PRESERVE**: `WORK_STATUS.md`, `memory/`, `sessions/{current,recovery,handoff-*}.md`, `.mcp.json`, `.gitignore`, `tmp-igbkp/{archive,restore,purge-history,verify-setup,uninstall,smoke-test-hooks,secret-guard,automode-validate,setup-worktree}.sh`, `.priv-storage/.claude/agents/tech-lead.md`, `.priv-storage/.claude/agents/*-team.md`.
3. **Confirm** — prompt `Proceed with migration? [Y/n]` (default Y).
4. **Run** — `lib/migrate-from-md.sh "$TARGET"`.
5. **Verify** — `lib/verify-init.sh "$TARGET"` and report PASS/FAIL.

## Output

```
[migrate] target            <PROJECT_ROOT>
[migrate] removed           <N> files (<top-level summary>)
[migrate] edited            .priv-storage/CLAUDE.md (slimmed to Section 1-7 + 11)
[migrate] preserved         <M> files (WORK_STATUS.md, memory/, sessions/, ...)
[migrate] verify            PASS
```

## Rules

- Never delete preserved files.
- Always require confirmation before destructive actions.
- If `.priv-storage/AI_PROJECT_SETUP.md` is absent, still proceed (forced mode) but WARN that no legacy `.md` was found and only EDIT + symlink/template repairs will run.
