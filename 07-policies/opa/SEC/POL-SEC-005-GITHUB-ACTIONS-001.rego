package platform.sec.sec_005_github_actions

# Control:  SEC-005 — Static application security analysis (SAST) must run in CI
# Binding:  BIND-SEC-005-GITHUB-ACTIONS
# Standard: SRC-OWASP-SAMM-V2 (ST-2: Requirements-driven Testing)
#           SRC-CIS-CONTROLS-V8 (Control 16.12 — Code-level security checks)
#
# Recognised SAST action patterns (case-insensitive prefix match on uses: field)
#   - github/codeql-action/analyze
#   - returntocorp/semgrep-action
#   - semgrep/semgrep-action
#   - PyCQA/bandit (via script)
#   - securecodewarrior/* (general SAST indicator)

import future.keywords.if
import future.keywords.in

sast_action_prefixes := {
    "github/codeql-action",
    "returntocorp/semgrep-action",
    "semgrep/semgrep-action",
    "securecodewarrior/",
    "checkmarx-ts/checkmarx-cxflow-github-action",
    "snyk/actions/",
    "veracode/",
}

default result := {
    "result": "error",
    "details": {
        "checked":  "SAST tool presence in GitHub Actions workflows",
        "found":    "No input provided or input malformed",
        "expected": "At least one recognised SAST action in CI workflows",
        "message":  "SEC-005 policy error: missing input data",
    },
}

result := {
    "result": "pass",
    "details": {
        "checked":  sprintf("GitHub Actions workflows in '%v'", [input.repository.name]),
        "found":    sprintf("SAST action detected: %v", [found_sast_action]),
        "expected": "At least one recognised SAST tool in CI pipeline",
        "message":  "SEC-005: SAST analysis is configured in the CI pipeline",
    },
} if {
    count(input.workflow_files) > 0
    found_sast_action != ""
}

result := {
    "result": "not_applicable",
    "details": {
        "message": "SEC-005: No GitHub Actions workflow files found in this repository",
    },
} if {
    count(input.workflow_files) == 0
}

result := {
    "result": "fail",
    "details": {
        "checked":  sprintf("GitHub Actions workflows in '%v'", [input.repository.name]),
        "found":    "No recognised SAST tool found in any workflow file",
        "expected": "github/codeql-action, returntocorp/semgrep-action, or equivalent SAST tool",
        "message":  "SEC-005: No SAST tool detected in CI pipeline. Add CodeQL (github/codeql-action/analyze) or Semgrep.",
    },
} if {
    count(input.workflow_files) > 0
    found_sast_action == ""
}

# Partial set: collects all matching found_sast_action references (avoids complete rule conflict)
found_sast_actions[action] if {
	some ref in input.action_references
	some prefix in sast_action_prefixes
	startswith(ref.uses, prefix)
	action := ref.uses
}

found_sast_action := action if {
	some action in found_sast_actions
} else := ""

found_sast_action_detected if count(found_sast_actions) > 0
