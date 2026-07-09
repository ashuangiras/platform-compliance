package platform.run.run_004_docker

# Control:  RUN-004 — Containers must drop ALL Linux capabilities
# Binding:  BIND-RUN-004-DOCKER
# Standard: SRC-CIS-DOCKER-V1-6 (5.3 — Linux kernel capabilities restricted)
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
		"checked":  "Linux capabilities in Docker Compose services",
		"found":    "No input provided or input malformed",
		"expected": "All services declare cap_drop: [ALL]",
		"message":  "RUN-004 policy error: missing input data",
	},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("%v Docker Compose service(s) in '%v'", [count(input.compose_services), input.repository.name]),
		"found":    "All services drop ALL Linux capabilities",
		"expected": "cap_drop: [ALL] on every service",
		"message":  "RUN-004: All containers drop ALL capabilities",
	},
} if {
	count(violations) == 0
	count(input.compose_services) > 0
}

result := {
	"result": "not_applicable",
	"details": {
		"message": "RUN-004: No Docker Compose service definitions found",
	},
} if {
	count(input.compose_services) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("%v Docker Compose service(s) in '%v'", [count(input.compose_services), input.repository.name]),
		"found":    sprintf("Capability violations: %v", [concat(", ", {v | violations[v]})]),
		"expected": "cap_drop: [ALL] on every service",
		"message":  sprintf("RUN-004: Container capability violations. %v", [concat(", ", {v | violations[v]})]),
	},
} if {
	count(violations) > 0
}

violations[msg] if {
	some svc in input.compose_services
	svc.caps_drop_all == false
	msg := sprintf("%v/%v: does not drop ALL capabilities (cap_drop must include ALL)", [svc.compose_file, svc.service])
}

violations[msg] if {
	some svc in input.compose_services
	svc.privileged == true
	msg := sprintf("%v/%v: privileged mode enabled (absolutely prohibited — use RUN-006 waiver process)", [svc.compose_file, svc.service])
}
