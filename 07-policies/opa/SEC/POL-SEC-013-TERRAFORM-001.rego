package platform.sec.sec_013_terraform

# Control:  SEC-013 — Provider and service configs must not disable TLS verification
# Binding:  BIND-SEC-013-TERRAFORM
# Input:    iac-terraform.json (collect-terraform-info.sh)
#
# Checks for tls_disable=true, skip_tls_verify=true, insecure=true in any .tf file.
# These patterns strip identity verification from all TLS connections.

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "SEC-013 policy error: missing TLS config data"},
}

# ── NOT APPLICABLE ─────────────────────────────────────────────────────────────
result := {
	"result": "not_applicable",
	"details": {"message": "SEC-013: no terraform files found — not applicable"},
} if {
	not input.tls_disabled_configs
	count(input.module_calls) == 0
}

# ── PASS ───────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("TLS configuration in '%v'", [input.repository.name]),
		"found":    "No tls_disable, skip_tls_verify, or insecure=true patterns found",
		"expected": "All provider and service TLS verification enabled",
		"message":  "SEC-013: TLS verification is not disabled",
	},
} if {
	count(input.tls_disabled_configs) == 0
}

# ── FAIL ───────────────────────────────────────────────────────────────────────
# Staging environments issue a warning (not blocking) to allow iterative hardening.
# Production environments must have zero TLS violations.
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("TLS configuration in '%v'", [input.repository.name]),
		"found":    sprintf("%v TLS violation(s): %v", [count(input.tls_disabled_configs), tls_violation_summary]),
		"expected": "tls_disable=false (or absent), skip_tls_verify=false, insecure=false",
		"message":  "SEC-013: TLS verification is disabled. Add a reverse proxy with TLS termination and Vault PKI for internal certificates. See ADR for TLS strategy.",
	},
} if {
	count(input.tls_disabled_configs) > 0
}

tls_violation_summary := concat("; ", {
	sprintf("%v:%v (%v)", [v.file, v.line, v.pattern]) |
	some v in input.tls_disabled_configs
})
