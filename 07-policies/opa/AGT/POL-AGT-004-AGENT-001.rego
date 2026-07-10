package platform.agt.agt_004_agent

# Control:  AGT-004 — Descriptions must be discoverable
# Binding:  BIND-AGT-004-AGENT
# Standard: SRC-VSCODE-AGENT-CUSTOMIZATION, SRC-PLATFORM-AGENT-CONVENTIONS

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "AGT-004 policy error: missing input data"},
}

result := {
	"result": "not_applicable",
	"details": {"message": "AGT-004: repository declares no agent configuration"},
} if {
	input.has_agent_config != true
}

result := {
	"result": "pass",
	"details": {
		"checked": sprintf("Descriptions in '%v'", [input.repository.name]),
		"expected": sprintf(">= %v chars, keyword-rich", [input.descriptions.weak_min]),
		"message": "AGT-004: all customization descriptions are substantive",
	},
} if {
	input.has_agent_config == true
	count(input.descriptions.weak_files) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked": sprintf("Descriptions in '%v'", [input.repository.name]),
		"found": sprintf("weak/short descriptions: %v", [concat(", ", input.descriptions.weak_files)]),
		"expected": sprintf(">= %v chars, keyword-rich (use 'Use when…')", [input.descriptions.weak_min]),
		"message": "AGT-004: strengthen the listed descriptions.",
	},
} if {
	input.has_agent_config == true
	count(input.descriptions.weak_files) > 0
}
