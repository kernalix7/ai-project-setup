#!/usr/bin/env bash
# AIPS v6.0 — detect-project.sh
# Auto-detect project language/framework/package-manager from a project root.
# Outputs key=value lines on stdout suitable for `eval` or `source`.
#
# Usage:
#   bash lib/detect-project.sh [PROJECT_ROOT]      # default: $PWD
#   eval "$(bash lib/detect-project.sh /path/to/project)"
#
# Output keys (always emitted, possibly empty):
#   PROJECT_NAME, LANG, FRAMEWORK, PKG_MGR, GIT_REMOTE, DEPLOYMENT

set -euo pipefail

ROOT="${1:-$PWD}"
ROOT="${ROOT%/}"

if [ ! -d "$ROOT" ]; then
  printf "PROJECT_NAME=\nLANG=Unknown\nFRAMEWORK=\nPKG_MGR=\nGIT_REMOTE=\nDEPLOYMENT=\n"
  exit 0
fi

# ---------- project name ----------
PROJECT_NAME="$(basename "$ROOT")"

# ---------- git remote ----------
GIT_REMOTE=""
if [ -d "$ROOT/.git" ] || git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  GIT_REMOTE="$(git -C "$ROOT" config --get remote.origin.url 2>/dev/null || true)"
fi

# ---------- helpers ----------
has()     { [ -e "$ROOT/$1" ]; }
glob1()   { compgen -G "$ROOT/$1" >/dev/null 2>&1; }
greph()   { grep -l -E "$1" "$ROOT/$2" 2>/dev/null | head -1; }

# ---------- language detection ----------
LANG="Unknown"
FRAMEWORK=""
PKG_MGR=""

if has "pyproject.toml" || has "requirements.txt" || has "setup.py" || has "Pipfile"; then
  LANG="Python"
  if   has "poetry.lock";    then PKG_MGR="poetry"
  elif has "Pipfile";        then PKG_MGR="pipenv"
  elif has "uv.lock";        then PKG_MGR="uv"
  elif has "pdm.lock";       then PKG_MGR="pdm"
  else                            PKG_MGR="pip"
  fi
  # framework hints (single-pass grep)
  if has "pyproject.toml" || has "requirements.txt"; then
    DEPS_FILE="$ROOT/pyproject.toml"; [ -f "$DEPS_FILE" ] || DEPS_FILE="$ROOT/requirements.txt"
    if   grep -qiE '(^|[^a-z])django([^a-z]|$)'  "$DEPS_FILE" 2>/dev/null; then FRAMEWORK="Django"
    elif grep -qiE '(^|[^a-z])fastapi'           "$DEPS_FILE" 2>/dev/null; then FRAMEWORK="FastAPI"
    elif grep -qiE '(^|[^a-z])flask'             "$DEPS_FILE" 2>/dev/null; then FRAMEWORK="Flask"
    elif grep -qiE '(^|[^a-z])(torch|tensorflow|jax)' "$DEPS_FILE" 2>/dev/null; then FRAMEWORK="ML/AI"
    fi
  fi

elif has "package.json"; then
  if has "tsconfig.json"; then LANG="TypeScript"; else LANG="JavaScript"; fi
  if   has "pnpm-lock.yaml"; then PKG_MGR="pnpm"
  elif has "yarn.lock";      then PKG_MGR="yarn"
  elif has "bun.lockb";      then PKG_MGR="bun"
  else                            PKG_MGR="npm"
  fi
  PKG_JSON="$ROOT/package.json"
  if   grep -qE '"next"[[:space:]]*:'        "$PKG_JSON" 2>/dev/null; then FRAMEWORK="Next.js"
  elif grep -qE '"nuxt"[[:space:]]*:'        "$PKG_JSON" 2>/dev/null; then FRAMEWORK="Nuxt"
  elif grep -qE '"svelte(kit)?"[[:space:]]*:' "$PKG_JSON" 2>/dev/null; then FRAMEWORK="SvelteKit"
  elif grep -qE '"@remix-run/'                "$PKG_JSON" 2>/dev/null; then FRAMEWORK="Remix"
  elif grep -qE '"react"[[:space:]]*:'       "$PKG_JSON" 2>/dev/null; then
    if grep -qE '"vite"[[:space:]]*:' "$PKG_JSON" 2>/dev/null; then FRAMEWORK="React+Vite"
    else FRAMEWORK="React"; fi
  elif grep -qE '"vue"[[:space:]]*:'         "$PKG_JSON" 2>/dev/null; then FRAMEWORK="Vue"
  elif grep -qE '"express"[[:space:]]*:'     "$PKG_JSON" 2>/dev/null; then FRAMEWORK="Express"
  elif grep -qE '"@nestjs/core"'             "$PKG_JSON" 2>/dev/null; then FRAMEWORK="NestJS"
  elif grep -qE '"electron"[[:space:]]*:'    "$PKG_JSON" 2>/dev/null; then FRAMEWORK="Electron"
  fi

