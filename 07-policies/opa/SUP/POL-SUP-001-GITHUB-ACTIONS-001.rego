package platform.sup.sup_001_github_actions

# Control:  SUP-001 — All dependency versions must be explicitly pinned
# Binding:  BIND-SUP-001-GITHUB-ACTIONS
# Standard: SRC-OPENSSF-SCORECARD-V2 (Pinned-Dependencies check)
#           SRC-OPENSSF-SLSA-V1 (hermetic build requirements)
#
# Input schema:
#   input.repository.name
#   input.workflow_files[]              — list of workflow files scanned
#   input.action_references[]           — all 'uses:' entries found
#   input.action_references[].workflow  — workflow file path
#   input.action_references[].step      — step name or index
#   input.action_references[].uses      — full uses: value (e.g. "actions/checkout@v4")
#   input.action_references[].pinned    — bool: is it pinned to a tag or SHA?
#   input.action_references[].pin_type  — "sha" | "tag" | "branch" | "none"

import future.keywords.if
import future.keywords.in

# Acceptable pin types
acceptable_pins := {"sha", "tag"}

# References that are not pinned
mutable_refs := [r |
	r := input.action_references[_]
	not r.pin_type in acceptable_pins
]

# Docker container actions are governed by SUP-002, not this policy
non_docker_mutable := [r |
	r := mutable_refs[_]
	not startswith(r.uses, "docker://")
]

default result := {
	"result": "error",
	"details": {"message": "SUP-001 (GitHub Actions) policy error: missing action reference data"},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("GitHub Actions 'uses:' references in %v workflow file(s) in '%v'", [count(input.workflow_files), input.repository.name]),
		"found":    sprintf("All %v action reference(s) use pinned tags or SHAs", [count(input.action_references)]),
		"expected": "All uses: references pinned to @vX.Y.Z tag or @{sha}",
		"message":  "SUP-001: All GitHub Actions references are pinned",
	},
} if {
	count(non_docker_mutable) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("GitHub Actions 'uses:' references in '%v'", [input.repository.name]),
		"found":    sprintf("%v unpinned reference(s) out of %v total", [count(non_docker_mutable), count(input.action_references)]),
		"expected": "All uses: references pinned to @vX.Y.Z or @{sha} (not @main, @master, or no pin)",
		"message":  "SUP-001: Unpinned GitHub Actions references detected — replace branch references with version tags or commit SHAs",
		"unpinned": [sprintf("%v in %v (step: %v) — pin_type: %v", [r.uses, r.workflow, r.step, r.pin_type]) | r := non_docker_mutable[_]],
	},
} if {
	count(non_docker_mutable) > 0
}

result := {
	"result": "not_applicable",
	"details": {
		"message": "SUP-001 (GitHub Actions): No action references found in workflow files",
	},
} if {
	count(input.action_references) == 0
}
