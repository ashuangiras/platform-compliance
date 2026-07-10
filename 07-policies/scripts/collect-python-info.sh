#!/usr/bin/env bash
# collect-python-info.sh
#
# Detects Python projects in a repository and collects code-quality and testing
# signals for the QUA and TST control domains (python context).
#
# The collector is defensive: if a required tool is missing it reports
# "unavailable" for that check and continues.  Policies treat an unavailable
# tool as a warning-level gap, not a hard error.
#
# Usage: ./collect-python-info.sh [repo-root]
# Output: JSON to stdout for QUA-001, QUA-002, QUA-004 and TST-001..002 (python context)
#
# JSON field contract:
#   has_python_project                   bool
#   quality.lint.result                  "pass"|"fail"|"unavailable"
#   quality.lint_config_present          bool
#   quality.format.result                "pass"|"fail"|"unavailable"
#   quality.typecheck.result             "pass"|"fail"|"unavailable"
#   quality.typecheck_config_present     bool
#   testing.tests_present                bool
#   testing.test_file_count              number
#   testing.test_result                  "pass"|"fail"|"unavailable"
#   testing.coverage_percent             number|null

set -euo pipefail

REPO_ROOT="${1:-.}"
REPO_NAME=$(basename "$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$REPO_ROOT")")

cd "$REPO_ROOT"

# ── Detect Python project ─────────────────────────────────────────────────────
HAS_PYTHON_PROJECT="false"
if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
  HAS_PYTHON_PROJECT="true"
fi

# ── Tool availability ─────────────────────────────────────────────────────────
PYTHON3_AVAILABLE="false"
RUFF_AVAILABLE="false"
MYPY_AVAILABLE="false"
PYTEST_AVAILABLE="false"

command -v python3 >/dev/null 2>&1 && PYTHON3_AVAILABLE="true"
command -v ruff    >/dev/null 2>&1 && RUFF_AVAILABLE="true"
command -v mypy    >/dev/null 2>&1 && MYPY_AVAILABLE="true"
command -v pytest  >/dev/null 2>&1 && PYTEST_AVAILABLE="true"

# ── QUA-001: Lint (ruff check) ───────────────────────────────────────────────
# Detect ruff config: pyproject.toml [tool.ruff], ruff.toml, or .ruff.toml
LINT_CONFIG_PRESENT="false"
if [ -f "ruff.toml" ] || [ -f ".ruff.toml" ]; then
  LINT_CONFIG_PRESENT="true"
elif [ -f "pyproject.toml" ] && grep -q '\[tool\.ruff\]' pyproject.toml 2>/dev/null; then
  LINT_CONFIG_PRESENT="true"
fi

LINT_EXIT="unavailable"
if [ "$HAS_PYTHON_PROJECT" = "true" ] && [ "$RUFF_AVAILABLE" = "true" ]; then
  if ruff check . >/tmp/ruff-check-out.txt 2>&1; then
    LINT_EXIT="pass"
  else
    LINT_EXIT="fail"
  fi
fi

# ── QUA-002: Format (ruff format --check) ────────────────────────────────────
FORMAT_EXIT="unavailable"
if [ "$HAS_PYTHON_PROJECT" = "true" ] && [ "$RUFF_AVAILABLE" = "true" ]; then
  if ruff format --check . >/tmp/ruff-format-out.txt 2>&1; then
    FORMAT_EXIT="pass"
  else
    FORMAT_EXIT="fail"
  fi
fi

# ── QUA-004: Type-check (mypy) ────────────────────────────────────────────────
# No QUA-003: Python has no compile step.
# Detect mypy config: pyproject.toml [tool.mypy], mypy.ini, setup.cfg [mypy], .mypy.ini
TYPECHECK_CONFIG_PRESENT="false"
if [ -f "mypy.ini" ] || [ -f ".mypy.ini" ]; then
  TYPECHECK_CONFIG_PRESENT="true"
elif [ -f "pyproject.toml" ] && grep -q '\[tool\.mypy\]' pyproject.toml 2>/dev/null; then
  TYPECHECK_CONFIG_PRESENT="true"
elif [ -f "setup.cfg" ] && grep -q '^\[mypy\]' setup.cfg 2>/dev/null; then
  TYPECHECK_CONFIG_PRESENT="true"
fi

TYPECHECK_EXIT="unavailable"
if [ "$HAS_PYTHON_PROJECT" = "true" ] && [ "$MYPY_AVAILABLE" = "true" ]; then
  if mypy . >/tmp/mypy-out.txt 2>&1; then
    TYPECHECK_EXIT="pass"
  else
    TYPECHECK_EXIT="fail"
  fi
fi

# ── TST-001/002: Tests exist + coverage (pytest) ─────────────────────────────
TEST_FILE_COUNT=$(find . \( -name "test_*.py" -o -name "*_test.py" \) \
                    -not -path "*/.git/*" -not -path "*/__pycache__/*" \
                    2>/dev/null | grep -c . || true)
TEST_FILE_COUNT=${TEST_FILE_COUNT:-0}

TESTS_PRESENT="false"
[ "$TEST_FILE_COUNT" -gt 0 ] 2>/dev/null && TESTS_PRESENT="true"

TEST_EXIT="unavailable"
COVERAGE_PERCENT="null"

if [ "$HAS_PYTHON_PROJECT" = "true" ] && [ "$PYTEST_AVAILABLE" = "true" ] && [ "$TESTS_PRESENT" = "true" ]; then
  if pytest >/tmp/pytest-out.txt 2>&1; then
    TEST_EXIT="pass"
  else
    TEST_EXIT="fail"
  fi
  # Extract coverage percentage from pytest --cov output
  # "TOTAL  <stmts>  <miss>  <cover>%"
  COV_LINE=$(pytest --cov --cov-report=term-missing >/tmp/pytest-cov-out.txt 2>&1 && \
             grep "^TOTAL" /tmp/pytest-cov-out.txt 2>/dev/null | tail -1 || true)
  COV=$(echo "${COV_LINE:-}" | awk '{print $NF}' | tr -d '%' 2>/dev/null || echo "")
  [ -n "$COV" ] && COVERAGE_PERCENT="$COV"
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
    "language": "python",
    "has_python_project": to_bool("${HAS_PYTHON_PROJECT}"),
    "tools": {
        "python3_available": to_bool("${PYTHON3_AVAILABLE}"),
        "ruff_available":    to_bool("${RUFF_AVAILABLE}"),
        "mypy_available":    to_bool("${MYPY_AVAILABLE}"),
        "pytest_available":  to_bool("${PYTEST_AVAILABLE}"),
    },
    "quality": {
        "lint":      {"result": "${LINT_EXIT}",      "lint_config_present":       to_bool("${LINT_CONFIG_PRESENT}")},
        "format":    {"result": "${FORMAT_EXIT}"},
        "typecheck": {"result": "${TYPECHECK_EXIT}", "typecheck_config_present":  to_bool("${TYPECHECK_CONFIG_PRESENT}")},
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
