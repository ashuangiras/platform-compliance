package platform.arc.arc_003_go

# Control:  ARC-003 — Go packages must have zero import cycles
# Binding:  BIND-ARC-003-GO
# Standard: SRC-GO-STYLE

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "ARC-003 policy error: missing input data"},
}

# NOT APPLICABLE — no Go module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "ARC-003: no Go module detected (has_go_module: false)"},
} if {
	input.has_go_module != true
}

# NOT APPLICABLE — Go tool unavailable on the runner (cannot evaluate)
result := {
	"result": "not_applicable",
	"details": {"message": "ARC-003: Go toolchain unavailable on runner; vet not evaluated"},
} if {
	input.has_go_module == true
	input.quality.vet.result == "unavailable"
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Go import cycles for '%v'", [input.repository.name]),
		"found":    "go vet passed — no import cycles detected",
		"expected": "vet result == pass",
		"message":  "ARC-003: No import cycles detected",
	},
} if {
	input.has_go_module == true
	input.quality.vet.result == "pass"
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Go import cycles for '%v'", [input.repository.name]),
		"found":    sprintf("vet result: %v", [input.quality.vet.result]),
		"expected": "vet result == pass",
		"message":  "ARC-003: go vet failed — check for import cycles or layer boundary violations.",
	},
} if {
	input.has_go_module == true
	input.quality.vet.result == "fail"
}
