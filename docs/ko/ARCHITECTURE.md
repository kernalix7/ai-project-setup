# AIPS v6.0 — 아키텍처

본 문서는 **AI Project Setup (AIPS) v6.0**의 내부 아키텍처를 설명합니다. installer, plugin, hooks, slash commands, templates, 그리고 dependency plugin이 어떻게 조합되어 모든 AI 코딩 프로젝트의 원-커맨드 부트스트랩을 구성하는지 다룹니다.

사용자 안내는 [`README.ko.md`](../README.ko.md), 프로젝트 규칙은 [`.priv-storage/CLAUDE.md`](../../.priv-storage/CLAUDE.md)를 참고하세요. 영문 원본은 [`../ARCHITECTURE.md`](../ARCHITECTURE.md).

---

## 1. 배포 모델

AIPS v5.x는 7,600줄짜리 markdown 파일 (`AI_PROJECT_SETUP.md`) 하나를 AI 도구가 *읽고 단계별로 실행*하는 방식이었습니다. v6.0은 이를 **Claude Code plugin** 방식으로 교체합니다. 표준 `/plugin marketplace` 메커니즘으로 배포되고, 최초 wiring만 얇은 `install.sh`가 담당합니다.

| 측면 | v5.x | v6.0 |
|---|---|---|
| 산출물 | markdown 파일 1개 | plugin (commands + hooks + templates) + install.sh |
| 도구 인터페이스 | AI가 markdown 읽기 | native slash command (`/aips:init`, `/aips:health`, …) |
| 업데이트 | raw URL 재-fetch + 재실행 | `/plugin update AIPS@AIPS` |
| 멀티 도구 | 도구별 재실행 | Claude Code 우선; AGENTS.md / .cursorrules 가 Codex / Cursor 구동 |
| 토큰 비용 | 재읽기당 ~25k 토큰 | ~0 (plugin metadata, lazy-load) |

---

## 2. 리포지토리 구조

```
ai-project-setup/
├── .claude-plugin/                  ← plugin manifest
│   ├── plugin.json                  (name, version, hooks, commands)
│   └── marketplace.json             (이 repo 자체가 marketplace 일 때)
├── install.sh                       ← user-level installer (no sudo)
├── lib/                             ← command 들이 호출하는 runtime helper
│   ├── detect-project.sh
│   ├── render-claude-md.sh
│   ├── setup-agentmemory-service.sh
│   ├── verify-init.sh
│   └── migrate-from-md.sh
├── hooks/                           ← 결정적 shell hook
│   ├── hooks.json
│   ├── SessionStart.sh
│   ├── PreToolUse.sh
│   ├── PostToolUse.sh
│   ├── PreCompact.sh
│   └── Stop.sh
├── commands/                        ← /aips:* slash command (9개)
├── agents/                          ← agent role 정의
├── templates/                       ← init 시 복사되는 project template
│   ├── CLAUDE.md.tmpl
│   ├── WORK_STATUS.md.tmpl
│   ├── memory/
│   └── tmp-igbkp/                   (toolkit script 9개)
├── docs/                            ← architecture, migration, ko/
└── README.md, LICENSE, CHANGELOG.md
```

프로젝트별 생성 구조는 [`.priv-storage/CLAUDE.md`](../../.priv-storage/CLAUDE.md) Section 3 참조.

---

## 3. `install.sh` 흐름

`install.sh`는 globally 실행되는 유일한 script. idempotent, sudo 불필요, 순수 user-level.

```
A. Pre-flight       → bash >= 4, git, curl, node >= 18.18 (--with agentmemory 시), claude CLI 확인
B. Marketplace add  → /plugin marketplace add kernalix7/AIPS
C. AIPS install     → /plugin install AIPS@AIPS  (있으면 update)
D. Dep plugins      → codex@openai-codex, caveman@caveman, agentmemory@agentmemory  (--with 에 따라)
D'. RTK             → curl install.sh | sh  (--with rtk + 없을 때)
E. agentmemory svc  → bash lib/setup-agentmemory-service.sh  (Linux 전용)
```

