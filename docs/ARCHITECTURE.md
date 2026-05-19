# AIPS v6.0 — Architecture

This document describes the internal architecture of **AI Project Setup (AIPS) v6.0**: how the installer, plugin, hooks, slash commands, templates, and dependency plugins compose into a one-command bootstrap for any AI-assisted coding project.

For end-user how-to, see [`README.md`](../README.md). For project conventions, see [`.priv-storage/CLAUDE.md`](../.priv-storage/CLAUDE.md).

---

## 1. Distribution model

AIPS v5.x shipped a single 7,600-line markdown file (`AI_PROJECT_SETUP.md`) that an AI tool was expected to *read and execute step-by-step*. v6.0 replaces that with a **Claude Code plugin** distributed through the standard `/plugin marketplace` mechanism, plus a thin `install.sh` for first-run wiring.

| Aspect | v5.x | v6.0 |
|---|---|---|
| Artifact | one markdown file | plugin (commands + hooks + templates) + install.sh |
| Tool surface | AI reads markdown | native slash commands (`/aips:init`, `/aips:health`, …) |
| Updates | re-fetch raw URL, re-run setup | `/plugin update AIPS@AIPS` |
| Multi-tool | full re-execution per tool | Claude Code primary; AGENTS.md / .cursorrules still drive Codex / Cursor |
| Token cost | ~25k tokens per re-read | ~0 (plugin metadata, lazy-loaded) |

---

## 2. Repository structure

```
ai-project-setup/
├── .claude-plugin/                  ← plugin manifest
│   ├── plugin.json                  (name, version, hooks, commands)
│   └── marketplace.json             (when this repo IS a marketplace)
├── install.sh                       ← user-level installer (no sudo)
├── lib/                             ← runtime helpers invoked by commands
│   ├── detect-project.sh
│   ├── render-claude-md.sh
│   ├── setup-agentmemory-service.sh
│   ├── verify-init.sh
│   └── migrate-from-md.sh
├── hooks/                           ← deterministic shell hooks
│   ├── hooks.json
│   ├── SessionStart.sh
│   ├── PreToolUse.sh
│   ├── PostToolUse.sh
│   ├── PreCompact.sh
│   └── Stop.sh
├── commands/                        ← /aips:* slash commands (9)
├── agents/                          ← agent role definitions
├── templates/                       ← project-template files copied on init
│   ├── CLAUDE.md.tmpl
│   ├── WORK_STATUS.md.tmpl
│   ├── memory/
│   └── tmp-igbkp/                   (9 toolkit scripts)
├── docs/                            ← architecture, migration, ko/
└── README.md, LICENSE, CHANGELOG.md
```

See [`.priv-storage/CLAUDE.md`](../.priv-storage/CLAUDE.md) Section 3 for the per-project layout this generates.

---

## 3. `install.sh` flow

`install.sh` is the only globally-invoked script. It is idempotent, sudo-free, and pure user-level.

```
A. Pre-flight        → check bash >= 4, git, curl, node >= 18.18 (if --with agentmemory), claude CLI
B. Marketplace add   → /plugin marketplace add kernalix7/AIPS
C. AIPS install      → /plugin install AIPS@AIPS  (or update if present)
D. Dep plugins       → codex@openai-codex, caveman@caveman, agentmemory@agentmemory  (per --with)
D'. RTK              → curl install.sh | sh  (if --with rtk and not present)
E. agentmemory svc   → bash lib/setup-agentmemory-service.sh  (Linux only)
```

Flags:
- `--no-plugin-update` — skip updates if already installed (offline mode).
- `--with codex,caveman,agentmemory,rtk` — comma-list of deps. Default = all.
- `--local-source <path>` — use a local clone instead of GitHub (for dev).
- `--dry-run` — print actions, no execution.

---

## 4. Plugin manifest

`.claude-plugin/plugin.json` declares:

```json
{
  "name": "AIPS",
  "version": "6.0.0",
  "hooks": "hooks/hooks.json",
  "commands": "commands/",
  "agents": "agents/"
}
```

`.claude-plugin/marketplace.json` lets this repo itself be added with `/plugin marketplace add kernalix7/AIPS` — i.e. AIPS is its own single-plugin marketplace.

