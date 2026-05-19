---
description: Diagnose AIPS global + per-project health. Read-only — no edits.
allowed-tools: ["Bash", "Read", "Grep", "Glob"]
---

# /aips:health

End-to-end health check across global plugin install, dependency plugins, and this project's `.priv-storage/`. Pure diagnostic — no file writes, no state changes.

## Checks (one line per check, PASS / WARN / FAIL + 1-line note)

1. **Global plugin present** — `~/.claude/plugins/AIPS/.claude-plugin/plugin.json` exists; report version.
2. **Dependency plugins** — `agentmemory`, `cavecrew`, `rtk`, `codex-relay` (if applicable) installed in `~/.claude/plugins/`. Each listed individually.
3. **agentmemory service active (Linux)** — `systemctl --user is-active agentmemory` returns `active`; on macOS check `launchctl list | grep agentmemory`; on other platforms WARN with "platform not auto-managed".
4. **Per-project `.priv-storage/` complete** — verify presence of `CLAUDE.md`, `WORK_STATUS.md`, `memory/MEMORY.md`, `sessions/` dir. Missing → FAIL with list.
5. **Root symlinks valid** — `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `.vscode/settings.json` resolve into `.priv-storage/`. Broken → FAIL.
6. **`.gitignore` block present** — AIPS marker block exists and covers `.priv-storage/`, `tmp-igbkp/`, `.claude/`, `.mcp.json`, `CLAUDE.local.md`.
7. **Toolkit scripts** — 9 expected `tmp-igbkp/*.sh` present and executable.
8. **Hooks firing (last 24h)** — `~/.claude/hook-errors.log` last 24h: 0 errors = PASS, >0 = WARN with count.
9. **Token discipline** — `wc -c .priv-storage/CLAUDE.md` under 8 KB (Section 1-7 + 11 only). Over → WARN.
10. **Plugin savings indicators** — grep recent session output for `🦴cv:`, `🧠am:`, `💰rtk:`, `🤖cdx:` markers; report which are active.

## Output

```
[health] global plugin       PASS  v6.0.0
[health] dep plugins         PASS  agentmemory, cavecrew, rtk
[health] agentmemory svc     PASS  active (systemd user)
[health] .priv-storage/      PASS  4/4 required files
[health] root symlinks       PASS  4/4 resolve
[health] .gitignore block    PASS
[health] toolkit scripts     PASS  9/9 +x
[health] hook-errors 24h     PASS  0 errors
[health] CLAUDE.md size      PASS  6.2 KB
[health] plugin savings      PASS  cv, am, rtk active
verdict: PASS (10/10)
```

## Rules

- Read-only. Never write, edit, or delete.
- Never spend AI tokens on analysis — checks are file reads + bash.
