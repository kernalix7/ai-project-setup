<div align="center">

# AIPS

### 한 번 설치, 모든 프로젝트에서 `/aips:init`.

<p>Claude Code 플러그인 마켓플레이스 — 한 줄 install로 의존 플러그인 4개(<b>codex-plugin-cc, caveman, agentmemory, RTK</b>)와 global hooks/agents/commands/skills/output-styles/statusline을 <code>~/.claude/</code>에 배치하고, 각 프로젝트에서는 <code>/aips:init</code> 한 번이면 신규/마이그레이션/재init/복구를 자동 분기합니다. <b>설치 1회, 프로젝트별 30초.</b></p>

<pre><code># 1회 머신 (one-time per machine)
curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/install.sh | bash

# 각 프로젝트 (per project)
cd my-project && claude
&gt; /aips:init
</code></pre>

[![Status](https://img.shields.io/badge/v7.0-개발_중-FF8C00?style=for-the-badge)](#-상태-v70-개발-중)
[![Stable](https://img.shields.io/badge/stable-v5.2-2EA44F?style=for-the-badge)](../AI_PROJECT_SETUP.md)

[![license](https://img.shields.io/github/license/kernalix7/AIPS?style=flat-square&color=blue)](../LICENSE)
[![plugin](https://img.shields.io/badge/Claude%20Code-plugin-7C3AED?style=flat-square&logo=anthropic&logoColor=white)](https://claude.com/claude-code)
[![deps](https://img.shields.io/badge/deps-4_plugins-blue?style=flat-square)](#-무엇이-설치되나)
[![commands](https://img.shields.io/badge/commands-12_+_deps-2EA44F?style=flat-square)](#-슬래시-명령)
[![stars](https://img.shields.io/github/stars/kernalix7/AIPS?style=flat-square&color=FFD93D&logo=github&logoColor=white)](https://github.com/kernalix7/AIPS/stargazers)
[![PRs](https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square)](../CONTRIBUTING.md)

###### 호환 도구

[![Claude Code](https://img.shields.io/badge/Claude%20Code-2.0%2B-7C3AED?style=flat-square&logo=anthropic&logoColor=white)](https://claude.com/claude-code)
[![Codex CLI](https://img.shields.io/badge/Codex%20CLI-0.10%2B-10B981?style=flat-square&logo=openai&logoColor=white)](https://github.com/openai/codex)
[![Cursor](https://img.shields.io/badge/Cursor-0.40%2B-000000?style=flat-square&logo=cursor&logoColor=white)](https://cursor.sh)
[![GitHub Copilot](https://img.shields.io/badge/Copilot-1.150%2B-24292F?style=flat-square&logo=githubcopilot&logoColor=white)](https://github.com/features/copilot)
[![MCP](https://img.shields.io/badge/MCP-aware-FF6B6B?style=flat-square)](https://modelcontextprotocol.io)
[![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat-square&logo=linux&logoColor=black)](#)
[![macOS](https://img.shields.io/badge/macOS-000000?style=flat-square&logo=apple&logoColor=white)](#)
[![Windows](https://img.shields.io/badge/Windows-Git%20Bash-0078D6?style=flat-square&logo=windows&logoColor=white)](#)

<sub>[English](../README.md) &nbsp;·&nbsp; **한국어** &nbsp;·&nbsp; [install.sh](../install.sh) &nbsp;·&nbsp; [기여](../CONTRIBUTING.md) &nbsp;·&nbsp; [보안](../SECURITY.md) &nbsp;·&nbsp; [체인지로그](../CHANGELOG.md)</sub>

</div>

---

### 상태: v7.0 개발 중

> **v5.2 안정**은 단일 파일 부트스트랩(`AI_PROJECT_SETUP.md`, ~7,600줄) 모델입니다. 다운로드받고 AI에게 "읽고 실행해줘"라고 시키는 방식. v5.x 사용자는 [`AI_PROJECT_SETUP.md`](../AI_PROJECT_SETUP.md)를 계속 쓰면 됩니다.
>
> **v6.0**은 동일 산출물을 **Claude Code 플러그인 marketplace**로 재배포합니다. 머신당 한 번 `install.sh`를 실행하면 `~/.claude/`에 marketplace를 등록하고 의존 plugin 4개를 install/update하며, 각 프로젝트에서는 `/aips:init` 한 번으로 신규/v5.x 마이그레이션/재init/복구를 **자동 분기**합니다. 7,600줄 마크다운을 매번 AI가 읽고 해석하던 모델을 버리고, 결정론적 install script + idempotent slash 명령으로 대체합니다. v6.0 셋업은 그대로 유효한 baseline입니다.
>
> **v7.0(개발 중)**은 v6.0 위에 **hybrid global-first** 모델을 얹습니다 — toolkit script, sessions mirror, memory, AIPS gitignore block을 `~/.claude/` / `~/.local/bin/` / `~/.config/git/ignore`로 globalize하고, CLAUDE.md / WORK_STATUS.md / `.mcp.json` / agent 파일 / `tmp-igbkp/` 백업 산출물은 그대로 프로젝트별로 둡니다. v7.0은 **non-breaking**입니다: 기존 v6.0 프로젝트는 손대지 않고 그대로 동작하며, 마이그레이션은 `/aips:upgrade --to v7.0`으로 opt-in.
>
> 이 문서는 **v7.0**을 설명하며 v6.0 baseline도 함께 다룹니다. v5.2가 필요하다면 [영문 README v5.2 섹션](../README.md) 또는 [`AI_PROJECT_SETUP.md`](../AI_PROJECT_SETUP.md)을 참고하세요.

---

## 목차

- [왜 v6.0](#-왜-v60)
- [빠른 시작](#-빠른-시작)
- [무엇이 설치되나](#-무엇이-설치되나)
- [라이프사이클](#-라이프사이클)
- [Statusline 미리보기](#-statusline-미리보기)
- [슬래시 명령](#-슬래시-명령)
- [v5.x → v6.0 마이그레이션](#-v5x--v60-마이그레이션)
- [v7.0 Hybrid Global-First](#-v70-hybrid-global-first)
- [지원 AI 도구](#-지원-ai-도구)
- [비교](#-비교)
- [문서](#-문서)
- [자주 묻는 질문](#-자주-묻는-질문)
- [로드맵](#-로드맵)
- [Star history](#-star-history)
- [후원](#-후원)
- [라이선스](#-라이선스)

---

## 왜 v6.0

v5.x는 잘 작동했지만 매 프로젝트마다 7,600줄 마크다운을 AI가 읽고 해석해야 했습니다(~25k 토큰, 1~3분 대기, 종종 실패 후 재시도). v6.0은 결정론적 shell script와 Claude Code 네이티브 plugin/skill/hook 기반으로 옮겨, 매 프로젝트 setup을 **30초**로 줄이고 AI가 산출물을 "이해"할 필요를 없앱니다.

| v5.x | v6.0 |
|---|---|
| 매 프로젝트마다 7,600줄 .md 다운로드 후 AI 실행 (~25k 토큰, 1~3분) | install 1회, 프로젝트당 `/aips:init` (~30초) |
| AI가 마크다운을 읽고 해석 → 비결정론적 | 결정론적 shell script + plugin manifest |
| 자가 업데이트 = AI가 raw URL 페치 후 재구성 | `/aips:update` = marketplace pull + 의존 update |
| 9개 toolkit script 모두 프로젝트 `tmp-igbkp/`에 복제 | 동일 toolkit 9개, 단 marketplace pull 시 자동 sync |
| 커스텀 `/codex-*` 4개를 프로젝트마다 재생성 | codex-plugin-cc가 global 제공 (`/codex:*`) |

---

## 빠른 시작

**1회 머신** (모든 프로젝트에 한 번):

```bash
curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/install.sh | bash
```

`install.sh`가 하는 일:

1. AIPS marketplace를 `~/.claude/`에 등록
2. 의존 플러그인 4개 install/update:
   - **codex-plugin-cc** — `/codex:*` 슬래시 명령 (Claude ↔ Codex 릴레이)
   - **caveman** — ultra-terse output style, `/caveman*` 명령
   - **agentmemory** + systemd unit — file-backed 메모리 + 자동 백업
   - **RTK** (Rust Token Killer) — 60–90% 토큰 절감 CLI 프록시
3. Global hooks/agents/commands/skills/output-styles/statusline 배치 (`~/.claude/`)

**각 프로젝트**:

```bash
cd my-project
claude
> /aips:init
```

`/aips:init`이 자동 분기:

| 케이스 | 트리거 | 동작 |
|---|---|---|
| **A. 신규** | `.priv-storage/` 없음, 루트에 v5.x .md도 없음 | fresh init (~30초) |
| **B. v5.x 마이그레이션** | 루트에 `AI_PROJECT_SETUP.md` (v5.x) 감지 | 1회 confirm → 백업 → 정리 → v6.0 init |
| **C. 재init (멱등)** | `.priv-storage/` v6.0 마커 존재 | idempotent re-init (drift 복구) |
| **D. 복구** | 손상된 부분 상태 감지 | repair 모드 |

끝. 모든 산출물은 gitignore 처리되어 git 히스토리는 깨끗합니다.

---

## 무엇이 설치되나

v6.0은 글로벌(머신당 1회)과 프로젝트별(`/aips:init`)을 명확히 분리합니다.

### 글로벌 — `~/.claude/` (install.sh)

| 카테고리 | 내용 |
|---|---|
| Plugins | 4개: `codex-plugin-cc`, `caveman`, `agentmemory` (+ systemd unit), `RTK` |
| Hooks | 5개: `PreToolUse`, `PostToolUse`, `SessionStart`, `PreCompact`, `Stop` |
| Agents | 3개 템플릿: `tech-lead`, `explorer`, `code-reviewer` |
| Commands | 16개: `/aips:*` 12개 (base 9 + v7.0 3) + 의존 plugin 명령 |
| Skills | on-demand 지식 모듈 (caveman, codex 등) |
| Output styles | `terse` (기본), `caveman/full`, `caveman/ultra` 등 |
| Statusline | 3줄 멀티 라인 (아래 미리보기) |
| Binaries | RTK Rust 바이너리 (`~/.local/bin/rtk`) |
| Daemons | agentmemory systemd unit (사용자 단위) |

### 프로젝트 — `.priv-storage/` (`/aips:init`)

```text
your-project/
|-- CLAUDE.md              -> .priv-storage/CLAUDE.md 심볼릭링크
|-- AGENTS.md              -> .priv-storage/CLAUDE.md 심볼릭링크  # Codex / Copilot
|-- .cursorrules           -> .priv-storage/CLAUDE.md 심볼릭링크  # Cursor
|-- WORK_STATUS.md         -> .priv-storage/WORK_STATUS.md
|
|-- .priv-storage/         [gitignored] 프로젝트 단위 AI 상태
|   |-- CLAUDE.md                   # 섹션 1-7 + 11만, ~150줄 (v5.x는 13개 섹션 ~10kB)
|   |-- CLAUDE.local.md             # 개발자별 오버라이드
|   |-- WORK_STATUS.md              # 현재 작업 상태
|   |-- memory/                     # agentmemory file-backed store
|   |-- sessions/                   # current.md / handoff-{date}.md / recovery.md
|   |-- agents/                     # tech-lead.md + 팀별 에이전트
|   |-- .mcp.json                   # MCP 서버 레지스트리 (env-var ref만)
|   `-- .gitignore                  # 22개 항목
|
`-- tmp-igbkp/             [gitignored] 백업 및 검증 toolkit (9개)
    |-- verify-setup.sh             # 헬스 체크
    |-- smoke-test-hooks.sh         # mock 페이로드 훅 검증
    |-- secret-guard.sh             # 14-패턴 pre-commit 스캐너
    |-- archive.sh / restore.sh     # AES-256-CBC + PBKDF2 60만 반복
    |-- purge-history.sh            # git-filter-repo 래퍼
    |-- setup-worktree.sh           # worktree 브릿지
    `-- uninstall.sh                # 안전 롤백
```

> `WORK_STATUS.md`, GitHub 표준 파일, `docs/` 한국어 미러, `.github/`만 커밋됩니다. `.priv-storage/`와 `tmp-igbkp/`의 모든 것은 의도적으로 gitignore 처리됩니다. **CLAUDE.md는 ~150줄로 축소** (v5.x는 ~10kB) — 8/9/10/12/13 섹션이 글로벌 plugin/skill로 빠졌기 때문.

> **v7.0 레이아웃 변경 (opt-in, `/aips:upgrade --to v7.0`)**:
>
> | 항목 | v6.0 위치 | v7.0 위치 |
> |---|---|---|
> | `tmp-igbkp/` script | 프로젝트별 (복사본) | 프로젝트별 (백업 산출물) + global (`~/.local/bin/aips-*` script) |
> | `sessions/` | 프로젝트별만 | 프로젝트별 (fast-write buffer) + global mirror `~/.claude/sessions/{path-hash}/` |
> | `memory/` | 프로젝트별 + global | global only — `~/.claude/projects/{path-encoded}/memory/` |
> | AIPS `.gitignore` block | 프로젝트별 22개 항목 | global `~/.config/git/ignore` + 최소 per-project `.gitignore` |

---

## 라이프사이클

```text
[1. 글로벌 install] (머신당 1회)
  curl ... | bash
  - AIPS marketplace 등록 → ~/.claude/
  - 의존 plugin 4개 install/update
  - hooks/agents/commands/skills/output-styles/statusline 배치
  - RTK 바이너리, agentmemory systemd unit 설치
        |
        v
[2. 프로젝트 init] (프로젝트당 1회, ~30초)
  cd project && claude → /aips:init
  - 케이스 A/B/C/D 자동 분기
  - .priv-storage/ + tmp-igbkp/ 생성, 심볼릭링크 3개 배치
  - CLAUDE.md 섹션 1-7 + 11 (~150줄)
  - .gitignore 22개 항목 추가
        |
        v
[3. 일반 세션]
  - SessionStart 훅이 직전 handoff + current.md 꼬리 자동 주입
  - AI는 CLAUDE.md (~150줄)만 읽음 — 7,600줄 .md 없음
  - PreToolUse가 위험 명령 + 과대 Read 차단
  - PostToolUse가 current.md 추가 + agentmemory 듀얼 라이트
  - Stop 훅이 handoff-{date}.md 기록
  - PreCompact 훅이 recovery.md 기록 (best-effort)
  - 통계 누적: statusline 3줄에 실시간 표시
        |
        v
[4. 크래시 / rate-limit / /clear]
  - 다음 세션 시작 시 SessionStart가 handoff + recovery 자동 로드
  - AI가 "어디까지 했죠?" 묻지 않고 이전 상태에서 이어감
        |
        v
[5. 업데이트] (트리거: /aips:update)
  - marketplace pull → 의존 plugin 4개 update
  - 글로벌 hooks/commands 자동 sync
  - 프로젝트는 손대지 않음 (재init하려면 /aips:init)
```

---

## Statusline 미리보기

3줄 멀티 라인. 핵심 신호를 한눈에 모음.

```
project [main*3] wip:2 | opus-4.7 | ctx:8%(15.5k/200k) | cache:71%
5h:8% ↻2h11m ∅1h23m | wk:12% ↻4d18h ∅2d4h
🦴cv:75%/full | 🧠am:40%/127 | 💰rtk:34% | 🤖cdx:55%/3runs | 💯Σ:95%
```

| 줄 | 표시 |
|---|---|
| 1 | 프로젝트명, git 브랜치 [지난 커밋 수], `wip` 카운트, 모델, 컨텍스트 사용률, prompt cache 히트율 |
| 2 | 5시간 윈도우 사용률 + 리셋까지 남은 시간(`↻`) + burn rate 기준 예상 소진 시간(`∅`); 주간 윈도우 동일 |
| 3 | caveman 절감률·강도, agentmemory 사용률·observation 수, RTK 절감률, codex 위임률·실행 수, 누적 절감률(`Σ`) |

`↻` = reset까지 남은 시간, `∅` = burn rate 기준 예상 소진 시간, `Σ` = 누적 절감률.

---

## 슬래시 명령

### AIPS 네이티브 (12개 — base 9 + v7.0 3)

| 명령 | 동작 |
|---|---|
| `/aips:init` | 자동 분기 init (신규/마이그/재init/복구) |
| `/aips:update` | marketplace pull + 의존 plugin update |
| `/aips:health` | verify-setup.sh + smoke-test-hooks.sh |
| `/aips:status` | 현재 작업 + 최근 활동 요약 |
| `/aips:migrate-from-md` | v5.x .md 명시적 마이그레이션 (B 케이스 수동 트리거) |
| `/aips:upgrade` | v5.x → v6.0 + 의존 plugin 업그레이드 |
| `/aips:repair` | 손상 상태 복구 (D 케이스 수동 트리거) |
| `/aips:reset` | 프로젝트 init 초기화 (백업 후) |
| `/aips:uninstall` | 글로벌 + 프로젝트 안전 제거 |
| `/aips:upgrade --to v7.0` | **v7.0** — 기존 `/aips:upgrade` 확장 플래그: v6.0 → v7.0 hybrid 마이그레이션 (opt-in, non-breaking) |
| `/aips:rebind <old-path>` | **v7.0** — 프로젝트 디렉터리가 이동/이름 변경되었을 때 globalize된 상태(sessions mirror, memory)를 rebind |
| `/aips:scope` | **v7.0** — 현재 프로젝트의 globalize vs per-project 레이아웃을 진단; drift나 orphan global 상태 표시 |

### 의존 plugin 명령

| Plugin | 명령 |
|---|---|
| codex-plugin-cc | `/codex:brief`, `/codex:review`, `/codex:fix`, `/codex:relay-status` |
| caveman | `/caveman`, `/caveman:lite`, `/caveman:ultra`, `/caveman:wenyan-*` |
| agentmemory | `/am:save`, `/am:recall`, `/am:reflect`, `/am:consolidate`, `/am:sessions` |
| RTK | hook 기반 자동 — 명시 명령 없음 (`rtk gain`은 shell에서) |

---

## v5.x → v6.0 마이그레이션

**자동(권장)** — 프로젝트에서 `/aips:init`만 실행:

```bash
cd existing-v5-project
claude
> /aips:init
# → 루트 AI_PROJECT_SETUP.md (v5.x) 감지
# → "v5.x 설치를 감지했습니다. v6.0으로 마이그레이션할까요? [y/N]"
# → y 입력 시:
#   1. .priv-storage/v5-backup/ 에 전체 백업
#   2. 7,600줄 AI_PROJECT_SETUP.md → 30줄 DEPRECATED redirect로 축소
#   3. 커스텀 /codex-* 4개 제거 (codex-plugin-cc가 대체)
#   4. tmp-igbkp/codex-relay-{check,run}.sh 제거
#   5. CLAUDE.md를 섹션 1-7 + 11만 남기고 축소 (~150줄)
#   6. v6.0 marker 기록
```

**수동** — `/aips:migrate-from-md`로 명시 트리거 가능.

### v6.0에서 제거된 것

- **7,600줄 AI_PROJECT_SETUP.md 실행 모델** → 30줄 DEPRECATED redirect로 축소 (다운스트림 raw URL 호환 유지)
- **커스텀 슬래시 명령** `/codex-brief`, `/codex-review`, `/codex-fix`, `/codex-relay-status` → codex-plugin-cc의 `/codex:*`로 대체
- **`tmp-igbkp/codex-relay-{check,run}.sh`** → codex-plugin-cc가 자체 락/원장 관리
- **CLAUDE.md 섹션 8/9/10/12/13** → 글로벌 plugin/skill/hook으로 이전, 프로젝트 CLAUDE.md는 1-7 + 11 (~150줄)만

---

## v7.0 Hybrid Global-First

v7.0은 안전성과 가치가 향상되는 항목들(toolkit script, sessions mirror, memory store, AIPS gitignore block)을 선택적으로 globalize합니다. 프로젝트에 bound되어야 하는 항목들(rules, work state, MCP, team agent, 백업 산출물)은 그대로 per-project. **v6.0 셋업은 손대지 않으며** 마이그레이션은 **opt-in**.

### Globalize 항목 (4개)

| 항목 | v6.0 위치 | v7.0 위치 | 이유 |
|---|---|---|---|
| Toolkit script | `tmp-igbkp/*.sh` 프로젝트별 복사 | `~/.local/bin/aips-*` (`lib/globalize-toolkit.sh`를 통한 symlink) | 단일 canonical copy, drift 없음, PATH 한 번 lookup |
| Sessions | `.priv-storage/sessions/`만 | `.priv-storage/sessions/` (fast-write buffer) + `~/.claude/sessions/{path-hash}/` mirror | 프로젝트 디렉터리 이동에도 살아남고, 단일 디렉터리로 머신 간 sync |
| Memory | `.priv-storage/memory/` + global | global only — `~/.claude/projects/{path-encoded}/memory/` | 단일 진실 공급원, 중복 쓰기 drift 없음 |
| `.gitignore` AIPS block | 프로젝트별 22개 항목 | `~/.config/git/ignore` (global) + 최소 per-project `.gitignore` | 프로젝트 gitignore 노이즈 0, 모든 repo에 자동 적용 |

### Preserved per-project (5개)

| 항목 | per-project 유지 이유 |
|---|---|
| `CLAUDE.md` 섹션 1–7 + 11 | 프로젝트 rules + 멀티 도구 보장 (Claude/Codex/Cursor/Copilot 모두 읽음) |
| `WORK_STATUS.md` | 팀 공유 작업 상태 — repo에 있어야 함 |
| `.mcp.json` | 프로젝트별 MCP server registry |
| `tech-lead.md` + team agents | 프로젝트별 팀 구성 |
| `tmp-igbkp/` 백업 산출물 | 암호화 백업 아카이브는 백업 대상 프로젝트와 함께 있어야 함 |

### 새 slash 명령 (3개)

- `/aips:upgrade --to v7.0` — 기존 `/aips:upgrade`를 확장해 v6.0 → v7.0 hybrid 마이그레이션 경로를 추가
- `/aips:rebind <old-path>` — 프로젝트 디렉터리가 이동/이름 변경되었을 때 globalize된 상태(sessions mirror, memory)를 rebind
- `/aips:scope` — 현재 프로젝트의 globalize vs per-project 레이아웃을 진단, drift나 orphan global 상태 표시

### 마이그레이션

```bash
cd existing-v6-project
claude
> /aips:upgrade --to v7.0
# → Strict 모드 (기본): 결과는 최초 v7.0 설치와 동일.
#   per-project tmp-igbkp/*.sh + sessions/*.md는 글로벌 카운터파트
#   검증 후 삭제. 전체 백업은 항상 tmp-igbkp/upgrade-v7-backup-{ts}/
#   에 먼저 저장.
# → --keep-local-fallback 전달 시 fallback 유지 (lenient).
```

---

## 지원 AI 도구

**AIPS는 Claude Code를 1순위로 만들어졌습니다.** 그 외 도구는 `CLAUDE.md` / `AGENTS.md` / `.cursorrules`를 통한 정책 전용 지원이며, 동급 플러그인 지원은 로드맵입니다.

### Tier 1 — 주 지원 / 완전

| 도구 | 최소 버전 | 읽는 파일 | v6.0 기능 |
|---|---|---|---|
| **Claude Code (CLI)** | 2.0+ | `CLAUDE.md` | 플러그인 전체 설치, 9개 `/aips:*` 슬래시 명령, 5개 훅, 3줄 statusline, 출력 스타일, 4개 번들 dep plugin (codex-plugin-cc, caveman, agentmemory, RTK) |

### Tier 2 — 부분 지원 (정책만)

| 도구 | 최소 버전 | 읽는 파일 | v6.0 기능 |
|---|---|---|---|
| **ChatGPT Codex CLI** | 0.10+ | `AGENTS.md` → `CLAUDE.md` | 규칙만 (hooks / slash / statusline 없음) |
| **Cursor** | 0.40+ | `.cursorrules` → `CLAUDE.md` | 규칙만 |
| **GitHub Copilot** | 1.150+ | `AGENTS.md` | 규칙만 |
| **claude.ai (웹)** | 현재 | `CLAUDE.md` 수동 업로드 | 규칙만 |
| **모든 MCP 지원 도구** | — | 도구별 상이 | `.mcp.json`만 |

> *정책만* = 규칙이 프롬프트 콘텐츠로 시행됨. 커널 레벨 차단도, hooks도, 슬래시 명령도, statusline도 없지만 AI가 읽는 규칙 파일에 명시되어 있으므로 따름.

### Tier 3 — 완전 지원 예정 (TBD)

Codex / Cursor / Copilot 대상 플러그인 동급 패리티 (hooks, 슬래시 명령, statusline, dep-plugin 스택)는 로드맵에 있습니다.

> **TBD — 로드맵, ETA 미정.** 진행 상황은 [로드맵](#로드맵)에서 확인하거나 이슈로 업보트해 주세요.

---

## 비교

| | AIPS v6.0 | AIPS v5.x (.md) | `.cursorrules`만 | 직접 작성한 CLAUDE.md |
|---|:---:|:---:|:---:|:---:|
| 프로젝트당 setup 시간 | ~30초 | 1~3분 | 즉시 | 시간 |
| 결정론적 | ✅ shell | ❌ AI 해석 | ✅ | ✅ |
| 도구 간 단일 진실 공급원 | ✅ | ✅ | ❌ Cursor만 | ❌ Claude만 |
| 글로벌 install 1회 | ✅ | ❌ | ❌ | ❌ |
| 안전 훅 (커널 레벨) | ✅ | ✅ | ❌ | 수동 |
| 크래시 시 세션 복원 | ✅ | ✅ | ❌ | 수동 |
| Statusline 3줄 (절감률 포함) | ✅ | ❌ | ❌ | ❌ |
| Cross-AI 릴레이 (Claude ↔ Codex) | ✅ plugin | ✅ 커스텀 | ❌ | ❌ |
| 토큰 절감 (RTK + caveman + agentmemory) | ✅ | ❌ | ❌ | ❌ |
| 업스트림 자가 업데이트 | ✅ `/aips:update` | ✅ AI 페치 | ❌ | ❌ |
| AI 도구 누출 방지 | ✅ | ✅ | ❌ | 수동 |
| Linux / macOS / Windows | ✅ | ✅ | ✅ | ✅ |

---

## 문서

| 문서 | 내용 |
|---|---|
| [install.sh](../install.sh) | 글로벌 install script |
| [README.md](../README.md) | 영문 README |
| [AI_PROJECT_SETUP.md](../AI_PROJECT_SETUP.md) | v5.2 아카이브 (v6.0에서는 30줄 DEPRECATED) |
| [CONTRIBUTING.md](../CONTRIBUTING.md) · [한국어](CONTRIBUTING.ko.md) | 개발 환경, 버전 bump 체크리스트, PR 규약 |
| [SECURITY.md](../SECURITY.md) · [한국어](SECURITY.ko.md) | 보안 공개 프로세스, secret-guard 패턴 |
| [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md) · [한국어](CODE_OF_CONDUCT.ko.md) | Contributor Covenant v2.1 |
| [CHANGELOG.md](../CHANGELOG.md) · [한국어](CHANGELOG.ko.md) | 전체 버전 히스토리 |

---

## 자주 묻는 질문

<details>
<summary><b>v5.x에서 v6.0으로 강제로 옮겨야 하나요?</b></summary>

아니요. v5.2는 안정 버전으로 계속 지원됩니다. v6.0이 stable로 승격되기 전까지 v5.x를 그대로 쓰세요. 옮길 준비가 되면 `/aips:init` 한 번으로 자동 마이그레이션됩니다(B 케이스).
</details>

<details>
<summary><b>v6.0에서 v7.0으로 강제로 옮겨야 하나요?</b></summary>

아니요. v7.0은 **opt-in, non-breaking**입니다. v6.0 셋업은 손대지 않고 그대로 동작합니다. hybrid global-first 이점(단일 canonical toolkit, sessions mirror, global gitignore, 단일 소스 memory)이 필요해지면 프로젝트에서 `/aips:upgrade --to v7.0`을 실행하세요.
</details>

<details>
<summary><b>v7.0 init 이후 프로젝트 이름을 바꾸거나 이동했어요.</b></summary>

새 위치의 프로젝트 안에서 `/aips:rebind <old-path>`를 실행하세요. path-hash 기반 globalize 상태(`~/.claude/sessions/{path-hash}/`, memory 매핑)를 다시 작성해서, sessions와 memory가 동일 프로젝트로 계속 해석되게 합니다.
</details>

<details>
<summary><b>무엇이 globalize되어 있고 무엇이 per-project인지 확인하려면?</b></summary>

`/aips:scope`를 실행하세요. 현재 프로젝트의 산출물 중 무엇이 global이고 무엇이 per-project인지 진단을 출력하며, drift(예: per-project sessions buffer가 global mirror보다 앞서 있음)나 orphan global 상태(존재하지 않는 프로젝트 디렉터리에 대한 mirror)를 표시합니다.
</details>

<details>
<summary><b>install.sh가 시스템 어디를 건드리나요?</b></summary>

`~/.claude/` (Claude Code 글로벌 설정), `~/.local/bin/rtk` (RTK 바이너리), 사용자 단위 systemd unit(agentmemory). 시스템 전역 디렉터리(`/usr/local/`, `/etc/`)는 건드리지 않습니다. uninstall은 `/aips:uninstall`로 안전 롤백.
</details>

<details>
<summary><b>왜 의존 plugin 4개를 묶었나요?</b></summary>

각각이 직교 가치를 제공해서입니다 — codex-plugin-cc(릴레이), caveman(출력 압축), agentmemory(영구 메모리), RTK(CLI 토큰 절감). 따로 설치하면 hook 충돌과 statusline 분기 처리가 복잡해집니다. 묶음으로 cross-plugin 동기화를 보장합니다.
</details>

<details>
<summary><b>오프라인에서 동작하나요?</b></summary>

install/update는 네트워크 필요(marketplace pull, RTK 바이너리 페치). 일반 세션과 `/aips:init`은 오프라인에서 동작 — 모든 산출물은 로컬 plugin store에서 읽습니다.
</details>

<details>
<summary><b>여러 머신에서 동기화하려면?</b></summary>

agentmemory가 프로젝트 메모리를 `~/.claude/projects/{path-encoded}/memory/`에 듀얼 라이트합니다. 새 머신에서 `install.sh` 실행 → 프로젝트에서 `/aips:init` → memory dir만 rsync로 복사하면 즉시 복원됩니다.
</details>

<details>
<summary><b>Windows는?</b></summary>

Git Bash, WSL, MSYS2에서 동작합니다. install.sh는 bash이고, hook도 bash이므로 네이티브 PowerShell은 미지원입니다. WSL을 권장합니다.
</details>

<details>
<summary><b>같은 프로젝트에서 여러 AI 도구를 동시에 쓸 수 있나요?</b></summary>

네. Claude Code는 `CLAUDE.md`, Codex/Copilot은 `AGENTS.md`, Cursor는 `.cursorrules`를 읽습니다. 세 파일 모두 동일한 `.priv-storage/CLAUDE.md` 심볼릭링크라서 업데이트가 원자적입니다. 다만 hook, statusline, 슬래시 명령은 Claude Code 전용입니다.
</details>

<details>
<summary><b>플러그인 마켓플레이스를 안 쓰고 그냥 클론해서 쓰면?</b></summary>

가능합니다. 저장소를 클론한 뒤 로컬 경로로 install.sh를 실행하면 marketplace 등록 단계가 로컬 경로를 가리키도록 fallback합니다. fork 환경에서 유용합니다.
</details>

<details>
<summary><b>버그를 찾았거나 기능을 원해요.</b></summary>

<https://github.com/kernalix7/AIPS>에서 이슈나 PR을 열어주세요. [CONTRIBUTING.md](../CONTRIBUTING.md) 참조.
</details>

---

## 로드맵

- **v6.0** — plugin marketplace + 의존 plugin 4개 + `/aips:*` 9개 명령 (baseline; 그대로 유효)
- **v7.0** *(개발 중)* — Hybrid global-first: toolkit/sessions/memory/gitignore globalize, 새 `/aips:*` 명령 3개 (`upgrade --to v7.0`, `rebind`, `scope`), v6.0 → v7.0은 opt-in non-breaking 마이그레이션
- **v7.1** — agentmemory 심화 통합 (cross-project workflow 추천, 공유 lesson surface)
- **v7.2** — `/aips:rebind` UX 개선 (path-hash heuristic으로 이동된 프로젝트 auto-detect)
- **v8.0 (candidate)** — TBD; 후보: cloud sync 기반 team-shared global, 또는 third-party AIPS 확장용 full plugin marketplace 퍼블리싱

버전 히스토리는 [CHANGELOG.md](../CHANGELOG.md) 참조.

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

## 후원

AIPS가 설정 시간을 절약해줬다면:

[![Ko-fi](https://img.shields.io/badge/Ko--fi-F16061?logo=ko-fi&logoColor=white&style=for-the-badge)](https://ko-fi.com/kernalix7)
[![Fairy](https://img.shields.io/badge/🧚_Fairy-EE6E73?style=for-the-badge&logoColor=white)](https://fairy.hada.io/@kernalix7)

Ko-fi는 해외 카드와 PayPal을 처리하고, fairy.hada.io는 한국 팁 플랫폼입니다. 버그 신고, PR, ⭐ 스타도 똑같이 감사하고 무료입니다.

---

## 라이선스

[MIT](../LICENSE) — Kim DaeHyun ([kernalix7@kodenet.io](mailto:kernalix7@kodenet.io))

<div align="center">

[버그 신고](https://github.com/kernalix7/AIPS/issues/new?template=bug_report.md) &nbsp;·&nbsp; [기능 요청](https://github.com/kernalix7/AIPS/issues/new?template=feature_request.md) &nbsp;·&nbsp; [English README](../README.md)

</div>
