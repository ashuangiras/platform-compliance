package platform.run.run_006_docker

# Control:  RUN-006 — Privileged containers are not allowed
# Binding:  BIND-RUN-006-DOCKER
# Standard: SRC-CIS-DOCKER-V1-6 (5.4 — privileged containers prohibited)

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "RUN-006 policy error: missing input data"},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("%v Docker Compose service(s) in '%v'", [count(input.compose_services), input.repository.name]),
		"found":    "No privileged containers",
		"expected": "privileged: false or absent for all services",
		"message":  "RUN-006: No privileged containers detected",
	},
} if {
	count(violations) == 0
	count(input.compose_services) > 0
}

result := {
	"result": "not_applicable",
	"details": {"message": "RUN-006: No Docker Compose service definitions found"},
} if {
	count(input.compose_services) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("%v Docker Compose service(s) in '%v'", [count(input.compose_services), input.repository.name]),
		"found":    sprintf("Privileged containers: %v", [concat(", ", {v | violations[v]})]),
		"expected": "privileged: false or absent for all services",
		"message":  sprintf("RUN-006: Privileged container(s) detected. %v", [concat(", ", {v | violations[v]})]),
	},
} if {
	count(violations) > 0
}

violations[msg] if {
	some svc in input.compose_services
	svc.privileged == true
	msg := sprintf("%v/%v: privileged: true (forbidden — use a waiver if genuinely required)", [svc.compose_file, svc.service])
}
