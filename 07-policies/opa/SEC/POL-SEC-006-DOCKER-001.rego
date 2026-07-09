package platform.sec.sec_006_docker

# Control:  SEC-006 — Container images must be scanned for vulnerabilities at build time
# Binding:  BIND-SEC-006-DOCKER
# Standard: SRC-CIS-CONTROLS-V8 (Control 7.6 — Automated vulnerability scanning)
#           SRC-OWASP-SAMM-V2 (SB-2: Software Dependencies image scanning)
#
# Recognised container image scanning action patterns
#   - aquasecurity/trivy-action
#   - anchore/grype-action
#   - snyk/actions/docker
#   - aquasecurity/trivy (script invocation indicator)

import future.keywords.if
import future.keywords.in

image_scanner_prefixes := {
    "aquasecurity/trivy-action",
    "anchore/grype-action",
    "snyk/actions/docker",
    "anchore/scan-action",
    "docker/scout-action",
    "securecodewarrior/github-action-docker-scan",
}

default result := {
    "result": "error",
    "details": {
        "checked":  "Container image vulnerability scanner in GitHub Actions",
        "found":    "No input provided or input malformed",
        "expected": "At least one recognised container image scanning action",
        "message":  "SEC-006 policy error: missing input data",
    },
}

result := {
    "result": "pass",
    "details": {
        "checked":  sprintf("GitHub Actions workflows in '%v'", [input.repository.name]),
        "found":    sprintf("Image scanner detected: %v", [found_scanner]),
        "expected": "Trivy, Grype, or equivalent scanning built image before publish",
        "message":  "SEC-006: Container image vulnerability scanning is configured in CI",
    },
} if {
    count(input.workflow_files) > 0
    found_scanner != ""
}

result := {
    "result": "not_applicable",
    "details": {
        "message": "SEC-006: No GitHub Actions workflow files found — not applicable",
    },
} if {
    count(input.workflow_files) == 0
}

result := {
    "result": "fail",
    "details": {
        "checked":  sprintf("GitHub Actions workflows in '%v'", [input.repository.name]),
        "found":    "No recognised container image scanner found in any workflow",
        "expected": "aquasecurity/trivy-action, anchore/grype-action, or equivalent",
        "message":  "SEC-006: No container image scanner detected. Add Trivy (aquasecurity/trivy-action) to CI build pipeline.",
    },
} if {
    count(input.workflow_files) > 0
    found_scanner == ""
}

# Partial set: collects all matching found_scanner references (avoids complete rule conflict)
found_scanners[action] if {
	some ref in input.action_references
	some prefix in image_scanner_prefixes
	startswith(ref.uses, prefix)
	action := ref.uses
}

found_scanner := action if {
	some action in found_scanners
} else := ""

found_scanner_detected if count(found_scanners) > 0