플래그:
- `--no-plugin-update` — 이미 설치된 plugin update 생략 (오프라인 모드).
- `--with codex,caveman,agentmemory,rtk` — dep 콤마 목록. 기본 = 전체.
- `--local-source <path>` — GitHub 대신 로컬 clone 사용 (개발용).
- `--dry-run` — 실행 없이 액션만 출력.

---

## 4. Plugin manifest

`.claude-plugin/plugin.json` 선언 내용:

```json
{
  "name": "AIPS",
  "version": "6.0.0",
  "hooks": "hooks/hooks.json",
  "commands": "commands/",
  "agents": "agents/"
}
```

`.claude-plugin/marketplace.json` 덕분에 이 repo 자체를 `/plugin marketplace add kernalix7/AIPS` 로 등록 가능 — 즉 AIPS는 single-plugin marketplace 입니다.

Claude Code 가 install 시점에 manifest 를 resolve 하고, command / hook 은 lazy-load. `lib/`, `templates/`, `docs/` 의 바이트는 command 가 명시적으로 cat 하지 않는 한 model context 로 들어가지 않습니다.

---

## 5. Hooks registry

`hooks/hooks.json`에 결정적 shell script 5개 등록. 모두 사용자 권한 실행, AI 호출 없음, 토큰 비용 0.

| 이벤트 | Script | 역할 |
|---|---|---|
| `SessionStart` | `SessionStart.sh` | `sessions/recovery.md` 있으면 복원; 최근 handoff 출력 |
| `PreToolUse` | `PreToolUse.sh` | Secret guard (API key 포함 write 차단); 파괴적 op 확인 |
| `PostToolUse` | `PostToolUse.sh` | tool name + 요약을 `sessions/current.md` 에 append; auto-save 카운터 |
| `PreCompact` | `PreCompact.sh` | context compact 직전 `sessions/recovery.md` 작성 |
| `Stop` | `Stop.sh` | 세션 종료 시 `sessions/handoff-YYYY-MM-DD.md` 작성 |

`HOOKS_DISABLED=1` (env) 로 디버깅 시 비활성.

---

## 6. Slash commands

`/aips:*` namespace 9개. 모두 사용자 노출, idempotent.

| Command | 역할 |
|---|---|
| `/aips:init` | 프로젝트 상태 자동 감지 (fresh / v5.x / v6.0 / repair) 후 적절 경로 실행 |
| `/aips:health` | `lib/verify-init.sh` + dependency plugin 점검 |
| `/aips:status` | `WORK_STATUS.md` "In Progress" + 최근 PostToolUse 10건 출력 |
| `/aips:repair` | 누락 symlink / template / .gitignore block 재구성 |
| `/aips:reset` | `.priv-storage/sessions/*` wipe (memory + work status 유지) |
| `/aips:update` | global plugin refresh (`/plugin update AIPS@AIPS`) |
| `/aips:upgrade` | 최신 template 로 `lib/render-claude-md.sh` 재실행 |
| `/aips:migrate-from-md` | `lib/migrate-from-md.sh` 수동 실행 |
| `/aips:uninstall` | 프로젝트 AIPS footprint 제거 (symlink + `.priv-storage/`) |

각 command 파일은 해당 `lib/*.sh` 를 적절한 arg 로 호출하는 얇은 wrapper.

---

## 7. Global vs Per-project 분리

v6.0의 핵심 설계 결정: rule 을 global `~/.claude/CLAUDE.md` 과 per-project `.priv-storage/CLAUDE.md` 로 분리.

