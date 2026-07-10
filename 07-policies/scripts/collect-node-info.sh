#!/usr/bin/env bash
# collect-node-info.sh
#
# Detects Node.js projects in a repository and collects code-quality and testing
# signals for the QUA and TST control domains (node context).
#
# The collector is defensive: if a required tool is missing it reports
# "unavailable" for that check and continues.  Policies treat an unavailable
# tool as a warning-level gap, not a hard error.
#
# Usage: ./collect-node-info.sh [repo-root]
# Output: JSON to stdout for QUA-001..004 and TST-001..002 (node context)
#
# JSON field contract:
#   has_node_module                      bool
#   quality.lint.result                  "pass"|"fail"|"unavailable"
#   quality.lint_config_present          bool
#   quality.format.result                "pass"|"fail"|"unavailable"
#   quality.build.result                 "pass"|"fail"|"unavailable"
#   quality.build_config_present         bool
#   quality.typecheck.result             "pass"|"fail"|"unavailable"
#   testing.tests_present                bool
#   testing.test_file_count              number
#   testing.test_result                  "pass"|"fail"|"unavailable"
#   testing.coverage_percent             number|null

set -euo pipefail

REPO_ROOT="${1:-.}"
REPO_NAME=$(basename "$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$REPO_ROOT")")

cd "$REPO_ROOT"

# ── Detect Node.js project ────────────────────────────────────────────────────
HAS_NODE_MODULE="false"
[ -f "package.json" ] && HAS_NODE_MODULE="true"

# ── Tool availability ─────────────────────────────────────────────────────────
NODE_AVAILABLE="false"
NPM_AVAILABLE="false"
ESLINT_AVAILABLE="false"
TSC_AVAILABLE="false"
JEST_AVAILABLE="false"
VITEST_AVAILABLE="false"
PRETTIER_AVAILABLE="false"

command -v node    >/dev/null 2>&1 && NODE_AVAILABLE="true"
command -v npm     >/dev/null 2>&1 && NPM_AVAILABLE="true"
command -v eslint  >/dev/null 2>&1 && ESLINT_AVAILABLE="true"
command -v tsc     >/dev/null 2>&1 && TSC_AVAILABLE="true"
command -v jest    >/dev/null 2>&1 && JEST_AVAILABLE="true"
command -v vitest  >/dev/null 2>&1 && VITEST_AVAILABLE="true"
command -v prettier >/dev/null 2>&1 && PRETTIER_AVAILABLE="true"

# Also probe local node_modules/.bin for tools installed locally
if [ -f "node_modules/.bin/eslint" ];   then ESLINT_AVAILABLE="true";   fi
if [ -f "node_modules/.bin/tsc" ];      then TSC_AVAILABLE="true";      fi
if [ -f "node_modules/.bin/jest" ];     then JEST_AVAILABLE="true";     fi
if [ -f "node_modules/.bin/vitest" ];   then VITEST_AVAILABLE="true";   fi
if [ -f "node_modules/.bin/prettier" ]; then PRETTIER_AVAILABLE="true"; fi

# ── QUA-001: Linter (eslint) ─────────────────────────────────────────────────
LINT_CONFIG_PRESENT="false"
for cfg in .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.yaml .eslintrc.yml \
           .eslintrc.json eslint.config.js eslint.config.mjs eslint.config.cjs; do
  [ -f "$cfg" ] && LINT_CONFIG_PRESENT="true" && break
done

LINT_EXIT="unavailable"
if [ "$HAS_NODE_MODULE" = "true" ] && [ "$ESLINT_AVAILABLE" = "true" ]; then
  ESLINT_BIN="eslint"
  [ -f "node_modules/.bin/eslint" ] && ESLINT_BIN="node_modules/.bin/eslint"
  if "$ESLINT_BIN" . >/tmp/eslint-out.txt 2>&1; then
    LINT_EXIT="pass"
  else
    LINT_EXIT="fail"
  fi
fi

# ── QUA-002: Formatting (prettier) ───────────────────────────────────────────
FORMAT_EXIT="unavailable"
if [ "$HAS_NODE_MODULE" = "true" ] && [ "$PRETTIER_AVAILABLE" = "true" ]; then
  PRETTIER_BIN="prettier"
  [ -f "node_modules/.bin/prettier" ] && PRETTIER_BIN="node_modules/.bin/prettier"
  if "$PRETTIER_BIN" --check . >/tmp/prettier-out.txt 2>&1; then
    FORMAT_EXIT="pass"
  else
    FORMAT_EXIT="fail"
  fi
fi

# ── QUA-003: Build/compile (tsc --noEmit) ────────────────────────────────────
BUILD_CONFIG_PRESENT="false"
[ -f "tsconfig.json" ] && BUILD_CONFIG_PRESENT="true"

BUILD_EXIT="unavailable"
if [ "$HAS_NODE_MODULE" = "true" ] && [ "$TSC_AVAILABLE" = "true" ] && [ "$BUILD_CONFIG_PRESENT" = "true" ]; then
  TSC_BIN="tsc"
  [ -f "node_modules/.bin/tsc" ] && TSC_BIN="node_modules/.bin/tsc"
  if "$TSC_BIN" --noEmit >/tmp/tsc-build-out.txt 2>&1; then
    BUILD_EXIT="pass"
  else
    BUILD_EXIT="fail"
  fi
