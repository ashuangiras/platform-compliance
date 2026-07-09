package platform.src.src_003_github

# Control:  SRC-003 — CODEOWNERS file must be present and valid
# Binding:  BIND-SRC-003-GITHUB
# Standard: SRC-OPENSSF-SCORECARD-V2
#
# Input schema:
#   input.repository.name  — Repository name
#   input.files[]          — List of {path, size} objects for files at commit SHA

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "SRC-003 policy error: missing file list input"},
}

# ─── PASS ─────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("CODEOWNERS file presence in '%v'", [input.repository.name]),
		"found":    sprintf("CODEOWNERS found at '%v' (%v bytes)", [codeowners_file.path, codeowners_file.size]),
		"expected": "CODEOWNERS at one of: CODEOWNERS, .github/CODEOWNERS, docs/CODEOWNERS",
		"message":  "SRC-003: CODEOWNERS file is present",
	},
} if {
	codeowners_file := codeowners_files[0]
	codeowners_file.size > 0
}

# ─── FAIL: absent ─────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("CODEOWNERS file presence in '%v'", [input.repository.name]),
		"found":    "No CODEOWNERS file found",
		"expected": "CODEOWNERS at one of: CODEOWNERS, .github/CODEOWNERS, docs/CODEOWNERS",
		"message":  "SRC-003: CODEOWNERS file is missing. Add one before release.",
	},
} if {
	count(codeowners_files) == 0
}

# ─── FAIL: empty ──────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("CODEOWNERS file in '%v'", [input.repository.name]),
		"found":    sprintf("CODEOWNERS found at '%v' but is empty (0 bytes)", [codeowners_file.path]),
		"expected": "CODEOWNERS with at least one ownership rule",
		"message":  "SRC-003: CODEOWNERS file exists but is empty",
	},
} if {
	codeowners_file := codeowners_files[0]
	codeowners_file.size == 0
}

# ─── Helpers ──────────────────────────────────────────────────────────────────
codeowners_paths := {"CODEOWNERS", ".github/CODEOWNERS", "docs/CODEOWNERS"}

codeowners_files := [f |
	f := input.files[_]
	f.path in codeowners_paths
]
