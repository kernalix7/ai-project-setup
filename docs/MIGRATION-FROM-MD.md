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

## Migrating from v6.0 to v7.0

v7.0 builds on v6.0 by **globalizing** the heavy, project-invariant pieces — toolkit scripts, sessions, memory, and the AIPS `.gitignore` block — so each project on disk shrinks roughly 4x and a new laptop becomes a one-command resume of every project. The migration is **non-breaking**: existing v6.0 setups keep working until you opt in, and multi-tool parity is preserved (Codex / Cursor / Copilot still read the project's `CLAUDE.md` / `AGENTS.md` / `.cursorrules`).

### Pre-flight

- Verify v6.0 install: `/aips:health` reports all green (no FAILs).
- Backup is automatic during upgrade, but extra: `bash tmp-igbkp/archive.sh`.
- `agentmemory` must be running globally — on Linux: `systemctl --user is-active agentmemory.service`.
- Disk: the upgrade backup tar is roughly the size of your current `.priv-storage/`.

### Step 1 — Install v7.0 globals (if not already)

```bash
curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/install.sh | bash
```

`install.sh` in v7.0 adds **step F**, which runs `lib/globalize-toolkit.sh` to materialize the global toolkit (`~/.local/bin/aips-*`) and the global `.gitignore` BLOCKLIST via `lib/setup-global-gitignore.sh`. The script is idempotent — re-running on an existing install is safe.

### Step 2 — Per-project upgrade

```bash
$ cd your-project && claude
> /aips:upgrade --to v7.0
```

What happens:

1. Detects current version from `.priv-storage/.aips-version` (or infers `v6.0` if the marker is absent but the v6.0 layout is present).
2. Prints the upgrade plan — explicit REMOVE / GLOBALIZE / PRESERVE list.
3. Prompts `Proceed? [Y/n]`.
4. On confirm: snapshots everything to `tmp-igbkp/upgrade-v7-backup-{TIMESTAMP}/`.
5. **GLOBALIZE**: toolkit scripts become symlinks into `~/.local/bin/`, the AIPS `.gitignore` block is stripped from per-project `.gitignore` (sed) and reinstalled at the global level, the local memory copy is dropped after verifying the global mirror, and existing session files are copied into the global mirror.
6. **STRICT PURGE (default)**: result equals a fresh v7.0 install. Per-project `tmp-igbkp/*.sh` is deleted once each `~/.local/bin/aips-*` symlink is verified; `.priv-storage/sessions/*.md` is cleared after the global mirror is confirmed (directory kept for hook fast-write). Pass `--keep-local-fallback` to retain both as fallback (lenient).
7. **PRESERVE**: `CLAUDE.md`, `WORK_STATUS.md`, `.mcp.json`, `tech-lead.md`, team agents, and any `tmp-igbkp/` encrypted backup outputs (snapshots, not the script files).
8. Writes `.priv-storage/.aips-version` = `7.0`.
9. Reports per-category counts (REMOVED / GLOBALIZED / PURGED / PRESERVED).

### Step 3 — Verify post-upgrade

```bash
> /aips:scope
> /aips:health
```

`/aips:scope` should show: **legacy v6.0 entries = 0**, **globalized count > 0**, all per-project preserved files present, and a summary line `AIPS version: 7.0`. `/aips:health` should return all green with the v7.0 verifier rules.

### Project move / rename after v7.0

Because sessions and project memory are keyed by path-hash in v7.0, moving or renaming a project requires a rebind:

```bash
# After mv ~/old-path ~/new-path
$ cd ~/new-path && claude
> /aips:rebind ~/old-path
```

`/aips:rebind`:
- Computes the old and new path-hash + path-encoded values.
- Moves `~/.claude/sessions/{old-hash}/` → `~/.claude/sessions/{new-hash}/`.
- Moves `~/.claude/projects/{old-encoded}/` → `~/.claude/projects/{new-encoded}/`.
- Rebinds agentmemory keys via API (best-effort) or prints manual steps if the API rebind fails.

### Rollback

If anything goes wrong, restore from the upgrade backup:

```bash
TS=<the timestamp shown by /aips:upgrade>    # e.g. 20260519-101522
cp -r tmp-igbkp/upgrade-v7-backup-$TS/.priv-storage/* .priv-storage/
cp tmp-igbkp/upgrade-v7-backup-$TS/.gitignore .gitignore
rm .priv-storage/.aips-version
```

You are now back at v6.0. The global toolkit symlinks and global `.gitignore` block remain (harmless — v6.0 ignores them).

### Troubleshooting v6.0 → v7.0

- **"global memory not found"** — `agentmemory` was not running during v6.0 dual-write. Manual fix: copy `.priv-storage/memory/*` to `~/.claude/projects/{path-encoded}/memory/` before re-running the upgrade.
- **"toolkit symlinks broken"** — `~/.local/bin` is not on PATH. Add to `~/.bashrc`: `export PATH="$HOME/.local/bin:$PATH"`.
- **"sessions not mirroring"** — hooks were not updated. Re-run `install.sh` to refresh `~/.claude/hooks/`.
- **"gitignore block missing"** — `setup-global-gitignore` did not run. Manual: `bash ~/.claude/plugins/cache/AIPS/AIPS/lib/setup-global-gitignore.sh`.

### Multi-tool note

Codex CLI, Cursor, and GitHub Copilot continue to read the project's `CLAUDE.md` / `AGENTS.md` / `.cursorrules` as in v6.0. v7.0 globalization does not touch these files — multi-tool support is identical to v6.0.

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
