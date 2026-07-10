package platform.agt.agt_002_agent

# Control:  AGT-002 — Customization files must have valid frontmatter + description
# Binding:  BIND-AGT-002-AGENT
# Standard: SRC-VSCODE-AGENT-CUSTOMIZATION

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "AGT-002 policy error: missing input data"},
}

# NOT APPLICABLE — repository ships no agent configuration
result := {
	"result": "not_applicable",
	"details": {"message": "AGT-002: repository declares no agent configuration"},
} if {
	input.has_agent_config != true
}

# PASS — all customization files have valid frontmatter + description
result := {
	"result": "pass",
	"details": {
		"checked": sprintf("Frontmatter of %v customization file(s) in '%v'", [input.frontmatter.total_files, input.repository.name]),
		"found": sprintf("valid: %v/%v", [input.frontmatter.valid_count, input.frontmatter.total_files]),
		"expected": "every .agent.md / .instructions.md / .prompt.md has valid frontmatter + description",
		"message": "AGT-002: all customization files have valid frontmatter and a description",
	},
} if {
	input.has_agent_config == true
	input.frontmatter.all_valid == true
}

# FAIL — one or more files have missing/invalid frontmatter or no description
result := {
	"result": "fail",
	"details": {
		"checked": sprintf("Frontmatter of %v customization file(s) in '%v'", [input.frontmatter.total_files, input.repository.name]),
		"found": sprintf("invalid: %v", [concat(", ", input.frontmatter.invalid_files)]),
		"expected": "every customization file has valid frontmatter + non-empty description",
		"message": "AGT-002: fix frontmatter/description on the listed files.",
	},
} if {
	input.has_agent_config == true
	input.frontmatter.all_valid == false
}
