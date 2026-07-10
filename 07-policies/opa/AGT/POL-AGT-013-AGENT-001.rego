package platform.agt.agt_013_agent

# Control:  AGT-013 — Every change records a meaningful agent improvement
# Binding:  BIND-AGT-013-AGENT
# Standard: SRC-PLATFORM-AGENT-CONVENTIONS

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "AGT-013 policy error: missing input data"},
}

# On a pull request the learnings ledger must be among the changed files.
pr_needs_ledger_update if {
	input.improvement.is_pull_request == true
	input.improvement.ledger_updated_in_pr != true
}

result := {
	"result": "not_applicable",
	"details": {"message": "AGT-013: repository declares no agent configuration"},
} if {
	input.has_agent_config != true
}

# FAIL — no learnings ledger at all
result := {
	"result": "fail",
	"details": {
		"checked": sprintf("Agent improvement ledger in '%v'", [input.repository.name]),
		"found": "no learnings ledger present",
		"expected": "an agent learnings ledger (e.g. .github/AGENT_LEARNINGS.md)",
		"message": "AGT-013: create an agent learnings ledger and record improvements per change.",
	},
} if {
	input.has_agent_config == true
	input.improvement.ledger_present != true
}

# FAIL — this pull request did not record an improvement
result := {
	"result": "fail",
	"details": {
		"checked": sprintf("Ledger update in PR for '%v'", [input.repository.name]),
		"found": sprintf("ledger '%v' not updated in this pull request", [input.improvement.ledger_path]),
		"expected": "each pull request adds/updates a learnings-ledger entry",
		"message": "AGT-013: add a meaningful entry to the agent learnings ledger in this PR.",
	},
} if {
	input.has_agent_config == true
	input.improvement.ledger_present == true
	pr_needs_ledger_update
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked": sprintf("Agent improvement ledger in '%v'", [input.repository.name]),
		"found": sprintf("ledger '%v' present with %v entries", [input.improvement.ledger_path, input.improvement.ledger_entry_count]),
		"expected": "ledger present; updated per pull request",
		"message": "AGT-013: agent improvements are recorded",
	},
} if {
	input.has_agent_config == true
	input.improvement.ledger_present == true
	not pr_needs_ledger_update
}
