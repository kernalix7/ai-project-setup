---
description: Show current project AIPS state — version, init date, files, memory, sessions, deps.
allowed-tools: ["Bash", "Read", "Grep"]
---

# /aips:status

Show the AIPS state of the current project. Read-only — pure file reads, no analysis.

## What it does

1. **AIPS version** — read `~/.claude/plugins/AIPS/.claude-plugin/plugin.json` `.version`. Print.
2. **Init date** — `stat -c %y .priv-storage/CLAUDE.md` (or BSD `stat -f %SB` on macOS). Print as `init date: YYYY-MM-DD`.
3. **Last update** — `stat` mtime on `.priv-storage/CLAUDE.md` AND most-recent template in `~/.claude/plugins/AIPS/templates/`; report the more recent. Print as `last update: YYYY-MM-DD`.
4. **CLAUDE.md sections present** — `grep -E '^## [0-9]+\.' .priv-storage/CLAUDE.md` → list section numbers found (expect 1-7 + 11).
5. **Memory** — count files in `.priv-storage/memory/*.md`, total size, list category names.
6. **Sessions** — for each of `current.md`, `recovery.md`, latest `handoff-*.md`: print filename + age (e.g. `current.md: 3m ago`, `handoff-2026-05-18.md: 1d ago`).
7. **Dep plugins active** — for each of `agentmemory`, `cavecrew`, `rtk`, `codex-relay`: report `installed` / `missing` based on presence under `~/.claude/plugins/`.
8. **Root symlinks** — confirm `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `.vscode/settings.json` resolve into `.priv-storage/`.

## Output

```
[status] AIPS version        v6.0.0
[status] init date           2026-05-12
[status] last update         2026-05-19
[status] CLAUDE.md sections  1, 2, 3, 4, 5, 6, 7, 11
[status] memory files        6 files, 12 KB (project_versioning, reference_install_url, ...)
[status] current.md          3m ago
[status] recovery.md         2h ago
[status] latest handoff      handoff-2026-05-18.md (1d ago)
[status] dep plugins         agentmemory: installed, cavecrew: installed, rtk: installed, codex-relay: missing
[status] root symlinks       4/4 valid
```

## Rules

- Read-only. Never write or edit.
- Never analyze content — just report what's present.
