# Changelog

**English** | [한국어](docs/CHANGELOG.ko.md)

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v7.0 — Unreleased] — 2026-05-19

**Hybrid Global-First architecture.** Non-breaking — v6.0 setups continue
working; v7.0 migration is opt-in via `/aips:upgrade --to v7.0`.

### Added
- `lib/globalize-toolkit.sh` — symlinks `templates/tmp-igbkp/*.sh` to
  `~/.local/bin/aips-*` (idempotent, `--dry-run` / `--unlink` flags).
- `lib/setup-global-gitignore.sh` — installs AIPS gitignore block at
  global `~/.config/git/ignore` (sets `core.excludesfile` if unset).
- `lib/backup-global-memory.sh` — appends `~/.claude/projects/
  {path-encoded}/memory/` to encrypted backup tarball.
- `lib/upgrade-to-v7.sh` — v6.0 → v7.0 migration with backup to
  `tmp-igbkp/upgrade-v7-backup-{ts}/`. Calls P1/P4/P6 helpers when
  available, gracefully skips when absent.
- `lib/rebind.sh` — rebinds globalized state when project path
  changes (old → new path-hash, agentmemory metadata best-effort).
- `lib/scope.sh` — diagnostic table of globalized vs per-project
  files for the current project (includes legacy v6.0 warnings).
- Slash commands: `/aips:rebind <old-path>`, `/aips:scope`,
  extended `/aips:upgrade --to v7.0`.
- Hook-level session global mirror: PostToolUse / PreCompact / Stop
  / SessionStart now write to `~/.claude/sessions/{path-hash}/`
  in addition to local `.priv-storage/sessions/`. SessionStart
  prefers global on resume. flock-guarded writes.
- `templates/tmp-igbkp/archive.sh` weaves global memory into tar
  staging; `restore.sh` extracts global memory back on restore.
- `lib/verify-init.sh` Section 10: v7.0 dual-write health checks
  (local-memory deprecation, global memory presence, helper
  availability).
- `install.sh` step F: calls globalize-toolkit.sh after agentmemory
  setup. Banner updated to v7.0.

### Changed
- `templates/.gitignore.patch` slimmed from full AIPS block to 6-line
  per-project override stub. Standard ignores moved to global git
  excludes file.
- `templates/CLAUDE.md.tmpl` v7.0 header note: Section 8/9/10/12/13
  inherit from global `~/.claude/CLAUDE.md`. Upgrade-path comment
  pointing v6.0 users to `/aips:upgrade --to v7.0`.

### Hybrid split (final v7.0)
**Globalized (4):**
- tmp-igbkp/ toolkit scripts (`~/.local/bin/aips-*`)
- sessions/ logs (`~/.claude/sessions/{path-hash}/`)
- memory/ files (`~/.claude/projects/{path-encoded}/memory/`)
- .gitignore AIPS block (`~/.config/git/ignore`)

**Preserved per-project (5):**
- CLAUDE.md Section 1-7 + 11 (multi-tool guarantee)
- WORK_STATUS.md (team-shared state)
- .mcp.json (project-specific MCP servers)
- tech-lead.md + team agents (project-customized)
- tmp-igbkp/ encrypted backup outputs (repo-scoped snapshots)

### Migration
- From v6.0: `/aips:upgrade --to v7.0` — single confirm, full
  backup to `tmp-igbkp/upgrade-v7-backup-{ts}/`. Idempotent.
- **Strict mode default**: upgraded project ends up identical to a
  fresh v7.0 install. Per-project `tmp-igbkp/*.sh` deleted after
  `~/.local/bin/aips-*` symlinks verified; `.priv-storage/sessions/
  *.md` cleared after global mirror at
  `~/.claude/sessions/{path-hash}/` confirmed.
- Pass `--keep-local-fallback` to retain both as fallback (lenient,
  v7.0 pre-strict behavior).
- Project rename / move: `/aips:rebind <old-path>` rebinds
  globalized state.
- Diagnose any project: `/aips:scope` (4-col table + legacy v6.0
  warnings + summary stats).

### Why v7.0 (not v6.1)
- New cross-project state convention (path-hash key) requires
  coordinated rollout.
- Removes per-project tmp-igbkp/ script duplication (~120 KB / project).
- Cuts per-project disk footprint roughly 4x for installed-tool state.
- Multi-tool parity (Codex/Cursor/Copilot) preserved unchanged.

## [v6.0 — Unreleased] — 2026-05-19

**BREAKING: AIPS becomes a Claude Code plugin.**

