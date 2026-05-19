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
3. **Dependency plugins** — for each of `agentmemory`, `cavecrew`, `rtk`, `codex-relay` (when present):
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
[upgrade] cavecrew           v1.1.0 (no change)
[upgrade] rtk                v2.0.1 → v2.0.2
[upgrade] codex-relay        not installed
[upgrade] agentmemory svc    restarted (version changed)
note: run /aips:update inside each project to sync per-project files.
```

## Rules

- Globals only. Never touch `.priv-storage/`, root symlinks, project source.
- If marketplace refresh fails, abort before running any plugin update.
- Surface any plugin update failure individually; do not abort the whole batch on one failure.
