---
description: Auto-detect project state and initialize / migrate / repair as AIPS v7.0.
allowed-tools: ["Bash", "Read", "Write", "Edit", "Glob", "Grep"]
---

# /aips:init

Auto-detect current directory state and run the correct v7.0 initialization path. Idempotent and safe to re-run.

## Paths (RESOLVE FIRST)

The lib scripts and templates live inside the installed plugin, not the current project. Before running any step, resolve `AIPS_ROOT`:

```bash
AIPS_ROOT="$(find ~/.claude/plugins/cache/AIPS/AIPS -maxdepth 1 -type d -name '[0-9]*' | sort -V | tail -1)"
```

`AIPS_ROOT` then contains `lib/`, `templates/`, `agents/`, `commands/`, `hooks/`, etc. Use it as the prefix for every `lib/...sh` and `templates/...` reference below.

`PROJECT_ROOT` = `git rev-parse --show-toplevel` (or `pwd` if not a git repo).

## Detection

Classify `PROJECT_ROOT` into one of 4 cases:

| Case | Signal | Action |
|------|--------|--------|
| **A — Fresh** | `.priv-storage/` does NOT exist | Full fresh init |
| **B — v5.x legacy** | `.priv-storage/AI_PROJECT_SETUP.md` exists | Migration plan + single confirm + `lib/upgrade.sh --only-cleanup --auto-confirm` (legacy alias: `lib/migrate-from-md.sh`) |
| **C — version-aware re-init / upgrade** | `.priv-storage/` exists, NO `AI_PROJECT_SETUP.md` inside | Read `.priv-storage/.aips-version`. If older than plugin → run `lib/upgrade.sh` (legacy alias: `lib/upgrade-to-v7.sh`) + write current marker. If equal → idempotent re-init. |
| **D — Repair** | `.priv-storage/` partially present, OR root `CLAUDE.md` exists but `.priv-storage/` missing, OR broken symlinks | Detect missing files, restore from templates only — never overwrite user content |

## CASE A — Fresh project

