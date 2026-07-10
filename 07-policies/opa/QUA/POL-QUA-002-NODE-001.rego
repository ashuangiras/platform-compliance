package platform.qua.qua_002_node

# Control:  QUA-002 — Code must be formatted according to project standards
# Binding:  BIND-QUA-002-NODE
# Standard: SRC-NODE-STYLE

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "QUA-002 policy error: missing input data"},
}

# NOT APPLICABLE — no Node.js module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-002: no Node.js module detected (has_node_module: false)"},
} if {
	input.has_node_module != true
}

# NOT APPLICABLE — Prettier unavailable on the runner (cannot evaluate)
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-002: Prettier unavailable in CI; format not evaluated"},
} if {
	input.has_node_module == true
	input.quality.format.result == "unavailable"
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Node.js formatting for '%v'", [input.repository.name]),
		"found":    "format passed",
		"expected": "format result == pass",
		"message":  "QUA-002: Prettier format check passed",
	},
} if {
	input.has_node_module == true
	input.quality.format.result == "pass"
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Node.js formatting for '%v'", [input.repository.name]),
		"found":    sprintf("format result: %v", [input.quality.format.result]),
		"expected": "format result == pass",
		"message":  "QUA-002: Prettier format check failed. Run 'prettier --write .' to fix formatting.",
	},
} if {
	input.has_node_module == true
	input.quality.format.result == "fail"
}
