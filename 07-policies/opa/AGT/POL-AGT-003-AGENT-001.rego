package platform.agt.agt_003_agent

# Control:  AGT-003 — MCP configuration must be valid and free of hardcoded secrets
# Binding:  BIND-AGT-003-AGENT
# Standard: SRC-MCP-SPEC, SRC-VSCODE-AGENT-CUSTOMIZATION

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "AGT-003 policy error: missing input data"},
}

# NOT APPLICABLE — no MCP configuration present
result := {
	"result": "not_applicable",
	"details": {"message": "AGT-003: no .vscode/mcp.json present; MCP control not applicable"},
} if {
	input.mcp.config_present != true
}

# PASS — MCP config is valid JSON and contains no hardcoded secrets
result := {
	"result": "pass",
	"details": {
		"checked": sprintf("MCP configuration for '%v'", [input.repository.name]),
		"found": sprintf("valid JSON, %v server(s), no secrets", [input.mcp.server_count]),
		"expected": "valid JSON with no embedded credentials",
		"message": "AGT-003: MCP configuration is valid and secret-free",
	},
} if {
	input.mcp.config_present == true
	input.mcp.config_valid == true
	input.mcp.hardcoded_secret_suspected == false
}

# FAIL — MCP config is not valid JSON
result := {
	"result": "fail",
	"details": {
		"checked": sprintf("MCP configuration for '%v'", [input.repository.name]),
		"found": "invalid JSON",
		"expected": "valid JSON",
		"message": "AGT-003: .vscode/mcp.json is not valid JSON.",
	},
} if {
	input.mcp.config_present == true
	input.mcp.config_valid == false
}

# FAIL — hardcoded secret detected in MCP config
result := {
	"result": "fail",
	"details": {
		"checked": sprintf("MCP configuration for '%v'", [input.repository.name]),
		"found": sprintf("hardcoded secret(s) detected: %v", [concat(", ", input.mcp.secret_findings)]),
		"expected": "credentials referenced via ${input:…} / ${env:…}, never literal",
		"message": "AGT-003: remove hardcoded credentials from .vscode/mcp.json; use input/env references.",
	},
} if {
	input.mcp.config_present == true
	input.mcp.config_valid == true
	input.mcp.hardcoded_secret_suspected == true
}
