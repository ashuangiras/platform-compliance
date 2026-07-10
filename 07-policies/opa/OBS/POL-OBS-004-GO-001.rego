package platform.obs.obs_004_go

# Control:  OBS-004 — Services must instrument distributed tracing using OpenTelemetry
# Binding:  BIND-OBS-004-GO
# Standard: SRC-CNCF-OTEL, SRC-GOOGLE-SRE

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "OBS-004 policy error: missing input data"},
}

# NOT APPLICABLE — no Go module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "OBS-004: no Go module detected (has_go_module: false)"},
} if {
	input.has_go_module != true
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("OpenTelemetry dependency for '%v'", [input.repository.name]),
		"found":    "go.opentelemetry.io/otel present in go.sum",
		"expected": "otel_dependency_present == true",
		"message":  "OBS-004: OpenTelemetry Go SDK is present",
	},
} if {
	input.has_go_module == true
	input.observability.otel_dependency_present == true
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("OpenTelemetry dependency for '%v'", [input.repository.name]),
		"found":    "go.opentelemetry.io/otel not found in go.sum",
		"expected": "otel_dependency_present == true",
		"message":  "OBS-004: Add go.opentelemetry.io/otel to instrument distributed tracing.",
	},
} if {
	input.has_go_module == true
	input.observability.otel_dependency_present != true
}
