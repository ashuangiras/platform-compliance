package platform.obs.obs_002_github

# Control:  OBS-002 — Services must emit structured logs with required fields
# Binding:  BIND-OBS-002-MANUAL (manual attestation)
# Standard: SRC-GOOGLE-SRE (Chapter 12), SRC-AWS-WAF-2024 (OPS 4)
#
# This control is not-automatable for the content check, but the attestation
# record itself CAN be validated for presence and freshness.
#
# Input schema:
#   input.repository.name
#   input.service_type              — set only for service-type repos
#   input.attestation_present       — bool: does a structured-log attestation exist?
#   input.attestation_date          — ISO date string of the attestation
#   input.attestor                  — identity of the attesting person
#   input.sample_log_entry          — sample log line (for human review)

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "OBS-002 policy error: missing attestation data"},
}

result := {
	"result": "not_applicable",
	"details": {"message": "OBS-002: Not a service repository — structured logging not required"},
} if {
	not input.service_type
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Structured logging attestation for '%v'", [input.repository.name]),
		"found":    sprintf("Attestation by %v on %v", [input.attestor, input.attestation_date]),
		"expected": "Manual attestation that service emits structured JSON logs with required fields",
		"message":  "OBS-002: Structured logging attestation on record",
	},
} if {
	input.service_type
	input.attestation_present == true
	input.attestor != ""
	input.attestation_date != ""
}

result := {
	"result": "manual_review",
	"details": {
		"checked":  sprintf("Structured logging attestation for '%v'", [input.repository.name]),
		"found":    "No structured logging attestation on record",
		"expected": "An attestor must confirm the service emits JSON logs with: timestamp, level, service, correlation_id, message",
		"message":  "OBS-002: Submit a manual attestation. See templates/evidence-record for the format. Include a sample log entry.",
	},
} if {
	input.service_type
	not input.attestation_present
}
