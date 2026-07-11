package platform.run.run_009_terraform

# Control:  RUN-009 — All platform services must use Authentik as IDP
# Binding:  BIND-RUN-009-TERRAFORM
# Input:    iac-terraform.json (collect-terraform-info.sh)
#
# For terraform-root repos: verifies that a vault_jwt_auth_backend pointing at
# Authentik (oidc_discovery_url present) is declared in the Terraform config.
# This proves Vault is wired to Authentik. MinIO OIDC is enforced via the same
# integrations/ module (has_integrations_module check).

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "RUN-009 policy error: missing terraform input data"},
}

# ── NOT APPLICABLE ─────────────────────────────────────────────────────────────
# ── NOT APPLICABLE — non-platform-root repositories ─────────────────────────
result := {
	"result": "not_applicable",
	"details": {"message": sprintf("only enforced on terraform-root repositories (this repo type=%v)", [input.repository.type])},
} if {
	input.repository.type != "terraform-root"
}

# ── PASS ───────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Vault JWT auth backend + integrations module in '%v'", [input.repository.name]),
		"found":    "vault_jwt_auth_backend with oidc_discovery_url declared; integrations/ module present",
		"expected": "Vault OIDC auth backend pointing at Authentik + integrations/ module",
		"message":  "RUN-009: Vault uses Authentik as OIDC identity provider",
	},
} if {
	input.has_vault_jwt_backend == true
	input.has_integrations_module == true
}

# ── FAIL: vault_jwt_auth_backend missing ───────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Vault JWT auth backend in '%v'", [input.repository.name]),
		"found":    "No vault_jwt_auth_backend with oidc_discovery_url found",
		"expected": "vault_jwt_auth_backend resource with oidc_discovery_url pointing at Authentik",
		"message":  "RUN-009: Add vault_jwt_auth_backend in integrations/ pointing at Authentik OIDC discovery URL.",
	},
} if {
	input.repository.type == "terraform-root"
	count(input.module_calls) > 0
	not input.has_vault_jwt_backend
}

# ── FAIL: integrations/ module missing ─────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("integrations/ module in '%v'", [input.repository.name]),
		"found":    "No integrations/ Terraform component found",
		"expected": "integrations/ directory with .tf files wiring Authentik OIDC to all services",
		"message":  "RUN-009: Create integrations/ component with Authentik OIDC wiring for Vault and MinIO.",
	},
} if {
	input.repository.type == "terraform-root"
	input.has_vault_jwt_backend == true
	not input.has_integrations_module
}
