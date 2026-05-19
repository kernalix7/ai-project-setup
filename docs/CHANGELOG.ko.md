# 변경 이력

[English](../CHANGELOG.md) | **한국어**

이 파일은 프로젝트의 주요 변경 사항을 기록합니다.

형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)를 따르며, [Semantic Versioning](https://semver.org/lang/ko/)을 준수합니다.

## [v7.0 — Unreleased] — 2026-05-19

**Hybrid Global-First 아키텍처.** Non-breaking — v6.0 설치는 그대로 작동하며,
v7.0 마이그레이션은 `/aips:upgrade --to v7.0`을 통한 opt-in 방식입니다.

### 추가
- `lib/globalize-toolkit.sh` — `templates/tmp-igbkp/*.sh`를
  `~/.local/bin/aips-*`로 symlink (idempotent, `--dry-run` / `--unlink`
  플래그).
- `lib/setup-global-gitignore.sh` — 글로벌 `~/.config/git/ignore`에
  AIPS gitignore 블록 설치 (`core.excludesfile` 미설정 시 설정).
- `lib/backup-global-memory.sh` — `~/.claude/projects/
  {path-encoded}/memory/`를 암호화 백업 tarball에 추가.
- `lib/upgrade-to-v7.sh` — v6.0 → v7.0 마이그레이션, `tmp-igbkp/
  upgrade-v7-backup-{ts}/`로 백업. P1/P4/P6 helper가 있으면 호출,
  없으면 graceful skip.
- `lib/rebind.sh` — 프로젝트 경로 변경 시 globalize된 상태를 rebind
  (old → new path-hash, agentmemory 메타데이터는 best-effort).
- `lib/scope.sh` — 현재 프로젝트의 globalize된 파일 vs per-project
  파일 진단 테이블 (legacy v6.0 경고 포함).
- Slash commands: `/aips:rebind <old-path>`, `/aips:scope`,
  확장된 `/aips:upgrade --to v7.0`.
- Hook 수준 세션 global mirror: PostToolUse / PreCompact / Stop /
  SessionStart가 로컬 `.priv-storage/sessions/`에 더해
  `~/.claude/sessions/{path-hash}/`에도 기록. SessionStart는 resume
  시 global을 우선. flock-guarded 쓰기.
- `templates/tmp-igbkp/archive.sh`가 global memory를 tar staging에
  포함; `restore.sh`가 복원 시 global memory를 다시 추출.
- `lib/verify-init.sh` Section 10: v7.0 dual-write 헬스 체크
  (local-memory deprecation, global memory 존재 여부, helper 가용성).
- `install.sh` step F: agentmemory 셋업 이후 globalize-toolkit.sh
  호출. 배너를 v7.0으로 업데이트.

### 변경
- `templates/.gitignore.patch`를 전체 AIPS 블록에서 6줄 per-project
  override stub으로 축소. 표준 ignore는 global git excludes 파일로
  이동.
- `templates/CLAUDE.md.tmpl` v7.0 헤더 노트: Section 8/9/10/12/13은
  글로벌 `~/.claude/CLAUDE.md`로부터 상속. v6.0 사용자를
  `/aips:upgrade --to v7.0`으로 안내하는 업그레이드 경로 주석 추가.

### Hybrid 분리 (v7.0 최종)
**Globalize (4):**
- tmp-igbkp/ toolkit scripts (`~/.local/bin/aips-*`)
- sessions/ 로그 (`~/.claude/sessions/{path-hash}/`)
- memory/ 파일 (`~/.claude/projects/{path-encoded}/memory/`)
- .gitignore AIPS 블록 (`~/.config/git/ignore`)

**Per-project 유지 (5):**
- CLAUDE.md Section 1-7 + 11 (멀티툴 보장)
- WORK_STATUS.md (팀 공유 상태)
- .mcp.json (프로젝트별 MCP 서버)
- tech-lead.md + team agents (프로젝트 커스터마이즈)
- tmp-igbkp/ 암호화 백업 산출물 (저장소 단위 스냅샷)

### 마이그레이션
- v6.0에서: `/aips:upgrade --to v7.0` — 1회 확인, `tmp-igbkp/
  upgrade-v7-backup-{ts}/`로 전체 백업. Idempotent.
- **Strict 모드 기본**: 업그레이드된 프로젝트가 최초 v7.0 설치와
  동일한 상태로 됨. per-project `tmp-igbkp/*.sh`는 글로벌
  `~/.local/bin/aips-*` symlink 검증 후 삭제; `.priv-storage/
  sessions/*.md`는 글로벌 mirror (`~/.claude/sessions/{path-hash}/`)
  확인 후 비움.
- `--keep-local-fallback` 전달 시 fallback 유지 (lenient, v7.0
  pre-strict 동작).
- 프로젝트 이름 변경 / 이동: `/aips:rebind <old-path>`로 globalize된
  상태 rebind.
- 모든 프로젝트 진단: `/aips:scope` (4열 테이블 + legacy v6.0 경고
  + 요약 통계).

### 왜 v7.0인가 (v6.1 아닌)
- 새 cross-project 상태 규약 (path-hash key)이 조율된 롤아웃을
  요구.
- per-project tmp-igbkp/ script 중복 제거 (~120 KB / 프로젝트).
- 설치형 툴 상태에 대한 per-project 디스크 footprint를 약 4배 절감.
- 멀티툴 패리티 (Codex/Cursor/Copilot) 무변경 유지.

## [v6.0 — Unreleased] — 2026-05-19

**BREAKING: AIPS가 Claude Code plugin으로 전환됩니다.**

### 추가
- 원라이너 글로벌 설치: `curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/install.sh | bash`
- 9개 slash commands: `/aips:{init,update,health,uninstall,status,migrate-from-md,upgrade,repair,reset}`
- install.sh가 설치하는 4개 번들 의존 plugin:
  - `codex-plugin-cc` (openai/codex-plugin-cc) — Claude ↔ Codex 공식 통합
  - `caveman` (JuliusBrussee/caveman) — 초압축 커뮤니케이션 모드
  - `agentmemory` (rohitg00/agentmemory) — 영속 tool-use 메모리 + 웹 뷰어 (port 3113)
  - `RTK` (rtk-ai/rtk) — 토큰 절약 CLI 프록시
- `agentmemory.service` — systemd user service (Linux), npx 서버를 127.0.0.1:3111+3113에서 실행
- agentmemory 최초 설치 시 한/영 이중언어 셋업 가이드 (1회 표시, 마커 `.first-install-shown`)
- Statusline v6.0 (3줄 레이아웃):
  - Line 1: `project [branch*N] wip:M | model | ctx:X%(used/max) | cache:Y%`
  - Line 2: `5h:X% ↻reset_eta ∅empty_eta | wk:X% ↻reset_eta ∅empty_eta`
  - Line 3: `🦴cv:S%/level | 🧠am:S%/N | 💰rtk:S% | 🤖cdx:S%/Nruns | 💯Σ:S%`
- `/aips:init` 4-way 자동 감지: fresh / v5.x 마이그레이션 / re-init / repair
- `/aips:migrate-from-md` — v5.x 흔적 클린 제거, `tmp-igbkp/migrate-backup-{ts}/`로 백업

### 변경
- 저장소 이름 변경: `kernalix7/ai-project-setup` → `kernalix7/AIPS`. GitHub 리다이렉트로 기존 URL은 그대로 유지.
- 글로벌 vs 프로젝트별 분리:
  - GLOBAL `~/.claude/`: hooks, agents (3 템플릿), commands (기본 6개 + 신규 aips-* 9개), skills, output-styles, statusline, plugin 의존성
  - PER-PROJECT `.priv-storage/`: CLAUDE.md (Section 1-7+11만, 기존 13섹션 ~600줄에서 ~150줄로), WORK_STATUS.md, memory/, sessions/, tech-lead.md, team agents, .mcp.json, tmp-igbkp/ (toolkit script 9개, codex-relay-* 제거)
- 프로젝트별 셋업: ~3분 (7600줄 md 읽기+실행)에서 ~30초 (`/aips:init`)로 단축
- CLAUDE.md Sections 8/9/10/12/13 (템플릿 보일러플레이트) → 프로젝트별 CLAUDE.md에서 1줄 글로벌 참조로
- v5.x → v6.0 업데이트 경로: `/aips:init`을 실행하는 모든 프로젝트가 v5.x 설치를 자동 감지하고 1회 확인 마이그레이션 제공

### 지원 매트릭스
- **Tier 1 — 주 지원 / 완전**: Claude Code (CLI) — 플러그인 전체, 9개 `/aips:*` 슬래시 명령, 5개 hooks, statusline, 4개 dep plugin (codex-plugin-cc, caveman, agentmemory, RTK).
- **Tier 2 — 부분 지원 (정책만)**: ChatGPT Codex CLI, Cursor, GitHub Copilot, claude.ai (웹), MCP 지원 도구 — CLAUDE.md / AGENTS.md / .cursorrules 규칙만 읽음; hooks, 슬래시 명령, statusline 없음.
- **Tier 3 — 완전 지원 예정 (TBD)**: Codex / Cursor / Copilot 대상 플러그인 동급 패리티는 로드맵, ETA 미정.

### 제거
- `AI_PROJECT_SETUP.md` (7,600줄 부트스트랩) → 30줄 DEPRECATED 리다이렉트 페이지로 축소
- Custom Codex Implementation Relay (v4.9 / v5.0):
  - Slash commands: `/codex-brief`, `/codex-review`, `/codex-fix`, `/codex-relay-status`
  - Scripts: `tmp-igbkp/codex-relay-check.sh`, `tmp-igbkp/codex-relay-run.sh`
  - CLAUDE.md Section 11 Path A-2, A-3
  - CLAUDE.md Section 13 Codex Implementation Relay 단락
  - 런타임 산출물: `.priv-storage/sessions/{codex-brief,codex-report,claude-review}.md`, `codex-relay/`
- codex-plugin-cc의 `/codex:exec`, `/codex:review`, `/codex:status`로 대체

### 마이그레이션
- v5.x에서: v6.0을 글로벌 설치 (`curl install.sh | bash`), 각 프로젝트에서 `/aips:init` 실행 — v5.x 설치를 자동 감지, 1회 확인을 요청, `tmp-igbkp/migrate-backup-{date}/`로 백업 후 정리 + 글로벌화.
- v5.x `/codex-*` 워크플로: `/codex:exec`, `/codex:review` (codex-plugin-cc)로 전환.
- 커스텀 statusline: v6.0 3줄 레이아웃으로 강제 덮어쓰기. 백업 자동 저장.

### v6.0이 breaking인 이유
- 7,600줄 markdown → AI 실행 모델 폐기
- 프로젝트별 셋업 명령 전면 변경
- Codex relay 워크플로 제거 (대체됨)
- 파일 레이아웃: 프로젝트별 파일 대거 제거

## [v5.2] - 2026-05-15

### 추가
- 초기 CHANGELOG.md, SECURITY.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md
- `.github/` 이슈/PR 템플릿
- 배지, 라이프사이클, 기능 매트릭스, FAQ, 로드맵, 후원 링크를 포함한 README.md 확장
- `docs/` 아래 한국어 문서 미러

### 비고
- `AI_PROJECT_SETUP.md` 자체의 버전 이력은 산출물 내 Version History 표에 있습니다. 이 changelog는 산출물 외부의 저장소 수준 변경을 추적합니다.
