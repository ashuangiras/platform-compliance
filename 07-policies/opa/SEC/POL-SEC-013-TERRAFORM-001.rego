package platform.sec.sec_013_terraform

# Control:  SEC-013 — Provider and service configs must not disable TLS verification
# Binding:  BIND-SEC-013-TERRAFORM
# Input:    iac-terraform.json (collect-terraform-info.sh)
#
# Checks for tls_disable=true, skip_tls_verify=true, insecure=true in any .tf file.
# Staging environments are not_applicable (TLS not yet deployed for local dev);
# every other environment (production, development, etc.) must have zero TLS
# violations. declared_environment now originates from the committed compliance
# manifest; the collector always sets it, but this policy fails safe to
# "production" (enforce) when it is absent or empty so enforcement is never
# silently skipped.

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "SEC-013 policy error: missing TLS config data"},
}

# ── Effective environment — fail-safe to "production" when absent/empty ───────
# Two definitions are mutually exclusive (guarded by declared_environment_present),
# so effective_env is always a single defined value.
effective_env := input.declared_environment if {
	declared_environment_present
}

effective_env := "production" if {
	not declared_environment_present
}

declared_environment_present if {
	is_string(input.declared_environment)
	input.declared_environment != ""
}

# TLS violation count, defensive against an absent tls_disabled_configs field
# (the collector always emits it as a list, but a hand-authored input may omit it).
# Two definitions are mutually exclusive (present vs absent).
tls_violation_count := count(input.tls_disabled_configs) if {
	input.tls_disabled_configs
}

tls_violation_count := 0 if {
	not input.tls_disabled_configs
}

# ── NOT APPLICABLE — no terraform files ───────────────────────────────────────
# Guarded with effective_env != "staging" so this can never fire together with
# the staging not_applicable branch (that overlap previously risked
# eval_conflict_error for a staging repo that also had no terraform files).
result := {
	"result": "not_applicable",
	"details": {"message": "SEC-013: no terraform files found — not applicable"},
} if {
	effective_env != "staging"
	not input.tls_disabled_configs
	count(input.module_calls) == 0
}

# ── NOT APPLICABLE — staging environment (TLS is a production requirement) ────
# Staging repos declare environment = "staging" (now sourced from the committed
# compliance manifest). The ADR for TLS strategy (ADR-0021) must be in place
# before this passes for production.
result := {
	"result": "not_applicable",
	"details": {
		"message": "SEC-013: environment=staging — TLS enforcement deferred. Resolve HIGH-001 (ADR-0021) before production promotion.",
		"environment": effective_env,
		"violations_present": tls_violation_count,
	},
} if {
	effective_env == "staging"
}

# ── PASS — enforced (non-staging) environment with no TLS violations ──────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("TLS configuration in '%v' (env=%v)", [input.repository.name, effective_env]),
		"found":    "No tls_disable, skip_tls_verify, or insecure=true patterns found",
		"expected": "All provider and service TLS verification enabled",
		"message":  "SEC-013: TLS verification is not disabled",
	},
} if {
	effective_env != "staging"
	count(input.tls_disabled_configs) == 0
}

# ── FAIL — enforced (non-staging) environment with TLS violations ─────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("TLS configuration in '%v' (env=%v)", [input.repository.name, effective_env]),
		"found":    sprintf("%v TLS violation(s): %v", [count(input.tls_disabled_configs), tls_violation_summary]),
		"expected": "tls_disable=false, skip_tls_verify=false, insecure=false for enforced (non-staging) environments",
		"message":  "SEC-013: TLS verification is disabled. Add a reverse proxy with TLS and Vault PKI before production.",
	},
} if {
	effective_env != "staging"
	count(input.tls_disabled_configs) > 0
}

tls_violation_summary := concat("; ", {
	sprintf("%v:%v (%v)", [v.file, v.line, v.pattern]) |
	some v in input.tls_disabled_configs
})
