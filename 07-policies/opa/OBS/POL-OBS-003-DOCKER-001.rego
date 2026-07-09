package platform.obs.obs_003_docker

# Control:  OBS-003 — Services must expose a Prometheus-compatible metrics endpoint
# Binding:  BIND-OBS-003-DOCKER
# Standard: SRC-GOOGLE-SRE (Chapter 6 — four golden signals)

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "OBS-003 policy error: missing input data"},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("%v Docker Compose service(s) in '%v'", [count(input.compose_services), input.repository.name]),
		"found":    "Metrics endpoint evidence found (port 9090 or METRICS env var)",
		"expected": "Port 9090 exposed or METRICS_PORT/METRICS_PATH env var declared",
		"message":  "OBS-003: Prometheus metrics endpoint is configured",
	},
} if {
	count(input.compose_services) > 0
	metrics_detected
}

result := {
	"result": "not_applicable",
	"details": {"message": "OBS-003: No Docker Compose service definitions found"},
} if {
	count(input.compose_services) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("%v Docker Compose service(s) in '%v'", [count(input.compose_services), input.repository.name]),
		"found":    "No metrics port or METRICS env var detected in any service",
		"expected": "Port 9090 exposed or METRICS_PORT/METRICS_PATH env var in docker-compose.yml",
		"message":  "OBS-003: No Prometheus metrics endpoint detected. Expose port 9090 or set METRICS_PORT env var.",
	},
} if {
	count(input.compose_services) > 0
	not metrics_detected
}

metrics_detected if {
	some svc in input.compose_services
	svc.metrics_port_exposed == true
}

metrics_detected if {
	some svc in input.compose_services
	svc.metrics_env_declared == true
}
