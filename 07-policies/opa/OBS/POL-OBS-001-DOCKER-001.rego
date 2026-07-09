package platform.obs.obs_001_docker

# Control:  OBS-001 — Every service must declare and implement a health check
# Binding:  BIND-OBS-001-DOCKER
# Standard: SRC-CIS-DOCKER-V1-6 (4.6 — HEALTHCHECK instructions)
#           SRC-GOOGLE-SRE (health monitoring)
#           SRC-AWS-WAF-2024 (workload health)
#
# Input: output of collect-dockerfile-info.sh
#   input.repository.name
#   input.dockerfiles[]
#   input.dockerfiles[].path
#   input.dockerfiles[].healthcheck_present   — bool

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "OBS-001 policy error: missing dockerfile analysis data"},
}

result := {
	"result": "not_applicable",
	"details": {"message": "OBS-001: No Dockerfiles found — not a containerised service"},
} if {
	count(input.dockerfiles) == 0
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("HEALTHCHECK in %v Dockerfile(s) in '%v'", [count(input.dockerfiles), input.repository.name]),
		"found":    "All Dockerfiles have a HEALTHCHECK instruction",
		"expected": "HEALTHCHECK instruction present in every Dockerfile",
		"message":  "OBS-001: Health check is declared in all Dockerfiles",
	},
} if {
	count(input.dockerfiles) > 0
	count(missing_healthcheck) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("HEALTHCHECK in Dockerfiles in '%v'", [input.repository.name]),
		"found":    sprintf("%v Dockerfile(s) missing HEALTHCHECK", [count(missing_healthcheck)]),
		"expected": "HEALTHCHECK instruction in every Dockerfile",
		"message":  sprintf("OBS-001: Add HEALTHCHECK to: %v", [concat(", ", {p | missing_healthcheck[p]})]),
		"missing":  [p | missing_healthcheck[p]],
	},
} if {
	count(missing_healthcheck) > 0
}

missing_healthcheck[path] if {
	df := input.dockerfiles[_]
	not df.healthcheck_present
	path := df.path
}
