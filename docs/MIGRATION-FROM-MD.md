# Migrating from v5.x (Markdown) to v6.0 (Plugin)

This is a user-facing walkthrough for moving an existing project from AIPS v5.x — where a single 7,600-line `AI_PROJECT_SETUP.md` lived in `.priv-storage/` and was re-executed by the AI on each setup change — to v6.0, which ships AIPS as a native Claude Code plugin.

For architecture detail, see [`ARCHITECTURE.md`](./ARCHITECTURE.md).

---

## Why v6.0

The v5.x model worked, but had three pain points that v6.0 removes:

1. **Token cost.** Every re-init asked an AI to re-read ~25k tokens of markdown.
2. **Cross-tool drift.** Each tool (Claude / Codex / Cursor / Copilot) executed the markdown slightly differently, so the resulting `.priv-storage/` could differ.
3. **Update friction.** Bumping a version required re-fetching the raw URL and re-running setup; with multi-tool ownership, this regularly diverged.

v6.0 ships AIPS as a Claude Code **plugin**: commands, hooks, and templates live in a single installed unit that updates atomically through `/plugin update AIPS@AIPS`.

---

## Pre-flight

Before migrating, take a backup. v5.x ships a backup toolkit:

```bash
cd your-v5-project
bash tmp-igbkp/archive.sh         # AES-256-CBC encrypted tarball of .priv-storage/
```

The migration script *also* creates its own backup at `tmp-igbkp/migrate-backup-{TIMESTAMP}/`, so this manual archive is belt-and-suspenders only.

Required tooling:
- `bash >= 4.0`, `git`, `curl`
- `node >= 18.18` (if you want `agentmemory`)
- `claude` CLI (Claude Code 2.0+)

---

## Step 1 — Install globals

One-line install. Idempotent and sudo-free.

```bash
curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/install.sh | bash
```

This runs `install.sh`, which:
- Registers the AIPS marketplace.
- Installs the `AIPS@AIPS` plugin.
- Installs dep plugins: `codex@openai-codex`, `caveman@caveman`, `agentmemory@agentmemory`.
- Installs RTK (`~/.local/bin/rtk`).
- On Linux: installs the agentmemory systemd user service.

If you want a subset:

```bash
bash install.sh --with caveman,rtk        # skip codex + agentmemory
bash install.sh --dry-run                  # print actions only
```

---

## Step 2 — Run `/aips:init` in your v5.x project

```bash
cd your-v5-project
claude
> /aips:init
```

`/aips:init` walks up from `$PWD` to the nearest `.git`, then classifies the directory state:

| Detected | Path taken |
|---|---|
| Fresh project (no `.priv-storage/`) | **CASE A** — full fresh init |
| **v5.x present (`.priv-storage/AI_PROJECT_SETUP.md` exists)** | **CASE B** — migration |
| v6.0 already initialized | CASE C — non-destructive re-sync |
| Partial / broken state | CASE D — repair |

For a v5.x project, you will land in CASE B.

---

## Step 3 — Confirm the migration plan

CASE B prints the explicit REMOVE / EDIT / PRESERVE plan before doing anything:

```
REMOVE (files):
  - .priv-storage/AI_PROJECT_SETUP.md
  - .priv-storage/.claude/commands/{status,recover,ship,health,save,clean,codex-brief,...}.md
  - .priv-storage/.claude/agents/{explorer,code-reviewer,log-analyzer}.md
  - tmp-igbkp/codex-relay-{check,run}.sh
  - .priv-storage/sessions/{codex-brief,codex-report,claude-review}.md

REMOVE (dirs):
  - .priv-storage/.claude/{hooks,skills,output-styles,statusline}/
  - .priv-storage/sessions/codex-relay/

EDIT:
  - .priv-storage/CLAUDE.md  (delete Sections 8, 9, 10, 12, 13 — globalized)

PRESERVE:
  - .priv-storage/WORK_STATUS.md
  - .priv-storage/memory/**
  - .priv-storage/sessions/{current,recovery,handoff-*}.md
  - .priv-storage/.mcp.json, root .gitignore
  - .priv-storage/.claude/agents/tech-lead.md, *-team.md
  - tmp-igbkp/{archive,restore,purge-history,verify-setup,uninstall,smoke-test-hooks,
              secret-guard,automode-validate,setup-worktree}.sh

Proceed? [Y/n]
```

