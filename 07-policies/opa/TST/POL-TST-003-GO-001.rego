package platform.tst.tst_003_go

# Control:  TST-003 — Services must have at least one integration/e2e test
# Binding:  BIND-TST-003-GO
# Standard: SRC-TESTING-PRACTICES, SRC-GOOGLE-SRE (Ch.17)
#
# Scope: repository.type == "service" (evaluated by the profile scope condition;
# this policy checks the signal and returns not_applicable when no Go module).

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "TST-003 policy error: missing input data"},
}

result := {
	"result": "not_applicable",
	"details": {"message": "TST-003: no Go module detected"},
} if {
	input.has_go_module != true
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Integration tests for '%v'", [input.repository.name]),
		"found":    "Integration or e2e test detected",
		"expected": "At least one integration/e2e test",
		"message":  "TST-003: Integration/e2e test present",
	},
} if {
	input.has_go_module == true
	input.testing.integration_test_present == true
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Integration tests for '%v'", [input.repository.name]),
		"found":    "No integration or e2e test detected",
		"expected": "At least one *_integration_test.go, integration/ or e2e/ test, or //go:build integration test",
		"message":  "TST-003: No integration/e2e test found. Services must test across component boundaries.",
	},
} if {
	input.has_go_module == true
	input.testing.integration_test_present == false
}
