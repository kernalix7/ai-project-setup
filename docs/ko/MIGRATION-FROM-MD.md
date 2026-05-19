# v5.x (Markdown) → v6.0 (Plugin) 마이그레이션

기존 프로젝트를 AIPS v5.x — `.priv-storage/` 에 7,600줄 `AI_PROJECT_SETUP.md` 가 있고 setup 변경마다 AI 가 재실행하던 — 에서 v6.0 (native Claude Code plugin) 으로 옮기는 사용자 walkthrough.

아키텍처 상세는 [`ARCHITECTURE.md`](./ARCHITECTURE.md). 영문 원본은 [`../MIGRATION-FROM-MD.md`](../MIGRATION-FROM-MD.md).

---

## v6.0 채택 이유

v5.x 모델도 동작했으나 3가지 pain point 가 있었고, v6.0 이 이를 해결합니다:

1. **토큰 비용.** 매 re-init 마다 AI 가 ~25k 토큰 markdown 재읽기.
2. **도구 간 drift.** Claude / Codex / Cursor / Copilot 각각 markdown 실행이 미묘하게 달라 `.priv-storage/` 결과가 갈림.
3. **업데이트 마찰.** 버전 bump 시 raw URL 재-fetch + setup 재실행 필요, 멀티 도구 시 정기적으로 분기.

v6.0은 AIPS 를 Claude Code **plugin** 으로 배포: command, hook, template 가 단일 설치 단위로 묶여 `/plugin update AIPS@AIPS` 한 줄로 atomic update.

---

## Pre-flight

마이그레이션 전 backup 필수. v5.x backup toolkit:

```bash
cd your-v5-project
bash tmp-igbkp/archive.sh         # AES-256-CBC 암호화 .priv-storage/ tarball
```

migration script 도 자체 backup 을 `tmp-igbkp/migrate-backup-{TIMESTAMP}/` 에 만들지만 이중 안전망.

필수 도구:
- `bash >= 4.0`, `git`, `curl`
- `node >= 18.18` (`agentmemory` 사용 시)
- `claude` CLI (Claude Code 2.0+)

---

## Step 1 — Global 설치

한 줄 설치. idempotent, sudo 불필요.

```bash
curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/install.sh | bash
```

`install.sh` 가 수행:
- AIPS marketplace 등록.
- `AIPS@AIPS` plugin 설치.
- Dep plugins 설치: `codex@openai-codex`, `caveman@caveman`, `agentmemory@agentmemory`.
- RTK 설치 (`~/.local/bin/rtk`).
- Linux: agentmemory systemd user service 설치.

부분 설치:

```bash
bash install.sh --with caveman,rtk        # codex + agentmemory skip
bash install.sh --dry-run                  # 액션만 출력
```

---

## Step 2 — v5.x 프로젝트에서 `/aips:init`

```bash
cd your-v5-project
claude
> /aips:init
```

`/aips:init` 가 `$PWD` 에서 위로 올라가 `.git` 찾고, 디렉터리 상태 분류:

| 감지 | 경로 |
|---|---|
| Fresh 프로젝트 (`.priv-storage/` 없음) | **CASE A** — full fresh init |
| **v5.x 존재 (`.priv-storage/AI_PROJECT_SETUP.md` 있음)** | **CASE B** — 마이그레이션 |
| v6.0 이미 초기화 | CASE C — 비파괴 re-sync |
| 부분 / 손상 상태 | CASE D — repair |

v5.x 프로젝트면 CASE B 진입.

---

## Step 3 — 마이그레이션 계획 확인

CASE B 는 동작 전 명시적 REMOVE / EDIT / PRESERVE 계획 출력:

```
REMOVE (files):
  - .priv-storage/AI_PROJECT_SETUP.md
  - .priv-storage/.claude/commands/{status,recover,ship,health,save,clean,codex-brief,...}.md
  - .priv-storage/.claude/agents/{explorer,code-reviewer,log-analyzer}.md
  - tmp-igbkp/codex-relay-{check,run}.sh
  - .priv-storage/sessions/{codex-brief,codex-report,claude-review}.md

REMOVE (dirs):
  - .priv-storage/.claude/{hooks,skills,output-styles,statusline}/
  - .priv-storage/sessions/codex-relay/

EDIT:
  - .priv-storage/CLAUDE.md  (Section 8, 9, 10, 12, 13 삭제 — globalized)

PRESERVE:
  - .priv-storage/WORK_STATUS.md
  - .priv-storage/memory/**
  - .priv-storage/sessions/{current,recovery,handoff-*}.md
  - .priv-storage/.mcp.json, root .gitignore
  - .priv-storage/.claude/agents/tech-lead.md, *-team.md
  - tmp-igbkp/{archive,restore,purge-history,verify-setup,uninstall,smoke-test-hooks,
              secret-guard,automode-validate,setup-worktree}.sh

Proceed? [Y/n]
```

Enter (또는 `y`) 로 진행. script 동작:

1. `tmp-igbkp/migrate-backup-{TIMESTAMP}/` 생성 — `.priv-storage/` + relay script 전체 복사.
2. v5.x 전용 파일/디렉터리 삭제.
3. `.priv-storage/CLAUDE.md` 에 `awk` pass 로 Section 8/9/10/12/13 삭제 + 단일 코멘트 삽입:
   `<!-- Sections 8/9/10/12/13 globalized in v6.0 — see ~/.claude/CLAUDE.md -->`
4. `.priv-storage/.aips-version` = `6.0` 작성.

쓰기 없이 preview:

```bash
bash ~/.claude/plugins/cache/AIPS/AIPS/lib/migrate-from-md.sh --dry-run
```

---

## Step 4 — 검증

```bash
> /aips:health
```

`lib/verify-init.sh` 실행, 9개 section (skeleton, CLAUDE.md content, root symlink, `.mcp.json`, `.gitignore`, `tmp-igbkp/` toolkit, global plugin, dep plugin, RTK) 별 PASS / WARN / FAIL 보고.

성공 시 `verify: PASS`, FAIL 0개. WARN 은 허용 — 보통 optional (PATH 에 RTK 없음, opt-out 한 dep plugin) 이며 나중에 처리 가능.

---

## v6.0 → v7.0 마이그레이션

v7.0 은 v6.0 위에 무거우면서 프로젝트-불변인 조각 — toolkit script, sessions, memory, AIPS `.gitignore` block — 을 **globalize** 합니다. 결과로 디스크의 프로젝트당 크기 약 4배 축소, 새 노트북에서 `curl install.sh | bash` 한 줄로 모든 프로젝트 즉시 resume. 마이그레이션은 **non-breaking**: 기존 v6.0 setup 은 opt-in 전까지 그대로 동작하고, multi-tool parity 도 유지 (Codex / Cursor / Copilot 은 여전히 프로젝트의 `CLAUDE.md` / `AGENTS.md` / `.cursorrules` 읽음).

### Pre-flight

- v6.0 설치 확인: `/aips:health` 가 all green (FAIL 0개).
- backup 은 upgrade 중 자동, 추가 안전망: `bash tmp-igbkp/archive.sh`.
- `agentmemory` 가 global 로 실행 중이어야 함 — Linux: `systemctl --user is-active agentmemory.service`.
- 디스크: upgrade backup tar 는 현재 `.priv-storage/` 크기와 비슷.

### Step 1 — v7.0 global 설치 (아직 안 했다면)

```bash
curl -fsSL https://raw.githubusercontent.com/kernalix7/AIPS/main/install.sh | bash
```

v7.0 `install.sh` 는 **step F** 추가, `lib/globalize-toolkit.sh` 실행으로 global toolkit (`~/.local/bin/aips-*`) 과 `lib/setup-global-gitignore.sh` 를 통한 global `.gitignore` BLOCKLIST 설치. script idempotent — 기존 설치 위에 재실행 안전.

### Step 2 — 프로젝트별 upgrade

```bash
$ cd your-project && claude
> /aips:upgrade --to v7.0
```