Claude Code resolves the manifest at install time and lazy-loads commands / hooks as needed. No bytes from `lib/`, `templates/`, or `docs/` enter the model's context unless a command explicitly cats them.

---

## 5. Hooks registry

`hooks/hooks.json` registers 5 deterministic shell scripts. All run as the user, no AI calls, no token cost.

| Event | Script | Purpose |
|---|---|---|
| `SessionStart` | `SessionStart.sh` | Restore from `sessions/recovery.md` if present; print last handoff |
| `PreToolUse` | `PreToolUse.sh` | Secret guard (block writes containing API keys); confirm destructive ops |
| `PostToolUse` | `PostToolUse.sh` | Append tool name + summary to `sessions/current.md`; bump auto-save counter |
| `PreCompact` | `PreCompact.sh` | Write `sessions/recovery.md` (in-progress state) before context compact |
| `Stop` | `Stop.sh` | Write `sessions/handoff-YYYY-MM-DD.md` with full session summary |

Hooks are gated by `HOOKS_DISABLED=1` (env var) for debugging.

---

## 6. Slash commands

9 commands under the `/aips:*` namespace. All are user-facing and idempotent.

| Command | Purpose |
|---|---|
| `/aips:init` | Auto-detect project state (fresh / v5.x / v6.0 / repair) and run correct path |
| `/aips:health` | Run `lib/verify-init.sh` + dependency plugin checks |
| `/aips:status` | Print `WORK_STATUS.md` "In Progress" + last 10 PostToolUse entries |
| `/aips:repair` | Rebuild missing symlinks / template files / .gitignore block |
| `/aips:reset` | Wipe `.priv-storage/sessions/*` (keeps memory + work status) |
| `/aips:update` | Refresh global plugin (`/plugin update AIPS@AIPS`) |
| `/aips:upgrade` | Run `lib/render-claude-md.sh` again with newest template |
| `/aips:migrate-from-md` | Force run `lib/migrate-from-md.sh` (manual entry) |
| `/aips:uninstall` | Remove project AIPS footprint (symlinks + `.priv-storage/`) |

Each command file is a thin wrapper that invokes the matching `lib/*.sh` script with appropriate args.

---

## 7. Global vs per-project split

A key v6.0 design decision: split rules between the global `~/.claude/CLAUDE.md` and the per-project `.priv-storage/CLAUDE.md`.

| Section | Global (`~/.claude/CLAUDE.md`) | Per-project (`.priv-storage/CLAUDE.md`) |
|---|---|---|
| 1. Project Identity | — | yes |
| 2. Core Design Goals | — | yes |
| 3. Project Structure | — | yes |
| 4. Coding Conventions | — | yes |
| 5. Build & Verification | — | yes |
| 6. Dependencies Policy | — | yes |
| 7. Git Workflow | — | yes (project-specific bits) |
| 8. AI Config Storage | yes (canonical layout) | — |
| 9. Work Status Tracking | yes (protocol) | — |
| 10. Memory System | yes (categories, save protocol) | — |
| 11. Agent Teams | — | yes (project-specific roster) |
| 12. Resilience | yes (hook contract) | — |
| 13. Token Efficiency | yes (Σ formula, caveman/RTK) | — |

The migration script (`lib/migrate-from-md.sh`) automates this slim-down: it preserves Sections 1-7 + 11 from a v5.x `CLAUDE.md` and deletes 8/9/10/12/13, leaving a comment pointing at the global file.

---

## 8. AgentMemory systemd service

`lib/setup-agentmemory-service.sh` installs a **user-level** systemd service (`~/.config/systemd/user/agentmemory.service`) that runs `npx -y @agentmemory/agentmemory` on ports 3111 (MCP) and 3113 (web viewer).

Design notes:
- **No sudo**: pure `systemctl --user`. Optional `loginctl enable-linger` is *suggested* but never invoked.
- **Idempotent**: short-circuits if `is-active` already returns true.
- **Linux-only**: macOS prints a skip message (users run `npx` manually).
- **First-install banner**: bilingual (EN + KR) 4-step guide printed once. Suppressed by `~/.config/aips/.agentmemory-first-install-shown`.
- **Health poll**: up to 10 s after enable; warns (not fails) if not responding (cold-start latency).

