package platform.acc.acc_001_github

# Control:  ACC-001 — MFA must be enabled for all platform developers
# Binding:  BIND-ACC-001-GITHUB
# Standard: SRC-CIS-CONTROLS-V8 (Control 6.5), SRC-GITHUB-SECURITY-HARDENING

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "ACC-001 policy error: missing input data"},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("GitHub account MFA for '%v'", [input.account.login]),
		"found":    "Multi-factor authentication is enabled",
		"expected": "two_factor_authentication: true OR two_factor_requirement_enabled: true",
		"message":  "ACC-001: MFA is enabled for the platform account",
	},
} if {
	mfa_status_known
	mfa_active
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("GitHub account MFA for '%v'", [input.account.login]),
		"found":    "Multi-factor authentication is NOT enabled",
		"expected": "two_factor_authentication: true",
		"message":  "ACC-001: MFA is not enabled. Enable 2FA at github.com/settings/security",
	},
} if {
	mfa_status_known
	not mfa_active
	input.account.login != ""
}

result := {
	"result": "not_applicable",
	"details": {
		"message": "ACC-001: 2FA status not verifiable — token lacks 'user' scope or login unknown. Verify MFA manually.",
	},
} if {
	not mfa_status_known
}

mfa_active if input.account.two_factor_authentication == true
mfa_active if input.account.two_factor_requirement_enabled == true

mfa_status_known if input.account.two_factor_authentication != null
mfa_status_known if input.account.two_factor_requirement_enabled != null
