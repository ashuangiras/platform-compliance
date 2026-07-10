package platform.tst.tst_001_python

# Control:  TST-001 — Repository must contain automated tests that run in CI
# Binding:  BIND-TST-001-PYTHON
# Standard: SRC-TESTING-PRACTICES

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "TST-001 policy error: missing input data"},
}

# NOT APPLICABLE — no Python project in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "TST-001: no Python project detected"},
} if {
	input.has_python_project != true
}

# NOT APPLICABLE — pytest unavailable on the runner (cannot evaluate)
result := {
	"result": "not_applicable",
	"details": {"message": "TST-001: pytest unavailable in CI; tests not evaluated"},
} if {
	input.has_python_project == true
	input.testing.tests_present == true
	input.testing.test_result == "unavailable"
}

# PASS — tests present and passing
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Python tests for '%v'", [input.repository.name]),
		"found":    "tests present and passing",
		"expected": "tests present and test result == pass",
		"message":  "TST-001: Automated tests exist and pass",
	},
} if {
	input.has_python_project == true
	input.testing.tests_present == true
	input.testing.test_result == "pass"
}

# FAIL — no tests found
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Python tests for '%v'", [input.repository.name]),
		"found":    "No test files found",
		"expected": "At least one test file with passing tests",
		"message":  "TST-001: No automated tests found. Add test files (e.g. test_*.py, *_test.py) and run with pytest.",
	},
} if {
	input.has_python_project == true
	input.testing.tests_present == false
}

# FAIL — tests present but failing
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Python tests for '%v'", [input.repository.name]),
		"found":    "Tests present but failing",
		"expected": "All tests must pass",
		"message":  "TST-001: Tests are failing. Fix failing pytest tests before merge.",
	},
} if {
	input.has_python_project == true
	input.testing.tests_present == true
	input.testing.test_result == "fail"
}
