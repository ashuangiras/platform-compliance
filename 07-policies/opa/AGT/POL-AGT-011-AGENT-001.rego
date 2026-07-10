package platform.agt.agt_011_agent

# Control:  AGT-011 — MCP server trust and pinning
# Binding:  BIND-AGT-011-AGENT
# Standard: SRC-MCP-SPEC, SRC-VSCODE-AGENT-CUSTOMIZATION

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "AGT-011 policy error: missing input data"},
}

# NOT APPLICABLE — no MCP configuration present
result := {
	"result": "not_applicable",
	"details": {"message": "AGT-011: no .vscode/mcp.json present"},
} if {
	input.mcp.config_present != true
}

result := {
	"result": "pass",
	"details": {
		"checked": sprintf("MCP servers in '%v'", [input.repository.name]),
		"expected": "every server declares a type and is version-pinned",
		"message": "AGT-011: all MCP servers declare a type and are pinned",
	},
} if {
	input.mcp.config_present == true
	count(input.mcp.servers_missing_type) == 0
	count(input.mcp.unpinned_servers) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked": sprintf("MCP servers in '%v'", [input.repository.name]),
		"found": sprintf("missing type: [%v]; unpinned: [%v]", [concat(", ", input.mcp.servers_missing_type), concat(", ", input.mcp.unpinned_servers)]),
		"expected": "explicit type per server; pinned endpoint (fixed URL, @version, or non-latest image tag)",
		"message": "AGT-011: declare a type and pin the listed MCP servers.",
	},
} if {
	input.mcp.config_present == true
	count(array.concat(input.mcp.servers_missing_type, input.mcp.unpinned_servers)) > 0
}
