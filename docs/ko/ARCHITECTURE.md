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

## 13. Roadmap

**v6.1** (계획):
- Codex / Cursor parity — non-Claude 도구도 동일 UX 갖도록 등가 slash command 를 plain markdown 으로 생성.
- `/aips:doctor` — 심층 진단 (hook log 분석, memory token 사용량).
- Windows native (PowerShell) `lib/*.sh` 포팅.

**v7.0** (구상):
- template rendering 을 작은 native binary 로 이동 (`sed`/`awk` portability 이슈 제거).
- 공식 Claude Code public registry marketplace 등록.
- 다국어 project template (현재 영어; 한국어는 `docs/ko/` 존재).

---

## 14. 참고

- 프로젝트 규칙: [`.priv-storage/CLAUDE.md`](../../.priv-storage/CLAUDE.md)
- 사용자 README: [`README.ko.md`](../README.ko.md)
- Migration walkthrough: [`MIGRATION-FROM-MD.md`](./MIGRATION-FROM-MD.md)
- 영문 원본: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
