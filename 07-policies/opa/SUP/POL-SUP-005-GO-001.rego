package platform.sup.sup_005_go

# Control:  SUP-005 — Go repositories must commit go.sum and keep it tidy
# Binding:  BIND-SUP-005-GO
# Standard: SRC-12-FACTOR, SRC-OPENSSF-SLSA-V1

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "SUP-005 policy error: missing input data"},
}

# NOT APPLICABLE — no Go module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "SUP-005: no Go module detected (has_go_module: false)"},
} if {
	input.has_go_module != true
}

# NOT APPLICABLE — Go tool unavailable (cannot verify tidy)
result := {
	"result": "not_applicable",
	"details": {"message": "SUP-005: Go toolchain unavailable; go.sum tidy check not evaluated"},
} if {
	input.has_go_module == true
	input.tools.go_available != true
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("go.sum committed and tidy for '%v'", [input.repository.name]),
		"found":    "go.sum committed and tidy",
		"expected": "gosum_committed == true AND gosum_tidy == true",
		"message":  "SUP-005: go.sum is committed and up to date",
	},
} if {
	input.has_go_module == true
	input.tools.go_available == true
	input.supply_chain.gosum_committed == true
	input.supply_chain.gosum_tidy == true
}

# FAIL — not committed
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("go.sum committed and tidy for '%v'", [input.repository.name]),
		"found":    "go.sum not committed",
		"expected": "go.sum committed to version control",
		"message":  "SUP-005: Commit go.sum to version control.",
	},
} if {
	input.has_go_module == true
	input.tools.go_available == true
	input.supply_chain.gosum_committed != true
}

# FAIL — not tidy
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("go.sum committed and tidy for '%v'", [input.repository.name]),
		"found":    "go.sum is committed but not tidy (go mod tidy produces changes)",
		"expected": "go.sum up to date after go mod tidy",
		"message":  "SUP-005: Run 'go mod tidy' and commit the updated go.sum.",
	},
} if {
	input.has_go_module == true
	input.tools.go_available == true
	input.supply_chain.gosum_committed == true
	input.supply_chain.gosum_tidy != true
}