fi

# ── QUA-004: Type-check (tsc --strict --noEmit) ───────────────────────────────
TYPECHECK_EXIT="unavailable"
if [ "$HAS_NODE_MODULE" = "true" ] && [ "$TSC_AVAILABLE" = "true" ]; then
  TSC_BIN="tsc"
  [ -f "node_modules/.bin/tsc" ] && TSC_BIN="node_modules/.bin/tsc"
  if "$TSC_BIN" --strict --noEmit >/tmp/tsc-strict-out.txt 2>&1; then
    TYPECHECK_EXIT="pass"
  else
    TYPECHECK_EXIT="fail"
  fi
fi

# ── TST-001/002: Tests exist + coverage ──────────────────────────────────────
TEST_FILE_COUNT=$(find . \( -name "*.test.ts" -o -name "*.spec.ts" \
                           -o -name "*.test.js" -o -name "*.spec.js" \) \
                    -not -path "*/node_modules/*" -not -path "*/.git/*" \
                    2>/dev/null | grep -c . || true)
TEST_FILE_COUNT=${TEST_FILE_COUNT:-0}

TESTS_PRESENT="false"
[ "$TEST_FILE_COUNT" -gt 0 ] 2>/dev/null && TESTS_PRESENT="true"

TEST_EXIT="unavailable"
COVERAGE_PERCENT="null"

if [ "$HAS_NODE_MODULE" = "true" ] && [ "$TESTS_PRESENT" = "true" ]; then
  if [ "$JEST_AVAILABLE" = "true" ]; then
    JEST_BIN="jest"
    [ -f "node_modules/.bin/jest" ] && JEST_BIN="node_modules/.bin/jest"
    if "$JEST_BIN" --coverage >/tmp/jest-out.txt 2>&1; then
      TEST_EXIT="pass"
    else
      TEST_EXIT="fail"
    fi
    # Extract coverage: Jest prints "All files | <stmts> | ..."
    COV=$(grep -E "^All files" /tmp/jest-out.txt 2>/dev/null \
          | awk -F'|' '{gsub(/ /,"",$2); print $2}' | head -1 || echo "")
    [ -n "$COV" ] && COVERAGE_PERCENT="$COV"
  elif [ "$VITEST_AVAILABLE" = "true" ]; then
    VITEST_BIN="vitest"
    [ -f "node_modules/.bin/vitest" ] && VITEST_BIN="node_modules/.bin/vitest"
    if "$VITEST_BIN" run --coverage >/tmp/vitest-out.txt 2>&1; then
      TEST_EXIT="pass"
    else
      TEST_EXIT="fail"
    fi
    # Extract coverage from vitest output: "All files | <num> |..."
    COV=$(grep -E "^All files" /tmp/vitest-out.txt 2>/dev/null \
          | awk -F'|' '{gsub(/ /,"",$2); print $2}' | head -1 || echo "")
    [ -n "$COV" ] && COVERAGE_PERCENT="$COV"
  fi
fi

# ── Emit JSON ─────────────────────────────────────────────────────────────────
python3 - "$REPO_NAME" <<PYTHON
import json, sys
repo_name = sys.argv[1]

def to_bool(s): return s == "true"
def to_num(s):
    try: return float(s)
    except (ValueError, TypeError): return None

output = {
    "repository": {"name": repo_name},
    "language": "node",
    "has_node_module": to_bool("${HAS_NODE_MODULE}"),
    "tools": {
        "node_available":    to_bool("${NODE_AVAILABLE}"),
        "npm_available":     to_bool("${NPM_AVAILABLE}"),
        "eslint_available":  to_bool("${ESLINT_AVAILABLE}"),
        "tsc_available":     to_bool("${TSC_AVAILABLE}"),
        "jest_available":    to_bool("${JEST_AVAILABLE}"),
        "vitest_available":  to_bool("${VITEST_AVAILABLE}"),
        "prettier_available":to_bool("${PRETTIER_AVAILABLE}"),
    },
    "quality": {
        "lint":       {"result": "${LINT_EXIT}",       "lint_config_present":   to_bool("${LINT_CONFIG_PRESENT}")},
        "format":     {"result": "${FORMAT_EXIT}"},
        "build":      {"result": "${BUILD_EXIT}",      "build_config_present":  to_bool("${BUILD_CONFIG_PRESENT}")},
        "typecheck":  {"result": "${TYPECHECK_EXIT}"},
    },
    "testing": {
        "tests_present":    to_bool("${TESTS_PRESENT}"),
        "test_file_count":  ${TEST_FILE_COUNT},
        "test_result":      "${TEST_EXIT}",
        "coverage_percent": to_num("${COVERAGE_PERCENT}"),
    },
}
print(json.dumps(output, indent=2, ensure_ascii=False, default=str))
PYTHON
