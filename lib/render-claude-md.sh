#!/usr/bin/env bash
# AIPS v6.0 — render-claude-md.sh
# Render templates/CLAUDE.md.tmpl using values from detect-project.sh into
# <PROJECT_ROOT>/.priv-storage/CLAUDE.md.
#
# Usage:
#   bash lib/render-claude-md.sh <PROJECT_ROOT> [TEMPLATE_PATH]
#
# Defaults:
#   TEMPLATE_PATH = $AIPS_TEMPLATE_DIR/CLAUDE.md.tmpl
#                 or  <plugin-cache>/templates/CLAUDE.md.tmpl
#                 or  <script-dir>/../templates/CLAUDE.md.tmpl
#
# Idempotent: overwrites .priv-storage/CLAUDE.md (rendered from template).
# If a CLAUDE.md already exists and contains user content beyond the template
# placeholders, the existing file is preserved and a *.new is written alongside.

set -euo pipefail

# ---------- color / logging ----------
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_RESET="$(tput sgr0)"; C_BLUE="$(tput setaf 4)"; C_GREEN="$(tput setaf 2)"
  C_YELLOW="$(tput setaf 3)"; C_RED="$(tput setaf 1)"
else
  C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi
log()  { printf "%s[render]%s %s\n" "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf "%s[ok]%s %s\n"     "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf "%s[warn]%s %s\n"   "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf "%s[error]%s %s\n"  "$C_RED"    "$C_RESET" "$*" >&2; }

# ---------- args ----------
ROOT="${1:-}"
TEMPLATE="${2:-}"
if [ -z "$ROOT" ]; then
  err "usage: $(basename "$0") <PROJECT_ROOT> [TEMPLATE_PATH]"; exit 1
fi
ROOT="${ROOT%/}"
if [ ! -d "$ROOT" ]; then err "PROJECT_ROOT not a directory: $ROOT"; exit 1; fi

# resolve script dir
SCRIPT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$TEMPLATE" ]; then
  for candidate in \
    "${AIPS_TEMPLATE_DIR:-}/CLAUDE.md.tmpl" \
    "$SCRIPT_DIR/../templates/CLAUDE.md.tmpl" \
    "$HOME/.claude/plugins/cache/AIPS/AIPS/templates/CLAUDE.md.tmpl" \
  ; do
    [ -n "$candidate" ] && [ -f "$candidate" ] && TEMPLATE="$candidate" && break
  done
fi
if [ -z "$TEMPLATE" ] || [ ! -f "$TEMPLATE" ]; then
  err "template not found (searched AIPS_TEMPLATE_DIR, script-relative, plugin cache)"
  exit 1
fi
log "template: $TEMPLATE"

# ---------- collect values from detect-project.sh ----------
DETECT="$SCRIPT_DIR/detect-project.sh"
if [ ! -f "$DETECT" ]; then err "detect-project.sh missing at $DETECT"; exit 1; fi

# shellcheck disable=SC1090
eval "$(bash "$DETECT" "$ROOT")"

# ---------- derive sensible defaults for template vars ----------
: "${PROJECT_NAME:=$(basename "$ROOT")}"
: "${LANG:=Unknown}"
: "${FRAMEWORK:=}"
: "${PKG_MGR:=}"
: "${GIT_REMOTE:=}"
: "${DEPLOYMENT:=}"

LICENSE="MIT"
[ -f "$ROOT/LICENSE" ] && head -1 "$ROOT/LICENSE" | grep -qiE 'apache'  && LICENSE="Apache-2.0"
[ -f "$ROOT/LICENSE" ] && head -1 "$ROOT/LICENSE" | grep -qiE 'bsd'     && LICENSE="BSD"
[ -f "$ROOT/LICENSE" ] && head -1 "$ROOT/LICENSE" | grep -qiE 'gpl'     && LICENSE="GPL"

ARCHITECTURE="(describe in 1-2 sentences after first review)"
TARGET_PLATFORM="Linux / macOS / Windows"
[ "$LANG" = "JavaScript" ] || [ "$LANG" = "TypeScript" ] && TARGET_PLATFORM="Browser / Node.js"
[ "$LANG" = "Rust" ] && TARGET_PLATFORM="Linux / macOS / Windows (native binary)"
[ "$LANG" = "Go"   ] && TARGET_PLATFORM="Linux / macOS / Windows (native binary)"

# language-keyed defaults
case "$LANG" in
  Python)
    STYLE_GUIDE="PEP 8 + ruff"
    FORMATTER="ruff format"; LINTER="ruff check"
    FORMAT_CMD="ruff format ."; LINT_CMD="ruff check ."
    INSTALL_CMD="$PKG_MGR install"; BUILD_CMD="(none — interpreted)"; TEST_CMD="pytest"
    PACKAGE_MANAGER="$PKG_MGR"; ADD_DEP_CMD="$PKG_MGR add"
    ENTRY_POINT="main.py"
    ;;
  TypeScript|JavaScript)
    STYLE_GUIDE="ESLint + Prettier"
    FORMATTER="prettier"; LINTER="eslint"
    FORMAT_CMD="$PKG_MGR run format"; LINT_CMD="$PKG_MGR run lint"
    INSTALL_CMD="$PKG_MGR install"; BUILD_CMD="$PKG_MGR run build"; TEST_CMD="$PKG_MGR test"
    PACKAGE_MANAGER="$PKG_MGR"; ADD_DEP_CMD="$PKG_MGR add"
    ENTRY_POINT="src/index.${LANG,,}"
    [ "$LANG" = "TypeScript" ] && ENTRY_POINT="src/index.ts"
    [ "$LANG" = "JavaScript" ] && ENTRY_POINT="src/index.js"
    ;;
  Rust)
    STYLE_GUIDE="rustfmt + clippy"
    FORMATTER="rustfmt"; LINTER="clippy"
    FORMAT_CMD="cargo fmt"; LINT_CMD="cargo clippy -- -D warnings"
    INSTALL_CMD="cargo fetch"; BUILD_CMD="cargo build --release"; TEST_CMD="cargo test"
    PACKAGE_MANAGER="cargo"; ADD_DEP_CMD="cargo add"
    ENTRY_POINT="src/main.rs"
    ;;
  Go)
    STYLE_GUIDE="gofmt + go vet"
    FORMATTER="gofmt"; LINTER="go vet"
    FORMAT_CMD="gofmt -w ."; LINT_CMD="go vet ./..."
    INSTALL_CMD="go mod download"; BUILD_CMD="go build ./..."; TEST_CMD="go test ./..."
    PACKAGE_MANAGER="go-modules"; ADD_DEP_CMD="go get"
    ENTRY_POINT="main.go"
    ;;
  Java/Kotlin)
    STYLE_GUIDE="google-java-format / ktlint"
    FORMATTER="google-java-format"; LINTER="checkstyle"
    if [ "$PKG_MGR" = "maven" ]; then
      FORMAT_CMD="mvn spotless:apply"; LINT_CMD="mvn verify"
      INSTALL_CMD="mvn install -DskipTests"; BUILD_CMD="mvn package"; TEST_CMD="mvn test"
      ADD_DEP_CMD="(edit pom.xml)"
    else
      FORMAT_CMD="gradle spotlessApply"; LINT_CMD="gradle check"
      INSTALL_CMD="gradle build -x test"; BUILD_CMD="gradle build"; TEST_CMD="gradle test"
      ADD_DEP_CMD="(edit build.gradle)"
    fi
    PACKAGE_MANAGER="$PKG_MGR"
    ENTRY_POINT="src/main/java/Main.java"
    ;;
  CSharp)
    STYLE_GUIDE=".NET coding conventions"
    FORMATTER="dotnet format"; LINTER="dotnet build /warnaserror"
    FORMAT_CMD="dotnet format"; LINT_CMD="dotnet build /warnaserror"
    INSTALL_CMD="dotnet restore"; BUILD_CMD="dotnet build"; TEST_CMD="dotnet test"
    PACKAGE_MANAGER="nuget"; ADD_DEP_CMD="dotnet add package"
    ENTRY_POINT="Program.cs"
    ;;
  Ruby)
    STYLE_GUIDE="rubocop"
    FORMATTER="rubocop -A"; LINTER="rubocop"
    FORMAT_CMD="rubocop -A"; LINT_CMD="rubocop"
    INSTALL_CMD="bundle install"; BUILD_CMD="(none — interpreted)"; TEST_CMD="bundle exec rspec"
    PACKAGE_MANAGER="bundler"; ADD_DEP_CMD="bundle add"
    ENTRY_POINT="lib/main.rb"
    ;;
  *)
    STYLE_GUIDE="(language-specific)"
    FORMATTER=""; LINTER=""
    FORMAT_CMD="(format command)"; LINT_CMD="(lint command)"
    INSTALL_CMD="(install command)"; BUILD_CMD="(build command)"; TEST_CMD="(test command)"
    PACKAGE_MANAGER="(package manager)"; ADD_DEP_CMD="(add-dep command)"
    ENTRY_POINT="(entry point)"
    ;;
