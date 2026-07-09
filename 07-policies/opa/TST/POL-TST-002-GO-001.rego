package platform.tst.tst_002_go

# Control:  TST-002 — Test coverage must meet the minimum threshold (>=70%)
# Binding:  BIND-TST-002-GO
# Standard: SRC-TESTING-PRACTICES
#
# Threshold: 70%. This control warns now, blocks at v2.0.0 (ADR-0016 decision 4).

import future.keywords.if

threshold := 70.0

default result := {
	"result": "error",
	"details": {"message": "TST-002 policy error: missing input data"},
}

result := {
	"result": "not_applicable",
	"details": {"message": "TST-002: no Go module detected"},
} if {
	input.has_go_module != true
}

result := {
	"result": "not_applicable",
	"details": {"message": "TST-002: coverage not measured (no tests or toolchain unavailable)"},
} if {
	input.has_go_module == true
	input.testing.coverage_percent == null
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Go test coverage for '%v'", [input.repository.name]),
		"found":    sprintf("coverage %v%%", [input.testing.coverage_percent]),
		"expected": sprintf("coverage >= %v%%", [threshold]),
		"message":  sprintf("TST-002: Test coverage %v%% meets the %v%% threshold", [input.testing.coverage_percent, threshold]),
	},
} if {
	input.has_go_module == true
	input.testing.coverage_percent != null
	input.testing.coverage_percent >= threshold
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Go test coverage for '%v'", [input.repository.name]),
		"found":    sprintf("coverage %v%%", [input.testing.coverage_percent]),
		"expected": sprintf("coverage >= %v%%", [threshold]),
		"message":  sprintf("TST-002: Coverage %v%% is below the %v%% threshold (warn now, blocks at v2.0.0)", [input.testing.coverage_percent, threshold]),
	},
} if {
	input.has_go_module == true
	input.testing.coverage_percent != null
	input.testing.coverage_percent < threshold
}
