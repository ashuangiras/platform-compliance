package platform.agt.agt_008_agent

# Control:  AGT-008 — PreToolUse safety hook
# Binding:  BIND-AGT-008-AGENT
# Standard: SRC-VSCODE-AGENT-CUSTOMIZATION, SRC-PLATFORM-AGENT-CONVENTIONS

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "AGT-008 policy error: missing input data"},
}

result := {
	"result": "not_applicable",
	"details": {"message": "AGT-008: repository declares no agent configuration"},
} if {
	input.has_agent_config != true
}

result := {
	"result": "pass",
	"details": {
		"checked": sprintf("Safety hook in '%v'", [input.repository.name]),
		"expected": "a PreToolUse guard with resolvable, executable scripts",
		"message": "AGT-008: a PreToolUse safety guard is configured and valid",
	},
} if {
	input.has_agent_config == true
	input.hooks.guard_ok == true
}

result := {
	"result": "fail",
	"details": {
		"checked": sprintf("Safety hook in '%v'", [input.repository.name]),
		"found": sprintf("PreToolUse present: %v; missing scripts: [%v]; non-executable: [%v]", [input.hooks.has_destructive_guard, concat(", ", input.hooks.missing_command_scripts), concat(", ", input.hooks.non_executable_scripts)]),
		"expected": "a PreToolUse hook guarding destructive ops; command scripts present and executable",
		"message": "AGT-008: add/repair the PreToolUse safety hook (.github/hooks/).",
	},
} if {
	input.has_agent_config == true
	input.hooks.guard_ok != true
}
