package platform.agt.agt_001_agent

# Control:  AGT-001 — Repository agent instructions must be single-sourced
# Binding:  BIND-AGT-001-AGENT
# Standard: SRC-VSCODE-AGENT-CUSTOMIZATION, SRC-AGENTS-MD

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "AGT-001 policy error: missing input data"},
}

# NOT APPLICABLE — repository ships no agent configuration
result := {
	"result": "not_applicable",
	"details": {"message": "AGT-001: repository declares no agent configuration"},
} if {
	input.has_agent_config != true
}

# PASS — exactly one root instruction source
result := {
	"result": "pass",
	"details": {
		"checked": sprintf("Root agent instructions for '%v'", [input.repository.name]),
		"found": sprintf("single source: %v", [input.instructions.root_instructions_file]),
		"expected": "exactly one of copilot-instructions.md / AGENTS.md",
		"message": "AGT-001: repository instructions are single-sourced",
	},
} if {
	input.has_agent_config == true
	input.instructions.single_source == true
}

# FAIL — zero or two root instruction sources
result := {
	"result": "fail",
	"details": {
		"checked": sprintf("Root agent instructions for '%v'", [input.repository.name]),
		"found": sprintf(
			"instruction source count: %v (copilot: %v, AGENTS.md: %v)",
			[input.instructions.instruction_source_count, input.instructions.copilot_instructions_present, input.instructions.agents_md_present],
		),
		"expected": "exactly one root instruction source (copilot-instructions.md XOR AGENTS.md)",
		"message": "AGT-001: repository must have exactly one root instruction source; found neither or both.",
	},
} if {
	input.has_agent_config == true
	input.instructions.single_source == false
}
