package platform.bak.bak_001_github

# Control:  BAK-001 — Stateful services must declare and implement a backup policy
# Binding:  BIND-BAK-001-MANUAL
# Standard: SRC-AWS-WAF-2024 (REL 9), SRC-GOOGLE-SRE (Chapter 26), SRC-ITIL-ADAPTED
#
# Input schema (from service-contract.yaml):
#   input.repository.name
#   input.service_type              — "stateful" | "stateless" | "gateway" | ...
#   input.backup_policy             — object or null
#   input.backup_policy.frequency
#   input.backup_policy.retention
#   input.backup_policy.storage_location
#   input.backup_policy.restoration_procedure
#   input.backup_policy.last_restore_test_date  — string or null
#   input.backup_policy.rto
#   input.backup_policy.rpo

import future.keywords.if
import future.keywords.in

required_fields := {"frequency", "retention", "storage_location", "restoration_procedure", "rto", "rpo"}

backup_field_missing[field] if {
	field := required_fields[_]
	not input.backup_policy[field]
}

default result := {
	"result": "error",
	"details": {"message": "BAK-001 policy error: missing service contract data"},
}

result := {
	"result": "not_applicable",
	"details": {"message": "BAK-001: Service is not stateful — backup policy not required"},
} if {
	input.service_type != "stateful"
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Backup policy declaration for stateful service '%v'", [input.repository.name]),
		"found":    sprintf("Backup policy declared: %v / %v / last test: %v", [input.backup_policy.frequency, input.backup_policy.retention, input.backup_policy.last_restore_test_date]),
		"expected": "All required backup policy fields present",
		"message":  "BAK-001: Backup policy is fully declared",
	},
} if {
	input.service_type == "stateful"
	input.backup_policy != null
	count(backup_field_missing) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Backup policy declaration for '%v'", [input.repository.name]),
		"found":    "backup_policy is absent from service-contract.yaml",
		"expected": "backup_policy block with frequency, retention, rto, rpo, restoration_procedure",
		"message":  "BAK-001: Add backup_policy to service-contract.yaml before deploying this stateful service",
	},
} if {
	input.service_type == "stateful"
	not input.backup_policy
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Backup policy completeness for '%v'", [input.repository.name]),
		"found":    sprintf("Missing required fields: %v", [concat(", ", {f | backup_field_missing[f]})]),
		"expected": "All backup policy fields: frequency, retention, storage_location, restoration_procedure, rto, rpo",
		"message":  sprintf("BAK-001: Incomplete backup_policy — add: %v", [concat(", ", {f | backup_field_missing[f]})]),
	},
} if {
	input.service_type == "stateful"
	input.backup_policy != null
	count(backup_field_missing) > 0
}
