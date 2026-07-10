package platform.agt.agt_010_agent

# Control:  AGT-010 — Agent role clarity and constraints
# Binding:  BIND-AGT-010-AGENT
# Standard: SRC-VSCODE-AGENT-CUSTOMIZATION, SRC-PLATFORM-AGENT-CONVENTIONS

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "AGT-010 policy error: missing input data"},
}

# NOT APPLICABLE — no custom agents defined
result := {
	"result": "not_applicable",
	"details": {"message": "AGT-010: repository defines no custom agents"},
} if {
	input.agents.count == 0
}

result := {
	"result": "pass",
	"details": {
		"checked": sprintf("Agent role/constraints in '%v'", [input.repository.name]),
		"expected": "each agent states a role and a constraints/boundaries section",
		"message": "AGT-010: every agent has a clear role and explicit constraints",
	},
} if {
	input.agents.count > 0
	count(input.agents.agents_missing_role) == 0
	count(input.agents.agents_missing_constraints) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked": sprintf("Agent role/constraints in '%v'", [input.repository.name]),
		"found": sprintf("missing role: [%v]; missing constraints: [%v]", [concat(", ", input.agents.agents_missing_role), concat(", ", input.agents.agents_missing_constraints)]),
		"expected": "each .agent.md states a single role and a constraints/boundaries section",
		"message": "AGT-010: add a role statement and constraints to the listed agents.",
	},
} if {
	input.agents.count > 0
	count(array.concat(input.agents.agents_missing_role, input.agents.agents_missing_constraints)) > 0
}