Press Enter (or `y`) to continue. The script then:

1. Creates `tmp-igbkp/migrate-backup-{TIMESTAMP}/` containing a full copy of `.priv-storage/` and the relay scripts.
2. Deletes the v5.x-only files and directories.
3. Runs an `awk` pass over `.priv-storage/CLAUDE.md` to delete Sections 8/9/10/12/13 and insert a single comment line:
   `<!-- Sections 8/9/10/12/13 globalized in v6.0 — see ~/.claude/CLAUDE.md -->`
4. Writes `.priv-storage/.aips-version` = `6.0`.

You can preview without writing:

```bash
bash ~/.claude/plugins/cache/AIPS/AIPS/lib/migrate-from-md.sh --dry-run
```

---

## Step 4 — Verify

```bash
> /aips:health
```

This runs `lib/verify-init.sh` and reports per-check PASS / WARN / FAIL across 9 sections (skeleton, CLAUDE.md content, root symlinks, `.mcp.json`, `.gitignore`, `tmp-igbkp/` toolkit, global plugin, dep plugins, RTK).

A successful migration shows `verify: PASS` with no FAILs. WARNs are acceptable — usually they flag optional pieces (RTK not on PATH, an opted-out dep plugin) you may want to address later.

---

## Troubleshooting

### `agentmemory` not starting

```bash
systemctl --user status agentmemory.service
journalctl --user -u agentmemory.service -n 50
```

Common causes:
- `node` < 18.18 — upgrade via your package manager.
- `npx` not on PATH — re-run `install.sh` after fixing PATH.
- Port 3111 or 3113 already in use — `ss -ltn | grep -E '3111|3113'`.

After fix, restart: `systemctl --user restart agentmemory.service`.

### `rtk` not on PATH

```bash
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc   # or ~/.zshrc
```

Verify with `rtk --version` (NOT a Rust Type Kit — see global `~/.claude/RTK.md`).

### Plugin update failure

```bash
> /plugin update AIPS@AIPS
```

If you see "not found", re-register the marketplace:

```bash
> /plugin marketplace add kernalix7/AIPS
> /plugin install AIPS@AIPS
```

### Hooks not firing

Check that `~/.claude/plugins/cache/AIPS/AIPS/hooks/hooks.json` exists, then ensure hooks are not disabled in your env:

```bash
echo "${HOOKS_DISABLED:-unset}"     # should be 'unset' or '0'
```

---

## Rollback

If anything goes wrong, restore from the migration backup:

```bash
cd your-project
TS=<the timestamp shown after migration>     # e.g. 20260519-101522
rm -rf .priv-storage
cp -a tmp-igbkp/migrate-backup-$TS/priv-storage .priv-storage
cp -a tmp-igbkp/migrate-backup-$TS/tmp-igbkp/codex-relay-*.sh tmp-igbkp/ 2>/dev/null || true
```

You are now back at v5.x. The global plugin install remains (harmless — v5.x ignored it).

---

## Per-tool migration notes

Claude Code is the primary v6.0 consumer (only place the plugin runs). Other tools continue to read the project's symlinked rule files as before:

| Tool | Reads | Behavior change |
|---|---|---|
| Claude Code | `CLAUDE.md` (+ plugin commands/hooks) | Gains `/aips:*` commands, native hooks, statusline |
| Codex CLI | `AGENTS.md` (→ same `.priv-storage/CLAUDE.md`) | No change — still reads slimmed CLAUDE.md |
| Cursor | `.cursorrules` | No change — still reads same content |
| GitHub Copilot | `.vscode/settings.json` | No change |

Because Sections 8/9/10/12/13 were globalized, Codex / Cursor users lose visibility into those rules at the project level. To retain that, either:
- Keep a copy of the original v5.x `CLAUDE.md` (rename to e.g. `docs/CONVENTIONS-FULL.md`), or
- Symlink `~/.claude/CLAUDE.md` into the project for those tools as well.

Most teams find the global rules suffice; project-specific overrides remain in `CLAUDE.md` Sections 1-7 + 11.

---

## Next steps

- Read [`ARCHITECTURE.md`](./ARCHITECTURE.md) for how the v6.0 internals fit together.
- Run `/aips:status` to see your in-progress work and last 10 tool calls.
- Skim `~/.claude/CLAUDE.md` for the global rules that now apply across every project.
