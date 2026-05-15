# ai-project-setup

A single-file bootstrap prompt that any AI coding assistant — **Claude Code, ChatGPT Codex CLI, Cursor, GitHub Copilot, or any MCP-aware tool** — reads and executes to wire up a consistent, secure, token-efficient project layout in one shot.

> Drop [`AI_PROJECT_SETUP.md`](AI_PROJECT_SETUP.md) into a git repository. Tell your AI to read it. In 1–3 minutes the project has 13-section rules, 5 shell hooks, session-resume, dual-write memory, slash commands, default agents, a backup toolkit, and GitHub standard files — all gitignored so your project history stays clean.

---

## Table of Contents

- [Why this exists](#why-this-exists)
- [Quick start (30 seconds)](#quick-start-30-seconds)
- [What gets created](#what-gets-created)
- [How it works (lifecycle)](#how-it-works-lifecycle)
- [Key features](#key-features)
- [Supported AI tools](#supported-ai-tools)
- [Self-update](#self-update)
- [Forking and customization](#forking-and-customization)
- [FAQ](#faq)
- [License](#license)

---

## Why this exists

When you start a new project with AI assistance, you usually re-do the same setup work every time:

- Write a `CLAUDE.md` / `AGENTS.md` / `.cursorrules` so the AI knows the project rules
- Configure hooks so dangerous commands (`rm -rf /`, force push, secret-leaking `cat ~/.ssh/...`) are blocked
- Set up some kind of session-resume so you don't lose context on crash / `/clear` / rate-limit
- Add memory files, slash commands, default agents
- Create README / SECURITY / CONTRIBUTING / CODE_OF_CONDUCT
- Make sure none of the AI-tooling files leak into git history

This file does all of that — **deterministically**, from a single prompt, across multiple AI tools, with the same output regardless of which AI runs it.

---

## Quick start (30 seconds)

1. **Place the file at your project root**:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/kernalix7/ai-project-setup/main/AI_PROJECT_SETUP.md > AI_PROJECT_SETUP.md
   ```

2. **Open your AI tool** in that directory (`claude`, `codex`, `cursor .`, or VS Code with Copilot).

3. **Tell the AI**:
   > Read `AI_PROJECT_SETUP.md` and execute it.

   (Korean works too: `"AI_PROJECT_SETUP.md 읽고 실행해줘"`)

4. **Wait 1–3 minutes**. The AI auto-detects your stack, runs through 10+ setup steps, and ends with `./tmp-igbkp/verify-setup.sh` passing.

5. **Verify**:
   ```bash
   ./tmp-igbkp/verify-setup.sh
   # → All required checks passed
   ```

That's it. Everything created is gitignored — your project's git history stays clean.

---

## What gets created

After setup, your project root looks like this:

```
your-project/
├── CLAUDE.md              → symlink to .priv-storage/CLAUDE.md
├── AGENTS.md              → symlink to .priv-storage/CLAUDE.md  (Codex/Copilot read this)
├── .cursorrules           → symlink to .priv-storage/CLAUDE.md  (Cursor reads this)
├── WORK_STATUS.md         → current work state (committed, project content)
├── .priv-storage/         [gitignored] all AI tooling lives here
│   ├── CLAUDE.md                   # 13-section project rules
│   ├── CLAUDE.local.md             # per-developer overrides
│   ├── POST_SETUP_INDEX.md         # ~50-line pointer table (saves re-reading setup file)
│   ├── AI_PROJECT_SETUP.md         # archived, never re-read
│   ├── .setup-version              # marker for stale-script detection
│   ├── memory/                     # dual-written to ~/.claude/projects/ for cross-machine sync
│   │   ├── MEMORY.md
│   │   ├── feedback/
│   │   ├── project/
│   │   └── README.md
│   ├── sessions/                   # auto-saved state
│   │   ├── current.md              # appended on every tool call
│   │   ├── handoff-{date}.md       # rotating snapshots
│   │   ├── recovery.md             # periodic compact snapshot
│   │   └── read-log.tsv            # which files the AI has Read (token-saving)
│   └── .claude/
│       ├── settings.json           # statusLine, hooks, outputStyle, defaultTeamMode
│       ├── hooks/                  # 5 shell scripts (see below)
│       ├── agents/                 # tech-lead.md, explorer.md, code-reviewer.md, log-analyzer.md, + team-specific
│       ├── commands/               # 10+ slash commands
│       ├── skills/                 # on-demand knowledge files
│       ├── rules/                  # path-scoped rules
│       ├── output-styles/terse.md  # default output style
│       └── statusline              # token/rate-limit status line script
├── tmp-igbkp/             [gitignored] backup & verification toolkit
│   ├── verify-setup.sh             # single-command health check
│   ├── automode-validate.sh        # automode safety gate
│   ├── smoke-test-hooks.sh         # fires each hook with mock payload
│   ├── secret-guard.sh             # blocks .mcp.json commits with inline secrets
│   ├── archive.sh / restore.sh     # full-repo backup
│   ├── uninstall.sh                # safe rollback
│   ├── setup-worktree.sh           # symlinks .claude/ for git worktrees
│   └── codex-relay-{check,run}.sh  # Claude Code ↔ Codex relay
├── .mcp.json              [gitignored] MCP server registry (env-var refs only)
├── README.md              # generated standard file (bilingual EN/KO)
├── SECURITY.md            # generated
├── CONTRIBUTING.md        # generated
├── CODE_OF_CONDUCT.md     # generated
├── CHANGELOG.md           # generated
├── docs/
│   ├── README.ko.md       # Korean mirror
│   ├── SECURITY.ko.md
│   └── ...
└── .github/
    └── ISSUE_TEMPLATE/    # generated issue/PR templates
```

**Key point**: only `WORK_STATUS.md`, the GitHub standard files (`README.md`, `SECURITY.md`, etc.), the `docs/` Korean mirrors, and `.github/` are committed. Everything inside `.priv-storage/` and `tmp-igbkp/` is gitignored by design (Absolute Rule #19 — "AI tooling work leaves NO footprint in project git history").

---

## How it works (lifecycle)

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. INITIAL SETUP (you ask AI to "execute" AI_PROJECT_SETUP.md)      │
│    AI runs Scenario A/B/C → creates everything above → STEP 6       │
│    archives AI_PROJECT_SETUP.md into .priv-storage/                 │
│    AI prints "Setup Complete" only if automode-validate.sh passes   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. NORMAL SESSIONS                                                  │
│    • SessionStart hook injects last handoff + current.md tail       │
│    • AI reads CLAUDE.md (~200 lines) + POST_SETUP_INDEX.md (~50)    │
│      — NOT the full AI_PROJECT_SETUP.md (saves ~25k tokens/session) │
│    • PreToolUse blocks dangerous commands + oversized Reads         │
│    • PostToolUse appends to current.md + dual-writes memory         │
│    • Stop hook writes handoff-{date}.md                             │
│    • PreCompact hook (best-effort) writes recovery.md               │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. CRASH / RATE-LIMIT / /clear                                      │
│    Next session: SessionStart auto-loads handoff + recovery         │
│    AI resumes from prior state without "where were we?" questions   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 4. SELF-UPDATE (you type "AI_PROJECT_SETUP 업데이트해")              │
│    AI fetches latest from GitHub raw URL → replaces archived file   │
│    → force-overwrites all 30+ shipped scripts (statusline, hooks,   │
│      toolkit, slash commands, default agents) with .bak backup      │
│    → re-runs automode-validate gate                                 │
│    → reports "Updated: v5.0 → v5.1. Recommend /clear."              │
│    Single command. No re-run prompt.                                │
└─────────────────────────────────────────────────────────────────────┘
```

### Three setup scenarios

The AI auto-detects which scenario applies and follows it:

| Scenario | When | What the AI does |
|----------|------|------------------|
| **A — existing project** | `.priv-storage/` exists, or a real `CLAUDE.md` is at root | Update/repair in place. Force-overwrite shipped scripts (with `.bak`), preserve user content (`CLAUDE.md` sections 1–7 and 11, `WORK_STATUS.md`, memory files, project agents). |
| **B — empty/new project** | No `.priv-storage/`, no `CLAUDE.md` at root | Full setup from scratch — STEP 0 detection → STEPs 1–12 → archive. |
| **C — broken/random state** | Files at root that look like CLAUDE.md but aren't, or partial leftover state | Detect, classify, convert to canonical layout, then bridge into Scenario A's STEPs 4–12. |

---

## Key features

### 🛡️ Safety hooks (Claude Code only — others get policy-only enforcement)

| Hook | Triggers on | Blocks / does |
|------|-------------|---------------|
| `PreToolUse` | Before any Bash/Read/Edit/Write | Blocks `rm -rf /`, force push, `git add` of gitignored AI files, eval, `base64 \| sh`, `curl http://`, `~/.ssh` reads, fork bombs, oversized Reads (>1000 lines without offset/limit), commit messages mentioning AI tooling |
| `PostToolUse` | After any tool call | Appends to `sessions/current.md`, dual-writes memory to `~/.claude/projects/`, rotates hook-error log, takes periodic recovery snapshots every 50 calls, logs Read events for stale-context detection |
| `SessionStart` | New session begins | Loads last handoff (capped 100 lines) + current.md tail + recovery + worktree-detection warning, emits Read-log hint, surfaces hook errors from last 24h |
| `PreCompact` | Before Claude Code compacts context (undocumented event — best effort) | Writes recovery.md snapshot |
| `Stop` | Session ends | Writes `handoff-{date}.md` capped at 50 lines + archives old handoffs |

### 🤖 Default agents (token-efficient)

- **`tech-lead`** — auto-evaluates complexity, forms teams (modules ≥ 2 OR files ≥ 5 OR cross-module work → TeamCreate)
- **`explorer`** — read-only codebase search (returns summaries, preserves main context window)
- **`code-reviewer`** — security/correctness/style review
- **`log-analyzer`** — parses crash logs / hook-error logs

### ⚡ Slash commands

`/status`, `/health`, `/recover`, `/ship`, `/save`, `/clean` — plus Claude Code ↔ Codex relay: `/codex-brief`, `/codex-review`, `/codex-fix`, `/codex-relay-status` (v5.0+).

### 💰 Token discipline (Absolute Rule #20)

- `CLAUDE.md` hard-capped at 16k chars (WARN) / 32k (FAIL)
- `PreToolUse` BLOCKS `Read` of >1000-line code files without `offset`/`limit`
- Subagent delegation MANDATORY (not optional) above thresholds: >3 files, >500 lines, codebase-wide search
- `read-log.tsv` tracks which files the AI has already read this session — duplicate Reads get WARN
- Auto-extends from terse → verbose only when reasoning is requested
- Expected impact: 30–60% token reduction vs naive AI-pair-programming

### 🔄 Resilience

- 3-tier session log (`current.md` → `handoff-{date}.md` → `recovery.md`)
- Memory dual-write: every memory file mirrors to `~/.claude/projects/{path-encoded}/memory/` — new laptop restores instantly
- Idempotent setup: re-running setup skips unchanged steps (SHA256 markers in `.priv-storage/.setup-step-{N}.done`)
- Force-overwrite of shipped scripts on every update (with `.bak` backup) — stale hook/statusline bugs auto-resolve

### 🔐 Secret guard

`tmp-igbkp/secret-guard.sh` is a pre-commit-style scanner that blocks committing `.mcp.json` (or any file) containing inline tokens matching `AKIA…`, `sk-…`, `ghp_…`, `slack-…`, etc. Use `${ENV_VAR}` references instead. Per-line `# secret-guard:ignore` available for false positives (e.g., AWS docs example keys).

### 🌏 Bilingual GitHub files

All GitHub standard files generated in EN (root) / KO (`docs/`) pairs with cross-links — same structure, identical content, separate files for clean diff history.

### 🔀 Cross-AI Codex relay (Claude Code only, v4.9+)

When `codex` CLI is on `PATH` and Claude Code is the primary local agent, Claude can offload implementation passes to Codex while remaining the planning/review authority:

```
Claude (plan) → /codex-brief → Codex (implement) → Claude (/codex-review) → Codex (/codex-fix)
```

v5.0 adds parallel per-agent relay lanes for TeamCreate work, with conflict prevention (disjoint allowed-paths per lane). The relay is opportunistic — `codex-relay-check.sh` verifies prerequisites first; if anything fails, Claude writes a manual handoff brief instead of forcing the relay.

---

## Supported AI tools

| Tool | Minimum version | Reads | Hook support |
|------|-----------------|-------|--------------|
| **Claude Code** | 2.0+ | `CLAUDE.md` | ✅ Full (`PreToolUse`, `PostToolUse`, `SessionStart`, `PreCompact`, `Stop`) |
| **ChatGPT Codex CLI** | 0.10+ | `AGENTS.md` (symlink to `CLAUDE.md`) | ❌ Policy-only |
| **Cursor** | 0.40+ | `.cursorrules` (copy of `CLAUDE.md`) | ❌ Policy-only |
| **GitHub Copilot** | 1.150+ | `AGENTS.md` | ❌ Policy-only |
| **claude.ai (web)** | current | upload `CLAUDE.md` manually | ❌ Policy-only |
| **Other MCP-aware tools** | — | depends on tool | ❌ Policy-only |

"Policy-only" means rules are enforced through prompt content, not shell hooks — the AI follows them because they're written in the rules file it reads, but there's no kernel-level block.

---

## Self-update

The file self-updates from this repository.

When the user types `"AI_PROJECT_SETUP 업데이트해"` / `"update AI_PROJECT_SETUP"` / `"fetch latest setup"`, the AI:

1. Fetches `https://raw.githubusercontent.com/kernalix7/ai-project-setup/main/AI_PROJECT_SETUP.md`
2. Compares the `Last Updated` line and version against the local copy
3. If newer, replaces `.priv-storage/AI_PROJECT_SETUP.md` and force-overwrites all 30+ shipped scripts (statusline, hooks, toolkit, slash commands, default agents) with `.bak` backup
4. Merges new template sections of `CLAUDE.md` (sections 8/9/10/12/13) while preserving project-specific content (sections 1–7 and 11)
5. Re-runs the validator gate
6. Reports `Updated: vOLD → vNEW. Force-patched N shipped scripts. Recommend /clear.`

**Single command, no re-run prompt** (since v4.6+).

> **v5.0 → v5.1 migration**: v5.1 moved the update source from a gist to this repository. Projects on v5.0 or earlier fetch v5.1 once from the legacy gist (which is frozen at v5.1 as a migration bridge), then all subsequent updates come from this repository. See the version history in [`AI_PROJECT_SETUP.md`](AI_PROJECT_SETUP.md) for details.

---

## Forking and customization

If you fork this repository and want your forks to self-update from your own repo:

1. Edit [`AI_PROJECT_SETUP.md`](AI_PROJECT_SETUP.md) — search for `kernalix7/ai-project-setup` and replace both occurrences with your `{user}/{repo}`:
   - The repo URL in the **Source of Truth** block
   - The raw URL in the same block and in the self-update protocol Step 2
2. Optionally remove the legacy gist URL block — it's only needed if you're migrating users from a pre-v5.1 gist-based source.
3. Commit and push to your fork's `main` branch.

For project-specific customization (your downstream projects), edit the generated `.priv-storage/CLAUDE.md` directly — sections 1–7 and 11 are preserved across self-updates.

---

## FAQ

**Q: Why a single 7000-line markdown file instead of a CLI tool?**
Because AI coding assistants natively read markdown. A CLI tool would need installation, version management, and platform support. A markdown file works everywhere any AI works — Linux, macOS, Windows, containers, browser-based agents — with zero install.

**Q: Doesn't 7000 lines blow up my context window?**
Only on the initial setup (~25k tokens, one time). After setup, the file is archived and a 50-line `POST_SETUP_INDEX.md` is the entry point. Sessions consume ~200 lines of `CLAUDE.md` + the index — about 4k tokens.

**Q: Is it safe that nothing gets committed? My CI/CD doesn't see hooks/agents.**
Correct — and that's intentional. AI tooling is per-developer ergonomics; CI/CD runs against your code, not your AI config. If a teammate doesn't use AI, their experience is unchanged. If they do, they run setup themselves and get the same config from this same source file.

**Q: Will this work with [some new AI tool that doesn't exist yet]?**
If the tool reads markdown rules files (`CLAUDE.md` / `AGENTS.md` / `.cursorrules` / similar), yes — point it at any of the three symlinks. If it supports MCP, it'll find `.mcp.json` automatically. Hooks are Claude Code-specific.

**Q: How do I uninstall?**
```bash
./tmp-igbkp/uninstall.sh
```
Backs up everything to `tmp-igbkp/uninstall-backup-{ts}/` before removing.

**Q: I found a bug / want a feature.**
Open an issue or PR at <https://github.com/kernalix7/ai-project-setup>.

---

## License

[MIT](LICENSE) © 2026 Kim DaeHyun (kernalix7@kodenet.io)
