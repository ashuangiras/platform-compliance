package platform.api.api_003_go

# Control:  API-003 — PRs modifying OpenAPI spec must include breaking-change analysis
# Binding:  BIND-API-003-GO
# Standard: SRC-OPENAPI-3-1

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "API-003 policy error: missing input data"},
}

# NOT APPLICABLE — no Go module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "API-003: no Go module detected (has_go_module: false)"},
} if {
	input.has_go_module != true
}

# NOT APPLICABLE — OpenAPI spec was not changed in this PR
result := {
	"result": "not_applicable",
	"details": {"message": "API-003: OpenAPI spec not modified in this PR; no breaking-change analysis required"},
} if {
	input.has_go_module == true
	input.api.openapi_spec_changed != true
}

# PASS — spec changed and annotation present
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Breaking-change analysis for '%v'", [input.repository.name]),
		"found":    "OpenAPI spec changed and breaking-change analysis present",
		"expected": "no-breaking-change annotation or oasdiff artifact",
		"message":  "API-003: Breaking-change analysis present for OpenAPI spec change",
	},
} if {
	input.has_go_module == true
	input.api.openapi_spec_changed == true
	input.api.breaking_change_analysed == true
}

# FAIL — spec changed but no annotation
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Breaking-change analysis for '%v'", [input.repository.name]),
		"found":    "OpenAPI spec changed but no breaking-change analysis found",
		"expected": "PR body contains 'no-breaking-change: true' or CI oasdiff artifact",
		"message":  "API-003: Add 'no-breaking-change: true' to PR body or attach oasdiff CI artifact.",
	},
} if {
	input.has_go_module == true
	input.api.openapi_spec_changed == true
	input.api.breaking_change_analysed != true
}
