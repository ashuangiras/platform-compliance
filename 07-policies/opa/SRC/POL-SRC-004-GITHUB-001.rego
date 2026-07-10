package platform.src.src_004_github

# Control:  SRC-004 — Commits on the default branch must be signed
# Binding:  BIND-SRC-004-GITHUB
# Standard: SRC-OPENSSF-SCORECARD-V2 (Signed-Releases / Branch-Protection check)
#
# Input schema:
#   input.branch_protection  — GitHub API response body for branch protection
#                              (null or absent if protection is not configured)
#   input.repository.name    — Repository name

import future.keywords.if

# ─── Default: error if no input ───────────────────────────────────────────────
default result := {
	"result": "error",
	"details": {"message": "SRC-004 policy error: missing input data"},
}

# ─── NOT APPLICABLE ───────────────────────────────────────────────────────────
# Guard: branch_protection is absent or not an object — signing cannot be
# evaluated independently of whether protection exists. SRC-001 gates whether
# protection is enabled at all.
result := {
	"result": "not_applicable",
	"details": {"message": "SRC-004: branch_protection data not present; commit-signing check skipped"},
} if {
	not branch_protection_present
}

# ─── PASS ─────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Commit signing on default branch in '%v'", [input.repository.name]),
		"found":    "required_signatures.enabled: true",
		"expected": "required_signatures.enabled: true",
		"message":  "SRC-004: Signed commits are required on the default branch",
	},
} if {
	branch_protection_present
	input.branch_protection.required_signatures.enabled == true
}

# ─── FAIL ─────────────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Commit signing on default branch in '%v'", [input.repository.name]),
		"found":    "required_signatures.enabled: false or absent",
		"expected": "required_signatures.enabled: true",
		"message":  "SRC-004: Commit signing not enforced on the default branch. Enable `required_signatures` in branch protection to require signed commits.",
	},
} if {
	branch_protection_present
	input.branch_protection.required_signatures.enabled != true
}

# ─── Guard predicate ──────────────────────────────────────────────────────────
# Ensures not_applicable and fail/pass are mutually exclusive.
branch_protection_present if {
	is_object(input.branch_protection)
}
