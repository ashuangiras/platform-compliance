package platform.sup.sup_004_github_actions

# Control:  SUP-004 — SBOM must be generated for every release
# Binding:  BIND-SUP-004-GITHUB-ACTIONS
# Standard: SRC-NTIA-SBOM-2021, SRC-CIS-CONTROLS-V8 (Control 2)

import future.keywords.if
import future.keywords.in

sbom_action_prefixes := {
    "anchore/sbom-action",
    "advanced-security/sbom-generator-action",
    "cyclonedx/",
    "CycloneDX/",
    "anchore/syft",
    "syft-action",
}

sbom_actions_found[action] if {
    some ref in input.action_references
    some prefix in sbom_action_prefixes
    startswith(ref.uses, prefix)
    action := ref.uses
}

sbom_detected if count(sbom_actions_found) > 0

found_sbom_action := action if {
    some action in sbom_actions_found
} else := ""

default result := {
    "result": "error",
    "details": {"message": "SUP-004 policy error: missing input data"},
}

result := {
    "result": "pass",
    "details": {
        "checked":  sprintf("GitHub Actions workflows in '%v'", [input.repository.name]),
        "found":    sprintf("SBOM generation action: %v", [found_sbom_action]),
        "expected": "anchore/sbom-action, cyclonedx, or equivalent SBOM tool in CI",
        "message":  "SUP-004: SBOM generation is configured in the release pipeline",
    },
} if {
    count(input.workflow_files) > 0
    sbom_detected
}

result := {
    "result": "not_applicable",
    "details": {"message": "SUP-004: No GitHub Actions workflow files found"},
} if {
    count(input.workflow_files) == 0
}

result := {
    "result": "fail",
    "details": {
        "checked":  sprintf("GitHub Actions workflows in '%v'", [input.repository.name]),
        "found":    "No SBOM generation action found in any workflow",
        "expected": "anchore/sbom-action, CycloneDX toolkit, or equivalent",
        "message":  "SUP-004: No SBOM generation detected. Add anchore/sbom-action to release workflow.",
    },
} if {
    count(input.workflow_files) > 0
    not sbom_detected
}
