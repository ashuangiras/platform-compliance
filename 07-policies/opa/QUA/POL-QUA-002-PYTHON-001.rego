package platform.qua.qua_002_python

# Control:  QUA-002 — Code must be formatted according to project standards
# Binding:  BIND-QUA-002-PYTHON
# Standard: SRC-PYTHON-STYLE

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "QUA-002 policy error: missing input data"},
}

# NOT APPLICABLE — no Python project in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-002: no Python project detected (has_python_project: false)"},
} if {
	input.has_python_project != true
}

# NOT APPLICABLE — ruff format unavailable on the runner (cannot evaluate)
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-002: ruff format unavailable in CI; format not evaluated"},
} if {
	input.has_python_project == true
	input.quality.format.result == "unavailable"
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Python formatting for '%v'", [input.repository.name]),
		"found":    "format passed",
		"expected": "format result == pass",
		"message":  "QUA-002: ruff format check passed",
	},
} if {
	input.has_python_project == true
	input.quality.format.result == "pass"
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Python formatting for '%v'", [input.repository.name]),
		"found":    sprintf("format result: %v", [input.quality.format.result]),
		"expected": "format result == pass",
		"message":  "QUA-002: ruff format check failed. Run 'ruff format .' to fix formatting.",
	},
} if {
	input.has_python_project == true
	input.quality.format.result == "fail"
}