### Added
- One-liner global install: `curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/install.sh | bash`
- 9 slash commands: `/aips:{init,update,health,uninstall,status,migrate-from-md,upgrade,repair,reset}`
- 4 bundled dependency plugins installed by install.sh:
  - `codex-plugin-cc` (openai/codex-plugin-cc) — Claude ↔ Codex official integration
  - `caveman` (JuliusBrussee/caveman) — ultra-compressed communication mode
  - `agentmemory` (rohitg00/agentmemory) — persistent tool-use memory + web viewer (port 3113)
  - `RTK` (rtk-ai/rtk) — token-saving CLI proxy
- `agentmemory.service` — systemd user service (Linux), runs npx server on 127.0.0.1:3111+3113
- agentmemory first-install bilingual setup guide (printed once, marker `.first-install-shown`)
- Statusline v6.0 (3-line layout):
  - Line 1: `project [branch*N] wip:M | model | ctx:X%(used/max) | cache:Y%`
  - Line 2: `5h:X% ↻reset_eta ∅empty_eta | wk:X% ↻reset_eta ∅empty_eta`
  - Line 3: `🦴cv:S%/level | 🧠am:S%/N | 💰rtk:S% | 🤖cdx:S%/Nruns | 💯Σ:S%`
- `/aips:init` 4-way auto-detect: fresh / v5.x migrate / re-init / repair
- `/aips:migrate-from-md` — clean removal of v5.x footprint, backup to `tmp-igbkp/migrate-backup-{ts}/`

### Changed
- Repo renamed: `kernalix7/ai-project-setup` → `kernalix7/AIPS`. GitHub redirect keeps old URL alive.
- Global vs per-project split:
  - GLOBAL `~/.claude/`: hooks, agents (3 templates), commands (default 6 + new aips-* 9), skills, output-styles, statusline, plugin deps
  - PER-PROJECT `.priv-storage/`: CLAUDE.md (Section 1-7+11 only, ~150 lines from former 13-section ~600 lines), WORK_STATUS.md, memory/, sessions/, tech-lead.md, team agents, .mcp.json, tmp-igbkp/ (9 toolkit scripts, codex-relay-* removed)
- Per-project setup: from ~3 min (read+execute 7600-line md) to ~30s (`/aips:init`)
- CLAUDE.md Sections 8/9/10/12/13 (template boilerplate) → global ref 1 line each in per-project CLAUDE.md
- v5.x → v6.0 update path: any project that runs `/aips:init` auto-detects v5.x install and offers 1-confirm migration

### Support Matrix
- **Tier 1 — Primary / Full**: Claude Code (CLI) — full plugin, 9 `/aips:*` slash commands, 5 hooks, statusline, 4 dep plugins (codex-plugin-cc, caveman, agentmemory, RTK).
- **Tier 2 — Partial (policy-only)**: ChatGPT Codex CLI, Cursor, GitHub Copilot, claude.ai (web), MCP-aware tools — read CLAUDE.md / AGENTS.md / .cursorrules rules only; no hooks, no slash commands, no statusline.
- **Tier 3 — Full support TBD**: full plugin-like parity for Codex / Cursor / Copilot is roadmap, no ETA.

### Removed
- `AI_PROJECT_SETUP.md` (7,600-line bootstrap) → reduced to 30-line DEPRECATED redirect page
- Custom Codex Implementation Relay (v4.9 / v5.0):
  - Slash commands: `/codex-brief`, `/codex-review`, `/codex-fix`, `/codex-relay-status`
  - Scripts: `tmp-igbkp/codex-relay-check.sh`, `tmp-igbkp/codex-relay-run.sh`
  - CLAUDE.md Section 11 Path A-2, A-3
  - CLAUDE.md Section 13 Codex Implementation Relay paragraph
  - Runtime artifacts: `.priv-storage/sessions/{codex-brief,codex-report,claude-review}.md`, `codex-relay/`
- Replaced by codex-plugin-cc's `/codex:exec`, `/codex:review`, `/codex:status`

### Migration
- From v5.x: install v6.0 globally (`curl install.sh | bash`), then in each project run `/aips:init` — auto-detects v5.x install, prompts once for confirmation, backs up to `tmp-igbkp/migrate-backup-{date}/`, then cleans + globalizes.
- v5.x `/codex-*` workflows: switch to `/codex:exec`, `/codex:review` (codex-plugin-cc).
- Custom statusline: force-overwritten with v6.0 3-line layout. Backup auto-saved.

### Why v6.0 is breaking
- 7,600-line markdown → AI execution model retired
- Per-project setup commands changed entirely
- Codex relay workflow removed (replaced)
- File layout: significant per-project file removal

## [v5.2] - 2026-05-15

### Added
- Initial CHANGELOG.md, SECURITY.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md
- `.github/` issue and PR templates
- Expanded README.md with badges, lifecycle, feature matrix, FAQ, roadmap, and support links
- Korean documentation mirrors under `docs/`

### Notes
- Version history of `AI_PROJECT_SETUP.md` itself lives inside the artifact (see its Version History table). This changelog tracks repo-level changes outside the artifact.
