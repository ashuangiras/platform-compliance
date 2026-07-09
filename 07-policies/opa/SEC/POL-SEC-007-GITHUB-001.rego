package platform.sec.sec_007_github

# Control:  SEC-007 — Vulnerability remediation SLA (Critical ≤7d, High ≤30d, Medium ≤90d)
# Binding:  BIND-SEC-007-GITHUB
# Standard: SRC-CIS-CONTROLS-V8 (Control 7.7), SRC-OWASP-SAMM-V2 (SB-2)

import future.keywords.if
import future.keywords.in

default result := {
    "result": "error",
    "details": {"message": "SEC-007 policy error: missing input data"},
}

result := {
    "result": "pass",
    "details": {
        "checked":  sprintf("Dependabot alert SLAs for '%v'", [input.repository.name]),
        "found":    sprintf("%v open alerts, 0 SLA breaches", [count(input.open_alerts)]),
        "expected": "No open alerts exceeding: Critical ≤7d, High ≤30d, Medium ≤90d",
        "message":  "SEC-007: All open vulnerability alerts are within SLA timelines",
    },
} if {
    count(input.open_alerts) > 0
    input.sla_breach_count == 0
}

result := {
    "result": "not_applicable",
    "details": {"message": "SEC-007: No open vulnerability alerts found"},
} if {
    count(input.open_alerts) == 0
}

result := {
    "result": "fail",
    "details": {
        "checked":  sprintf("Dependabot alert SLAs for '%v'", [input.repository.name]),
        "found":    sprintf("%v SLA breach(es): %v", [input.sla_breach_count, concat(", ", {v | some v in input.sla_violations})]),
        "expected": "No alerts exceeding: Critical ≤7d, High ≤30d, Medium ≤90d",
        "message":  sprintf("SEC-007: %v vulnerability alert(s) exceed SLA. Remediate or create a waiver.", [input.sla_breach_count]),
    },
} if {
    input.sla_breach_count > 0
}