동작 흐름:

1. `.priv-storage/.aips-version` 에서 현재 버전 감지 (marker 없으면 v6.0 layout 존재 여부로 v6.0 추론).
2. upgrade 계획 출력 — 명시적 REMOVE / GLOBALIZE / PRESERVE 리스트.
3. `Proceed? [Y/n]` 프롬프트.
4. 확인 시: 전체 snapshot 을 `tmp-igbkp/upgrade-v7-backup-{TIMESTAMP}/` 에 저장.
5. **GLOBALIZE**: toolkit script 는 `~/.local/bin/` symlink 로 전환, AIPS `.gitignore` block 은 프로젝트 `.gitignore` 에서 sed 로 제거 후 global 레벨에 재설치, local memory 복사본은 global mirror 검증 후 삭제, 기존 session 파일들은 global mirror 로 복사.
6. **STRICT PURGE (기본)**: 결과는 최초 v7.0 설치와 동일. per-project `tmp-igbkp/*.sh` 는 각 `~/.local/bin/aips-*` symlink 검증 후 삭제; `.priv-storage/sessions/*.md` 는 global mirror 확인 후 비움 (디렉토리는 hook fast-write 위해 유지). `--keep-local-fallback` 전달 시 fallback 유지 (lenient).
7. **PRESERVE**: `CLAUDE.md`, `WORK_STATUS.md`, `.mcp.json`, `tech-lead.md`, team agent, `tmp-igbkp/` 암호화 backup 출력물 (snapshot, script 파일 아님).
8. `.priv-storage/.aips-version` = `7.0` 작성.
9. 카테고리별 카운트 보고 (REMOVED / GLOBALIZED / PURGED / PRESERVED).

### Step 3 — upgrade 후 검증

```bash
> /aips:scope
> /aips:health
```

`/aips:scope` 출력 기대: **legacy v6.0 entry = 0**, **globalized count > 0**, 프로젝트 preserved 파일 모두 존재, 요약 라인 `AIPS version: 7.0`. `/aips:health` 는 v7.0 verifier 룰로 all green 반환.

### v7.0 이후 프로젝트 이동 / 리네임

v7.0 에서는 session 과 project memory 가 path-hash 로 키잉되므로 프로젝트 이동/리네임 시 rebind 필요:

```bash
# mv ~/old-path ~/new-path 후
$ cd ~/new-path && claude
> /aips:rebind ~/old-path
```

`/aips:rebind` 동작:
- old/new path-hash + path-encoded 계산.
- `~/.claude/sessions/{old-hash}/` → `~/.claude/sessions/{new-hash}/` 이동.
- `~/.claude/projects/{old-encoded}/` → `~/.claude/projects/{new-encoded}/` 이동.
- agentmemory 키 API 로 rebind (best-effort) 또는 API rebind 실패 시 수동 단계 출력.

### Rollback

문제 발생 시 upgrade backup 에서 복구:

```bash
TS=<aips:upgrade 가 표시한 timestamp>    # 예: 20260519-101522
cp -r tmp-igbkp/upgrade-v7-backup-$TS/.priv-storage/* .priv-storage/
cp tmp-igbkp/upgrade-v7-backup-$TS/.gitignore .gitignore
rm .priv-storage/.aips-version
```

v6.0 으로 복귀. global toolkit symlink 와 global `.gitignore` block 은 남음 (harmless — v6.0 이 무시).

### v6.0 → v7.0 트러블슈팅

- **"global memory not found"** — v6.0 dual-write 중 `agentmemory` 미실행. 수동 fix: upgrade 재실행 전 `.priv-storage/memory/*` 를 `~/.claude/projects/{path-encoded}/memory/` 로 복사.
- **"toolkit symlinks broken"** — `~/.local/bin` 이 PATH 에 없음. `~/.bashrc` 에 추가: `export PATH="$HOME/.local/bin:$PATH"`.
- **"sessions not mirroring"** — hook 업데이트 안 됨. `install.sh` 재실행으로 `~/.claude/hooks/` 갱신.
- **"gitignore block missing"** — `setup-global-gitignore` 미실행. 수동: `bash ~/.claude/plugins/cache/AIPS/AIPS/lib/setup-global-gitignore.sh`.