---

## 9. Statusline (3-line format)

When `agentmemory` and `caveman` are present, the Claude Code statusline shows:

```
line 1:   <model> · <branch> · <token-used>/<token-budget>
line 2:   memory: <session-count> sessions · <obs-count> obs · last: <topic>
line 3:   caveman: <intensity> · RTK: <savings-%> · Σ: <cumulative-savings>
```

Implementation lives in the `caveman` plugin's statusline hook; AIPS only ensures it is installed.

---

## 10. Dependency plugin integration

AIPS does not vendor its dependencies — it installs them through their own marketplaces.

| Plugin | Source | Purpose |
|---|---|---|
| `openai-codex` | `openai/codex-plugin-cc` | Bridge to Codex CLI for second-opinion code review |
| `caveman` | `JuliusBrussee/caveman` | Token-compressed I/O modes + subagents |
| `agentmemory` | `rohitg00/agentmemory.git` | Persistent cross-session memory via MCP |
| `RTK` | `rtk-ai/rtk` (curl install) | Rust CLI proxy that rewrites dev commands for 60-90% token savings |

Each is installed as a *separate* plugin so users can opt out (`install.sh --with codex,caveman` skips agentmemory and rtk).

---

## 11. Token discipline

Three mechanisms combine to reduce token spend:

1. **caveman mode** — compresses model output ~75% while preserving technical accuracy. Auto-triggered by "be brief" or `/caveman`.
2. **RTK proxy** — rewrites `git status`, `npm install`, etc. through a Rust CLI that filters noise before it reaches the model. 60-90% savings per command.
3. **Σ cumulative formula** — statusline shows running savings: `Σ = caveman_saved + RTK_saved`. Visible feedback motivates continued use.

The per-project `.priv-storage/CLAUDE.md` Section 13 (when present in v5.x) is *deleted* in v6.0 because all three rules now live globally in `~/.claude/CLAUDE.md`.

---

## 12. v5.x → v6.0 migration

`/aips:init` auto-detects v5.x by looking for `.priv-storage/AI_PROJECT_SETUP.md` or `.priv-storage/.claude/commands/codex-brief.md`. When found, it offers `lib/migrate-from-md.sh`:

1. Print REMOVE / EDIT / PRESERVE plan.
2. Prompt `Proceed? [Y/n]`.
3. Backup all of `.priv-storage/` + relay scripts → `tmp-igbkp/migrate-backup-{TS}/`.
4. Remove v5.x-only artifacts (codex-relay, v5 hooks/skills, v5 commands, `AI_PROJECT_SETUP.md`).
5. Trim `.priv-storage/CLAUDE.md` to Sections 1-7 + 11.
6. Write `.priv-storage/.aips-version` = `6.0` as marker.
7. Re-run `lib/verify-init.sh` for PASS/FAIL.

Rollback path: restore `tmp-igbkp/migrate-backup-{TS}/priv-storage` over `.priv-storage/`.

See [`MIGRATION-FROM-MD.md`](./MIGRATION-FROM-MD.md) for the user walkthrough.

---

## 13. Roadmap

**v6.1** (planned):
- Codex / Cursor parity surfacing — generate equivalent slash-commands as plain markdown so non-Claude tools get the same UX.
- `/aips:doctor` — deeper diagnostics (hook log analysis, memory token usage).
- Windows native (PowerShell) port of `lib/*.sh`.

**v7.0** (speculative):
- Move template rendering into a small native binary (eliminate `sed`/`awk` portability quirks).
- Marketplace listing on the official Claude Code public registry.
- Multi-language project templates (currently English; Korean exists in `docs/ko/`).

---

## 14. References

- Project conventions: [`.priv-storage/CLAUDE.md`](../.priv-storage/CLAUDE.md)
- User-facing README: [`README.md`](../README.md)
- Migration walkthrough: [`MIGRATION-FROM-MD.md`](./MIGRATION-FROM-MD.md)
- Korean mirror: [`ko/ARCHITECTURE.md`](./ko/ARCHITECTURE.md)
