package platform.agt.agt_009_agent

# Control:  AGT-009 — Multi-agent routing
# Binding:  BIND-AGT-009-AGENT
# Standard: SRC-PLATFORM-AGENT-CONVENTIONS

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "AGT-009 policy error: missing input data"},
}

# NOT APPLICABLE — zero or one agent means no routing is required
result := {
	"result": "not_applicable",
	"details": {"message": "AGT-009: one or zero agents; routing not required"},
} if {
	input.agents.count <= 1
}

result := {
	"result": "pass",
	"details": {
		"checked": sprintf("Routing across %v agents in '%v'", [input.agents.count, input.repository.name]),
		"expected": "a router/coordinator agent",
		"message": "AGT-009: a router coordinates the specialist agents",
	},
} if {
	input.agents.count > 1
	input.agents.router_present == true
}

result := {
	"result": "fail",
	"details": {
		"checked": sprintf("Routing across %v agents in '%v'", [input.agents.count, input.repository.name]),
		"found": "no router/coordinator agent",
		"expected": "a coordinator/router agent when more than one agent exists",
		"message": "AGT-009: add a router agent to coordinate the specialists.",
	},
} if {
	input.agents.count > 1
	input.agents.router_present != true
}
