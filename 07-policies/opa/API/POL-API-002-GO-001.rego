package platform.api.api_002_go

# Control:  API-002 — OpenAPI spec must declare explicit version and versioned path
# Binding:  BIND-API-002-GO
# Standard: SRC-OPENAPI-3-1

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "API-002 policy error: missing input data"},
}

# NOT APPLICABLE — no Go module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "API-002: no Go module detected (has_go_module: false)"},
} if {
	input.has_go_module != true
}

# NOT APPLICABLE — no OpenAPI spec to check
result := {
	"result": "not_applicable",
	"details": {"message": "API-002: no OpenAPI spec present; API-001 must pass first"},
} if {
	input.has_go_module == true
	input.api.openapi_spec_present != true
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("API versioning in OpenAPI spec for '%v'", [input.repository.name]),
		"found":    "info.version declared and versioned path prefix present",
		"expected": "api_version_declared == true",
		"message":  "API-002: API versioning strategy is properly declared",
	},
} if {
	input.has_go_module == true
	input.api.openapi_spec_present == true
	input.api.api_version_declared == true
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("API versioning in OpenAPI spec for '%v'", [input.repository.name]),
		"found":    "info.version missing or no /vN/ path prefix found",
		"expected": "api_version_declared == true",
		"message":  "API-002: Set info.version in OpenAPI spec and prefix all paths with /v1/ (or /v2/, etc.).",
	},
} if {
	input.has_go_module == true
	input.api.openapi_spec_present == true
	input.api.api_version_declared != true
}
