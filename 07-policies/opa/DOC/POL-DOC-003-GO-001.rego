package platform.doc.doc_003_go

# Control:  DOC-003 — Service repositories must include a runbook
# Binding:  BIND-DOC-003-GO
# Standard: SRC-GOOGLE-SRE, SRC-ITIL-ADAPTED

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "DOC-003 policy error: missing input data"},
}

# NOT APPLICABLE — no Go module in this repository
result := {
	"result": "not_applicable",
	"details": {"message": "DOC-003: no Go module detected (has_go_module: false)"},
} if {
	input.has_go_module != true
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Runbook presence for '%v'", [input.repository.name]),
		"found":    "runbook file found",
		"expected": "docs/runbook.md or RUNBOOK.md present",
		"message":  "DOC-003: Runbook is present",
	},
} if {
	input.has_go_module == true
	input.documentation.runbook_present == true
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Runbook presence for '%v'", [input.repository.name]),
		"found":    "no runbook file found",
		"expected": "docs/runbook.md or RUNBOOK.md with startup/shutdown/escalation/failures sections",
		"message":  "DOC-003: Add docs/runbook.md covering startup, shutdown, escalation path, and common failures.",
	},
} if {
	input.has_go_module == true
	input.documentation.runbook_present != true
}
