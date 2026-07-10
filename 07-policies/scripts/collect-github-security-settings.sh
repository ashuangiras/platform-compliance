#!/usr/bin/env bash
# collect-github-security-settings.sh
#
# Collects GitHub repository security settings and secret scanning alerts.
# Output feeds OPA policy checks: SEC-001, SEC-002, SEC-003, SUP-003.
#
# Usage: ./collect-github-security-settings.sh <owner/repo>
# Output: YAML to stdout

set -euo pipefail

REPO="${1:-}"
if [ -z "$REPO" ]; then
  echo "Usage: $0 <owner/repo>" >&2
  exit 1
fi

REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

# Repo security settings (secret scanning status)
repo_json=$(gh api "repos/${REPO}" 2>/dev/null || echo "{}")

# Open secret scanning alerts
alerts_json=$(gh api "repos/${REPO}/secret-scanning/alerts" 2>/dev/null || echo "[]")

# Dependabot alerts (for SEC-003 SLA check)
dependabot_json=$(gh api "repos/${REPO}/dependabot/alerts?state=open&per_page=100" 2>/dev/null || echo "[]")

# Vulnerability alerts enabled — HTTP 204 means enabled, 404 means not enabled (SUP-003)
vulnerability_alerts_enabled="false"
if gh api "repos/${REPO}/vulnerability-alerts" >/dev/null 2>&1; then
    vulnerability_alerts_enabled="true"
fi

# Automated security fixes (SUP-003)
automated_security_fixes_json=$(gh api "repos/${REPO}/automated-security-fixes" 2>/dev/null || echo '{"enabled":false}')

# Gitleaks scan (requires gitleaks binary in PATH)
gitleaks_findings="[]"
if command -v gitleaks >/dev/null 2>&1; then
  tmpfile=$(mktemp /tmp/gitleaks-XXXXXX.json)
  if gitleaks detect --source . --report-format json --report-path "$tmpfile" --exit-code 0 2>/dev/null; then
    gitleaks_findings=$(cat "$tmpfile" 2>/dev/null || echo "[]")
  fi
  rm -f "$tmpfile"
fi

python3 - <<PYTHON
import json, sys
from datetime import datetime, timezone

repo = json.loads('''${repo_json}'''.replace("'", '"').replace('\\n', ''))
alerts = json.loads('''${alerts_json}'''.replace("'", '"'))
dependabot = json.loads('''${dependabot_json}'''.replace("'", '"'))
findings = json.loads('''${gitleaks_findings}'''.replace("'", '"'))
automated_security_fixes = json.loads('${automated_security_fixes_json}')

sec_analysis = repo.get('security_and_analysis', {})

output = {
    'repository': {
        'name': '${REPO_NAME}',
        'security_and_analysis': sec_analysis
    },
    'vulnerability_alerts_enabled': ('${vulnerability_alerts_enabled}' == 'true'),
    'automated_security_fixes_enabled': automated_security_fixes.get('enabled', False),
    'scan_tool': 'gitleaks',
    'scan_tool_version': 'system',
    'findings': findings if isinstance(findings, list) else [],
    'github_alerts_open': len([a for a in alerts if isinstance(alerts, list)]),
    'evaluation_timestamp': datetime.now(timezone.utc).isoformat(),
    'alerts': [
        {
            'number': a.get('number'),
            'severity': a.get('security_vulnerability', {}).get('severity', 'unknown'),
            'created_at': a.get('created_at', ''),
            'advisory': {
                'ghsa_id': a.get('security_advisory', {}).get('ghsa_id', ''),
                'summary': a.get('security_advisory', {}).get('summary', '')
            }
        }
        for a in (dependabot if isinstance(dependabot, list) else [])
    ]
}

print(json.dumps(output, indent=2, ensure_ascii=False, default=str))
PYTHON
