#!/usr/bin/env bash
# collect-go-info.sh
#
# Detects Go modules in a repository and collects code-quality and testing
# signals for the QUA and TST control domains (go context).
#
# The collector is defensive: if the Go toolchain or a linter is not installed,
# it reports the tool as "unavailable" rather than failing. Policies treat an
# unavailable tool as a warning-level gap, not a hard error, so the collector
# is safe to run on any runner.
#
# Usage: ./collect-go-info.sh [repo-root]
# Output: JSON to stdout for QUA-001..004 and TST-001..003 (go context)

set -euo pipefail

REPO_ROOT="${1:-.}"
REPO_NAME=$(basename "$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$REPO_ROOT")")

cd "$REPO_ROOT"

# ── Detect Go modules ─────────────────────────────────────────────────────────
GO_MOD_FILES=$(find . -name "go.mod" -not -path "*/vendor/*" -not -path "*/.git/*" 2>/dev/null || true)
HAS_GO_MODULE="false"
if [ -n "$GO_MOD_FILES" ]; then
  HAS_GO_MODULE="true"
fi

# ── Tool availability ─────────────────────────────────────────────────────────
GO_AVAILABLE="false"
GOLANGCI_AVAILABLE="false"
command -v go >/dev/null 2>&1 && GO_AVAILABLE="true"
command -v golangci-lint >/dev/null 2>&1 && GOLANGCI_AVAILABLE="true"

# ── QUA-001: Linter (golangci-lint) ───────────────────────────────────────────
# We check two things: (1) is a golangci-lint config present in the repo,
# (2) does golangci-lint run clean (if the tool is installed).
LINT_CONFIG_PRESENT="false"
for cfg in .golangci.yml .golangci.yaml .golangci.toml .golangci.json; do
  [ -f "$cfg" ] && LINT_CONFIG_PRESENT="true" && break
done
LINT_EXIT="unavailable"
LINT_ISSUE_COUNT=0
if [ "$HAS_GO_MODULE" = "true" ] && [ "$GOLANGCI_AVAILABLE" = "true" ]; then
  if golangci-lint run --timeout 120s ./... >/tmp/golangci-out.txt 2>&1; then
    LINT_EXIT="pass"
  else
    LINT_EXIT="fail"
    LINT_ISSUE_COUNT=$(grep -c ":" /tmp/golangci-out.txt 2>/dev/null); LINT_ISSUE_COUNT=${LINT_ISSUE_COUNT:-0}
  fi
fi

# ── QUA-002: Formatting (gofmt) ───────────────────────────────────────────────
# gofmt -l lists files that are NOT formatted. Empty output = all formatted.
GOFMT_EXIT="unavailable"
GOFMT_UNFORMATTED_COUNT=0
if [ "$HAS_GO_MODULE" = "true" ] && [ "$GO_AVAILABLE" = "true" ]; then
  UNFORMATTED=$(gofmt -l . 2>/dev/null | grep -v "/vendor/" || true)
  if [ -z "$UNFORMATTED" ]; then
    GOFMT_EXIT="pass"
  else
    GOFMT_EXIT="fail"
    GOFMT_UNFORMATTED_COUNT=$(printf '%s\n' "$UNFORMATTED" | grep -c . || true); GOFMT_UNFORMATTED_COUNT=${GOFMT_UNFORMATTED_COUNT:-0}
  fi
fi

# ── QUA-003: Build (go build) ─────────────────────────────────────────────────
BUILD_EXIT="unavailable"
if [ "$HAS_GO_MODULE" = "true" ] && [ "$GO_AVAILABLE" = "true" ]; then
  if go build ./... >/tmp/gobuild-out.txt 2>&1; then
    BUILD_EXIT="pass"
  else
    BUILD_EXIT="fail"
  fi
fi

# ── QUA-004: Static analysis (go vet) ─────────────────────────────────────────
VET_EXIT="unavailable"
if [ "$HAS_GO_MODULE" = "true" ] && [ "$GO_AVAILABLE" = "true" ]; then
  if go vet ./... >/tmp/govet-out.txt 2>&1; then
    VET_EXIT="pass"
  else
    VET_EXIT="fail"
  fi
fi

# ── TST-001/002: Tests exist + coverage (go test) ─────────────────────────────
# Detect *_test.go files
TEST_FILE_COUNT=$(find . -name "*_test.go" -not -path "*/vendor/*" -not -path "*/.git/*" 2>/dev/null | grep -c . || true)
TEST_FILE_COUNT=${TEST_FILE_COUNT:-0}
TESTS_PRESENT="false"
[ "$TEST_FILE_COUNT" -gt 0 ] 2>/dev/null && TESTS_PRESENT="true"

