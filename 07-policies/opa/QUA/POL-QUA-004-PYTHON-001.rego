package platform.qua.qua_004_python

# Control:  QUA-004 — Code must pass static type checking
# Binding:  BIND-QUA-004-PYTHON
# Standard: SRC-PYTHON-STYLE

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "QUA-004 policy error: missing input data"},
}

# NOT APPLICABLE — no Python project in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-004: no Python project detected (has_python_project: false)"},
} if {
	input.has_python_project != true
}

# NOT APPLICABLE — mypy unavailable on the runner (cannot evaluate)
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-004: mypy unavailable in CI; typecheck not evaluated"},
} if {
	input.has_python_project == true
	input.quality.typecheck.result == "unavailable"
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Python type check for '%v'", [input.repository.name]),
		"found":    "typecheck passed",
		"expected": "typecheck result == pass",
		"message":  "QUA-004: mypy type check passed",
	},
} if {
	input.has_python_project == true
	input.quality.typecheck.result == "pass"
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Python type check for '%v'", [input.repository.name]),
		"found":    sprintf("typecheck result: %v", [input.quality.typecheck.result]),
		"expected": "typecheck result == pass",
		"message":  "QUA-004: mypy type check failed. Fix type errors reported by mypy before merge.",
	},
} if {
	input.has_python_project == true
	input.quality.typecheck.result == "fail"
}
