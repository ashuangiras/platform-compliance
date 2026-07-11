package platform.sec.sec_012_terraform

# Control:  SEC-012 — Sensitive files must not be tracked in version control
# Binding:  BIND-SEC-012-TERRAFORM
# Input:    iac-terraform.json (collect-terraform-info.sh)
#
# Checks git ls-files output for terraform.tfvars and other sensitive file patterns.
# A tracked tfvars file means plaintext credentials are in git history.

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "SEC-012 policy error: missing git tracking data"},
}

# ── NOT APPLICABLE ─────────────────────────────────────────────────────────────
result := {
	"result": "not_applicable",
	"details": {"message": "SEC-012: no terraform files found — not applicable"},
} if {
	not input.sensitive_files_in_git
	not input.tfvars_tracked_in_git
}

# ── PASS ───────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Git-tracked sensitive files in '%v'", [input.repository.name]),
		"found":    "No sensitive files (tfvars, .env, .key, vault-keys) tracked in git",
		"expected": "Only *.example placeholder files in version control",
		"message":  "SEC-012: No sensitive files committed to git",
	},
} if {
	count(input.sensitive_files_in_git) == 0
}

# ── FAIL ───────────────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Git-tracked sensitive files in '%v'", [input.repository.name]),
		"found":    sprintf("%v sensitive file(s) committed: %v", [count(input.sensitive_files_in_git), concat(", ", input.sensitive_files_in_git)]),
		"expected": "Sensitive files listed in .gitignore and never committed",
		"message":  "SEC-012 CRITICAL: Remove sensitive files from git history. Run: git filter-repo --path <file> --invert-paths. Rotate all exposed credentials immediately.",
	},
} if {
	count(input.sensitive_files_in_git) > 0
}