esac

# framework-specific bullet defaults
FRAMEWORK_CONVENTION_1="(framework-specific convention 1)"
FRAMEWORK_CONVENTION_2="(framework-specific convention 2)"
case "$FRAMEWORK" in
  React|React+Vite|Next.js)
    FRAMEWORK_CONVENTION_1="Functional components + hooks; no class components."
    FRAMEWORK_CONVENTION_2="Prefer server components / SSR where Next.js supports it."
    ;;
  Django|FastAPI|Flask)
    FRAMEWORK_CONVENTION_1="Use dependency injection / context managers; avoid module-level mutable state."
    FRAMEWORK_CONVENTION_2="All HTTP routes return typed responses; validate inputs at the boundary."
    ;;
  Axum|Actix-Web|Rocket)
    FRAMEWORK_CONVENTION_1="Use typed extractors; avoid runtime panics in handlers."
    FRAMEWORK_CONVENTION_2="Prefer tower middleware composition over ad-hoc wrappers."
    ;;
esac

# design goals — placeholders the user customizes
DESIGN_GOAL_1="(primary goal — what this project optimizes for)"
DESIGN_GOAL_2="(secondary goal — non-functional priority)"
DESIGN_GOAL_3="(tertiary goal — quality bar / SLA)"

MERGE_STRATEGY="squash-merge PRs to \`main\`"
CI_DESCRIPTION="(none yet — manual verification per Section 5)"
[ -d "$ROOT/.github/workflows" ] && CI_DESCRIPTION="GitHub Actions (see \`.github/workflows/\`)"

