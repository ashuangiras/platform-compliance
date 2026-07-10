package platform.sec.sec_011_frontend

# Control:  SEC-011 — JavaScript bundle size within threshold
# Binding:  BIND-SEC-011-FRONTEND
#
# Input schema (from collect-frontend-info.sh):
#   input.has_frontend_project                    — bool; true when frontend project found
#   input.bundle.max_bundle_size_kb_gzipped       — number|null; largest JS bundle KB gzipped
#
# Thresholds:
#   pass  : size < 500 KB
#   warn  : 500 KB ≤ size < 2048 KB
#   fail  : size ≥ 2048 KB (2 MB block gate)

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "SEC-011 policy error: missing input data"},
}

# ─── APPLICABLE GUARD ─────────────────────────────────────────────────────────
# Policy produces pass/warn/fail only when: frontend project present AND bundle
# size is a known number. Guards below use `not applicable` to invert this.
applicable if {
	input.has_frontend_project == true
	is_number(input.bundle.max_bundle_size_kb_gzipped)
}

# ─── NOT APPLICABLE ───────────────────────────────────────────────────────────
result := {
	"result": "not_applicable",
	"details": {"message": na_reason},
} if {
	not applicable
}

na_reason := "SEC-011: Not applicable — repository is not a frontend project" if {
	input.has_frontend_project != true
} else := "SEC-011: Bundle size data unavailable (no production build output or no bundles detected)"

# ─── PASS: bundle < 500 KB ────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  "Maximum gzipped JavaScript bundle size",
		"found":    sprintf("%v KB gzipped", [input.bundle.max_bundle_size_kb_gzipped]),
		"expected": "Largest bundle < 500 KB gzipped",
		"message":  sprintf("SEC-011: Bundle is %v KB gzipped, within the 500 KB warn threshold.", [input.bundle.max_bundle_size_kb_gzipped]),
	},
} if {
	applicable
	input.bundle.max_bundle_size_kb_gzipped < 500
}

# ─── WARN: 500 KB ≤ bundle < 2048 KB ─────────────────────────────────────────
result := {
	"result": "warn",
	"details": {
		"checked":  "Maximum gzipped JavaScript bundle size",
		"found":    sprintf("%v KB gzipped", [input.bundle.max_bundle_size_kb_gzipped]),
		"expected": "Largest bundle < 500 KB gzipped (block at 2 MB)",
		"message":  sprintf("SEC-011: Bundle is %v KB gzipped (warn threshold: 500 KB). Optimize before it hits the 2 MB block limit.", [input.bundle.max_bundle_size_kb_gzipped]),
	},
} if {
	applicable
	input.bundle.max_bundle_size_kb_gzipped >= 500
	input.bundle.max_bundle_size_kb_gzipped < 2048
}

# ─── FAIL: bundle ≥ 2048 KB ───────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  "Maximum gzipped JavaScript bundle size",
		"found":    sprintf("%v KB gzipped", [input.bundle.max_bundle_size_kb_gzipped]),
		"expected": "Largest bundle < 2048 KB gzipped",
		"message":  sprintf("SEC-011: Bundle is %v KB gzipped, exceeding the 2 MB block limit. Reduce bundle size immediately.", [input.bundle.max_bundle_size_kb_gzipped]),
	},
} if {
	applicable
	input.bundle.max_bundle_size_kb_gzipped >= 2048
}
