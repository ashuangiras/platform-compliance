package platform.qua.qua_003_go

# Control:  QUA-003 — Project must build successfully
# Binding:  BIND-QUA-003-GO
# Standard: SRC-GO-STYLE

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "QUA-003 policy error: missing input data"},
}

# NOT APPLICABLE — no Go module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-003: no Go module detected (has_go_module: false)"},
} if {
	input.has_go_module != true
}

# NOT APPLICABLE — Go tool unavailable on the runner (cannot evaluate)
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-003: Go toolchain unavailable on runner; build not evaluated"},
} if {
	input.has_go_module == true
	input.quality.build.result == "unavailable"
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Go build for '%v'", [input.repository.name]),
		"found":    "build passed",
		"expected": "build result == pass",
		"message":  "QUA-003: Go build check passed",
	},
} if {
	input.has_go_module == true
	input.quality.build.result == "pass"
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Go build for '%v'", [input.repository.name]),
		"found":    sprintf("build result: %v", [input.quality.build.result]),
		"expected": "build result == pass",
		"message":  "QUA-003: Go build check failed. Fix the reported issues.",
	},
} if {
	input.has_go_module == true
	input.quality.build.result == "fail"
}
