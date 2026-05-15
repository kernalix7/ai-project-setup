# ai-project-setup

A universal bootstrap prompt that AI coding assistants (Claude Code, ChatGPT Codex CLI, Cursor, GitHub Copilot, and other MCP-aware tools) execute to set up a consistent, secure, token-efficient project layout — hooks, agents, slash commands, memory dual-write, GitHub standard files, and more.

The entire setup lives in a single file: [`AI_PROJECT_SETUP.md`](AI_PROJECT_SETUP.md).

## What it does

Given an existing or empty project, an AI assistant reading this file will:

1. Detect the project's tech stack, package manager, and structure.
2. Create a gitignored `.priv-storage/` workspace containing `CLAUDE.md`, hooks, agents, slash commands, sessions, and memory.
3. Symlink `CLAUDE.md` / `AGENTS.md` / `.cursorrules` to the same source so all AI tools share one rulebook.
4. Install five shell hooks (`SessionStart`, `PreToolUse`, `PostToolUse`, `PreCompact`, `Stop`) for session resumption, dangerous-command blocking, secret scanning, and audit logging.
5. Generate GitHub standard files (README, SECURITY, CONTRIBUTING, CODE_OF_CONDUCT, issue/PR templates) in bilingual (EN root / KO `docs/`) layout.
6. Archive itself into `.priv-storage/` so subsequent sessions use a lightweight `POST_SETUP_INDEX.md` instead of re-reading ~25k tokens.

## Usage

In your project, ask an AI assistant:

> Read `AI_PROJECT_SETUP.md` and execute it.

The assistant picks the right scenario (A: existing project, B: empty project, C: re-setup) and walks the steps.

## Supported tools

| Tool | Version | Notes |
|------|---------|-------|
| Claude Code | 2.0+ | Full feature set (hooks, statusline, Codex relay) |
| ChatGPT Codex CLI | 0.10+ | Reads `AGENTS.md` (symlink to `CLAUDE.md`) |
| Cursor | 0.40+ | Reads `.cursorrules` (copy of `CLAUDE.md`) |
| GitHub Copilot | 1.150+ | Reads `AGENTS.md` |
| Other MCP tools | — | Policy-only enforcement (no PreToolUse hook) |

## Self-update

`AI_PROJECT_SETUP.md` self-updates from a public gist. **If you fork this repo**, replace the gist URL in the file header (search for `gist.github.com/kernalix7/`) with your own gist, or remove the self-update block.

## License

[MIT](LICENSE)
