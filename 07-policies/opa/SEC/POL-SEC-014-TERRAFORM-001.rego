package platform.sec.sec_014_terraform

# Control:  SEC-014 (maps to audit finding HIGH-007)
#           Vault audit device must be enabled
# Binding:  BIND-SEC-014-TERRAFORM
# Input:    iac-terraform.json (collect-terraform-info.sh)
#
# Checks that a vault_audit resource is declared in the repository.
# Without an audit device, there is zero record of secret access.

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "SEC-014 policy error: missing vault audit data"},
}

# ── NOT APPLICABLE ─────────────────────────────────────────────────────────────
# Only applies to terraform-root repos that deploy the full platform stack.
result := {
	"result": "not_applicable",
	"details": {"message": "SEC-014: no Vault deployment found — not applicable"},
} if {
	input.repository.type != "terraform-root"
}

result := {
	"result": "not_applicable",
	"details": {"message": "SEC-014: no Vault deployment found — not applicable"},
} if {
	input.repository.type == "terraform-root"
	not input.has_vault_jwt_backend
	not input.has_integrations_module
}

# ── PASS ───────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Vault audit device in '%v'", [input.repository.name]),
		"found":    "vault_audit resource declared — audit logging is configured",
		"expected": "vault_audit resource with type=file or type=syslog",
		"message":  "SEC-014: Vault audit device is configured",
	},
} if {
	input.has_vault_audit_device == true
}

# ── FAIL ───────────────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Vault audit device in '%v'", [input.repository.name]),
		"found":    "No vault_audit resource found",
		"expected": "vault_audit resource (type=file) in integrations/vault-oidc-auth.tf",
		"message":  "SEC-014: Vault audit device is not configured. Add vault_audit resource to integrations/. Without it, there is NO record of which service accessed which secret.",
	},
} if {
	input.has_integrations_module == true
	not input.has_vault_audit_device
}
