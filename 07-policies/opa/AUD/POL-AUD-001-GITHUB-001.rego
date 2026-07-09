package platform.aud.aud_001_github

# Control:  AUD-001 — GitHub audit log must be accessible and retained ≥90 days
# Binding:  BIND-AUD-001-GITHUB
# Standard: SRC-CIS-CONTROLS-V8 (Control 8.2/8.3), SRC-NIST-CSF-V2 (DE.CM)

import future.keywords.if

default result := {
    "result": "error",
    "details": {"message": "AUD-001 policy error: missing input data"},
}

result := {
    "result": "pass",
    "details": {
        "checked":  sprintf("GitHub audit log accessibility for '%v'", [input.audit_log.owner]),
        "found":    sprintf("Audit log accessible, %v recent entries", [input.audit_log.recent_entry_count]),
        "expected": "Audit log accessible via API with recent entries",
        "message":  "AUD-001: GitHub audit log is accessible",
    },
} if {
    input.audit_log.accessible == true
}

result := {
    "result": "fail",
    "details": {
        "checked":  sprintf("GitHub audit log accessibility for '%v'", [input.audit_log.owner]),
        "found":    "Audit log is not accessible via API",
        "expected": "Audit log accessible via GitHub API",
        "message":  "AUD-001: Audit log inaccessible. For full audit logging, upgrade to GitHub Enterprise or enable org audit log.",
    },
} if {
    input.audit_log.accessible == false
}

result := {
    "result": "not_applicable",
    "details": {"message": "AUD-001: Audit log status could not be determined"},
} if {
    not input.audit_log
}
