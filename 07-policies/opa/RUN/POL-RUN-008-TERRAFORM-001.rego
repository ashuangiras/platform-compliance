package platform.run.run_008_terraform

# Control:  RUN-008 — Containers must declare memory and CPU resource limits
# Binding:  BIND-RUN-008-TERRAFORM
# Input:    iac-terraform.json (collect-terraform-info.sh)
#
# Checks docker_container Terraform resources for the presence of a memory limit.
# Modules that wrap docker_container should expose and pass through a memory variable.

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "RUN-008 policy error: missing terraform input data"},
}

# ── NOT APPLICABLE ─────────────────────────────────────────────────────────────
# Only terraform-root and terraform-module repos can contain docker_container resources.
result := {
	"result": "not_applicable",
	"details": {"message": "RUN-008: not applicable to non-Terraform repositories"},
} if {
	not input.docker_containers_missing_limits
	not input.module_calls
}

# ── PASS ───────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("docker_container resources in '%v'", [input.repository.name]),
		"found":    "All docker_container resources declare a memory limit",
		"expected": "memory = <MiB> present on every docker_container resource",
		"message":  "RUN-008: All containers have memory limits declared",
	},
} if {
	count(input.docker_containers_missing_limits) == 0
	# At least one module call exists (non-trivial repository)
	count(input.module_calls) > 0
}

# ── PASS (no containers in this repo — infrastructure managed externally) ──────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("docker_container resources in '%v'", [input.repository.name]),
		"found":    "No direct docker_container resource declarations found",
		"expected": "memory limits in module definitions",
		"message":  "RUN-008: No docker_container resources in this repo — limits enforced in platform-modules",
	},
} if {
	count(input.docker_containers_missing_limits) == 0
	count(input.module_calls) == 0
}

# ── FAIL ───────────────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("docker_container resources in '%v'", [input.repository.name]),
		"found":    sprintf("%v docker_container resource(s) missing memory limit: %v", [count(input.docker_containers_missing_limits), missing_names]),
		"expected": "memory = <MiB> on every docker_container resource",
		"message":  "RUN-008: Add memory limits to all docker_container resources. See RUN-008 control guidance.",
	},
} if {
	count(input.docker_containers_missing_limits) > 0
}

missing_names := concat(", ", {sprintf("%v/%v", [c.file, c.name]) | some c in input.docker_containers_missing_limits})
