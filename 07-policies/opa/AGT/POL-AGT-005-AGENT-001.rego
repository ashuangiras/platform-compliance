package platform.agt.agt_005_agent

# Control:  AGT-005 — Least-privilege agent tools
# Binding:  BIND-AGT-005-AGENT
# Standard: SRC-VSCODE-AGENT-CUSTOMIZATION, SRC-PLATFORM-AGENT-CONVENTIONS

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "AGT-005 policy error: missing input data"},
}

result := {
	"result": "not_applicable",
	"details": {"message": "AGT-005: repository declares no agent configuration"},
} if {
	input.has_agent_config != true
}

result := {
	"result": "pass",
	"details": {
		"checked": sprintf("Agent tool declarations in '%v'", [input.repository.name]),
		"expected": "explicit tools per agent; read-only agents without edit",
		"message": "AGT-005: all agents declare least-privilege tools",
	},
} if {
	input.has_agent_config == true
	count(input.agents.agents_missing_tools) == 0
	count(input.agents.readonly_agents_with_write_tools) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked": sprintf("Agent tool declarations in '%v'", [input.repository.name]),
		"found": sprintf("no explicit tools: [%v]; read-only agents holding edit: [%v]", [concat(", ", input.agents.agents_missing_tools), concat(", ", input.agents.readonly_agents_with_write_tools)]),
		"expected": "every agent declares explicit tools; review/read-only agents exclude edit",
		"message": "AGT-005: fix the listed agents' tool sets.",
	},
} if {
	input.has_agent_config == true
	count(array.concat(input.agents.agents_missing_tools, input.agents.readonly_agents_with_write_tools)) > 0
}
