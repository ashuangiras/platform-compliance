package platform.sec.sec_013_terraform

# Control:  SEC-013 — Provider and service configs must not disable TLS verification
# Binding:  BIND-SEC-013-TERRAFORM
# Input:    iac-terraform.json (collect-terraform-info.sh)
#
# Checks for tls_disable=true, skip_tls_verify=true, insecure=true in any .tf file.
# Staging environments are not_applicable (TLS not yet deployed for local dev);
# any environment other than staging must have zero TLS violations.

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "SEC-013 policy error: missing TLS config data"},
}

# ── NOT APPLICABLE — no terraform files ───────────────────────────────────────
result := {
	"result": "not_applicable",
	"details": {"message": "SEC-013: no terraform files found — not applicable"},
} if {
	not input.tls_disabled_configs
	count(input.module_calls) == 0
}

# ── NOT APPLICABLE — staging environment (TLS is a production requirement) ────
# Staging repos explicitly declare environment = "staging" in terraform.tfvars.
# The ADR for TLS strategy (to be written as ADR-0021) must be in place before
# this passes for production.
result := {
	"result": "not_applicable",
	"details": {
		"message": "SEC-013: environment=staging — TLS enforcement deferred. Resolve HIGH-001 (ADR-0021) before production promotion.",
		"environment": input.declared_environment,
		"violations_present": count(input.tls_disabled_configs),
	},
} if {
	input.declared_environment == "staging"
}

# ── PASS — production with no TLS violations ──────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("TLS configuration in '%v' (env=%v)", [input.repository.name, input.declared_environment]),
		"found":    "No tls_disable, skip_tls_verify, or insecure=true patterns found",
		"expected": "All provider and service TLS verification enabled",
		"message":  "SEC-013: TLS verification is not disabled",
	},
} if {
	input.declared_environment != "staging"
	count(input.tls_disabled_configs) == 0
}

# ── FAIL — production with TLS violations ─────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("TLS configuration in '%v' (env=%v)", [input.repository.name, input.declared_environment]),
		"found":    sprintf("%v TLS violation(s): %v", [count(input.tls_disabled_configs), tls_violation_summary]),
		"expected": "tls_disable=false, skip_tls_verify=false, insecure=false for non-staging environments",
		"message":  "SEC-013: TLS verification is disabled. Add a reverse proxy with TLS and Vault PKI before production.",
	},
} if {
	input.declared_environment != "staging"
	count(input.tls_disabled_configs) > 0
}

tls_violation_summary := concat("; ", {
	sprintf("%v:%v (%v)", [v.file, v.line, v.pattern]) |
	some v in input.tls_disabled_configs
})
