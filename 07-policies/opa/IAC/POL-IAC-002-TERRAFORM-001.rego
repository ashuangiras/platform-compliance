package platform.iac.iac_002_terraform

# Control:  IAC-002 — Terraform plan output must be reviewed before apply
# Binding:  BIND-IAC-002-TERRAFORM (partially-automated)
# Standard: SRC-OPENGITOPS-V1 (Principle 3), SRC-AWS-WAF-2024
# Input:    iac-plan-review.json (collected by the reusable workflow from PR context)
#
# Input schema — PR-context shape (input.pr_context == true):
#   input.repository.name        — string
#   input.repository.type        — string (gated: only "terraform-root")
#   input.pr_context             — bool (true)
#   input.head_sha               — string: the PR head commit SHA
#   input.changed_tf_files       — [string]: changed paths ending in ".tf"
#   input.plan_generated         — bool: was a plan generated for this PR?
#   input.plan_commit_sha        — string|null: commit SHA the plan was generated from
#   input.plan_posted_at         — string|null: RFC3339 time the plan was posted to the PR
#   input.plan_summary           — object|null
#   input.plan_artifact_url      — string|null
#   input.approving_reviews      — [{state: "APPROVED", submitted_at: <RFC3339>}]
#
# Input schema — no-PR shape (input.pr_context == false):
#   input.repository.{name,type}, input.pr_context == false   (nothing else)
#
# Every not_applicable branch is mutually exclusive with the others and with
# pass/fail (see guards), so evaluation can never raise eval_conflict_error.

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "IAC-002 policy error: missing plan-review context data"},
}

# ── NOT APPLICABLE — repository is not a terraform-root ────────────────────────
result := {
	"result": "not_applicable",
	"details": {"message": "IAC-002: only applies to terraform-root repositories"},
} if {
	input.repository.type != "terraform-root"
}

# ── NOT APPLICABLE — terraform-root but no pull-request context ───────────────
# Push-to-main, tag/release without a PR, or a plan not yet run: plan review is
# gated in the PR/CI context, not in this apply context.
result := {
	"result": "not_applicable",
	"details": {"message": "IAC-002: no pull-request context — plan review is gated in CI on the PR, not in this apply/plan-in-CI context"},
} if {
	input.repository.type == "terraform-root"
	input.pr_context == false
}

# ── NOT APPLICABLE — PR changes no .tf files ─────────────────────────────────
result := {
	"result": "not_applicable",
	"details": {"message": "IAC-002: pull request changes no .tf files — plan review not required"},
} if {
	input.repository.type == "terraform-root"
	input.pr_context == true
	count(input.changed_tf_files) == 0
}

# ── PASS — plan generated for the head SHA and approved after it was posted ────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Terraform plan review for '%v'", [input.repository.name]),
		"found":    sprintf("Plan generated for head %v and approved after it was posted at %v", [input.head_sha, input.plan_posted_at]),
		"expected": "Plan generated for the head commit, posted to the PR, and approved after posting",
		"message":  "IAC-002: Terraform plan was reviewed and approved before apply",
	},
} if {
	input.repository.type == "terraform-root"
	input.pr_context == true
	count(input.changed_tf_files) > 0
	plan_review_ok
}

# ── FAIL — .tf changes present but plan/approval evidence is missing or stale ──
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Terraform plan review for '%v'", [input.repository.name]),
		"found":    fail_reason,
		"expected": "Plan generated for the head commit, posted to the PR, and approved after posting",
		"message":  "IAC-002: Generate a terraform plan for the head commit, post it to the PR, and obtain an approval submitted after the plan",
	},
} if {
	input.repository.type == "terraform-root"
	input.pr_context == true
	count(input.changed_tf_files) > 0
	not plan_review_ok
}

# ── Helpers ──────────────────────────────────────────────────────────────────

# A plan was generated for the exact commit being reviewed (the PR head).
plan_for_head if {
	input.plan_generated == true
	input.plan_commit_sha == input.head_sha
}

# The plan is current AND at least one approval was submitted after it was posted.
# is_string guards keep time.parse_rfc3339_ns from ever receiving a null timestamp
# (defensive: plan_posted_at is null until a plan is posted).
plan_review_ok if {
	plan_for_head
	is_string(input.plan_posted_at)
	some r in input.approving_reviews
	r.state == "APPROVED"
	is_string(r.submitted_at)
	time.parse_rfc3339_ns(r.submitted_at) > time.parse_rfc3339_ns(input.plan_posted_at)
}

# Mutually-exclusive fail reasons (only referenced from the fail rule).
fail_reason := "No terraform plan was generated for the applied (head) commit — plan_commit_sha must equal head_sha" if {
	not plan_for_head
}

fail_reason := "A plan exists for the head commit but no approving review was submitted after the plan was posted (stale or missing approval)" if {
	plan_for_head
}
