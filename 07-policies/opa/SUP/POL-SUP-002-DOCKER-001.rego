package platform.sup.sup_002_docker

# Control:  SUP-002 — Container images must not reference the latest tag
# Binding:  BIND-SUP-002-DOCKER
# Standard: SRC-CIS-DOCKER-V1-6 (4.8 — latest tag prohibited)
#           SRC-OPENSSF-SLSA-V1 (immutable artifact references)
#           SRC-OPENGITOPS-V1 (Principle 2 — Versioned and Immutable)
#
# Input schema:
#   input.repository.name
#   input.image_references[]           — all image refs found in repo
#   input.image_references[].file      — file containing the reference
#   input.image_references[].line      — line number
#   input.image_references[].reference — full image reference string
#   input.image_references[].tag       — extracted tag (empty string if none)
#   input.image_references[].is_digest — true if reference uses @sha256:...

import future.keywords.if
import future.keywords.in

# Tags that are always mutable (regardless of name)
mutable_tag_patterns := {"latest", "stable", "current", "edge", "main", "master", "develop", "dev", "nightly", "canary"}

# A reference is acceptable if it uses a digest or a clearly versioned tag
is_acceptable_ref(ref) if {
	ref.is_digest == true
}

is_acceptable_ref(ref) if {
	ref.is_digest == false
	not ref.tag in mutable_tag_patterns
	# Tag must look like a version (contains a digit)
	regex.match(`[0-9]`, ref.tag)
	# Tag must not be empty
	ref.tag != ""
}

# Mutable references are violations
mutable_refs := [r |
	r := input.image_references[_]
	not is_acceptable_ref(r)
]

default result := {
	"result": "error",
	"details": {"message": "SUP-002 policy error: missing image reference data"},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Container image references in '%v'", [input.repository.name]),
		"found":    sprintf("%v image reference(s) checked, all use pinned tags or digests", [count(input.image_references)]),
		"expected": "All references use immutable tags (x.y.z, sha256:...) or content-addressable digests",
		"message":  "SUP-002: All container image references are pinned",
	},
} if {
	count(mutable_refs) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Container image references in '%v'", [input.repository.name]),
		"found":    sprintf("%v mutable reference(s) detected out of %v total", [count(mutable_refs), count(input.image_references)]),
		"expected": "All references use immutable version tags or sha256 digests",
		"message":  "SUP-002: Mutable image references detected — replace 'latest' and unversioned tags with specific versions or digests",
		"mutable_refs": [sprintf("%v:%v in %v:%v", [r.reference, r.tag, r.file, r.line]) | r := mutable_refs[_]],
	},
} if {
	count(mutable_refs) > 0
}

result := {
	"result": "not_applicable",
	"details": {
		"checked":  sprintf("Container image references in '%v'", [input.repository.name]),
		"found":    "No container image references found in repository",
		"expected": "n/a",
		"message":  "SUP-002: No image references — control not applicable to this repository",
	},
} if {
	count(input.image_references) == 0
}
