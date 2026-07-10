package platform.agt.agt_012_agent

# Control:  AGT-012 — Repository instruction completeness
# Binding:  BIND-AGT-012-AGENT
# Standard: SRC-VSCODE-AGENT-CUSTOMIZATION, SRC-AGENTS-MD, SRC-PLATFORM-AGENT-CONVENTIONS

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "AGT-012 policy error: missing input data"},
}

root_present if {
	input.instructions.root_instructions_file != null
}

# NOT APPLICABLE — no root instruction file (AGT-001 governs its presence)
result := {
	"result": "not_applicable",
	"details": {"message": "AGT-012: no root instruction file present"},
} if {
	not root_present
}

result := {
	"result": "pass",
	"details": {
		"checked": sprintf("Instruction completeness in '%v'", [input.instructions.root_instructions_file]),
		"expected": "covers build/test/validation, conventions/architecture, and safety",
		"message": "AGT-012: repository instructions are complete",
	},
} if {
	root_present
	input.instructions.complete == true
}

result := {
	"result": "fail",
	"details": {
		"checked": sprintf("Instruction completeness in '%v'", [input.instructions.root_instructions_file]),
		"found": sprintf("build/test: %v, conventions: %v, safety: %v", [input.instructions.has_build_test, input.instructions.has_conventions, input.instructions.has_safety]),
		"expected": "all of: build/test/validation, conventions/architecture, and safety",
		"message": "AGT-012: add the missing section(s) to repository instructions.",
	},
} if {
	root_present
	input.instructions.complete != true
}
