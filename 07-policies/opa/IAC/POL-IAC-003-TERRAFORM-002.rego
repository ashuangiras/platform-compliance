package platform.iac.iac_003b_terraform

# Control:  IAC-003 (extension) — Terraform modules must use pinned, immutable version refs
# Binding:  BIND-IAC-003-TERRAFORM-REFS
# Input:    iac-terraform.json (collect-terraform-info.sh)
#
# Checks that all git-sourced module calls use a specific tag ref (e.g., ?ref=v1.2.3)
# rather than a mutable branch name (main, master, HEAD, develop).
# Mutable refs cause non-reproducible deployments and silent production changes.

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "IAC-003b policy error: missing module ref data"},
}

# ── NOT APPLICABLE ─────────────────────────────────────────────────────────────
result := {
	"result": "not_applicable",
	"details": {"message": "IAC-003b: no module calls found — not applicable"},
} if {
	count(input.module_calls) == 0
}

# ── PASS ───────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Module ref pinning in '%v' (%v module calls)", [input.repository.name, count(input.module_calls)]),
		"found":    "All git-sourced modules use pinned version tags",
		"expected": "?ref=vX.Y.Z (semver tag) on all git:: module sources",
		"message":  "IAC-003b: All module refs are pinned to immutable tags",
	},
} if {
	count(input.modules_with_mutable_refs) == 0
	count(input.module_calls) > 0
}

# ── FAIL ───────────────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Module ref pinning in '%v'", [input.repository.name]),
		"found":    sprintf("%v module(s) using mutable refs: %v", [count(input.modules_with_mutable_refs), mutable_summary]),
		"expected": "?ref=vX.Y.Z (semver tag) — not main, master, HEAD, or no ref",
		"message":  "IAC-003b: Pin module refs to a specific version tag. Mutable refs cause silent production changes on every terraform init -upgrade.",
	},
} if {
	count(input.modules_with_mutable_refs) > 0
}

mutable_summary := concat("; ", {
	sprintf("%v (?ref=%v)", [m.name, m.ref]) |
	some m in input.modules_with_mutable_refs
})
