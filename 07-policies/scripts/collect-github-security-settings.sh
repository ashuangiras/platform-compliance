#!/usr/bin/env bash
# collect-github-security-settings.sh
#
# Collects GitHub repository security settings and secret scanning alerts.
# Output feeds OPA policy checks: SEC-001, SEC-002, SEC-003, SUP-003.
#
# Usage: ./collect-github-security-settings.sh <owner/repo>
# Output: JSON to stdout

set -euo pipefail

REPO="${1:-}"
if [ -z "$REPO" ]; then
  echo "Usage: $0 <owner/repo>" >&2
  exit 1
fi

REPO_NAME="${REPO##*/}"

# Pass all gh JSON blobs to python via FILES, never by interpolating them into the
# script body. The previous version inlined blobs into a triple-quoted Python
# string and ran `.replace("'", '"')` over them, which corrupted any apostrophes in
# text fields and produced invalid Python source on python 3.14 (DEFECT-3). A
# private temp dir keeps the blobs isolated and cleaned up on exit.
workdir="$(mktemp -d /tmp/sec-settings-XXXXXX)"
trap 'rm -rf "$workdir"' EXIT

# Repo security settings (secret scanning status) — default {} on any error.
gh api "repos/${REPO}" > "$workdir/repo.json" 2>/dev/null || echo '{}' > "$workdir/repo.json"

# Open secret scanning alerts — default [] (404 when GHAS/secret-scanning disabled).
gh api "repos/${REPO}/secret-scanning/alerts?state=open&per_page=100" > "$workdir/alerts.json" 2>/dev/null || echo '[]' > "$workdir/alerts.json"

# Open Dependabot alerts (for SEC-003 SLA check) — default [].
gh api "repos/${REPO}/dependabot/alerts?state=open&per_page=100" > "$workdir/dependabot.json" 2>/dev/null || echo '[]' > "$workdir/dependabot.json"

# Vulnerability alerts enabled — HTTP 204 means enabled, 404 means not enabled (SUP-003)
vulnerability_alerts_enabled="false"
if gh api "repos/${REPO}/vulnerability-alerts" >/dev/null 2>&1; then
    vulnerability_alerts_enabled="true"
fi

# Automated security fixes (SUP-003) — default {"enabled":false}.
gh api "repos/${REPO}/automated-security-fixes" > "$workdir/autofix.json" 2>/dev/null || echo '{"enabled":false}' > "$workdir/autofix.json"

# Gitleaks scan (optional — absent tool ⇒ empty findings, never hard-fail).
echo '[]' > "$workdir/gitleaks.json"
scan_tool_version="unavailable"
if command -v gitleaks >/dev/null 2>&1; then
  scan_tool_version="system"
  gitleaks detect --source . --report-format json --report-path "$workdir/gitleaks.json" --exit-code 0 >/dev/null 2>&1 || true
  # gitleaks may leave the file empty if it wrote nothing — normalise to [].
  [ -s "$workdir/gitleaks.json" ] || echo '[]' > "$workdir/gitleaks.json"
fi

REPO_NAME="$REPO_NAME" \
VULN_ALERTS_ENABLED="$vulnerability_alerts_enabled" \
SCAN_TOOL_VERSION="$scan_tool_version" \
WORKDIR="$workdir" \
python3 - <<'PYTHON'
import json, os
from datetime import datetime, timezone

workdir = os.environ["WORKDIR"]


def load(name, default):
    """Robustly load a gh JSON blob from a file; fall back to default on any error."""
    try:
        with open(os.path.join(workdir, name)) as fh:
            return json.load(fh)
    except Exception:
        return default


repo = load("repo.json", {})
alerts = load("alerts.json", [])
dependabot = load("dependabot.json", [])
findings = load("gitleaks.json", [])
autofix = load("autofix.json", {"enabled": False})

if not isinstance(repo, dict):
    repo = {}
if not isinstance(alerts, list):
    alerts = []
if not isinstance(dependabot, list):
    dependabot = []
if not isinstance(findings, list):
    findings = []
if not isinstance(autofix, dict):
    autofix = {"enabled": False}

sec_analysis = repo.get("security_and_analysis", {}) or {}

output = {
    "repository": {
        "name": os.environ["REPO_NAME"],
        "security_and_analysis": sec_analysis,
    },
    "vulnerability_alerts_enabled": os.environ["VULN_ALERTS_ENABLED"] == "true",
    "automated_security_fixes_enabled": bool(autofix.get("enabled", False)),
    # ── SEC-001 secret-scan fields (input schema for POL-SEC-001) ────────────
    "scan_tool": "gitleaks",
    "scan_tool_version": os.environ["SCAN_TOOL_VERSION"],
    "findings": findings,
    "github_alerts_open": len(alerts),
    "evaluation_timestamp": datetime.now(timezone.utc).isoformat(),
    "alerts": [
        {
            "number": a.get("number"),
            "severity": (a.get("security_vulnerability") or {}).get("severity", "unknown"),
            "created_at": a.get("created_at", ""),
            "advisory": {
                "ghsa_id": (a.get("security_advisory") or {}).get("ghsa_id", ""),
                "summary": (a.get("security_advisory") or {}).get("summary", ""),
            },
        }
        for a in dependabot
    ],
}

print(json.dumps(output, indent=2, ensure_ascii=False, default=str))
PYTHON
