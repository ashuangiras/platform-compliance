package platform.chg.chg_002_github

# Control:  CHG-002 — Every tagged release must have a corresponding release record
# Binding:  BIND-CHG-002-GITHUB
# Standard: SRC-ITIL-ADAPTED (Change Enablement — release documentation)
#           SRC-OPENSSF-SLSA-V1 (release provenance requirements)
#
# Input schema:
#   input.repository.name
#   input.release_tag              — the version tag being released, e.g. "v1.0.0"
#   input.release_record_exists    — bool: does 09-assessments/releases/{tag}.yaml exist?
#   input.release_record           — parsed YAML if exists, null otherwise
#   input.release_record.id        — version string
#   input.release_record.change_record_ids — array, must be non-empty
#   input.release_record.gate_assessment_id — string, must be present

import future.keywords.if
import future.keywords.in

# Valid release tag pattern: v followed by MAJOR.MINOR.PATCH
is_release_tag if {
	regex.match(`^v[0-9]+\.[0-9]+\.[0-9]+$`, input.release_tag)
}

default result := {
	"result": "error",
	"details": {"message": "CHG-002 policy error: missing release tag or file check input"},
}

# Not a release tag — not applicable
result := {
	"result": "not_applicable",
	"details": {
		"message": sprintf("CHG-002: Tag '%v' is not a semantic version release tag (vMAJOR.MINOR.PATCH)", [input.release_tag]),
	},
} if {
	not is_release_tag
}

# Release tag but no record
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Release record for '%v' in '%v'", [input.release_tag, input.repository.name]),
		"found":    sprintf("09-assessments/releases/%v.yaml not found", [input.release_tag]),
		"expected": "Release record YAML file with id, change_record_ids, gate_assessment_id, summary",
		"message":  sprintf("CHG-002: Release record is missing for %v. Create 09-assessments/releases/%v.yaml before publishing.", [input.release_tag, input.release_tag]),
	},
} if {
	is_release_tag
	not input.release_record_exists
}

# Record exists but is incomplete
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Release record completeness for '%v'", [input.release_tag]),
		"found":    sprintf("Record exists but missing required fields: %v", [concat(", ", {v | record_violations[v]})]),
		"expected": "All required fields present and non-empty",
		"message":  sprintf("CHG-002: Release record for %v is incomplete: %v", [input.release_tag, concat(", ", {v | record_violations[v]})]),
	},
} if {
	is_release_tag
	input.release_record_exists
	count(record_violations) > 0
}

# All good
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Release record for '%v' in '%v'", [input.release_tag, input.repository.name]),
		"found":    sprintf("Release record present with %v change record(s) and assessment reference", [count(input.release_record.change_record_ids)]),
		"expected": "Complete release record",
		"message":  sprintf("CHG-002: Release record exists for %v", [input.release_tag]),
	},
} if {
	is_release_tag
	input.release_record_exists
	count(record_violations) == 0
}

record_violations[msg] if {
	count(input.release_record.change_record_ids) == 0
	msg := "change_record_ids is empty (at least one required)"
}

record_violations[msg] if {
	not input.release_record.gate_assessment_id
	msg := "gate_assessment_id is missing"
}

record_violations[msg] if {
	not input.release_record.release_summary
	msg := "release_summary is missing"
}
