package platform.run.run_005_docker

# Control:  RUN-005 — Container root filesystem must be read-only
# Binding:  BIND-RUN-005-DOCKER
# Standard: SRC-CIS-DOCKER-V1-6 (5.12 — Root filesystem mounted as read only)
#           SRC-CIS-CONTROLS-V8 (Control 4 — Secure Configuration)
#
# Input schema:
#   input.compose_services  — array of Docker Compose service security settings
#   input.repository.name   — repository name

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {
		"checked":  "Read-only root filesystem in Docker Compose services",
		"found":    "No input provided or input malformed",
		"expected": "All services declare read_only: true",
		"message":  "RUN-005 policy error: missing input data",
	},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("%v Docker Compose service(s) in '%v'", [count(input.compose_services), input.repository.name]),
		"found":    "All services use read-only root filesystem",
		"expected": "read_only: true on every service",
		"message":  "RUN-005: All containers use read-only root filesystem",
	},
} if {
	count(violations) == 0
	count(input.compose_services) > 0
}

result := {
	"result": "not_applicable",
	"details": {
		"message": "RUN-005: No Docker Compose service definitions found",
	},
} if {
	count(input.compose_services) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("%v Docker Compose service(s) in '%v'", [count(input.compose_services), input.repository.name]),
		"found":    sprintf("Writable filesystem violations: %v", [concat(", ", {v | violations[v]})]),
		"expected": "read_only: true on every service",
		"message":  sprintf("RUN-005: Writable root filesystem detected. %v", [concat(", ", {v | violations[v]})]),
	},
} if {
	count(violations) > 0
}

violations[msg] if {
	some svc in input.compose_services
	svc.read_only != true
	msg := sprintf("%v/%v: read_only is not set to true (root filesystem is writable)", [svc.compose_file, svc.service])
}
