package platform.agt.agt_006_agent

# Control:  AGT-006 — Instruction scoping hygiene
# Binding:  BIND-AGT-006-AGENT
# Standard: SRC-VSCODE-AGENT-CUSTOMIZATION

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "AGT-006 policy error: missing input data"},
}

result := {
	"result": "not_applicable",
	"details": {"message": "AGT-006: repository declares no agent configuration"},
} if {
	input.has_agent_config != true
}

result := {
	"result": "pass",
	"details": {
		"checked": sprintf("Instruction scoping in '%v'", [input.repository.name]),
		"expected": "each .instructions.md scoped via applyTo or description; no bare '**'",
		"message": "AGT-006: all file instructions are scoped",
	},
} if {
	input.has_agent_config == true
	count(input.instruction_files.broad_applyto_files) == 0
	count(input.instruction_files.missing_description_files) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked": sprintf("Instruction scoping in '%v'", [input.repository.name]),
		"found": sprintf("broad applyTo '**': [%v]; undiscoverable (no applyTo/description): [%v]", [concat(", ", input.instruction_files.broad_applyto_files), concat(", ", input.instruction_files.missing_description_files)]),
		"expected": "specific applyTo or a description on every .instructions.md; never bare '**'",
		"message": "AGT-006: scope the listed instruction files.",
	},
} if {
	input.has_agent_config == true
	count(array.concat(input.instruction_files.broad_applyto_files, input.instruction_files.missing_description_files)) > 0
}
