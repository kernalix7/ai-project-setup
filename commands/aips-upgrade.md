---
description: Upgrade the global AIPS plugin marketplace, plugin itself, and dep plugins.
allowed-tools: ["Bash", "Read", "Grep"]
---

# /aips:upgrade

Refresh everything global: plugin marketplace metadata, the AIPS plugin, and every dependency plugin AIPS relies on. Per-project state is **not** touched — run `/aips:update` afterward to sync the local project.

## What it does

1. **Marketplace refresh**:
   ```bash
   claude --print "/plugin marketplace update"
   ```
2. **AIPS plugin upgrade**:
   ```bash
   claude --print "/plugin update AIPS@AIPS"
   ```
   Capture pre/post versions from `~/.claude/plugins/AIPS/.claude-plugin/plugin.json`.
3. **Dependency plugins** — for each of `agentmemory`, `caveman`, `rtk`, `codex-plugin-cc` (when present):
   ```bash
   claude --print "/plugin update <name>@<marketplace>"
   ```
   Capture pre/post versions from each plugin's `plugin.json`.
4. **Restart agentmemory service** if its version changed (Linux):
   ```bash
   systemctl --user restart agentmemory
   ```
   macOS: `launchctl kickstart -k gui/$(id -u)/agentmemory` (if loaded). Other platforms: WARN and skip.

## Output

One line per plugin showing the version delta:

```
[upgrade] marketplace        refreshed
[upgrade] AIPS               v6.0.0 → v6.1.0
[upgrade] agentmemory        v0.3.2 → v0.3.3
[upgrade] caveman           v1.1.0 (no change)
[upgrade] rtk                v2.0.1 → v2.0.2
[upgrade] codex-plugin-cc        not installed
[upgrade] agentmemory svc    restarted (version changed)
note: run /aips:update inside each project to sync per-project files.
```

## Rules

- Globals only. Never touch `.priv-storage/`, root symlinks, project source.
- If marketplace refresh fails, abort before running any plugin update.
- Surface any plugin update failure individually; do not abort the whole batch on one failure.

---

## Optional arg: `--to v7.0` (hybrid migration)

When invoked as `/aips:upgrade --to v7.0` (or `/aips:upgrade --to v7.0 $ARGUMENTS`), perform the **v6.0 → v7.0 hybrid migration** for the current project instead of (or in addition to) the global plugin refresh.

### Detection

1. Read `.priv-storage/.aips-version` in the project root.
   - If missing **and** `.priv-storage/CLAUDE.md` is present with the v6.0 section layout (Sections 1–7, 11) → treat as **v6.0**.
   - If file reads `7.0` → abort with `already on v7.0 (no-op)`.
   - If file reads anything else (e.g. `5.x`) → abort with `unsupported source version: <ver>; run /aips:migrate-from-md first`.

### Plan preview

Print the upgrade plan from `lib/upgrade-to-v7.sh --plan` (the PLAN block):

```
[plan] backup    → tmp-igbkp/upgrade-v7-backup-{ts}/
[plan] globalize → hooks, skills, output-styles, statusline → ~/.claude/
[plan] gitignore → strip per-project AIPS block, add to ~/.config/git/ignore
[plan] memory    → mirror .priv-storage/memory/* → ~/.claude/projects/<encoded>/memory/, then prune
[plan] sessions  → mirror .priv-storage/sessions/* → ~/.claude/sessions/<hash>/
[plan] CLAUDE.md → trim Sections 8–13 ref comments (re-render via lib/render-claude-md.sh)
[plan] marker    → write .priv-storage/.aips-version ← 7.0
```

### Confirm

Prompt `Proceed? [Y/n]` (default Y).

### Execute

On confirm:

```bash
UPGRADE_SH="$(find ~/.claude/plugins/cache/AIPS/AIPS/lib -name upgrade-to-v7.sh 2>/dev/null | head -1)"
[ -z "$UPGRADE_SH" ] && UPGRADE_SH="$(find ~/.claude/plugins -name upgrade-to-v7.sh 2>/dev/null | head -1)"
bash "$UPGRADE_SH" "$(pwd)"
```

Pass-through flags: `--dry-run`, `--force`, `--keep-local-fallback` (e.g. `/aips:upgrade --to v7.0 --dry-run`).

**Strict mode is the default.** Result equals a fresh v7.0 install:
- per-project `tmp-igbkp/*.sh` deleted after global `~/.local/bin/aips-*` symlinks verified
- `.priv-storage/sessions/*.md` cleared after global mirror verified (dir kept for hook fast-write)

Pass `--keep-local-fallback` to retain both as fallback (pre-strict v7.0 behavior). Full backup is always at `tmp-igbkp/upgrade-v7-backup-{ts}/` regardless of mode — strict purges are reversible.

### Post-checks

- Verify `.priv-storage/.aips-version` contains `7.0`.
- Verify global mirror exists for memory + sessions.
- Verify backup dir is non-empty.

### Report

```
[upgrade-v7] backup     tmp-igbkp/upgrade-v7-backup-{ts}/  (N files)
[upgrade-v7] globalized X files → ~/.claude/
[upgrade-v7] preserved  Y files (per-project AIPS bits)
[upgrade-v7] marker     .priv-storage/.aips-version = 7.0
Upgraded to v7.0 — N files globalized, M files preserved, backup at tmp-igbkp/upgrade-v7-backup-{ts}/
```

### Rules (v7.0 path)

- Backup **before** any destructive operation. Never delete a source file until its mirror is verified.
- `--dry-run` prints the plan and exits without touching the FS.
- `--force` skips the v6.0 pre-check (use only if state is known good but the marker is missing).
- `--keep-local-fallback` switches strict → lenient (per-project tmp-igbkp/*.sh + sessions/*.md retained).
- Strict purges are guarded: a per-project script is deleted only if its `~/.local/bin/aips-*` symlink resolves; a session file is deleted only if its global mirror exists. Anything failing the guard is kept and reported via WARN.
- Still no AI attribution in any output.

Without `--to v7.0`, behavior is unchanged from the section above (global plugin update only).
