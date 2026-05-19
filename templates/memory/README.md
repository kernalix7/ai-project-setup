# Memory System ({{PROJECT_NAME}})

File-backed memory portable across machines. Index: `MEMORY.md`.

Memory types: `user`, `feedback`, `project`, `reference`. See `~/.claude/CLAUDE.md` Section 10 for the full protocol (globalized in v6.0).

Memory files auto-mirror to `~/.claude/projects/{path-encoded}/memory/` (dual-write) so a new machine restores from globals.

agentmemory MCP plugin (global) provides cross-project observation memory in parallel.