| Section | Global (`~/.claude/CLAUDE.md`) | Per-project (`.priv-storage/CLAUDE.md`) |
|---|---|---|
| 1. Project Identity | — | O |
| 2. Core Design Goals | — | O |
| 3. Project Structure | — | O |
| 4. Coding Conventions | — | O |
| 5. Build & Verification | — | O |
| 6. Dependencies Policy | — | O |
| 7. Git Workflow | — | O (프로젝트 고유 부분) |
| 8. AI Config Storage | O (canonical layout) | — |
| 9. Work Status Tracking | O (protocol) | — |
| 10. Memory System | O (categories, save protocol) | — |
| 11. Agent Teams | — | O (프로젝트 고유 roster) |
| 12. Resilience | O (hook 계약) | — |
| 13. Token Efficiency | O (Σ 공식, caveman/RTK) | — |

migration script (`lib/migrate-from-md.sh`)가 이 슬림화를 자동화: v5.x `CLAUDE.md` 의 Section 1-7 + 11 보존, 8/9/10/12/13 삭제, global 참조 코멘트 삽입.

---

## 8. AgentMemory systemd service

`lib/setup-agentmemory-service.sh`가 **user-level** systemd service (`~/.config/systemd/user/agentmemory.service`)를 설치. `npx -y @agentmemory/agentmemory`를 port 3111 (MCP), 3113 (web viewer)에서 실행.

설계 노트:
- **sudo 없음**: 순수 `systemctl --user`. `loginctl enable-linger`는 *제안*만 하고 자동 호출하지 않음.
- **Idempotent**: `is-active` 이미 true면 short-circuit.
- **Linux 전용**: macOS는 skip 메시지 출력 (사용자가 `npx` 직접 실행).
- **첫 설치 배너**: 이중언어 (EN + KR) 4단계 안내. `~/.config/aips/.agentmemory-first-install-shown` 으로 1회만 표시.
- **Health poll**: enable 후 최대 10초. 미응답 시 warn (fail 아님, cold-start latency 고려).

---

## 9. Statusline (3-line format)

`agentmemory` + `caveman` 설치 시 Claude Code statusline 표시:

```
line 1:   <model> · <branch> · <token-used>/<token-budget>
line 2:   memory: <session-count> sessions · <obs-count> obs · last: <topic>
line 3:   caveman: <intensity> · RTK: <savings-%> · Σ: <cumulative-savings>
```

구현은 `caveman` plugin 의 statusline hook; AIPS는 설치 여부만 보장.

---

## 10. Dependency plugin 통합

AIPS는 dependency 를 vendor 하지 않고 각자의 marketplace 를 통해 설치.

| Plugin | Source | 역할 |
|---|---|---|
| `openai-codex` | `openai/codex-plugin-cc` | Codex CLI bridge — second-opinion code review |
| `caveman` | `JuliusBrussee/caveman` | 토큰 압축 I/O mode + subagent |
| `agentmemory` | `rohitg00/agentmemory.git` | MCP 기반 cross-session persistent memory |
| `RTK` | `rtk-ai/rtk` (curl install) | dev command 를 rewrite 하는 Rust CLI proxy, 60-90% 토큰 절감 |

각각 *별개* plugin 이라 opt-out 가능 (`install.sh --with codex,caveman` 시 agentmemory + rtk skip).

---

## 11. Token discipline

토큰 절감 3가지 메커니즘:

1. **caveman mode** — 기술적 정확성 유지하면서 모델 output ~75% 압축. "be brief" / `/caveman` 으로 auto-trigger.
2. **RTK proxy** — `git status`, `npm install` 등을 Rust CLI 통해 rewrite, noise 필터링 후 모델에 전달. command 당 60-90% 절감.
3. **Σ 누적 공식** — statusline 에 누적 절감 표시: `Σ = caveman_saved + RTK_saved`. 가시 피드백으로 사용 동기부여.

v5.x 의 per-project Section 13은 v6.0 에서 *삭제* — 위 3가지 rule 이 모두 global `~/.claude/CLAUDE.md` 로 이동.

---

## 12. v5.x → v6.0 migration

`/aips:init`가 `.priv-storage/AI_PROJECT_SETUP.md` 또는 `.priv-storage/.claude/commands/codex-brief.md` 로 v5.x 자동 감지. 발견 시 `lib/migrate-from-md.sh` 제안:

