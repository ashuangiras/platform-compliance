#!/usr/bin/env bash
# collect-github-branch-protection.sh
#
# Collects GitHub branch protection settings and outputs structured YAML
# suitable as input for OPA policy checks: SRC-001, SRC-002.
#
# Usage: ./collect-github-branch-protection.sh <owner/repo> <branch>
# Output: YAML to stdout
# Requirements: gh CLI authenticated, yq (optional — falls back to python3)
#
# OPA policies consuming this output:
#   07-policies/opa/SRC/POL-SRC-001-GITHUB-001.rego
#   07-policies/opa/SRC/POL-SRC-002-GITHUB-001.rego

set -euo pipefail

REPO="${1:-}"
BRANCH="${2:-main}"

if [ -z "$REPO" ]; then
  echo "Usage: $0 <owner/repo> [branch]" >&2
  exit 1
fi

OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

# Collect branch protection (API returns 404 if not protected)
protection_json=$(gh api "repos/${REPO}/branches/${BRANCH}/protection" 2>/dev/null || echo "null")

# Collect repo metadata for SEC-002
repo_json=$(gh api "repos/${REPO}" 2>/dev/null || echo "{}")

# Output structured YAML for OPA input
python3 - <<PYTHON
import json, sys

protection = json.loads('''${protection_json}''')
repo = json.loads('''${repo_json}'''.replace("'", '"'))

output = {
    'repository': {
        'name': '${REPO_NAME}',
        'url': f'https://github.com/${REPO}',
        'type': 'platform-repo'  # override from .compliance-manifest.yaml in CI
    },
    'default_branch': '${BRANCH}',
    'branch_protection': protection if protection != 'null' else None
}

print(json.dumps(output, indent=2, ensure_ascii=False, default=str))
PYTHON
