package platform.qua.qua_001_go

# Control:  QUA-001 — Source code must pass the linter
# Binding:  BIND-QUA-001-GO
# Standard: SRC-GO-STYLE

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "QUA-001 policy error: missing input data"},
}

# NOT APPLICABLE — no Go module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-001: no Go module detected (has_go_module: false)"},
} if {
	input.has_go_module != true
}

# NOT APPLICABLE — Go tool unavailable on the runner (cannot evaluate)
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-001: Go toolchain unavailable on runner; lint not evaluated"},
} if {
	input.has_go_module == true
	input.quality.lint.result == "unavailable"
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Go lint for '%v'", [input.repository.name]),
		"found":    "lint passed",
		"expected": "lint result == pass",
		"message":  "QUA-001: Go lint check passed",
	},
} if {
	input.has_go_module == true
	input.quality.lint.result == "pass"
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Go lint for '%v'", [input.repository.name]),
		"found":    sprintf("lint result: %v", [input.quality.lint.result]),
		"expected": "lint result == pass",
		"message":  "QUA-001: Go lint check failed. Fix the reported issues.",
	},
} if {
	input.has_go_module == true
	input.quality.lint.result == "fail"
}
