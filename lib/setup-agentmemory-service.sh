#!/usr/bin/env bash
# AIPS v6.0 — setup-agentmemory-service.sh
# Linux-only systemd user service installer for agentmemory MCP server.
# Idempotent. macOS / other OSes: no-op (prints skip message and exits 0).
#
# Usage:
#   bash lib/setup-agentmemory-service.sh
#
# Side effects:
#   - Writes  ~/.config/systemd/user/agentmemory.service
#   - Runs    systemctl --user daemon-reload && enable --now
#   - On first install, prints bilingual setup banner and touches
#     ~/.config/aips/.agentmemory-first-install-shown to suppress next time.

set -euo pipefail

# ---------- color / logging ----------
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_RESET="$(tput sgr0)"; C_BLUE="$(tput setaf 4)"; C_GREEN="$(tput setaf 2)"
  C_YELLOW="$(tput setaf 3)"; C_RED="$(tput setaf 1)"
else
  C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi
log()  { printf "%s[agentmemory]%s %s\n" "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf "%s[ok]%s %s\n"          "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf "%s[warn]%s %s\n"        "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf "%s[error]%s %s\n"       "$C_RED"    "$C_RESET" "$*" >&2; }
skip() { printf "%s[skip]%s %s\n"        "$C_YELLOW" "$C_RESET" "$*"; }

# ---------- OS gate ----------
UNAME="$(uname -s 2>/dev/null || echo unknown)"
if [ "$UNAME" != "Linux" ]; then
  skip "systemd setup is Linux-only. macOS users: run agentmemory manually via npx."
  skip "  macOS 사용자: npx 로 agentmemory 직접 실행하세요."
  exit 0
fi

if ! command -v systemctl >/dev/null 2>&1; then
  skip "systemctl not found — agentmemory service step skipped."
  exit 0
fi

# ---------- already-active short-circuit ----------
if systemctl --user is-active --quiet agentmemory.service 2>/dev/null; then
  ok "agentmemory.service already active — no-op."
  exit 0
fi

# ---------- write unit file ----------
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT_FILE="$UNIT_DIR/agentmemory.service"
mkdir -p "$UNIT_DIR"

# Detect npx path; prefer ~/.local/bin/npx, fall back to PATH
NPX_BIN=""
if [ -x "$HOME/.local/bin/npx" ]; then
  NPX_BIN="%h/.local/bin/npx"
elif command -v npx >/dev/null 2>&1; then
  NPX_BIN="$(command -v npx)"
else
  err "npx not found — install Node.js >= 18.18 first."
  exit 1
fi
log "using npx: $NPX_BIN"

cat > "$UNIT_FILE" <<EOF
[Unit]
Description=AgentMemory MCP server + web viewer (ports 3111/3113)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$NPX_BIN -y @agentmemory/agentmemory
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=default.target
EOF
ok "wrote $UNIT_FILE"

# ---------- enable + start ----------
log "systemctl --user daemon-reload"
systemctl --user daemon-reload

log "systemctl --user enable --now agentmemory.service"
if systemctl --user enable --now agentmemory.service 2>&1; then
  ok "service enabled and started"
else
  warn "enable --now returned non-zero — check 'systemctl --user status agentmemory.service'"
fi

# ---------- health poll (up to 10s) ----------
log "polling health (up to 10s)…"
HEALTHY=0
for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -sf http://127.0.0.1:3111/health >/dev/null 2>&1; then HEALTHY=1; break; fi
  if command -v nc >/dev/null 2>&1 && nc -z 127.0.0.1 3113 >/dev/null 2>&1; then HEALTHY=1; break; fi
  sleep 1
done

if [ "$HEALTHY" = "1" ]; then
  ok "agentmemory healthy (ports 3111/3113 responding)"
else
  warn "agentmemory not responding yet — service may still be starting. Check:"
  warn "  systemctl --user status agentmemory.service"
  warn "  journalctl --user -u agentmemory.service -n 50"
fi

# ---------- first-install banner ----------
BANNER_MARK_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/aips"
BANNER_MARK="$BANNER_MARK_DIR/.agentmemory-first-install-shown"
mkdir -p "$BANNER_MARK_DIR"

if [ ! -f "$BANNER_MARK" ]; then
  cat <<'BANNER'

────────────────────────────────────────────────────────────────────
  AgentMemory — first-install setup
  AgentMemory 최초 설치 가이드
────────────────────────────────────────────────────────────────────

  1. Verify the service is running:
     서비스 동작 확인:
       systemctl --user status agentmemory.service

  2. Open the web viewer in a browser and copy your token:
     브라우저에서 웹 뷰어 열고 토큰 복사:
       http://127.0.0.1:3113

  3. Initialize for the current project:
     현재 프로젝트에 초기화:
       agentmemory init --auto

  4. From inside Claude Code, verify wiring:
     Claude Code 안에서 연결 확인:
       /am:health

  Optional: keep the service running after logout (no sudo prompt here —
  copy and run manually if you want):
  로그아웃 후에도 계속 실행하려면 (필요 시 수동 실행):
       loginctl enable-linger "$USER"

────────────────────────────────────────────────────────────────────

BANNER
  touch "$BANNER_MARK"
fi

exit 0
