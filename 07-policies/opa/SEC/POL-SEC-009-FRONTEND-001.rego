package platform.sec.sec_009_frontend

# Control:  SEC-009 — Content-Security-Policy header present
# Binding:  BIND-SEC-009-FRONTEND
#
# Input schema (from collect-frontend-info.sh):
#   input.has_frontend_project              — bool; true when dist/, build/, etc. found
#   input.security.csp_header_present       — bool|null; true when CSP header/meta found

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "SEC-009 policy error: missing input data"},
}

# ─── NOT APPLICABLE: no frontend project ──────────────────────────────────────
result := {
	"result": "not_applicable",
	"details": {"message": "SEC-009: Not applicable — repository is not a frontend project"},
} if {
	input.has_frontend_project != true
}

# ─── NOT APPLICABLE: CSP status unknown (field missing or null) ───────────────
# object.get returns the sentinel null when csp_header_present is absent or null;
# is_boolean() with an undefined reference silently fails in OPA so we use
# object.get(..., null) == null instead to cover both missing and null values.
# Mutually exclusive with the rule above (requires has_frontend_project == true).
result := {
	"result": "not_applicable",
	"details": {"message": "SEC-009: CSP detection unavailable"},
} if {
	input.has_frontend_project == true
	object.get(object.get(input, "security", {}), "csp_header_present", null) == null
}

# ─── PASS ─────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  "Content-Security-Policy header or meta tag presence",
		"found":    "CSP header or meta tag detected",
		"expected": "CSP header or meta tag present in the application",
		"message":  "SEC-009: Content-Security-Policy header is present. XSS protection enabled.",
	},
} if {
	input.has_frontend_project == true
	input.security.csp_header_present == true
}

# ─── FAIL ─────────────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  "Content-Security-Policy header or meta tag presence",
		"found":    "No CSP header or meta tag detected",
		"expected": "CSP header or meta tag present in the application",
		"message":  "SEC-009: No Content-Security-Policy header or meta tag found. Add a CSP to protect against XSS.",
	},
} if {
	input.has_frontend_project == true
	input.security.csp_header_present == false
}
