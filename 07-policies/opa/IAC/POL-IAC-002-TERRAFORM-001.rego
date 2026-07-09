package platform.iac.iac_002_terraform

# Control:  IAC-002 — Terraform plan output must be reviewed before apply
# Binding:  BIND-IAC-002-TERRAFORM (partially-automated)
# Standard: SRC-OPENGITOPS-V1 (Principle 3), SRC-AWS-WAF-2024
#
# Input schema (from CI context — collected by reusable workflow):
#   input.repository.name
#   input.repository.type
#   input.plan_reviewed             — bool: was a plan generated and reviewed?
#   input.plan_commit_sha           — string: commit SHA the plan was generated from
#   input.apply_commit_sha          — string: commit SHA being applied
#   input.plan_posted_at            — ISO timestamp: when plan was posted to PR
#   input.approval_after_plan       — bool: was PR approved after plan was posted?

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "IAC-002 policy error: missing plan review context data"},
}

result := {
	"result": "not_applicable",
	"details": {"message": "IAC-002: Only applies to terraform-root repositories"},
} if {
	input.repository.type != "terraform-root"
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Terraform plan reviewed for '%v'", [input.repository.name]),
		"found":    sprintf("Plan generated at %v, reviewed and approved", [input.plan_posted_at]),
		"expected": "Plan generated, posted, reviewed, and approved before apply",
		"message":  "IAC-002: Terraform plan was reviewed before apply",
	},
} if {
	input.repository.type == "terraform-root"
	input.plan_reviewed == true
	input.approval_after_plan == true
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Terraform plan review for '%v'", [input.repository.name]),
		"found":    "No reviewed plan found for the commit being applied",
		"expected": "terraform plan posted as PR comment, PR approved after plan was posted",
		"message":  "IAC-002: Generate a terraform plan, post it to the PR, obtain review, then apply",
	},
} if {
	input.repository.type == "terraform-root"
	not input.plan_reviewed
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Terraform plan approval for '%v'", [input.repository.name]),
		"found":    "Plan was generated but PR was not approved after plan was posted",
		"expected": "At least one PR approval granted after the plan was posted",
		"message":  "IAC-002: Plan must be approved after it was posted — stale approvals do not count",
	},
} if {
	input.repository.type == "terraform-root"
	input.plan_reviewed == true
	not input.approval_after_plan
}