1. REMOVE / EDIT / PRESERVE 계획 출력.
2. `Proceed? [Y/n]` prompt.
3. `.priv-storage/` + relay script 전체 backup → `tmp-igbkp/migrate-backup-{TS}/`.
4. v5.x 전용 artifact 제거 (codex-relay, v5 hook/skill, v5 command, `AI_PROJECT_SETUP.md`).
5. `.priv-storage/CLAUDE.md` 를 Section 1-7 + 11 로 trim.
6. `.priv-storage/.aips-version` = `6.0` marker 작성.
7. `lib/verify-init.sh` 재실행 (PASS/FAIL).

Rollback: `tmp-igbkp/migrate-backup-{TS}/priv-storage` 를 `.priv-storage/` 위에 복구.

사용자 walkthrough: [`MIGRATION-FROM-MD.md`](./MIGRATION-FROM-MD.md).

---

## 13. v7.0 하이브리드 글로벌-우선 아키텍처

v6.0 은 모든 toolkit script, session log, memory 파일, gitignore block 을 **프로젝트별로** 배포합니다. 이는 portability 를 보장하지만 3가지 비용이 따릅니다: N개 프로젝트에 걸친 디스크 중복, toolkit script 패치 시 수동 동기화 필요, 그리고 session state 의 cross-machine 재개 불가. v7.0 은 정말 중요한 per-project 보장 (multi-tool rule 파일, team-shared work status, project-specific MCP server) 은 유지하면서, 공유해도 안전한 부분만 **선택적으로 globalize** 합니다.

artifact 를 globalize 할 수 있는 판단 기준: (1) multi-tool parity 를 깨지 않아야 하고 (Codex / Cursor / Copilot 가 여전히 project-local rule 파일을 읽을 수 있어야 함), (2) per-project privacy 위험이 없어야 하고, (3) team-shared git surface 의 일부가 아니어야 함. 이 3가지 중 하나라도 실패하면 per-project 유지. 따라서 v7.0 은 **additive** — v6.0 layout 은 변경 없이 계속 동작하고, migration 은 opt-in.

### 13.1 globalize 4개 + per-project 보존 5개

| 항목 | v6.0 | v7.0 | 근거 |
|---|---|---|---|
| `tmp-igbkp/` scripts | per-project | `~/.local/bin/aips-*` | 디스크 dedup, update 전파 |
| `sessions/` logs | per-project | `~/.claude/sessions/{path-hash}/` mirror (local fast-write buffer 유지) | Cross-machine 재개 |
| `memory/` 파일 | per-project + dual-write | global only (`~/.claude/projects/{path-encoded}/memory/`) | Dual-write 검증 완료; local copy 중복 |
| `.gitignore` AIPS block | per-project | `~/.config/git/ignore` | 단일 source; 모든 repo 가 상속 |
| **Per-project 보존** | | | |
| `CLAUDE.md` Section 1-7 + 11 | per-project | per-project | Multi-tool 보장 (Codex / Cursor / Copilot 이 프로젝트 파일 읽음) |
| `WORK_STATUS.md` | per-project | per-project | repo 안에서 team-shared |
| `.mcp.json` | per-project | per-project | 프로젝트별 MCP server |
| `tech-lead.md` + team agent | per-project | per-project | 프로젝트별 customized team table |
| `tmp-igbkp/` backup 결과물 | per-project | per-project | repo 범위 encrypted snapshot |

### 13.2 path-hash 규약

global 디렉토리에서 per-project state 를 주소 지정하는 데 2가지 인코딩 사용:

- `path-hash` = `md5sum <(echo "$PROJECT_ROOT")` 의 앞 12자 — `~/.claude/sessions/{path-hash}/` 에서 사용.
- `path-encoded` = `$PROJECT_ROOT` 의 `/` → `-` 치환 — `~/.claude/projects/{path-encoded}/memory/` 에서 사용.

프로젝트를 옮기거나 이름 변경하면 global state 가 orphaned 상태가 됩니다 (경로가 더 이상 같은 값으로 hash 되지 않음). 해결책은 `/aips:rebind <old-path>` — orphaned global directory 를 현재 `$PROJECT_ROOT` 로 재-pointing.

