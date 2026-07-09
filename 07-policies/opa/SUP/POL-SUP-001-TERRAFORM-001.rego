package platform.sup.sup_001_terraform

# Control:  SUP-001 — All dependency versions must be explicitly pinned
# Binding:  BIND-SUP-001-TERRAFORM
# Standard: SRC-OPENSSF-SCORECARD-V2 (Pinned-Dependencies check)
#           SRC-OPENSSF-SLSA-V1 (hermetic build requirements)
#
# Input schema:
#   input.repository.name
#   input.required_version            — string, e.g. "~> 1.5" or null if absent
#   input.required_providers[]        — { name, source, version }
#   input.module_calls[]              — { name, source, version }
#   input.violations[]                — pre-computed violations from HCL parser
#                                       (optional — policy also evaluates directly)

import future.keywords.if
import future.keywords.in

# Acceptable version constraint patterns (Terraform semantics):
# - Exact: "= 1.2.3" or "1.2.3"
# - Patch-level float: "~> 1.2.3"
# - Minor-level float (acceptable if bounded): "~> 1.2"
# Unacceptable: ">= 1.0" (no upper bound), "" (absent), "~> 1" (too broad)

# A version constraint is acceptable if it prevents major version surprises
is_acceptable_constraint(v) if {
	# Exact version
	startswith(v, "= ")
}

is_acceptable_constraint(v) if {
	# Exact version without operator
	regex.match(`^[0-9]+\.[0-9]+\.[0-9]+$`, v)
}

is_acceptable_constraint(v) if {
	# Pessimistic constraint operator (~>) — acceptable
	startswith(v, "~> ")
}

default result := {
	"result": "error",
	"details": {"message": "SUP-001 policy error: missing Terraform dependency data"},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Terraform version pinning in '%v'", [input.repository.name]),
		"found":    sprintf("All %v provider(s) and %v module(s) pinned; required_version: '%v'", [count(input.required_providers), count(input.module_calls), input.required_version]),
		"expected": "All dependencies use pinned or tightly bounded version constraints",
		"message":  "SUP-001: All Terraform dependencies are pinned",
	},
} if {
	count(violations) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Terraform version pinning in '%v'", [input.repository.name]),
		"found":    sprintf("%v pinning violation(s)", [count(violations)]),
		"expected": "All dependencies use = x.y.z or ~> x.y constraints",
		"message":  sprintf("SUP-001: Unpinned dependencies detected: %v", [concat("; ", {v | violations[v]})]),
		"violations": violations,
	},
} if {
	count(violations) > 0
}

violations[msg] if {
	not input.required_version
	msg := "required_version is not declared in the Terraform configuration"
}

violations[msg] if {
	input.required_version
	not is_acceptable_constraint(input.required_version)
	msg := sprintf("required_version '%v' is too broad (use ~> or = constraint)", [input.required_version])
}

violations[msg] if {
	p := input.required_providers[_]
	not is_acceptable_constraint(p.version)
	msg := sprintf("Provider '%v' has unpinned version '%v'", [p.name, p.version])
}

violations[msg] if {
	m := input.module_calls[_]
	not is_acceptable_constraint(m.version)
	msg := sprintf("Module '%v' source '%v' has unpinned version '%v'", [m.name, m.source, m.version])
}