TEST_EXIT="unavailable"
COVERAGE_PERCENT="null"
if [ "$HAS_GO_MODULE" = "true" ] && [ "$GO_AVAILABLE" = "true" ] && [ "$TESTS_PRESENT" = "true" ]; then
  if go test -cover -coverprofile=/tmp/cover.out ./... >/tmp/gotest-out.txt 2>&1; then
    TEST_EXIT="pass"
  else
    TEST_EXIT="fail"
  fi
  # Extract total coverage percentage
  if [ -f /tmp/cover.out ]; then
    COV=$(go tool cover -func=/tmp/cover.out 2>/dev/null | grep "^total:" | awk '{print $3}' | tr -d '%' || echo "")
    [ -n "$COV" ] && COVERAGE_PERCENT="$COV"
  fi
fi

# ── TST-003: Integration test detection ───────────────────────────────────────
# Heuristic: presence of integration test files or an integration/e2e directory
INTEGRATION_TEST_PRESENT="false"
if find . -path "*/vendor/*" -prune -o \( -name "*_integration_test.go" -o -path "*integration*" -name "*_test.go" -o -path "*e2e*" -name "*_test.go" \) -print 2>/dev/null | grep -q .; then
  INTEGRATION_TEST_PRESENT="true"
fi
# Also check for build-tag based integration tests (//go:build integration)
if grep -rl "//go:build integration" --include="*_test.go" . 2>/dev/null | grep -q .; then
  INTEGRATION_TEST_PRESENT="true"
fi

# ── ARC-001: Standard Go project layout ─────────────────────────────────────
# Check for cmd/ directory (primary entry points)
PROJECT_LAYOUT_CMD="false"
PROJECT_LAYOUT_INTERNAL="false"
PROJECT_LAYOUT_PKG="false"
[ -d "cmd" ] && PROJECT_LAYOUT_CMD="true"
[ -d "internal" ] && PROJECT_LAYOUT_INTERNAL="true"
[ -d "pkg" ] && PROJECT_LAYOUT_PKG="true"
# Standard layout: has cmd/ OR (single-binary: only main.go at root, no other .go files at root)
LAYOUT_OK="false"
if [ "$PROJECT_LAYOUT_CMD" = "true" ]; then
  LAYOUT_OK="true"
elif [ -f "main.go" ]; then
  # Single-binary repo: main.go at root is acceptable
  ROOT_GO_COUNT=$(find . -maxdepth 1 -name "*.go" -not -name "main.go" 2>/dev/null | grep -c . || true)
  ROOT_GO_COUNT=${ROOT_GO_COUNT:-0}
  [ "$ROOT_GO_COUNT" -eq 0 ] 2>/dev/null && LAYOUT_OK="true"
fi

# ── API-001: OpenAPI spec present ─────────────────────────────────────────────
OPENAPI_SPEC_PRESENT="false"
OPENAPI_SPEC_PATH=""
for spec_path in openapi.yaml openapi.json docs/openapi.yaml docs/openapi.json api/openapi.yaml api/openapi.json; do
  if [ -f "$spec_path" ]; then
    OPENAPI_SPEC_PRESENT="true"
    OPENAPI_SPEC_PATH="$spec_path"
    break
  fi
done

