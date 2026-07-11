package platform.iac.iac_006_terraform

# Control:  IAC-006 — Full platform deployment must be achievable by a single automated script
# Binding:  BIND-IAC-006-TERRAFORM
# Input:    iac-terraform.json (collect-terraform-info.sh)
#
# Verifies that deploy.sh (or scripts/deploy.sh) exists in the repository root.
# This is the single entrypoint for automated platform deployment.

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "IAC-006 policy error: missing terraform input data"},
}

# ── NOT APPLICABLE ─────────────────────────────────────────────────────────────
# Only applies to terraform-root repos that deploy the full platform stack.
result := {
	"result": "not_applicable",
	"details": {"message": sprintf("only enforced on terraform-root repositories (this repo type=%v)", [input.repository.type])},
} if {
	input.repository.type != "terraform-root"
}

# ── PASS ───────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("deploy.sh in repository root of '%v'", [input.repository.name]),
		"found":    "deploy.sh exists and is the automated deployment entrypoint",
		"expected": "deploy.sh at repository root performing staged terraform apply",
		"message":  "IAC-006: Automated deployment script is present",
	},
} if {
	input.has_deploy_script == true
}

# ── FAIL ───────────────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("deploy.sh in '%v'", [input.repository.name]),
		"found":    "No deploy.sh found at repository root or scripts/",
		"expected": "deploy.sh implementing two-phase terraform apply with health gates",
		"message":  "IAC-006: Create deploy.sh. See IAC-006 control guidance for required structure.",
	},
} if {
	input.repository.type == "terraform-root"
	count(input.module_calls) > 0
	not input.has_deploy_script
}
