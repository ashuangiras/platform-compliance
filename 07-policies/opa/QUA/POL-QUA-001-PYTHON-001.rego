package platform.qua.qua_001_python

# Control:  QUA-001 — Source code must pass the linter
# Binding:  BIND-QUA-001-PYTHON
# Standard: SRC-PYTHON-STYLE

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "QUA-001 policy error: missing input data"},
}

# NOT APPLICABLE — no Python project in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-001: no Python project detected (has_python_project: false)"},
} if {
	input.has_python_project != true
}

# NOT APPLICABLE — ruff unavailable on the runner (cannot evaluate)
result := {
	"result": "not_applicable",
	"details": {"message": "QUA-001: ruff unavailable in CI; lint not evaluated"},
} if {
	input.has_python_project == true
	input.quality.lint.result == "unavailable"
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Python lint for '%v'", [input.repository.name]),
		"found":    "lint passed",
		"expected": "lint result == pass",
		"message":  "QUA-001: ruff lint check passed",
	},
} if {
	input.has_python_project == true
	input.quality.lint.result == "pass"
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Python lint for '%v'", [input.repository.name]),
		"found":    sprintf("lint result: %v", [input.quality.lint.result]),
		"expected": "lint result == pass",
		"message":  "QUA-001: ruff lint check failed. Fix the reported issues and re-run ruff check.",
	},
} if {
	input.has_python_project == true
	input.quality.lint.result == "fail"
}
