package platform.iac.iac_007_terraform

# Control:  IAC-007 — Service credentials must be injected via Vault; no hardcoded secrets
# Binding:  BIND-IAC-007-TERRAFORM
# Input:    iac-terraform.json (collect-terraform-info.sh)
#
# Verifies that an integrations/ component exists (which writes all credentials
# to Vault KV). The actual secret scan (no hardcoded secrets) is enforced by
# SEC-001/POL-SEC-001 (Semgrep + gitleaks). This policy is complementary:
# it checks the POSITIVE requirement that Vault KV integration exists.

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "IAC-007 policy error: missing terraform input data"},
}

# ── NOT APPLICABLE ─────────────────────────────────────────────────────────────
result := {
	"result": "not_applicable",
	"details": {"message": "IAC-007: only enforced on terraform-root repositories"},
} if {
	count(input.module_calls) == 0
	not input.has_integrations_module
}

# ── PASS ───────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("integrations/ Vault KV module in '%v'", [input.repository.name]),
		"found":    "integrations/ directory with Terraform files present; Vault KV credential injection configured",
		"expected": "integrations/ component writing credentials to Vault KV secret/platform/*",
		"message":  "IAC-007: Vault credential injection is configured via integrations/ component",
	},
} if {
	input.has_integrations_module == true
}

# ── FAIL ───────────────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("integrations/ module in '%v'", [input.repository.name]),
		"found":    "No integrations/ directory with .tf files",
		"expected": "integrations/ component with vault_kv_secret_v2 resources writing all service credentials",
		"message":  "IAC-007: Create integrations/ component. See IAC-007 control guidance for Vault path schema.",
	},
} if {
	count(input.module_calls) > 0
	not input.has_integrations_module
}
