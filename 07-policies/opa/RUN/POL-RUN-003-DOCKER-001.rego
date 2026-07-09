package platform.run.run_003_docker

# Control:  RUN-003 — Containerised services must declare CPU and memory resource limits
# Binding:  BIND-RUN-003-DOCKER
# Standard: SRC-GOOGLE-SRE (capacity planning), SRC-AWS-WAF-2024 (reliability)
#
# Input schema (from collect-dockerfile-info.sh or service-contract.yaml):
#   input.repository.name
#   input.services[]                    — docker-compose services
#   input.services[].name
#   input.services[].cpu_limit          — string or null
#   input.services[].memory_limit       — string or null

import future.keywords.if
import future.keywords.in

services_without_limits[name] if {
	svc := input.services[_]
	name := svc.name
	not svc.cpu_limit
}

services_without_limits[name] if {
	svc := input.services[_]
	name := svc.name
	not svc.memory_limit
}

default result := {
	"result": "error",
	"details": {"message": "RUN-003 policy error: missing deployment configuration data"},
}

result := {
	"result": "not_applicable",
	"details": {"message": "RUN-003: No services found in deployment configuration"},
} if {
	count(input.services) == 0
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Resource limits in %v service(s) in '%v'", [count(input.services), input.repository.name]),
		"found":    "All services declare CPU and memory limits",
		"expected": "CPU and memory limits declared for every service",
		"message":  "RUN-003: Resource limits are declared for all services",
	},
} if {
	count(input.services) > 0
	count(services_without_limits) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Resource limits in '%v'", [input.repository.name]),
		"found":    sprintf("%v service(s) missing CPU or memory limits: %v", [count(services_without_limits), concat(", ", {n | services_without_limits[n]})]),
		"expected": "deploy.resources.limits.cpus and deploy.resources.limits.memory set for every service",
		"message":  sprintf("RUN-003: Declare resource limits for: %v", [concat(", ", {n | services_without_limits[n]})]),
		"missing_limits": [n | services_without_limits[n]],
	},
} if {
	count(services_without_limits) > 0
}