### Multi-tool 노트

Codex CLI, Cursor, GitHub Copilot 은 v6.0 처럼 프로젝트의 `CLAUDE.md` / `AGENTS.md` / `.cursorrules` 그대로 읽음. v7.0 globalization 은 이 파일들을 건드리지 않음 — multi-tool 지원은 v6.0 과 동일.

---

## 트러블슈팅

### `agentmemory` 시작 안 됨

```bash
systemctl --user status agentmemory.service
journalctl --user -u agentmemory.service -n 50
```

흔한 원인:
- `node` < 18.18 — package manager 로 업그레이드.
- `npx` PATH 에 없음 — PATH 수정 후 `install.sh` 재실행.
- Port 3111 / 3113 사용 중 — `ss -ltn | grep -E '3111|3113'`.

수정 후: `systemctl --user restart agentmemory.service`.

### `rtk` PATH 에 없음

```bash
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc   # or ~/.zshrc
```

`rtk --version` 확인 (Rust Type Kit 아님 — global `~/.claude/RTK.md` 참조).

### Plugin update 실패

```bash
> /plugin update AIPS@AIPS
```

"not found" 나오면 marketplace 재등록:

```bash
> /plugin marketplace add kernalix7/AIPS
> /plugin install AIPS@AIPS
```

### Hook 동작 안 함

`~/.claude/plugins/cache/AIPS/AIPS/hooks/hooks.json` 존재 확인 + hook 비활성 env 확인:

```bash
echo "${HOOKS_DISABLED:-unset}"     # 'unset' 또는 '0' 이어야 함
```

---

## Rollback

문제 발생 시 마이그레이션 backup 에서 복구:

```bash
cd your-project
TS=<마이그레이션 후 표시된 timestamp>     # 예: 20260519-101522
rm -rf .priv-storage
cp -a tmp-igbkp/migrate-backup-$TS/priv-storage .priv-storage
cp -a tmp-igbkp/migrate-backup-$TS/tmp-igbkp/codex-relay-*.sh tmp-igbkp/ 2>/dev/null || true
```

v5.x 로 복귀. global plugin 설치는 남아있음 (harmless — v5.x 가 무시).

---

## 도구별 마이그레이션 노트

Claude Code 가 v6.0 의 primary consumer (plugin 동작하는 유일한 곳). 다른 도구는 기존처럼 symlink 된 rule 파일 읽음:

| 도구 | 읽는 파일 | 동작 변화 |
|---|---|---|
| Claude Code | `CLAUDE.md` (+ plugin commands/hooks) | `/aips:*` command, native hook, statusline 획득 |
| Codex CLI | `AGENTS.md` (→ 동일 `.priv-storage/CLAUDE.md`) | 변화 없음 — slim 된 CLAUDE.md 그대로 |
| Cursor | `.cursorrules` | 변화 없음 — 동일 내용 |
| GitHub Copilot | `.vscode/settings.json` | 변화 없음 |

Section 8/9/10/12/13 가 globalize 되어 Codex / Cursor 사용자는 project 레벨에서 해당 rule 가시성 상실. 유지하려면:
- v5.x `CLAUDE.md` 원본 사본 보존 (예: `docs/CONVENTIONS-FULL.md` 리네임), 또는
- 해당 도구들에 `~/.claude/CLAUDE.md` 를 project 로 symlink.

대부분 팀은 global rule 로 충분; project 고유 override 는 `CLAUDE.md` Section 1-7 + 11 에 남음.

---

## Next steps

- v6.0 내부 구조: [`ARCHITECTURE.md`](./ARCHITECTURE.md)
- `/aips:status` 로 in-progress work + 최근 tool call 10건 확인.
- 모든 프로젝트 적용되는 global rule: `~/.claude/CLAUDE.md` 훑어보기.
