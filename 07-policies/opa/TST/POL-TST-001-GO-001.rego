package platform.tst.tst_001_go

# Control:  TST-001 — Repository must contain automated tests that run in CI
# Binding:  BIND-TST-001-GO
# Standard: SRC-TESTING-PRACTICES

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "TST-001 policy error: missing input data"},
}

result := {
	"result": "not_applicable",
	"details": {"message": "TST-001: no Go module detected"},
} if {
	input.has_go_module != true
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Go tests for '%v'", [input.repository.name]),
		"found":    sprintf("%v test file(s), tests pass", [input.testing.test_file_count]),
		"expected": "tests present and go test passes",
		"message":  "TST-001: Automated tests exist and pass",
	},
} if {
	input.has_go_module == true
	input.testing.tests_present == true
	input.testing.test_result == "pass"
}

result := {
	"result": "not_applicable",
	"details": {"message": "TST-001: Go toolchain unavailable on runner; tests not run"},
} if {
	input.has_go_module == true
	input.testing.tests_present == true
	input.testing.test_result == "unavailable"
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Go tests for '%v'", [input.repository.name]),
		"found":    "No test files found",
		"expected": "At least one *_test.go file with passing tests",
		"message":  "TST-001: No automated tests found. Add *_test.go files.",
	},
} if {
	input.has_go_module == true
	input.testing.tests_present == false
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Go tests for '%v'", [input.repository.name]),
		"found":    "Tests present but failing",
		"expected": "go test ./... passes",
		"message":  "TST-001: Tests are failing. Fix failing tests before merge.",
	},
} if {
	input.has_go_module == true
	input.testing.tests_present == true
	input.testing.test_result == "fail"
}
