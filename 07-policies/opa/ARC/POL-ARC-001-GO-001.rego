package platform.arc.arc_001_go

# Control:  ARC-001 — Go repositories must follow the standard project layout
# Binding:  BIND-ARC-001-GO
# Standard: SRC-GO-STYLE, SRC-12-FACTOR

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "ARC-001 policy error: missing input data"},
}

# NOT APPLICABLE — no Go module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "ARC-001: no Go module detected (has_go_module: false)"},
} if {
	input.has_go_module != true
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Go project layout for '%v'", [input.repository.name]),
		"found":    "standard project layout present",
		"expected": "cmd/ directory or single main.go at root",
		"message":  "ARC-001: Go project layout check passed",
	},
} if {
	input.has_go_module == true
	input.architecture.project_layout.layout_ok == true
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Go project layout for '%v'", [input.repository.name]),
		"found":    "non-standard project layout",
		"expected": "cmd/ directory or single main.go at root",
		"message":  "ARC-001: Go project layout check failed. Add a cmd/ directory for application entry points.",
	},
} if {
	input.has_go_module == true
	input.architecture.project_layout.layout_ok != true
}