elif has "Cargo.toml"; then
  LANG="Rust"
  PKG_MGR="cargo"
  if   grep -qiE '^axum[[:space:]]*='     "$ROOT/Cargo.toml" 2>/dev/null; then FRAMEWORK="Axum"
  elif grep -qiE '^actix-web[[:space:]]*=' "$ROOT/Cargo.toml" 2>/dev/null; then FRAMEWORK="Actix-Web"
  elif grep -qiE '^tauri[[:space:]]*='    "$ROOT/Cargo.toml" 2>/dev/null; then FRAMEWORK="Tauri"
  elif grep -qiE '^bevy[[:space:]]*='     "$ROOT/Cargo.toml" 2>/dev/null; then FRAMEWORK="Bevy"
  elif grep -qiE '^rocket[[:space:]]*='   "$ROOT/Cargo.toml" 2>/dev/null; then FRAMEWORK="Rocket"
  fi

elif has "go.mod"; then
  LANG="Go"
  PKG_MGR="go-modules"
  if   grep -qiE 'gin-gonic/gin'   "$ROOT/go.mod" 2>/dev/null; then FRAMEWORK="Gin"
  elif grep -qiE 'labstack/echo'   "$ROOT/go.mod" 2>/dev/null; then FRAMEWORK="Echo"
  elif grep -qiE 'gofiber/fiber'   "$ROOT/go.mod" 2>/dev/null; then FRAMEWORK="Fiber"
  fi

elif has "pom.xml" || glob1 "build.gradle*"; then
  LANG="Java/Kotlin"
  if has "pom.xml"; then PKG_MGR="maven"; else PKG_MGR="gradle"; fi
  GRADLE_FILE=""
  for f in "$ROOT/build.gradle" "$ROOT/build.gradle.kts"; do
    [ -f "$f" ] && GRADLE_FILE="$f" && break
  done
  if [ -f "$ROOT/pom.xml" ]; then
    if   grep -qiE 'spring-boot'        "$ROOT/pom.xml" 2>/dev/null; then FRAMEWORK="Spring Boot"
    elif grep -qiE 'quarkus'            "$ROOT/pom.xml" 2>/dev/null; then FRAMEWORK="Quarkus"
    fi
  elif [ -n "$GRADLE_FILE" ]; then
    if   grep -qiE 'org\.springframework\.boot' "$GRADLE_FILE" 2>/dev/null; then FRAMEWORK="Spring Boot"
    elif grep -qiE 'kotlin-android'             "$GRADLE_FILE" 2>/dev/null; then FRAMEWORK="Android (Kotlin)"
    fi
  fi

elif glob1 "*.csproj" || glob1 "*.sln"; then
  LANG="CSharp"
  PKG_MGR="nuget"
  if compgen -G "$ROOT"/*.csproj >/dev/null 2>&1; then
    if grep -qiE 'Microsoft\.AspNetCore' "$ROOT"/*.csproj 2>/dev/null; then FRAMEWORK="ASP.NET Core"; fi
  fi

elif has "Gemfile"; then
  LANG="Ruby"
  PKG_MGR="bundler"
  if   grep -qiE "^gem ['\"]rails['\"]"   "$ROOT/Gemfile" 2>/dev/null; then FRAMEWORK="Rails"
  elif grep -qiE "^gem ['\"]sinatra['\"]" "$ROOT/Gemfile" 2>/dev/null; then FRAMEWORK="Sinatra"
  fi
fi

# ---------- deployment hint (best-effort) ----------
DEPLOYMENT=""
if   has "vercel.json";          then DEPLOYMENT="Vercel"
elif has "netlify.toml";         then DEPLOYMENT="Netlify"
elif has "fly.toml";             then DEPLOYMENT="Fly.io"
elif has "Dockerfile";           then DEPLOYMENT="Docker"
elif has "render.yaml";          then DEPLOYMENT="Render"
elif has ".github/workflows";    then DEPLOYMENT="GitHub Actions"
fi

# ---------- emit ----------
printf 'PROJECT_NAME=%s\n' "$PROJECT_NAME"
printf 'LANG=%s\n'         "$LANG"
printf 'FRAMEWORK=%s\n'    "$FRAMEWORK"
printf 'PKG_MGR=%s\n'      "$PKG_MGR"
printf 'GIT_REMOTE=%s\n'   "$GIT_REMOTE"
printf 'DEPLOYMENT=%s\n'   "$DEPLOYMENT"
