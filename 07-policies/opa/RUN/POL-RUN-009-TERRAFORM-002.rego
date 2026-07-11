package platform.run.run_009b_terraform

# Control:  RUN-009 (extension) — Grafana must use Authentik as identity provider
# Binding:  BIND-RUN-009-TERRAFORM-GRAFANA
# Input:    iac-terraform.json (collect-terraform-info.sh)
#
# If the repository deploys a Grafana module AND does not configure Grafana OIDC
# via Authentik, this policy fails. Extends POL-RUN-009-TERRAFORM-001.

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "RUN-009b policy error: missing Grafana OIDC data"},
}

# ── Check if Grafana is deployed in this repo ──────────────────────────────────
grafana_deployed if {
	some m in input.module_calls
	contains(lower(m.source), "grafana")
}

# ── NOT APPLICABLE ─────────────────────────────────────────────────────────────
result := {
	"result": "not_applicable",
	"details": {"message": "RUN-009b: no Grafana module found — not applicable"},
} if {
	not grafana_deployed
}

# ── PASS ───────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Grafana Authentik OIDC in '%v'", [input.repository.name]),
		"found":    "Grafana module present AND Authentik OIDC/OAuth2 configuration found",
		"expected": "Authentik OAuth2 application for Grafana with GF_AUTH_GENERIC_OAUTH_* env vars",
		"message":  "RUN-009b: Grafana is configured to use Authentik as identity provider",
	},
} if {
	grafana_deployed
	input.has_grafana_oidc == true
}

# ── FAIL ───────────────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Grafana Authentik OIDC in '%v'", [input.repository.name]),
		"found":    "Grafana deployed but no Authentik OIDC/OAuth2 configuration found",
		"expected": "module 'oidc_grafana' in integrations/ AND GF_AUTH_GENERIC_OAUTH_ENABLED=true in Grafana module",
		"message":  "RUN-009b: Grafana uses local admin account. Add Authentik OIDC: create module.oidc_grafana in integrations/ and pass GF_AUTH_GENERIC_OAUTH_* env vars to the Grafana module.",
	},
} if {
	grafana_deployed
	not input.has_grafana_oidc
}
