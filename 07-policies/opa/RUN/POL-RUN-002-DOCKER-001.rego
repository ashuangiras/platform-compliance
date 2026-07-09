package platform.run.run_002_docker

# Control:  RUN-002 — Containers must run as a non-root user
# Binding:  BIND-RUN-002-DOCKER
# Standard: SRC-CIS-DOCKER-V1-6 (4.1 — user for container must be created)
#
# Input schema:
#   input.repository.name
#   input.dockerfiles[]                  — parsed Dockerfile per file
#   input.dockerfiles[].path             — Dockerfile path
#   input.dockerfiles[].instructions[]   — {instruction, value}
#   input.dockerfiles[].user_before_entrypoint — bool
#   input.dockerfiles[].user_is_root     — bool
#   input.dockerfiles[].user_value       — string (the USER value, "" if absent)

import future.keywords.if
import future.keywords.in

root_identifiers := {"root", "0", ""}

default result := {
	"result": "error",
	"details": {"message": "RUN-002 policy error: missing Dockerfile analysis"},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("USER instruction in %v Dockerfile(s) in '%v'", [count(input.dockerfiles), input.repository.name]),
		"found":    "All Dockerfiles specify a non-root USER before ENTRYPOINT/CMD",
		"expected": "USER instruction present, non-root, before ENTRYPOINT/CMD",
		"message":  "RUN-002: All containers will run as non-root",
	},
} if {
	count(violations) == 0
	count(input.dockerfiles) > 0
}

result := {
	"result": "not_applicable",
	"details": {
		"message": "RUN-002: No Dockerfiles found — control not applicable",
	},
} if {
	count(input.dockerfiles) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("USER instruction in Dockerfiles in '%v'", [input.repository.name]),
		"found":    sprintf("%v violation(s)", [count(violations)]),
		"expected": "All Dockerfiles: non-root USER before ENTRYPOINT/CMD",
		"message":  sprintf("RUN-002: Non-root user requirement violated: %v", [concat("; ", {v | violations[v]})]),
		"violations": violations,
	},
} if {
	count(violations) > 0
}

violations[msg] if {
	df := input.dockerfiles[_]
	df.user_value in root_identifiers
	not df.user_value == ""
	msg := sprintf("'%v': USER is 'root' or '0'", [df.path])
}

violations[msg] if {
	df := input.dockerfiles[_]
	df.user_value == ""
	msg := sprintf("'%v': No USER instruction found (default is root)", [df.path])
}

violations[msg] if {
	df := input.dockerfiles[_]
	not df.user_before_entrypoint
	not df.user_value == ""
	msg := sprintf("'%v': USER instruction appears after ENTRYPOINT or CMD", [df.path])
}
