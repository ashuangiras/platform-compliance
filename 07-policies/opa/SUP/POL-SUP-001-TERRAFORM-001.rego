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
#   input.modules_with_mutable_refs[] — { name, source, ref }
#                                       git modules whose ref is mutable or absent
#                                       (collector-precomputed; immutable semver
#                                       tags and 40-hex SHAs are excluded and thus
#                                       never appear in this list)
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

# Module source classification (Terraform getter semantics):
# - local  : in-repo path (./ or ../) — EXEMPT, not an external dependency
# - git    : git:: getter or any source carrying a ?ref= — pinned iff its ref is
#            an immutable tag/SHA. The collector precomputes mutable/absent refs
#            into input.modules_with_mutable_refs, so the policy does not re-parse
#            refs here; it simply trusts that classification.
# - registry: everything else (e.g. namespace/name/provider) — must carry a
#            bounded `version` constraint.
is_local_module(m) if startswith(m.source, "./")

is_local_module(m) if startswith(m.source, "../")

is_git_module(m) if startswith(m.source, "git::")

is_git_module(m) if contains(m.source, "?ref=")

is_registry_module(m) if {
	not is_local_module(m)
	not is_git_module(m)
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

# Git modules: the collector already classified mutable/absent refs. Each entry in
# input.modules_with_mutable_refs is an unpinned git dependency (branch ref or no
# ref). Immutable tag/SHA refs never appear here, so they produce no violation.
violations[msg] if {
	gm := input.modules_with_mutable_refs[_]
	msg := sprintf("Module '%v' git source '%v' uses mutable/absent ref '%v' (pin to an immutable tag or commit SHA)", [gm.name, gm.source, gm.ref])
}

# Registry modules only: their pinning is expressed via the `version` constraint.
# Local (./ ../) modules are exempt; git modules are handled above via the
# collector's ref classification, not via `version`.
violations[msg] if {
	m := input.module_calls[_]
	is_registry_module(m)
	not is_acceptable_constraint(m.version)
	msg := sprintf("Module '%v' source '%v' has unpinned version '%v'", [m.name, m.source, m.version])
}
