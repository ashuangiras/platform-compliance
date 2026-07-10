package platform.qua.qua_001_node

# Control:  QUA-001 — Source code must pass the linter
# Binding:  BIND-QUA-001-NODE
# Standard: SRC-NODE-STYLE

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "QUA-001 policy error: missing input data"},
}

# NOT APPLICABLE — no Node.js module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-001: no Node.js module detected (has_node_module: false)"},
} if {
	input.has_node_module != true
}

# NOT APPLICABLE — ESLint unavailable on the runner (cannot evaluate)
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-001: ESLint unavailable in CI; lint not evaluated"},
} if {
	input.has_node_module == true
	input.quality.lint.result == "unavailable"
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Node.js lint for '%v'", [input.repository.name]),
		"found":    "lint passed",
		"expected": "lint result == pass",
		"message":  "QUA-001: ESLint check passed",
	},
} if {
	input.has_node_module == true
	input.quality.lint.result == "pass"
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Node.js lint for '%v'", [input.repository.name]),
		"found":    sprintf("lint result: %v", [input.quality.lint.result]),
		"expected": "lint result == pass",
		"message":  "QUA-001: ESLint check failed. Fix the reported issues and re-run ESLint.",
	},
} if {
	input.has_node_module == true
	input.quality.lint.result == "fail"
}
