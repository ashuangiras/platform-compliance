package platform.net.net_002_terraform

# Control:  NET-002 — Internal services must not bind to all interfaces (0.0.0.0)
# Binding:  BIND-NET-002-TERRAFORM
# Input:    iac-terraform.json (collect-terraform-info.sh)
#
# Checks docker_container resources for internal services (postgresql, redis) that
# have external port bindings without an explicit ip = "127.0.0.1" restriction.

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "NET-002 policy error: missing container port data"},
}

# ── NOT APPLICABLE ─────────────────────────────────────────────────────────────
result := {
	"result": "not_applicable",
	"details": {"message": "NET-002: no container port bindings found — not applicable"},
} if {
	not input.containers_with_all_interfaces
	count(input.module_calls) == 0
}

# ── PASS ───────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Internal service port bindings in '%v'", [input.repository.name]),
		"found":    "No internal services bound to 0.0.0.0",
		"expected": "Internal services (postgresql, redis) bind to 127.0.0.1 or have no host port",
		"message":  "NET-002: Internal service ports are not exposed on all interfaces",
	},
} if {
	count(input.containers_with_all_interfaces) == 0
}

# ── FAIL ───────────────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Internal service port bindings in '%v'", [input.repository.name]),
		"found":    sprintf("%v container(s) bound to 0.0.0.0: %v", [count(input.containers_with_all_interfaces), violation_summary]),
		"expected": "ip = \"127.0.0.1\" on all internal service port blocks, or no host port at all",
		"message":  "NET-002: Internal services are reachable from all host interfaces. Add ip = \"127.0.0.1\" to the ports block or remove host port binding.",
	},
} if {
	count(input.containers_with_all_interfaces) > 0
}

violation_summary := concat("; ", {
	sprintf("%v/%v", [c.file, c.name]) |
	some c in input.containers_with_all_interfaces
})