# team placeholders
TEAM_1_NAME="backend";   TEAM_1_ID="backend-team";  TEAM_1_PATHS="src/server/**"; TEAM_1_DOMAIN="API + DB"; TEAM_1_MODEL="sonnet"; TEAM_1_EFFORT="medium"
TEAM_2_NAME="frontend";  TEAM_2_ID="frontend-team"; TEAM_2_PATHS="src/client/**"; TEAM_2_DOMAIN="UI + state"; TEAM_2_MODEL="sonnet"; TEAM_2_EFFORT="medium"

# ---------- render via sed (portable, no envsubst dep) ----------
TARGET_DIR="$ROOT/.priv-storage"
TARGET="$TARGET_DIR/CLAUDE.md"
mkdir -p "$TARGET_DIR"

# Helper: escape for sed-replacement RHS
esc() { printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g' -e 's/$/\\n/' | tr -d '\n' | sed 's/\\n$//'; }

TMP="$(mktemp)"
cp "$TEMPLATE" "$TMP"

substitute() {
  local key="$1" val="$2"
  local sval; sval="$(esc "$val")"
  # use | as sed delimiter to allow / in values
  sed -i.bak -e "s|{{${key}}}|${sval}|g" "$TMP" && rm -f "$TMP.bak"
}

substitute PROJECT_NAME           "$PROJECT_NAME"
substitute LICENSE                "$LICENSE"
substitute LANG                   "$LANG"
substitute FRAMEWORK              "${FRAMEWORK:-(none detected)}"
substitute ARCHITECTURE           "$ARCHITECTURE"
substitute TARGET_PLATFORM        "$TARGET_PLATFORM"
substitute DEPLOYMENT             "${DEPLOYMENT:-(not configured)}"
substitute DESIGN_GOAL_1          "$DESIGN_GOAL_1"
substitute DESIGN_GOAL_2          "$DESIGN_GOAL_2"
substitute DESIGN_GOAL_3          "$DESIGN_GOAL_3"
substitute ENTRY_POINT            "$ENTRY_POINT"
substitute STYLE_GUIDE            "$STYLE_GUIDE"
substitute FORMATTER              "${FORMATTER:-(none)}"
substitute LINTER                 "${LINTER:-(none)}"
substitute FORMAT_CMD             "$FORMAT_CMD"
substitute LINT_CMD               "$LINT_CMD"
substitute INSTALL_CMD            "$INSTALL_CMD"
substitute BUILD_CMD              "$BUILD_CMD"
substitute TEST_CMD               "$TEST_CMD"
substitute PACKAGE_MANAGER        "$PACKAGE_MANAGER"
substitute ADD_DEP_CMD            "$ADD_DEP_CMD"
substitute MERGE_STRATEGY         "$MERGE_STRATEGY"
substitute CI_DESCRIPTION         "$CI_DESCRIPTION"
substitute FRAMEWORK_CONVENTION_1 "$FRAMEWORK_CONVENTION_1"
substitute FRAMEWORK_CONVENTION_2 "$FRAMEWORK_CONVENTION_2"
substitute TEAM_1_NAME            "$TEAM_1_NAME"
substitute TEAM_1_ID              "$TEAM_1_ID"
substitute TEAM_1_PATHS           "$TEAM_1_PATHS"
substitute TEAM_1_DOMAIN          "$TEAM_1_DOMAIN"
substitute TEAM_1_MODEL           "$TEAM_1_MODEL"
substitute TEAM_1_EFFORT          "$TEAM_1_EFFORT"
substitute TEAM_2_NAME            "$TEAM_2_NAME"
substitute TEAM_2_ID              "$TEAM_2_ID"
substitute TEAM_2_PATHS           "$TEAM_2_PATHS"
substitute TEAM_2_DOMAIN          "$TEAM_2_DOMAIN"
substitute TEAM_2_MODEL           "$TEAM_2_MODEL"
substitute TEAM_2_EFFORT          "$TEAM_2_EFFORT"

# ---------- write target (preserve user edits) ----------
if [ -f "$TARGET" ] && ! grep -q '{{[A-Z_]\+}}' "$TARGET" 2>/dev/null; then
  # existing file looks fully rendered (no placeholders) — preserve, write .new
  cp "$TMP" "$TARGET.new"
  warn "$TARGET already rendered — wrote $TARGET.new (review diff manually)"
else
  cp "$TMP" "$TARGET"
  ok "rendered $TARGET ($(wc -l <"$TARGET") lines, lang=$LANG, framework=${FRAMEWORK:-none})"
fi
rm -f "$TMP"
