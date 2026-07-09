package platform.qua.qua_002_go

# Control:  QUA-002 — Source code must be formatted
# Binding:  BIND-QUA-002-GO
# Standard: SRC-GO-STYLE

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "QUA-002 policy error: missing input data"},
}

# NOT APPLICABLE — no Go module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-002: no Go module detected (has_go_module: false)"},
} if {
	input.has_go_module != true
}

# NOT APPLICABLE — Go tool unavailable on the runner (cannot evaluate)
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-002: Go toolchain unavailable on runner; format not evaluated"},
} if {
	input.has_go_module == true
	input.quality.format.result == "unavailable"
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Go format for '%v'", [input.repository.name]),
		"found":    "format passed",
		"expected": "format result == pass",
		"message":  "QUA-002: Go format check passed",
	},
} if {
	input.has_go_module == true
	input.quality.format.result == "pass"
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Go format for '%v'", [input.repository.name]),
		"found":    sprintf("format result: %v", [input.quality.format.result]),
		"expected": "format result == pass",
		"message":  "QUA-002: Go format check failed. Fix the reported issues.",
	},
} if {
	input.has_go_module == true
	input.quality.format.result == "fail"
}