1. Run `bash "$AIPS_ROOT/lib/detect-project.sh" "$PROJECT_ROOT"` → capture `LANG`, `FRAMEWORK`, `PKG_MGR`, `PROJECT_NAME`, `GIT_REMOTE`, `DEPLOYMENT`.
2. Render: `bash "$AIPS_ROOT/lib/render-claude-md.sh" "$PROJECT_ROOT"` → writes `.priv-storage/CLAUDE.md` (Section 1-7 + 11 only).
3. `mkdir -p .priv-storage` and `cp "$AIPS_ROOT/templates/WORK_STATUS.md.tmpl" .priv-storage/WORK_STATUS.md` (only if absent — never clobber user content).
4. `cp -r "$AIPS_ROOT/templates/memory/." .priv-storage/memory/` (MEMORY.md index + starter category files).
5. Render `.priv-storage/.claude/settings.json` from `$AIPS_ROOT/templates/settings.json.tmpl` via `bash "$AIPS_ROOT/lib/render-settings-json.sh" "$PROJECT_ROOT"` — sets statusLine to `$HOME/.local/bin/aips-statusline` (created by globalize-toolkit.sh in install.sh), keeps user-tunable keys (model, outputStyle, env, teammateMode, defaultTeamMode, attribution), and removes any stale .hooks block (the plugin's hooks.json owns hooks).
6. Create root symlinks if absent: `CLAUDE.md → .priv-storage/CLAUDE.md`, `AGENTS.md → .priv-storage/CLAUDE.md`, `.cursorrules → .priv-storage/CLAUDE.md`, `.vscode/settings.json → .priv-storage/.vscode/settings.json` (create `.priv-storage/.vscode/settings.json` if absent first). The `.claude` directory at the project root is itself a symlink to `.priv-storage/.claude`, so the rendered settings.json above is visible at both paths.
6. `mkdir -p tmp-igbkp && cp "$AIPS_ROOT/templates/tmp-igbkp/"*.sh tmp-igbkp/ && chmod +x tmp-igbkp/*.sh` (project-local toolkit; v7.0 hybrid will later globalize via `/aips:upgrade --to v7.0`).
7. Patch `.gitignore` idempotently: if marker `# === AIPS v7.0 ===` absent, append the block from `$AIPS_ROOT/templates/.gitignore.patch`.
8. Write marker with the current plugin version (read it from `"$AIPS_ROOT/.claude-plugin/plugin.json"`): `jq -r .version "$AIPS_ROOT/.claude-plugin/plugin.json" > .priv-storage/.aips-version`. Falls back to `sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'` if `jq` is absent.
9. Run `bash "$AIPS_ROOT/lib/verify-init.sh" "$PROJECT_ROOT"` for PASS/FAIL summary.

Output: `init: fresh — <lang>/<framework> — <N> files written — verify: PASS`

## CASE B — v5.x migration

**Single confirm — no per-step prompts.**

1. Print the REMOVE / EDIT / PRESERVE plan:
   - **REMOVE**: `.priv-storage/AI_PROJECT_SETUP.md`; `.priv-storage/.claude/{hooks,skills,output-styles,statusline}/*`; `.priv-storage/.claude/agents/{explorer,code-reviewer,log-analyzer}.md`; `.priv-storage/.claude/commands/{status,recover,ship,health,save,clean,codex-brief,codex-review,codex-fix,codex-relay-status}.md`; `tmp-igbkp/codex-relay-{check,run}.sh`; `.priv-storage/sessions/{codex-brief,codex-report,claude-review}.md` and `.priv-storage/sessions/codex-relay/`.
   - **EDIT**: `.priv-storage/CLAUDE.md` → slim to Section 1-7 + 11 only.
   - **RECONSTRUCT**: `.priv-storage/.claude/settings.json` via `lib/render-settings-json.sh` (backup `.v5.bak`). The .hooks block is removed (plugin's hooks.json owns hooks); .statusLine is repointed to `$HOME/.local/bin/aips-statusline` so it survives plugin version bumps; user-tunable keys (model, outputStyle, env, teammateMode, defaultTeamMode, attribution) are preserved.
   - **PRESERVE**: `WORK_STATUS.md`, `memory/`, `sessions/{current,recovery,handoff-*}.md`, `.mcp.json`, `.gitignore`, `tmp-igbkp/{archive,restore,purge-history,verify-setup,uninstall,smoke-test-hooks,secret-guard,automode-validate,setup-worktree}.sh`, `.priv-storage/.claude/agents/tech-lead.md` + any `agents/*-team.md`.
2. Prompt **once**: `Run all of the above without further prompts? [Y/n]` — default Y on Enter, abort on `n`.
3. On confirm, call `bash "$AIPS_ROOT/lib/upgrade.sh" "$PROJECT_ROOT" --only-cleanup --auto-confirm` — the `--auto-confirm` flag suppresses the script's internal prompt so the whole migration runs end-to-end without re-asking. (`lib/migrate-from-md.sh` is a thin backward-compat wrapper for the same call.)
4. Run `bash "$AIPS_ROOT/lib/verify-init.sh" "$PROJECT_ROOT"` after migration.

Output: `init: migrated v5.x → v7.0 — removed <N>, preserved <M> — verify: PASS`

## CASE C — version-aware re-init / upgrade

**Detect first, then route based on version delta.**

1. Read the project marker: `CUR="$(cat .priv-storage/.aips-version 2>/dev/null | tr -d '[:space:]')"`. Empty = assume `6.0`.
2. Read the plugin version: `PLUGIN="$(jq -r .version "$AIPS_ROOT/.claude-plugin/plugin.json")"`. Trim to major.minor (e.g. `7.0`).
3. Compare:
   - **CUR == PLUGIN (same major.minor)** → idempotent re-init only:
     - For each managed template under `$AIPS_ROOT/templates/`, diff vs the project copy and apply non-destructive updates (skeleton headers, missing toolkit scripts in `tmp-igbkp/`).
     - NEVER overwrite `WORK_STATUS.md` body, `memory/*.md` content, or `sessions/*`.
     - Re-validate symlinks and `.gitignore` block.
     - Re-write marker to the full plugin version read from `"$AIPS_ROOT/.claude-plugin/plugin.json"` (never hardcode).
   - **CUR < PLUGIN (project marker older than plugin)** → upgrade in place:
     - Print a one-line summary: `upgrade: detected v$CUR, plugin v$PLUGIN — running lib/upgrade.sh`.
     - Single prompt: `Run v$CUR → v$PLUGIN upgrade now? [Y/n]` (default Y).
     - On confirm: `bash "$AIPS_ROOT/lib/upgrade.sh" "$PROJECT_ROOT"` (strict by default — globalizes toolkit + gitignore, drops local memory copy after global mirror verified, clears local sessions/*.md after global mirror verified, slims CLAUDE.md, writes the marker to the current plugin version). The legacy `lib/upgrade-to-v7.sh` is a thin backward-compat wrapper for the same call.
     - Then run `bash "$AIPS_ROOT/lib/verify-init.sh" "$PROJECT_ROOT"`.
   - **CUR > PLUGIN (project marker ahead of plugin)** → STOP and warn: user is running an older plugin against a newer project. Prompt them to run `curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/install.sh | bash` to refresh the global plugin install.

Output: `init: re-init — <N> templates updated, <M> preserved — verify: PASS`
   or: `init: upgraded v<CUR> → v<PLUGIN> — <N> globalized, <M> preserved — verify: PASS`

## CASE D — Repair

1. Enumerate missing/broken: symlinks, required template files, toolkit scripts, `.gitignore` block, version marker.
2. Restore each from `$AIPS_ROOT/templates/` without touching existing user files.

Output: `init: repaired — restored <N> files (<list>) — verify: PASS`

## Rules

- Never delete content outside `.priv-storage/`, `tmp-igbkp/`, root symlinks.
- Never overwrite `WORK_STATUS.md` body, `memory/*.md` user content, `sessions/*`.
- All file writes are idempotent and re-runnable.
- If `$AIPS_ROOT` does not resolve (plugin not installed), STOP with: `AIPS plugin not installed globally. Run: curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/install.sh | bash`
