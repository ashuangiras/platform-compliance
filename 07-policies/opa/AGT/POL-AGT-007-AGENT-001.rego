package platform.agt.agt_007_agent

# Control:  AGT-007 — Pre-flight and post-flight checklists
# Binding:  BIND-AGT-007-AGENT
# Standard: SRC-PLATFORM-AGENT-CONVENTIONS

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "AGT-007 policy error: missing input data"},
}

root_present if {
	input.instructions.root_instructions_file != null
}

both_present if {
	input.instructions.has_preflight == true
	input.instructions.has_postflight == true
}

# NOT APPLICABLE — no root instruction file (AGT-001 governs its presence)
result := {
	"result": "not_applicable",
	"details": {"message": "AGT-007: no root instruction file present"},
} if {
	not root_present
}

result := {
	"result": "pass",
	"details": {
		"checked": sprintf("Pre/post-flight in '%v'", [input.instructions.root_instructions_file]),
		"expected": "both a pre-flight and a post-flight checklist",
		"message": "AGT-007: repository instructions define pre-flight and post-flight",
	},
} if {
	root_present
	both_present
}

result := {
	"result": "fail",
	"details": {
		"checked": sprintf("Pre/post-flight in '%v'", [input.instructions.root_instructions_file]),
		"found": sprintf("pre-flight: %v, post-flight: %v", [input.instructions.has_preflight, input.instructions.has_postflight]),
		"expected": "both a pre-flight and a post-flight checklist",
		"message": "AGT-007: add the missing pre-flight/post-flight checklist to repository instructions.",
	},
} if {
	root_present
	not both_present
}
