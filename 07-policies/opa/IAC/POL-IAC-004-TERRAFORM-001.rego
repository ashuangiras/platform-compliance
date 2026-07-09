package platform.iac.iac_004_terraform

# Control:  IAC-004 — Terraform code must pass automated security scanning on every PR
# Binding:  BIND-IAC-004-TERRAFORM
# Standard: SRC-CIS-CONTROLS-V8 (Control 4.2 — Secure configuration for network infrastructure)
#           SRC-OWASP-SAMM-V2 (ST-3: Automated Security Testing)
#
# Recognised Terraform security scanner action patterns
#   - aquasecurity/tfsec-action
#   - bridgecrew/checkov-action
#   - tenable/terrascan-action
#   - checkmarx/kics-github-action

import future.keywords.if
import future.keywords.in

iac_scanner_prefixes := {
    "aquasecurity/tfsec-action",
    "aquasecurity/trivy-action",
    "bridgecrew/checkov-action",
    "tenable/terrascan-action",
    "checkmarx/kics-github-action",
    "snyk/actions/iac",
    "triat/terraform-security-scan",
}

default result := {
    "result": "error",
    "details": {
        "checked":  "Terraform security scanner in GitHub Actions workflows",
        "found":    "No input provided or input malformed",
        "expected": "At least one recognised Terraform security scanning action",
        "message":  "IAC-004 policy error: missing input data",
    },
}

result := {
    "result": "pass",
    "details": {
        "checked":  sprintf("GitHub Actions workflows in '%v'", [input.repository.name]),
        "found":    sprintf("IaC security scanner detected: %v", [found_scanner]),
        "expected": "tfsec, Checkov, Terrascan, or KICS in CI pipeline",
        "message":  "IAC-004: Terraform security scanning is configured in the CI pipeline",
    },
} if {
    count(input.workflow_files) > 0
    found_scanner != ""
}

result := {
    "result": "not_applicable",
    "details": {
        "message": "IAC-004: No GitHub Actions workflow files found — not applicable to this repository",
    },
} if {
    count(input.workflow_files) == 0
}

result := {
    "result": "fail",
    "details": {
        "checked":  sprintf("GitHub Actions workflows in '%v'", [input.repository.name]),
        "found":    "No recognised Terraform security scanner found in any workflow",
        "expected": "aquasecurity/tfsec-action, bridgecrew/checkov-action, or equivalent",
        "message":  "IAC-004: No Terraform security scanner detected. Add tfsec or Checkov to CI pipeline.",
    },
} if {
    count(input.workflow_files) > 0
    found_scanner == ""
}

found_scanner := action if {
    some ref in input.action_references
    some prefix in iac_scanner_prefixes
    startswith(ref.uses, prefix)
    action := ref.uses
} else := ""
