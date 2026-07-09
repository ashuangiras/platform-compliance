package platform.sec.sec_003_github

# Control:  SEC-003 — Critical and high severity dependency vulnerabilities must
#           be remediated within SLA (critical: 7 days, high: 30 days)
# Binding:  BIND-SEC-003-GITHUB
# Standard: SRC-OPENSSF-SCORECARD-V2 (Vulnerabilities check)
#
# Input schema:
#   input.repository.name
#   input.evaluation_timestamp  — ISO 8601 string, e.g. "2026-07-08T14:30:00Z"
#   input.alerts[]              — Open Dependabot alerts
#   input.alerts[].number       — Alert number
#   input.alerts[].severity     — "critical" | "high"
#   input.alerts[].created_at   — ISO 8601 creation timestamp
#   input.alerts[].advisory     — { ghsa_id, summary }

import future.keywords.if
import future.keywords.in

# SLA thresholds in nanoseconds
critical_sla_ns := 7 * 24 * 60 * 60 * 1000000000

high_sla_ns := 30 * 24 * 60 * 60 * 1000000000

# Compute age of an alert in nanoseconds
alert_age_ns(alert) := now - created if {
	created := time.parse_rfc3339_ns(alert.created_at)
	now := time.parse_rfc3339_ns(input.evaluation_timestamp)
}

# Alerts that have breached their SLA
breached_critical := [a |
	a := input.alerts[_]
	a.severity == "critical"
	alert_age_ns(a) > critical_sla_ns
]

breached_high := [a |
	a := input.alerts[_]
	a.severity == "high"
	alert_age_ns(a) > high_sla_ns
]

default result := {
	"result": "error",
	"details": {"message": "SEC-003 policy error: missing alert data or timestamps"},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Dependabot alert SLA compliance in '%v'", [input.repository.name]),
		"found":    sprintf("No SLA breaches — %v critical and %v high alert(s) open, all within SLA", [count([a | a := input.alerts[_]; a.severity == "critical"]), count([a | a := input.alerts[_]; a.severity == "high"])]),
		"expected": "No critical alerts > 7 days, no high alerts > 30 days",
		"message":  "SEC-003: All open vulnerability alerts are within SLA",
	},
} if {
	count(breached_critical) == 0
	count(breached_high) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Dependabot alert SLA compliance in '%v'", [input.repository.name]),
		"found":    sprintf("%v critical SLA breach(es), %v high SLA breach(es)", [count(breached_critical), count(breached_high)]),
		"expected": "No critical alerts > 7 days, no high alerts > 30 days",
		"message":  sprintf("SEC-003: SLA breached — %v critical alert(s) exceed 7-day limit: [%v]; %v high alert(s) exceed 30-day limit: [%v]", [
			count(breached_critical),
			concat(", ", [sprintf("#%v: %v", [a.number, a.advisory.ghsa_id]) | a := breached_critical[_]]),
			count(breached_high),
			concat(", ", [sprintf("#%v: %v", [a.number, a.advisory.ghsa_id]) | a := breached_high[_]]),
		]),
		"breached_critical": [sprintf("#%v (%v) opened %v", [a.number, a.advisory.ghsa_id, a.created_at]) | a := breached_critical[_]],
		"breached_high":     [sprintf("#%v (%v) opened %v", [a.number, a.advisory.ghsa_id, a.created_at]) | a := breached_high[_]],
	},
} if {
	count(breached_critical) + count(breached_high) > 0
}
