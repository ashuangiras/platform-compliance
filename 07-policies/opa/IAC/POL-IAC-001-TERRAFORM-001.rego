package platform.iac.iac_001_terraform

# Control:  IAC-001 — Terraform code must pass fmt check and validate
# Binding:  BIND-IAC-001-TERRAFORM
# Standard: SRC-OPENGITOPS-V1 (Principle 1 — Declarative)
#
# Input schema:
#   input.fmt_result.exit_code        — 0 = pass, non-zero = fail
#   input.fmt_result.diff             — diff output if fmt failed
#   input.fmt_result.terraform_version — Terraform version used
#   input.validate_result.exit_code   — 0 = pass, non-zero = fail
#   input.validate_result.errors[]    — Error messages from validate
#   input.validate_result.warnings[]  — Warning messages from validate
#   input.validate_result.directories_checked[] — Directories that were validated
#   input.repository.name             — Repository name

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "IAC-001 policy error: missing terraform check results"},
}

# ─── PASS ─────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("terraform fmt and validate in '%v' (tf %v)", [input.repository.name, input.fmt_result.terraform_version]),
		"found":    sprintf("fmt: exit %v, validate: exit %v across %v director(ies)", [input.fmt_result.exit_code, input.validate_result.exit_code, count(input.validate_result.directories_checked)]),
		"expected": "Both commands exit 0",
		"message":  "IAC-001: Terraform code passes formatting check and validation",
	},
} if {
	input.fmt_result.exit_code == 0
	input.validate_result.exit_code == 0
}

# ─── FAIL: fmt only ───────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("terraform fmt in '%v'", [input.repository.name]),
		"found":    sprintf("fmt failed (exit %v). Diff: %v", [input.fmt_result.exit_code, input.fmt_result.diff]),
		"expected": "terraform fmt -check exits 0",
		"message":  sprintf("IAC-001: terraform fmt check failed. Run 'terraform fmt -recursive' to fix. Diff: %v", [input.fmt_result.diff]),
	},
} if {
	input.fmt_result.exit_code != 0
	input.validate_result.exit_code == 0
}

# ─── FAIL: validate only ──────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("terraform validate in '%v'", [input.repository.name]),
		"found":    sprintf("validate failed (exit %v). Errors: %v", [input.validate_result.exit_code, concat("; ", input.validate_result.errors)]),
		"expected": "terraform validate exits 0",
		"message":  sprintf("IAC-001: terraform validate failed: %v", [concat("; ", input.validate_result.errors)]),
	},
} if {
	input.fmt_result.exit_code == 0
	input.validate_result.exit_code != 0
}

# ─── FAIL: both ───────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("terraform fmt and validate in '%v'", [input.repository.name]),
		"found":    sprintf("Both failed — fmt (exit %v), validate (exit %v)", [input.fmt_result.exit_code, input.validate_result.exit_code]),
		"expected": "Both commands exit 0",
		"message":  sprintf("IAC-001: Both terraform fmt and validate failed. fmt diff: %v; validate errors: %v", [input.fmt_result.diff, concat("; ", input.validate_result.errors)]),
	},
} if {
	input.fmt_result.exit_code != 0
	input.validate_result.exit_code != 0
}
