package platform.lic.lic_001_github

# Control:  LIC-001 — Repository must declare a license and not use incompatible dependencies
# Binding:  BIND-LIC-001-GITHUB
# Standard: SRC-CIS-CONTROLS-V8 (Control 2.3), SRC-NTIA-SBOM-2021

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "LIC-001 policy error: missing input data"},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Repository license for '%v'", [input.repository.name]),
		"found":    sprintf("License declared: %v (not copyleft)", [input.license.spdx_id]),
		"expected": "LICENSE file present, SPDX ID known, not a copyleft license",
		"message":  "LIC-001: Repository has a permissive license declared",
	},
} if {
	input.license.present == true
	input.license.is_copyleft == false
	input.license.spdx_id != ""
	input.license.spdx_id != "NOASSERTION"
	input.license.spdx_id != "UNLICENSED"
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Repository license for '%v'", [input.repository.name]),
		"found":    "No LICENSE file or unknown license",
		"expected": "LICENSE file with permissive SPDX identifier",
		"message":  "LIC-001: No license file detected. Add a LICENSE file to the repository root.",
	},
} if {
	input.license.present == false
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Repository license for '%v'", [input.repository.name]),
		"found":    sprintf("Copyleft license detected: %v", [input.license.spdx_id]),
		"expected": "Permissive license (MIT, Apache-2.0, BSD-*) — not GPL/AGPL",
		"message":  sprintf("LIC-001: Copyleft license '%v' may impose open-source obligations. Create a waiver if intentional.", [input.license.spdx_id]),
	},
} if {
	input.license.present == true
	input.license.is_copyleft == true
}
