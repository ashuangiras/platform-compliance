package platform.doc.doc_001_github

# Control:  DOC-001 — Every repository must have a README at the root level
# Binding:  BIND-DOC-001-GITHUB
# Standard: SRC-OPENSSF-SCORECARD-V2
#
# Input schema:
#   input.repository.name  — Repository name
#   input.files[]          — List of {path, size} objects at commit SHA

import future.keywords.if
import future.keywords.in

README_MIN_BYTES := 100

default result := {
	"result": "error",
	"details": {"message": "DOC-001 policy error: missing file list input"},
}

# ─── PASS ─────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("README.md at root of '%v'", [input.repository.name]),
		"found":    sprintf("README.md present (%v bytes)", [readme.size]),
		"expected": sprintf("README.md with at least %v bytes", [README_MIN_BYTES]),
		"message":  "DOC-001: README.md is present with meaningful content",
	},
} if {
	readme := readme_file
	readme.size >= README_MIN_BYTES
}

# ─── FAIL: missing ────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("README.md at root of '%v'", [input.repository.name]),
		"found":    "README.md not found at repository root",
		"expected": "README.md at root with at least 100 bytes",
		"message":  "DOC-001: README.md is missing. Add one describing the repository's purpose, ownership, and usage.",
	},
} if {
	not readme_file
}

# ─── FAIL: too small (likely placeholder) ─────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("README.md content in '%v'", [input.repository.name]),
		"found":    sprintf("README.md exists but has only %v bytes (likely a placeholder)", [readme_file.size]),
		"expected": sprintf("README.md with at least %v bytes", [README_MIN_BYTES]),
		"message":  sprintf("DOC-001: README.md exists but appears to be empty or a placeholder (%v bytes). Add meaningful content.", [readme_file.size]),
	},
} if {
	readme_file
	readme_file.size < README_MIN_BYTES
}

# ─── Helpers ──────────────────────────────────────────────────────────────────
readme_file := f if {
	f := input.files[_]
	f.path == "README.md"
}
