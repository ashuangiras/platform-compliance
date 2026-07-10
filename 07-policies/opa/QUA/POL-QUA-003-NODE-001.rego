package platform.qua.qua_003_node

# Control:  QUA-003 — Project must build successfully
# Binding:  BIND-QUA-003-NODE
# Standard: SRC-NODE-STYLE

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "QUA-003 policy error: missing input data"},
}

# NOT APPLICABLE — no Node.js module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-003: no Node.js module detected (has_node_module: false)"},
} if {
	input.has_node_module != true
}

# NOT APPLICABLE — build tool unavailable on the runner (cannot evaluate)
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-003: Node.js build unavailable in CI; build not evaluated"},
} if {
	input.has_node_module == true
	input.quality.build.result == "unavailable"
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Node.js build for '%v'", [input.repository.name]),
		"found":    "build passed",
		"expected": "build result == pass",
		"message":  "QUA-003: Node.js build succeeded",
	},
} if {
	input.has_node_module == true
	input.quality.build.result == "pass"
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Node.js build for '%v'", [input.repository.name]),
		"found":    sprintf("build result: %v", [input.quality.build.result]),
		"expected": "build result == pass",
		"message":  "QUA-003: Node.js build failed. Fix build errors before merge.",
	},
} if {
	input.has_node_module == true
	input.quality.build.result == "fail"
}