# ── API-002: API version declared ──────────────────────────────────────────────
API_VERSION_DECLARED="false"
if [ "$OPENAPI_SPEC_PRESENT" = "true" ] && [ -n "$OPENAPI_SPEC_PATH" ]; then
  # Check info.version field exists and is non-empty
  if command -v python3 >/dev/null 2>&1; then
    VERSION_CHECK=$(python3 -c "
import sys
try:
    import json, yaml
    with open('${OPENAPI_SPEC_PATH}') as f:
        content = f.read()
    try:
        spec = json.loads(content)
    except:
        spec = yaml.safe_load(content)
    version = spec.get('info', {}).get('version', '')
    paths = spec.get('paths', {})
    has_version = bool(version and str(version).strip())
    # Check if any path starts with /v followed by a digit
    has_versioned_path = any(str(p).startswith('/v') and len(str(p)) > 2 and str(p)[2].isdigit() for p in paths)
    print('true' if (has_version and has_versioned_path) else 'false')
except Exception as e:
    print('false')
" 2>/dev/null || echo "false")
    API_VERSION_DECLARED="${VERSION_CHECK:-false}"
  fi
fi

# ── API-003: OpenAPI spec changed (in current PR / working tree) ───────────────
# Detect if openapi spec was modified vs main branch (best-effort)
OPENAPI_SPEC_CHANGED="false"
if [ "$OPENAPI_SPEC_PRESENT" = "true" ]; then
  # Check git diff vs origin/main or HEAD~1 for openapi files
  if git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -qE '(openapi\.(yaml|json)|docs/openapi\.(yaml|json)|api/openapi\.(yaml|json))'; then
    OPENAPI_SPEC_CHANGED="true"
  elif git diff --name-only origin/main...HEAD 2>/dev/null | grep -qE '(openapi\.(yaml|json)|docs/openapi\.(yaml|json)|api/openapi\.(yaml|json))'; then
    OPENAPI_SPEC_CHANGED="true"
  fi
fi

# ── OBS-004: OpenTelemetry dependency present ─────────────────────────────────
OTEL_DEPENDENCY_PRESENT="false"
if [ -f "go.sum" ]; then
  if grep -q "go.opentelemetry.io/otel" go.sum 2>/dev/null; then
    OTEL_DEPENDENCY_PRESENT="true"
  fi
fi

# ── SUP-005: go.sum committed and tidy ────────────────────────────────────────
GOSUM_COMMITTED="false"
GOSUM_TIDY="false"
if [ -f "go.sum" ] && git ls-files --error-unmatch go.sum >/dev/null 2>&1; then
  GOSUM_COMMITTED="true"
fi
if [ "$GOSUM_COMMITTED" = "true" ] && [ "$HAS_GO_MODULE" = "true" ] && [ "$GO_AVAILABLE" = "true" ]; then
  # Copy go.sum, run tidy, compare
  cp go.sum /tmp/gosum-before.txt 2>/dev/null || true
  if go mod tidy 2>/dev/null; then
    if diff -q go.sum /tmp/gosum-before.txt >/dev/null 2>&1; then
      GOSUM_TIDY="true"
    fi
    # Restore original go.sum
    cp /tmp/gosum-before.txt go.sum 2>/dev/null || true
  fi
fi

# ── DOC-003: Service runbook present ─────────────────────────────────────────
RUNBOOK_PRESENT="false"
for runbook_path in docs/runbook.md RUNBOOK.md runbook.md docs/RUNBOOK.md; do
  if [ -f "$runbook_path" ]; then
    RUNBOOK_PRESENT="true"
    break
  fi
done

# ── SRC-005: Conventional Commits CI enforcement ──────────────────────────────
CONVENTIONAL_COMMITS_ENFORCED="false"
if find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null | xargs grep -l "commitlint\|conventional-commits-check\|commit-lint" 2>/dev/null | grep -q .; then
  CONVENTIONAL_COMMITS_ENFORCED="true"
fi
# Also check for commitlint config files
COMMITLINT_CONFIG="false"
for cfg in .commitlintrc .commitlintrc.yaml .commitlintrc.yml .commitlintrc.json commitlint.config.js commitlint.config.ts; do
  [ -f "$cfg" ] && COMMITLINT_CONFIG="true" && break
done

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
    "language": "go",
    "has_go_module": to_bool("${HAS_GO_MODULE}"),
    "tools": {
        "go_available": to_bool("${GO_AVAILABLE}"),
        "golangci_lint_available": to_bool("${GOLANGCI_AVAILABLE}"),
    },
    "quality": {
        "lint": {"config_present": to_bool("${LINT_CONFIG_PRESENT}"), "result": "${LINT_EXIT}", "issue_count": ${LINT_ISSUE_COUNT}},
        "format": {"result": "${GOFMT_EXIT}", "unformatted_count": ${GOFMT_UNFORMATTED_COUNT}},
        "build": {"result": "${BUILD_EXIT}"},
        "vet": {"result": "${VET_EXIT}"},
    },
    "testing": {
        "tests_present": to_bool("${TESTS_PRESENT}"),
        "test_file_count": ${TEST_FILE_COUNT},
        "test_result": "${TEST_EXIT}",
        "coverage_percent": to_num("${COVERAGE_PERCENT}"),
        "integration_test_present": to_bool("${INTEGRATION_TEST_PRESENT}"),
    },
    "architecture": {
        "project_layout": {
            "cmd_present": to_bool("${PROJECT_LAYOUT_CMD}"),
            "internal_present": to_bool("${PROJECT_LAYOUT_INTERNAL}"),
            "pkg_present": to_bool("${PROJECT_LAYOUT_PKG}"),
            "layout_ok": to_bool("${LAYOUT_OK}"),
        },
    },
    "api": {
        "openapi_spec_present": to_bool("${OPENAPI_SPEC_PRESENT}"),
        "openapi_spec_path": "${OPENAPI_SPEC_PATH}",
        "api_version_declared": to_bool("${API_VERSION_DECLARED}"),
        "openapi_spec_changed": to_bool("${OPENAPI_SPEC_CHANGED}"),
    },
    "observability": {
        "otel_dependency_present": to_bool("${OTEL_DEPENDENCY_PRESENT}"),
    },
    "supply_chain": {
        "gosum_committed": to_bool("${GOSUM_COMMITTED}"),
        "gosum_tidy": to_bool("${GOSUM_TIDY}"),
    },
    "documentation": {
        "runbook_present": to_bool("${RUNBOOK_PRESENT}"),
    },
    "source_hygiene": {
        "conventional_commits_enforced": to_bool("${CONVENTIONAL_COMMITS_ENFORCED}"),
        "commitlint_config_present": to_bool("${COMMITLINT_CONFIG}"),
    },
}
print(json.dumps(output, indent=2, ensure_ascii=False, default=str))
PYTHON
