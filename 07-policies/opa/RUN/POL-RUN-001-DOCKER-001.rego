package platform.run.run_001_docker

# Control:  RUN-001 — Docker images built by the platform must use standard OCI labels
# Binding:  BIND-RUN-001-DOCKER
# Standard: SRC-CIS-DOCKER-V1-6 (image labelling)
#           SRC-OPENSSF-SLSA-V1 (provenance — source reference in artifact)
#
# Input schema:
#   input.repository.name
#   input.image_ref            — full image reference (e.g., "registry/image:v1.0.0")
#   input.labels               — object: label_name → label_value (from docker inspect)
#   input.missing_labels       — pre-computed list of required labels not found (optional)
#   input.invalid_labels       — pre-computed list of labels with empty values (optional)

import future.keywords.if
import future.keywords.in

required_labels := {
	"org.opencontainers.image.title",
	"org.opencontainers.image.description",
	"org.opencontainers.image.version",
	"org.opencontainers.image.source",
	"org.opencontainers.image.revision",
}

# Labels that are present but empty are treated as missing
present_labels := {k | _ := input.labels[k]; input.labels[k] != ""}

missing := required_labels - present_labels

default result := {
	"result": "error",
	"details": {"message": "RUN-001 policy error: missing image label data"},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("OCI image labels on '%v' in '%v'", [input.image_ref, input.repository.name]),
		"found":    sprintf("All %v required OCI labels present and non-empty", [count(required_labels)]),
		"expected": "org.opencontainers.image.{title,description,version,source,revision}",
		"message":  "RUN-001: All required OCI image labels are present",
	},
} if {
	count(missing) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("OCI image labels on '%v' in '%v'", [input.image_ref, input.repository.name]),
		"found":    sprintf("%v required label(s) missing or empty: %v", [count(missing), concat(", ", {v | missing[v]})]),
		"expected": "All 5 org.opencontainers.image.* labels present and non-empty",
		"message":  sprintf("RUN-001: Missing or empty OCI labels: %v. Set these in the Dockerfile with ARG-fed LABEL instructions.", [concat(", ", {v | missing[v]})]),
		"missing_labels": [l | l := missing[_]],
		"present_labels": [k | _ := present_labels[k]],
	},
} if {
	count(missing) > 0
}

result := {
	"result": "not_applicable",
	"details": {
		"message": "RUN-001: No image reference provided — control not applicable",
	},
} if {
	not input.image_ref
}
