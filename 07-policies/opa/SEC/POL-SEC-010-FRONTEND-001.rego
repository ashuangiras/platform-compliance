package platform.sec.sec_010_frontend

# Control:  SEC-010 — No source maps in production build output
# Binding:  BIND-SEC-010-FRONTEND
#
# Input schema (from collect-frontend-info.sh):
#   input.has_frontend_project                — bool; true when dist/, build/, etc. found
#   input.security.prod_source_maps_found     — bool; true when .map files found
#   input.security.source_map_count           — integer count of .map files

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "SEC-010 policy error: missing input data"},
}

# ─── NOT APPLICABLE: no frontend project ──────────────────────────────────────
result := {
	"result": "not_applicable",
	"details": {"message": "SEC-010: Not applicable — repository is not a frontend project"},
} if {
	input.has_frontend_project != true
}

# ─── PASS ─────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  "Source map (.map) files in production build output",
		"found":    "No source map files found in production build output",
		"expected": "Zero .map files in production build artifacts",
		"message":  "SEC-010: No source map files found in production build output. Source code is not exposed.",
	},
} if {
	input.has_frontend_project == true
	input.security.prod_source_maps_found == false
}

# ─── FAIL ─────────────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  "Source map (.map) files in production build output",
		"found":    sprintf("%v source map file(s) found in build output", [input.security.source_map_count]),
		"expected": "Zero .map files in production build artifacts",
		"message":  sprintf("SEC-010: %v source map file(s) found in build output. Remove .map files from production builds.", [input.security.source_map_count]),
	},
} if {
	input.has_frontend_project == true
	input.security.prod_source_maps_found == true
}
