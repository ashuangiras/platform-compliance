package platform.agt.agt_014_agent

# Control:  AGT-014 — Pre-merge agent readiness check and retrospective
# Binding:  BIND-AGT-014-AGENT
# Standard: SRC-PLATFORM-AGENT-CONVENTIONS

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "AGT-014 policy error: missing input data"},
}

both_present if {
	input.improvement.pr_has_readiness == true
	input.improvement.pr_has_retro == true
}

# NOT APPLICABLE — only evaluated on pull requests (the merge gate)
result := {
	"result": "not_applicable",
	"details": {"message": "AGT-014: no pull-request context; readiness/retro checked at merge gate"},
} if {
	input.improvement.is_pull_request != true
}

result := {
	"result": "pass",
	"details": {
		"checked": sprintf("Readiness + retro for '%v' PR", [input.repository.name]),
		"expected": "a completed readiness checklist and a retrospective",
		"message": "AGT-014: pull request includes a completed readiness check and retro",
	},
} if {
	input.improvement.is_pull_request == true
	both_present
}

result := {
	"result": "fail",
	"details": {
		"checked": sprintf("Readiness + retro for '%v' PR", [input.repository.name]),
		"found": sprintf("readiness (ticked): %v, retro: %v", [input.improvement.pr_has_readiness, input.improvement.pr_has_retro]),
		"expected": "a completed readiness checklist (ticked) and a retrospective in the PR body",
		"message": "AGT-014: complete the Agent Readiness & Retro section in the pull request.",
	},
} if {
	input.improvement.is_pull_request == true
	not both_present
}
