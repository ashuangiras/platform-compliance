package platform.qua.qua_004_node

# Control:  QUA-004 — Code must pass static type checking
# Binding:  BIND-QUA-004-NODE
# Standard: SRC-NODE-STYLE

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "QUA-004 policy error: missing input data"},
}

# NOT APPLICABLE — no Node.js module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-004: no Node.js module detected (has_node_module: false)"},
} if {
	input.has_node_module != true
}

# NOT APPLICABLE — TypeScript / tsc unavailable on the runner (cannot evaluate)
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-004: TypeScript (tsc) unavailable in CI; typecheck not evaluated"},
} if {
	input.has_node_module == true
	input.quality.typecheck.result == "unavailable"
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Node.js type check for '%v'", [input.repository.name]),
		"found":    "typecheck passed",
		"expected": "typecheck result == pass",
		"message":  "QUA-004: TypeScript type check passed",
	},
} if {
	input.has_node_module == true
	input.quality.typecheck.result == "pass"
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Node.js type check for '%v'", [input.repository.name]),
		"found":    sprintf("typecheck result: %v", [input.quality.typecheck.result]),
		"expected": "typecheck result == pass",
		"message":  "QUA-004: TypeScript type check failed. Fix type errors reported by tsc before merge.",
	},
} if {
	input.has_node_module == true
	input.quality.typecheck.result == "fail"
}
