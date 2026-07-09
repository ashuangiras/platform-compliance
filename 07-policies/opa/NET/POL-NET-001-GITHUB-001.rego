package platform.net.net_001_github

# Control:  NET-001 — Externally exposed services must declare an explicit ingress policy
# Binding:  BIND-NET-001-SERVICE-CONTRACT
# Standard: SRC-CIS-DOCKER-V1-6 (network configuration), SRC-AWS-WAF-2024 (SEC 5)
#
# Input schema (from service-contract.yaml):
#   input.repository.name
#   input.externally_exposed        — bool
#   input.ingress_policy            — object or null
#   input.ingress_policy.allowed_sources[]
#   input.ingress_policy.allowed_protocols[]
#   input.ingress_policy.authentication_required

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "NET-001 policy error: missing service contract data"},
}

result := {
	"result": "not_applicable",
	"details": {"message": "NET-001: Service is not externally exposed — ingress policy not required"},
} if {
	not input.externally_exposed
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Ingress policy declaration for '%v'", [input.repository.name]),
		"found":    sprintf("Ingress policy declared: %v protocol(s), auth_required: %v", [count(input.ingress_policy.allowed_protocols), input.ingress_policy.authentication_required]),
		"expected": "ingress_policy with allowed_sources, allowed_protocols, authentication_required",
		"message":  "NET-001: Ingress policy is fully declared",
	},
} if {
	input.externally_exposed
	input.ingress_policy != null
	count(input.ingress_policy.allowed_sources) > 0
	count(input.ingress_policy.allowed_protocols) > 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Ingress policy for '%v'", [input.repository.name]),
		"found":    "ingress_policy absent from service-contract.yaml",
		"expected": "ingress_policy block with allowed_sources and allowed_protocols",
		"message":  "NET-001: Add ingress_policy to service-contract.yaml before deploying this externally exposed service",
	},
} if {
	input.externally_exposed
	not input.ingress_policy
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Ingress policy completeness for '%v'", [input.repository.name]),
		"found":    "ingress_policy present but missing required fields",
		"expected": "allowed_sources (non-empty), allowed_protocols (non-empty), authentication_required",
		"message":  "NET-001: ingress_policy must have at least one allowed_source and one allowed_protocol",
	},
} if {
	input.externally_exposed
	input.ingress_policy != null
	count(input.ingress_policy.allowed_sources) == 0
}
