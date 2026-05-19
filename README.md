<div align="center">

# AIPS

### One curl. One slash command. Disciplined AI in every project.

<p>A <b>Claude Code plugin</b> that bootstraps disciplined AI tooling across every git project — global hooks/agents/commands, per-project rules, session resume, dual-write memory, statusline metrics, and Claude ↔ Codex relay. <b>Install once per machine. Init each project with one slash command.</b></p>

<pre><code># 1. Once per machine
curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/install.sh | bash

# 2. Once per project
cd my-project && claude
> /aips:init
</code></pre>

[![Status](https://img.shields.io/badge/status-v7.0%20in%20development-FF8C00?style=for-the-badge)](.priv-storage/v6.0-PLAN.md)
[![Latest](https://img.shields.io/badge/latest-v7.0--dev-2962FF?style=for-the-badge)](.priv-storage/v6.0-PLAN.md)

[![license](https://img.shields.io/github/license/kernalix7/AIPS?style=flat-square&color=blue)](LICENSE)
[![plugin](https://img.shields.io/badge/Claude%20Code-plugin-7C3AED?style=flat-square&logo=anthropic&logoColor=white)](https://claude.com/claude-code)
[![commands](https://img.shields.io/badge/slash%20commands-12-2EA44F?style=flat-square)](#slash-commands)
[![deps](https://img.shields.io/badge/plugin%20deps-4-blue?style=flat-square)](#what-gets-installed)
[![stars](https://img.shields.io/github/stars/kernalix7/AIPS?style=flat-square&color=FFD93D&logo=github&logoColor=white)](https://github.com/kernalix7/AIPS/stargazers)
[![PRs](https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square)](CONTRIBUTING.md)

###### Works with

[![Claude Code](https://img.shields.io/badge/Claude%20Code-2.0%2B-7C3AED?style=flat-square&logo=anthropic&logoColor=white)](https://claude.com/claude-code)
[![Codex CLI](https://img.shields.io/badge/Codex%20CLI-0.10%2B-10B981?style=flat-square&logo=openai&logoColor=white)](https://github.com/openai/codex)
[![Cursor](https://img.shields.io/badge/Cursor-0.40%2B-000000?style=flat-square&logo=cursor&logoColor=white)](https://cursor.sh)
[![GitHub Copilot](https://img.shields.io/badge/Copilot-1.150%2B-24292F?style=flat-square&logo=githubcopilot&logoColor=white)](https://github.com/features/copilot)
[![MCP](https://img.shields.io/badge/MCP-aware-FF6B6B?style=flat-square)](https://modelcontextprotocol.io)
[![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat-square&logo=linux&logoColor=black)](#)
[![macOS](https://img.shields.io/badge/macOS-000000?style=flat-square&logo=apple&logoColor=white)](#)
[![Windows](https://img.shields.io/badge/Windows-Git%20Bash-0078D6?style=flat-square&logo=windows&logoColor=white)](#)

<sub>**English** &nbsp;·&nbsp; [한국어](docs/README.ko.md) &nbsp;·&nbsp; [v6.0 plan](.priv-storage/v6.0-PLAN.md) &nbsp;·&nbsp; [Contributing](CONTRIBUTING.md) &nbsp;·&nbsp; [Security](SECURITY.md) &nbsp;·&nbsp; [Changelog](CHANGELOG.md)</sub>

</div>

---

### Status: v7.0 in development

> **v5.2 (stable)** is the single-file bootstrap model (`AI_PROJECT_SETUP.md`, ~7,600 lines). You download it and tell the AI "read and execute this." v5.x users can keep using [`AI_PROJECT_SETUP.md`](AI_PROJECT_SETUP.md).
>
> **v6.0** redistributes the same artifact as a **Claude Code plugin marketplace**. One `install.sh` per machine registers the marketplace in `~/.claude/` and installs/updates 4 dependency plugins; each project runs `/aips:init` once and **auto-branches** between fresh / v5.x migrate / re-init / repair. The 7,600-line markdown the AI used to parse every time is replaced by a deterministic install script + idempotent slash commands. v6.0 setups remain a fully valid baseline.
>
> **v7.0 (in development)** layers a **hybrid global-first** model on top of v6.0 — toolkit scripts, sessions mirror, memory, and the AIPS gitignore block move into `~/.claude/` / `~/.local/bin/` / `~/.config/git/ignore`, while CLAUDE.md, WORK_STATUS.md, `.mcp.json`, agent files, and `tmp-igbkp/` backup outputs stay per-project. v7.0 is **non-breaking**: existing v6.0 projects keep working untouched, and migration is opt-in via `/aips:upgrade --to v7.0`.
>
> This document describes **v7.0** with v6.0 baseline notes. If you need v5.2, see the [v5.2 archive](AI_PROJECT_SETUP.md) or the [Korean README](docs/README.ko.md) v5.2 section.

---

## Table of contents

- [Why this exists](#why-this-exists)
- [Quick start](#quick-start)
- [What gets installed](#what-gets-installed)
- [Lifecycle](#lifecycle)
- [Statusline](#statusline)
- [Slash commands](#slash-commands)
- [Migration from v5.x](#migration-from-v5x)
- [v7.0 Hybrid Global-First](#v70-hybrid-global-first)
- [Supported AI tools](#supported-ai-tools)
- [Comparison](#comparison)
- [Documentation](#documentation)
- [FAQ](#faq)
- [Roadmap](#roadmap)
- [Star history](#star-history)
- [Support](#support)
- [License](#license)

---

## Why this exists

v5.x worked, but every project required the AI to read and interpret a 7,600-line markdown file (~25k tokens, 1–3 minutes wait, occasional retry on failure). v6.0 moves to deterministic shell scripts and Claude Code's native plugin / skill / hook system, cutting per-project setup to **30 seconds** and removing the need for the AI to "understand" the artifact at all.

| v5.x | v6.0 |
|---|---|
| Download a 7,600-line `.md` per project, AI executes it (~25k tokens, 1–3 min) | One install, then `/aips:init` per project (~30 sec) |
| AI reads and interprets markdown → non-deterministic | Deterministic shell script + plugin manifest |
| Self-update = AI fetches raw URL and rebuilds | `/aips:update` = marketplace pull + dependency update |
| 9 toolkit scripts copied into each project `tmp-igbkp/` | Same 9 toolkit scripts, auto-synced via marketplace pull |
| Custom `/codex-*` (×4) regenerated per project | `codex-plugin-cc` ships them globally as `/codex:*` |

---

## Quick start

**Once per machine** (every project ever, run once):

```bash
curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/install.sh | bash
```

What `install.sh` does:

1. Registers the AIPS marketplace in `~/.claude/`
2. Installs / updates 4 dependency plugins:
   - **codex-plugin-cc** — `/codex:*` slash commands (Claude ↔ Codex relay)
   - **caveman** — ultra-terse output style + `/caveman*` commands
   - **agentmemory** + systemd unit — file-backed memory + auto-backup
   - **RTK** (Rust Token Killer) — 60–90% token savings CLI proxy
3. Drops global hooks / agents / commands / skills / output-styles / statusline into `~/.claude/`

**Per project**:

```bash
cd my-project
claude
> /aips:init
```

`/aips:init` auto-branches:

| Case | Trigger | Action |
|---|---|---|
| **A. Fresh** | No `.priv-storage/`, no v5.x `.md` at root | Fresh init (~30 sec) |
| **B. v5.x migrate** | Root `AI_PROJECT_SETUP.md` (v5.x) detected | 1 confirm → backup → cleanup → v6.0 init |
| **C. Re-init (idempotent)** | `.priv-storage/` v6.0 marker present | Idempotent re-init (drift repair) |
| **D. Repair** | Broken / partial state detected | Repair mode |

Done. Every artifact is gitignored — your git history stays clean. Verify any time with `/aips:health`.

---

## What gets installed

v6.0 strictly separates **global** (once per machine) from **per-project** (`/aips:init`).

### Global — `~/.claude/` (install.sh)

| Category | Contents |
|---|---|
| Plugins | 4: `codex-plugin-cc`, `caveman`, `agentmemory` (+ systemd unit), `RTK` |
| Hooks | 5: `PreToolUse`, `PostToolUse`, `SessionStart`, `PreCompact`, `Stop` |
| Agents | 3 templates: `tech-lead`, `explorer`, `code-reviewer` |
| Commands | 16: 12 `/aips:*` (9 base + 3 v7.0) + dependency plugin commands |
| Skills | On-demand knowledge modules (caveman, codex, etc.) |
| Output styles | `terse` (default), `caveman/full`, `caveman/ultra`, etc. |
| Statusline | 3-line multi-line (see preview below) |
| Binaries | RTK Rust binary (`~/.local/bin/rtk`) |
| Daemons | agentmemory systemd unit (user-level) |

### Project — `.priv-storage/` (`/aips:init`)

```text
your-project/
|-- CLAUDE.md              -> .priv-storage/CLAUDE.md  (symlink)
|-- AGENTS.md              -> .priv-storage/CLAUDE.md  (symlink, Codex / Copilot)
|-- .cursorrules           -> .priv-storage/CLAUDE.md  (symlink, Cursor)
|-- WORK_STATUS.md         -> .priv-storage/WORK_STATUS.md
|
|-- .priv-storage/         [gitignored] per-project AI state
|   |-- CLAUDE.md                   # Sections 1-7 + 11 only, ~150 lines (v5.x was 13 sections, ~10kB)
|   |-- CLAUDE.local.md             # per-developer overrides
|   |-- WORK_STATUS.md              # current task state
|   |-- memory/                     # agentmemory file-backed store
|   |-- sessions/                   # current.md / handoff-{date}.md / recovery.md
|   |-- agents/                     # tech-lead.md + per-team agents
|   |-- .mcp.json                   # MCP server registry (env-var refs only)
|   `-- .gitignore                  # 22 entries
|
`-- tmp-igbkp/             [gitignored] backup + verification toolkit (9 scripts)
    |-- verify-setup.sh             # health check
    |-- smoke-test-hooks.sh         # hook validation with mock payloads
    |-- secret-guard.sh             # 14-pattern pre-commit scanner
    |-- archive.sh / restore.sh     # AES-256-CBC + PBKDF2 600k iterations
    |-- purge-history.sh            # git-filter-repo wrapper
    |-- setup-worktree.sh           # worktree bridge
    `-- uninstall.sh                # safe rollback
```

> Only `WORK_STATUS.md`, GitHub standard files, the `docs/` Korean mirrors, and `.github/` get committed. Everything in `.priv-storage/` and `tmp-igbkp/` is gitignored on purpose. **`CLAUDE.md` is reduced to ~150 lines** (v5.x was ~10kB) — Sections 8 / 9 / 10 / 12 / 13 moved out into the global plugin / skill layer.

> **v7.0 layout shifts (opt-in via `/aips:upgrade --to v7.0`)**:
>
> | Item | v6.0 location | v7.0 location |
> |---|---|---|
> | `tmp-igbkp/` scripts | per-project (copied) | per-project (backup outputs) + global (scripts via `~/.local/bin/aips-*`) |
> | `sessions/` | per-project only | per-project (fast-write buffer) + global mirror in `~/.claude/sessions/{path-hash}/` |
> | `memory/` | per-project + global | global only — `~/.claude/projects/{path-encoded}/memory/` |
> | AIPS `.gitignore` block | per-project (22 entries) | global `~/.config/git/ignore` + minimal per-project `.gitignore` |

---

## Lifecycle

```text
[1. Global install] (once per machine)
  curl ... | bash
  - Register AIPS marketplace → ~/.claude/
  - Install/update 4 dependency plugins
  - Drop hooks/agents/commands/skills/output-styles/statusline
  - Install RTK binary, agentmemory systemd unit
        |
        v
[2. Project init] (once per project, ~30 sec)
  cd project && claude → /aips:init
  - Auto-branch A/B/C/D
  - Create .priv-storage/ + tmp-igbkp/, drop 3 symlinks
  - CLAUDE.md Sections 1-7 + 11 (~150 lines)
  - Add 22 .gitignore entries
        |
        v
[3. Normal session]
  - SessionStart hook auto-injects prior handoff + current.md tail
  - AI reads only CLAUDE.md (~150 lines) — no 7,600-line .md
  - PreToolUse blocks dangerous commands + oversized reads
  - PostToolUse appends current.md + dual-writes to agentmemory
  - Stop hook writes handoff-{date}.md
  - PreCompact hook writes recovery.md (best-effort)
  - Stats accumulate: 3-line statusline updates live
        |
        v
[4. Crash / rate-limit / /clear]
  - Next session, SessionStart auto-loads handoff + recovery
  - AI resumes from prior state without asking "where were we?"
        |
        v
[5. Updates] (trigger: /aips:update)
  - marketplace pull → update 4 dependency plugins
  - Global hooks/commands auto-sync
  - Projects untouched (re-init via /aips:init if needed)
```

---

## Statusline

3-line multi-line. Key signals at a glance.

```
project [main*3] wip:2 | opus-4.7 | ctx:8%(15.5k/200k) | cache:71%
5h:8% ↻2h11m ∅1h23m | wk:12% ↻4d18h ∅2d4h
🦴cv:75%/full | 🧠am:40%/127 | 💰rtk:34% | 🤖cdx:55%/3runs | 💯Σ:95%
```

| Line | Shows |
|---|---|
| 1 | Project name, git branch [commits since base], `wip` count, model, context usage, prompt cache hit rate |
| 2 | 5-hour window usage + time until reset (`↻`) + projected empty ETA at current burn rate (`∅`); weekly window same |
| 3 | caveman savings/intensity, agentmemory hit rate / observation count, RTK savings, codex delegation rate / runs, cumulative savings (`Σ`) |

`↻` = time until reset, `∅` = projected empty ETA at current burn rate, `Σ` = cumulative savings (`Σ = 1 − Π(1 − SAVED_i / 100)`).

---

## Slash commands

### AIPS native (12 — 9 base + 3 v7.0)

| Command | Action |
|---|---|
| `/aips:init` | Auto-branched init (fresh / migrate / re-init / repair) |
| `/aips:update` | marketplace pull + dependency plugin update |
| `/aips:health` | `verify-setup.sh` + `smoke-test-hooks.sh` |
| `/aips:status` | Current task + recent activity summary |
| `/aips:migrate-from-md` | Explicit v5.x `.md` migration (manual case-B trigger) |
| `/aips:upgrade` | v5.x → v6.0 + dependency plugin upgrade |
| `/aips:repair` | Repair broken state (manual case-D trigger) |
| `/aips:reset` | Reset project init (with backup) |
| `/aips:uninstall` | Safe removal, global + project |
| `/aips:upgrade --to v7.0` | **v7.0** — Extended `/aips:upgrade` flag: v6.0 → v7.0 hybrid migration (opt-in, non-breaking) |
| `/aips:rebind <old-path>` | **v7.0** — Rebind globalized state (sessions mirror, memory) when a project directory moves or is renamed |
| `/aips:scope` | **v7.0** — Diagnose what is globalized vs per-project for the current project; flag drift or orphaned global state |

### Dependency plugin commands

| Plugin | Commands |
|---|---|
| codex-plugin-cc | `/codex:brief`, `/codex:review`, `/codex:fix`, `/codex:relay-status` |
| caveman | `/caveman`, `/caveman:lite`, `/caveman:ultra`, `/caveman:wenyan-*` |
| agentmemory | `/am:save`, `/am:recall`, `/am:reflect`, `/am:consolidate`, `/am:sessions` |
| RTK | hook-based auto — no explicit command (`rtk gain` from shell) |

> The legacy custom `/codex-brief`, `/codex-review`, `/codex-fix`, `/codex-relay-status` from v5.x are **removed**. Use `/codex:*` from the official `codex-plugin-cc` instead.

---

## Migration from v5.x

**Automatic (recommended)** — just run `/aips:init` in the project:

```bash
cd existing-v5-project
claude
> /aips:init
# → Detects root AI_PROJECT_SETUP.md (v5.x)
# → "v5.x install detected. Migrate to v6.0? [y/N]"
# → On y:
#   1. Full backup to .priv-storage/v5-backup/
#   2. Reduce 7,600-line AI_PROJECT_SETUP.md → 30-line DEPRECATED redirect
#   3. Remove custom /codex-* (4 commands) — replaced by codex-plugin-cc
#   4. Remove tmp-igbkp/codex-relay-{check,run}.sh
#   5. Slim CLAUDE.md down to Sections 1-7 + 11 only (~150 lines)
#   6. Write v6.0 marker
```

**Manual** — `/aips:migrate-from-md` triggers the same flow explicitly.

### Removed in v6.0

- **7,600-line `AI_PROJECT_SETUP.md` execution model** → reduced to 30-line DEPRECATED redirect (downstream raw-URL compatibility preserved)
- **Custom slash commands** `/codex-brief`, `/codex-review`, `/codex-fix`, `/codex-relay-status` → replaced by `codex-plugin-cc`'s `/codex:*`
- **`tmp-igbkp/codex-relay-{check,run}.sh`** → codex-plugin-cc manages its own locks / ledger
- **`CLAUDE.md` Sections 8 / 9 / 10 / 12 / 13** → moved into the global plugin / skill / hook layer; per-project `CLAUDE.md` keeps only Sections 1-7 + 11 (~150 lines)

---

## v7.0 Hybrid Global-First

v7.0 selectively globalizes per-project files where doing so improves safety and value (toolkit scripts, sessions mirror, memory store, AIPS gitignore block). Everything that needs to stay project-bound (rules, work state, MCP, team agents, backup outputs) remains per-project. **v6.0 setups are untouched** and migration is **opt-in**.

### Globalized (4 items)

| Item | v6.0 location | v7.0 location | Why |
|---|---|---|---|
| Toolkit scripts | `tmp-igbkp/*.sh` copied per project | `~/.local/bin/aips-*` (symlinks via `lib/globalize-toolkit.sh`) | One canonical copy, no drift, one PATH lookup |
| Sessions | `.priv-storage/sessions/` only | `.priv-storage/sessions/` (fast-write buffer) + `~/.claude/sessions/{path-hash}/` mirror | Survives project-dir moves, cross-machine sync via single dir |
| Memory | `.priv-storage/memory/` + global | global only — `~/.claude/projects/{path-encoded}/memory/` | Single source of truth, no duplicate-write drift |
| `.gitignore` AIPS block | 22 entries per project `.gitignore` | `~/.config/git/ignore` (global) + minimal per-project `.gitignore` | Zero-noise project gitignore; works across all repos automatically |

### Preserved per-project (5 items)

| Item | Why it stays per-project |
|---|---|
| `CLAUDE.md` Sections 1–7 + 11 | Project rules + multi-tool guarantee (Claude/Codex/Cursor/Copilot all read it) |
| `WORK_STATUS.md` | Team-shared task state — must live in the repo |
| `.mcp.json` | Project-specific MCP server registry |
| `tech-lead.md` + team agents | Per-project team composition |
| `tmp-igbkp/` backup outputs | Encrypted backup archives belong with the project they back up |

### New slash commands (3)

- `/aips:upgrade --to v7.0` — extends existing `/aips:upgrade` with the v6.0 → v7.0 hybrid migration path
- `/aips:rebind <old-path>` — rebind globalized state (sessions mirror, memory) when a project directory moves or is renamed
- `/aips:scope` — diagnose what is globalized vs per-project for the current project, flag drift or orphaned global state

### Migration

```bash
cd existing-v6-project
claude
> /aips:upgrade --to v7.0
# → Strict mode (default): result is identical to a fresh v7.0 install.
#   per-project tmp-igbkp/*.sh and sessions/*.md are purged after their
#   global counterparts are verified. Full backup at
#   tmp-igbkp/upgrade-v7-backup-{ts}/ is always taken first.
# → Pass --keep-local-fallback to retain both as fallback (lenient).
```

---

## Supported AI tools

**AIPS is built for Claude Code first.** Other tools get policy-only support via `CLAUDE.md` / `AGENTS.md` / `.cursorrules`; full plugin-like support for them is roadmap.

### Tier 1 — Primary / Full

| Tool | Min version | Reads | v6.0 features |
|---|---|---|---|
| **Claude Code (CLI)** | 2.0+ | `CLAUDE.md` | Full plugin install, 9 `/aips:*` slash commands, 5 hooks, 3-line statusline, output styles, 4 bundled dep plugins (codex-plugin-cc, caveman, agentmemory, RTK) |

### Tier 2 — Partial (policy-only)

| Tool | Min version | Reads | v6.0 features |
|---|---|---|---|
| **ChatGPT Codex CLI** | 0.10+ | `AGENTS.md` → `CLAUDE.md` | Rules only (no hooks / slash / statusline) |
| **Cursor** | 0.40+ | `.cursorrules` → `CLAUDE.md` | Rules only |
| **GitHub Copilot** | 1.150+ | `AGENTS.md` | Rules only |
| **claude.ai (web)** | current | `CLAUDE.md` manual upload | Rules only |
| **Any MCP-aware tool** | — | depends | `.mcp.json` only |

> *Policy-only* = rules enforced through prompt content. No kernel-level blocking, no hooks, no slash commands, no statusline — but the rule file is read by the AI and followed.

### Tier 3 — Full support TBD

Full plugin-like parity (hooks, slash commands, statusline, dep-plugin stack) for Codex / Cursor / Copilot is on the roadmap.

> **TBD — roadmap, no ETA.** Track progress in [Roadmap](#roadmap) or open an issue to upvote.

---

## Comparison

| | AIPS v6.0 | AIPS v5.x (.md) | `.cursorrules` only | Hand-written CLAUDE.md |
|---|:---:|:---:|:---:|:---:|
| Per-project setup time | ~30 sec | 1–3 min | instant | hours |
| Deterministic | yes (shell) | no (AI interprets) | yes | yes |
| Single source of truth across tools | yes | yes | no (Cursor only) | no (Claude only) |
| One-line global install | yes | no | no | no |
| Safety hooks (kernel-level) | yes | yes | no | manual |
| Session resume on crash | yes | yes | no | manual |
| 3-line statusline (incl. savings) | yes | no | no | no |
| Cross-AI relay (Claude ↔ Codex) | yes (plugin) | yes (custom) | no | no |
| Token savings (RTK + caveman + agentmemory) | yes | no | no | no |
| Upstream self-update | yes (`/aips:update`) | yes (AI fetch) | no | no |
| AI-tooling leak prevention | yes | yes | no | manual |
| Linux / macOS / Windows | yes | yes | yes | yes |

---

## Documentation

| Document | What's inside |
|---|---|
| [install.sh](install.sh) | Global install script |
| [docs/README.ko.md](docs/README.ko.md) | This README in Korean |
| [AI_PROJECT_SETUP.md](AI_PROJECT_SETUP.md) | v5.2 archive (becomes 30-line DEPRECATED stub in v6.0) |
| [CONTRIBUTING.md](CONTRIBUTING.md) · [한국어](docs/CONTRIBUTING.ko.md) | Dev setup, version-bump checklist, PR conventions |
| [SECURITY.md](SECURITY.md) · [한국어](docs/SECURITY.ko.md) | Disclosure process, secret-guard patterns |
| [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) · [한국어](docs/CODE_OF_CONDUCT.ko.md) | Contributor Covenant v2.1 |
| [CHANGELOG.md](CHANGELOG.md) · [한국어](docs/CHANGELOG.ko.md) | Full version history |

---

## FAQ

<details>
<summary><b>Do I have to move from v5.x to v6.0?</b></summary>

No. v5.2 stays supported as the stable line. Keep using v5.x until v6.0 is promoted to stable. When you're ready, a single `/aips:init` auto-migrates (case B).
</details>

<details>
<summary><b>Do I need to upgrade from v6.0 to v7.0?</b></summary>

No. v7.0 is **opt-in and non-breaking**. v6.0 setups continue working untouched. When you want the hybrid global-first benefits (one canonical toolkit, sessions mirror, global gitignore, single-source memory), run `/aips:upgrade --to v7.0` per project.
</details>

<details>
<summary><b>What if I rename or move my project after v7.0 init?</b></summary>

Run `/aips:rebind <old-path>` from inside the project's new location. It rewrites the path-hash-keyed globalized state (`~/.claude/sessions/{path-hash}/`, memory mappings) so sessions and memory continue resolving to the same project.
</details>

<details>
<summary><b>How do I check what's globalized vs per-project?</b></summary>

Run `/aips:scope`. It prints a diagnostic of which artifacts for the current project live globally vs per-project, and flags drift (e.g., per-project sessions buffer ahead of the global mirror) or orphaned global state (mirror exists for a project dir that no longer exists).
</details>

<details>
<summary><b>What does install.sh touch on my system?</b></summary>

`~/.claude/` (Claude Code global config), `~/.local/bin/rtk` (RTK binary), and a user-level systemd unit (agentmemory). It does not touch system-wide directories (`/usr/local/`, `/etc/`). Uninstall via `/aips:uninstall` for a safe rollback.
</details>

<details>
<summary><b>Why bundle 4 dependency plugins?</b></summary>

Each provides an orthogonal value — codex-plugin-cc (relay), caveman (output compression), agentmemory (persistent memory), RTK (CLI token savings). Installing them separately makes hook conflicts and statusline fallbacks painful. Bundling guarantees cross-plugin sync.
</details>

<details>
<summary><b>Does it work offline?</b></summary>

Install / update need the network (marketplace pull, RTK binary fetch). Normal sessions and `/aips:init` work offline — every artifact is read from the local plugin store.
</details>

<details>
<summary><b>How do I sync across multiple machines?</b></summary>

agentmemory dual-writes project memory into `~/.claude/projects/{path-encoded}/memory/`. On a new machine: run `install.sh` → `/aips:init` in the project → `rsync` the memory dir over and you're restored.
</details>

<details>
<summary><b>What about Windows?</b></summary>

Git Bash, WSL, and MSYS2 work. `install.sh` is bash, hooks are bash, so native PowerShell is not supported. WSL is recommended.
</details>

<details>
<summary><b>Can I use multiple AI tools in the same project?</b></summary>

Yes. Claude Code reads `CLAUDE.md`, Codex / Copilot read `AGENTS.md`, Cursor reads `.cursorrules` — all three are symlinks to the same `.priv-storage/CLAUDE.md`, so updates are atomic. Hooks, statusline, and slash commands are Claude Code-only.
</details>

<details>
<summary><b>Can I skip the marketplace and just clone the repo?</b></summary>

Yes. Clone the repo and run `install.sh` from the local path — the marketplace-registration step falls back to pointing at the local path. Useful for forked environments.
</details>

<details>
<summary><b>I found a bug / want a feature.</b></summary>

Open an issue or PR at <https://github.com/kernalix7/AIPS>. See [CONTRIBUTING.md](CONTRIBUTING.md).
</details>

---

## Roadmap

- **v6.0** — Plugin marketplace + 4 dependency plugins + 9 `/aips:*` commands (baseline; remains valid)
- **v7.0** *(in development)* — Hybrid global-first: globalized toolkit/sessions/memory/gitignore, 3 new `/aips:*` commands (`upgrade --to v7.0`, `rebind`, `scope`), opt-in non-breaking migration from v6.0
- **v7.1** — agentmemory deeper integration (cross-project workflow recommendations, shared lesson surfaces)
- **v7.2** — `/aips:rebind` UX improvements (auto-detect moved projects via path-hash heuristics)
- **v8.0 (candidate)** — TBD; options under consideration: team-shared globals via cloud sync, or full plugin-marketplace publishing for third-party AIPS extensions

See [CHANGELOG.md](CHANGELOG.md) for shipped versions.

---

## Star history

<a href="https://star-history.com/#kernalix7/AIPS&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=kernalix7/AIPS&type=Date&theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=kernalix7/AIPS&type=Date" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=kernalix7/AIPS&type=Date" />
  </picture>
</a>

---

## Support

If AIPS saved you setup time:

[![Ko-fi](https://img.shields.io/badge/Ko--fi-F16061?logo=ko-fi&logoColor=white&style=for-the-badge)](https://ko-fi.com/kernalix7)
[![Fairy](https://img.shields.io/badge/Fairy-EE6E73?style=for-the-badge&logoColor=white)](https://fairy.hada.io/@kernalix7)

Ko-fi handles international cards and PayPal; fairy.hada.io is a Korean tipping platform. Bug reports, PRs, and stars on the repo are equally appreciated and free.

---

## License

[MIT](LICENSE) — Kim DaeHyun ([kernalix7@kodenet.io](mailto:kernalix7@kodenet.io))

<div align="center">

[Report bug](https://github.com/kernalix7/AIPS/issues/new?template=bug_report.md) &nbsp;·&nbsp; [Request feature](https://github.com/kernalix7/AIPS/issues/new?template=feature_request.md) &nbsp;·&nbsp; [한국어 README](docs/README.ko.md)

</div>
