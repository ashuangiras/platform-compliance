package platform.qua.qua_004_go

# Control:  QUA-004 — Static analysis (go vet) must pass
# Binding:  BIND-QUA-004-GO
# Standard: SRC-GO-STYLE

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "QUA-004 policy error: missing input data"},
}

# NOT APPLICABLE — no Go module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-004: no Go module detected (has_go_module: false)"},
} if {
	input.has_go_module != true
}

# NOT APPLICABLE — Go tool unavailable on the runner (cannot evaluate)
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-004: Go toolchain unavailable on runner; vet not evaluated"},
} if {
	input.has_go_module == true
	input.quality.vet.result == "unavailable"
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Go vet for '%v'", [input.repository.name]),
		"found":    "vet passed",
		"expected": "vet result == pass",
		"message":  "QUA-004: Go vet check passed",
	},
} if {
	input.has_go_module == true
	input.quality.vet.result == "pass"
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Go vet for '%v'", [input.repository.name]),
		"found":    sprintf("vet result: %v", [input.quality.vet.result]),
		"expected": "vet result == pass",
		"message":  "QUA-004: Go vet check failed. Fix the reported issues.",
	},
} if {
	input.has_go_module == true
	input.quality.vet.result == "fail"
}
