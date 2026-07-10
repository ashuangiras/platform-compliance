package platform.api.api_001_go

# Control:  API-001 — Services must include a machine-readable OpenAPI specification
# Binding:  BIND-API-001-GO
# Standard: SRC-OPENAPI-3-1

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "API-001 policy error: missing input data"},
}

# NOT APPLICABLE — no Go module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "API-001: no Go module detected (has_go_module: false)"},
} if {
	input.has_go_module != true
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("OpenAPI spec presence for '%v'", [input.repository.name]),
		"found":    sprintf("OpenAPI spec found at: %v", [input.api.openapi_spec_path]),
		"expected": "openapi.yaml or openapi.json present",
		"message":  "API-001: OpenAPI specification is present",
	},
} if {
	input.has_go_module == true
	input.api.openapi_spec_present == true
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("OpenAPI spec presence for '%v'", [input.repository.name]),
		"found":    "no openapi.yaml or openapi.json found",
		"expected": "openapi.yaml or openapi.json at root, docs/, or api/",
		"message":  "API-001: Missing OpenAPI specification. Add openapi.yaml or openapi.json.",
	},
} if {
	input.has_go_module == true
	input.api.openapi_spec_present != true
}
