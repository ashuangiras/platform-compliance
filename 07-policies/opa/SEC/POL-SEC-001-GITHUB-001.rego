package platform.sec.sec_001_github

# Control:  SEC-001 — No plaintext secrets in repositories
# Binding:  BIND-SEC-001-GITHUB
# Standard: SRC-OPENSSF-SCORECARD-V2 (Secrets check)
#           SRC-CIS-DOCKER-V1-6 (secrets handling)
#
# Input schema:
#   input.scan_tool              — Tool used (gitleaks, detect-secrets)
#   input.scan_tool_version      — Version of scan tool
#   input.findings[]             — Array of secret findings (empty = pass)
#   input.findings[].rule_id     — Rule that triggered
#   input.findings[].file        — File path containing the finding
#   input.findings[].line        — Line number
#   input.findings[].description — Human-readable finding description
#   input.github_alerts_open     — Count of open GitHub secret scanning alerts
#   input.repository.name        — Repository name

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "SEC-001 policy error: missing scan output"},
}

# ─── PASS ─────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Repository '%v' for plaintext secrets (%v scan)", [input.repository.name, input.scan_tool]),
		"found":    "No secrets detected",
		"expected": "Zero findings from secret scan and zero open GitHub alerts",
		"message":  sprintf("SEC-001: No secrets found by %v v%v. GitHub alerts: 0", [input.scan_tool, input.scan_tool_version]),
	},
} if {
	count(input.findings) == 0
	input.github_alerts_open == 0
}

# ─── FAIL: scan findings ──────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Repository '%v' for plaintext secrets", [input.repository.name]),
		"found":    sprintf("%v potential secret(s) detected by %v", [count(input.findings), input.scan_tool]),
		"expected": "Zero findings",
		"message":  "SEC-001: CRITICAL — Potential secrets detected. Rotate credentials immediately and clean git history.",
		"findings": [sprintf("%v in %v:%v", [f.rule_id, f.file, f.line]) | f := input.findings[_]],
	},
} if {
	count(input.findings) > 0
}

# ─── FAIL: GitHub alerts open ─────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Repository '%v' open GitHub secret scanning alerts", [input.repository.name]),
		"found":    sprintf("%v open alert(s) in GitHub secret scanning", [input.github_alerts_open]),
		"expected": "Zero open alerts",
		"message":  sprintf("SEC-001: %v open GitHub secret scanning alert(s). Review and dismiss or remediate.", [input.github_alerts_open]),
	},
} if {
	count(input.findings) == 0
	input.github_alerts_open > 0
}
