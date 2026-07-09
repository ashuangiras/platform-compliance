package platform.run.run_007_docker

# Control:  RUN-007 — Containers must not share host network/PID/IPC namespaces
# Binding:  BIND-RUN-007-DOCKER
# Standard: SRC-CIS-DOCKER-V1-6 (5.9 network, 5.15 PID, 5.16 IPC)

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "RUN-007 policy error: missing input data"},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("%v Docker Compose service(s) in '%v'", [count(input.compose_services), input.repository.name]),
		"found":    "No host namespace sharing",
		"expected": "network_mode, pid, ipc not set to 'host'",
		"message":  "RUN-007: All containers use isolated namespaces",
	},
} if {
	count(violations) == 0
	count(input.compose_services) > 0
}

result := {
	"result": "not_applicable",
	"details": {"message": "RUN-007: No Docker Compose service definitions found"},
} if {
	count(input.compose_services) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("%v Docker Compose service(s) in '%v'", [count(input.compose_services), input.repository.name]),
		"found":    sprintf("Host namespace violations: %v", [concat(", ", {v | violations[v]})]),
		"expected": "network_mode, pid, ipc not set to 'host'",
		"message":  sprintf("RUN-007: Host namespace sharing detected. %v", [concat(", ", {v | violations[v]})]),
	},
} if {
	count(violations) > 0
}

violations[msg] if {
	some svc in input.compose_services
	svc.host_network == true
	msg := sprintf("%v/%v: network_mode: host (host network namespace shared)", [svc.compose_file, svc.service])
}

violations[msg] if {
	some svc in input.compose_services
	svc.host_pid == true
	msg := sprintf("%v/%v: pid: host (host PID namespace shared)", [svc.compose_file, svc.service])
}

violations[msg] if {
	some svc in input.compose_services
	svc.host_ipc == true
	msg := sprintf("%v/%v: ipc: host (host IPC namespace shared)", [svc.compose_file, svc.service])
}
