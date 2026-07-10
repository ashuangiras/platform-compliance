package platform.agt.agt_015_agent

# Control:  AGT-015 — Team-wide agent discovery settings
# Binding:  BIND-AGT-015-AGENT
# Standard: SRC-VSCODE-AGENT-CUSTOMIZATION, SRC-PLATFORM-AGENT-CONVENTIONS

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "AGT-015 policy error: missing input data"},
}

# NOT APPLICABLE — no custom agents, so discovery settings are moot
result := {
	"result": "not_applicable",
	"details": {"message": "AGT-015: repository defines no custom agents"},
} if {
	input.agents.count == 0
}

result := {
	"result": "pass",
	"details": {
		"checked": sprintf("Agent discovery settings for '%v'", [input.repository.name]),
		"expected": ".vscode/settings.json enables chat.agentFilesLocations for .github/agents",
		"message": "AGT-015: agent discovery is enabled for the whole team",
	},
} if {
	input.agents.count > 0
	input.discovery.agent_location_enabled == true
}

result := {
	"result": "fail",
	"details": {
		"checked": sprintf("Agent discovery settings for '%v'", [input.repository.name]),
		"found": sprintf("settings.json present: %v, agent location enabled: %v", [input.discovery.settings_file_present, input.discovery.agent_location_enabled]),
		"expected": ".vscode/settings.json with chat.agentFilesLocations enabling .github/agents",
		"message": "AGT-015: commit .vscode/settings.json (see templates/agent-vscode-settings.template.json) to make the agent team discoverable for everyone.",
	},
} if {
	input.agents.count > 0
	input.discovery.agent_location_enabled != true
}
