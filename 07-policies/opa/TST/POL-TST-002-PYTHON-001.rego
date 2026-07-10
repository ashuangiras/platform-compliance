package platform.tst.tst_002_python

# Control:  TST-002 — Test coverage must meet the minimum threshold (>=70%)
# Binding:  BIND-TST-002-PYTHON
# Standard: SRC-TESTING-PRACTICES
#
# Threshold: 70%. This control warns now, blocks at v2.0.0 (ADR-0016 decision 4).

import future.keywords.if

threshold := 70.0

default result := {
	"result": "error",
	"details": {"message": "TST-002 policy error: missing input data"},
}

# NOT APPLICABLE — no Python project in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "TST-002: no Python project detected"},
} if {
	input.has_python_project != true
}

# NOT APPLICABLE — coverage not measured (no tests or toolchain unavailable)
result := {
	"result": "not_applicable",
	"details": {"message": "TST-002: coverage not measured (no tests or toolchain unavailable)"},
} if {
	input.has_python_project == true
	input.testing.coverage_percent == null
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Python test coverage for '%v'", [input.repository.name]),
		"found":    sprintf("coverage %v%%", [input.testing.coverage_percent]),
		"expected": sprintf("coverage >= %v%%", [threshold]),
		"message":  sprintf("TST-002: Test coverage %v%% meets the %v%% threshold", [input.testing.coverage_percent, threshold]),
	},
} if {
	input.has_python_project == true
	input.testing.coverage_percent != null
	input.testing.coverage_percent >= threshold
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Python test coverage for '%v'", [input.repository.name]),
		"found":    sprintf("coverage %v%%", [input.testing.coverage_percent]),
		"expected": sprintf("coverage >= %v%%", [threshold]),
		"message":  sprintf("TST-002: Coverage %v%% is below the %v%% threshold (warn now, blocks at v2.0.0)", [input.testing.coverage_percent, threshold]),
	},
} if {
	input.has_python_project == true
	input.testing.coverage_percent != null
	input.testing.coverage_percent < threshold
}