### 13.3 `lib/` 스크립트 (v7.0) — 신규 6개 + 수정 1개

- `lib/globalize-toolkit.sh` — toolkit script 를 `~/.local/bin/aips-*` 로 symlink.
- `lib/setup-global-gitignore.sh` — AIPS block 을 `~/.config/git/ignore` 에 설치.
- `lib/backup-global-memory.sh` — `archive.sh` 를 확장해 global memory 디렉토리 커버.
- `lib/upgrade-to-v7.sh` — v6.0 → v7.0 migration, backup + rollback 포함.
- `lib/rebind.sh` — move/rename 후 orphaned global state 재-pointing.
- `lib/scope.sh` — 4-column 표 (item · location · scope · status) 출력 진단.
- `lib/verify-init.sh` *(수정)* — Section 10 v7.0 dual-write health check 추가.

### 13.4 신규 slash command

| Command | 역할 |
|---|---|
| `/aips:upgrade --to v7.0` | 기존 `/aips:upgrade` 확장 — v6.0 → v7.0 migration 수행 |
| `/aips:rebind <old-path>` | move/rename 후 orphaned global state 를 현재 `$PROJECT_ROOT` 로 재-bind |
| `/aips:scope` | 진단 — 현재 프로젝트의 4-column scope table 출력 |

### 13.5 Hook 변경사항

- `PostToolUse` / `PreCompact` / `Stop` / `SessionStart` 가 이제 local `.priv-storage/sessions/` buffer **와 병행하여** `~/.claude/sessions/{path-hash}/` 에 write.
- Mirror write 는 `flock` 으로 가드 — 두 프로젝트가 같은 `path-hash` 로 hash 될 때 collision 방지.
- `SessionStart` 는 resume 시 local copy 보다 global mirror 를 우선; global 디렉토리가 없거나 stale 이면 local 로 fallback.

### 13.6 내장 mitigation

- **프로젝트 move/rename** → `/aips:rebind <old-path>` 로 orphaned global state 재-pointing.
- **Global memory backup** → `archive.sh` 가 `~/.claude/projects/{path-encoded}/memory/` 까지 커버.
- **Per-project gitignore override** → `!pattern` 으로 global block 의 항목 unignore 가능.
- **Cross-project hook 오염** → hook 이 global write 전에 엄격히 `PROJECT_ROOT` lock.
- **Privacy** → per-project `BLOCKLIST` 준수; `agentmemory` MCP 를 프로젝트별로 정지 가능.

### 13.7 호환성

- **Non-breaking** — v6.0 setup 은 변경 없이 그대로 동작.
- v7.0 migration 은 `/aips:upgrade --to v7.0` 으로 **opt-in**.
- v6.0 → v7.0 migration 은 backup 포함 ~10-30초 소요.
- **Rollback** — `tmp-igbkp/upgrade-v7-backup-{ts}/` 에서 복구.

---

## 14. Roadmap

**v6.1** (계획):
- Codex / Cursor parity — non-Claude 도구도 동일 UX 갖도록 등가 slash command 를 plain markdown 으로 생성.
- `/aips:doctor` — 심층 진단 (hook log 분석, memory token 사용량).
- Windows native (PowerShell) `lib/*.sh` 포팅.

**v7.x** (post-hybrid):
- template rendering 을 작은 native binary 로 이동 (`sed`/`awk` portability 이슈 제거).
- 공식 Claude Code public registry marketplace 등록.
- 다국어 project template (현재 영어; 한국어는 `docs/ko/` 존재).

---

## 15. 참고

- 프로젝트 규칙: [`.priv-storage/CLAUDE.md`](../../.priv-storage/CLAUDE.md)
- 사용자 README: [`README.ko.md`](../README.ko.md)
- Migration walkthrough: [`MIGRATION-FROM-MD.md`](./MIGRATION-FROM-MD.md)
- 영문 원본: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
