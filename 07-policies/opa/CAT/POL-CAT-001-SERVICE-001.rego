package platform.cat.cat_001_service

# Control:  CAT-001 — Every service must be registered with a service contract
# Binding:  BIND-CAT-001-SERVICE
#
# Input schema:
#   input.files[]               — list of files in the repository ({path, size})
#   input.repository.name       — repository name
#   input.repository.type       — repository type (only applies to "service")

import future.keywords.if
import future.keywords.in

default result := {
    "result": "error",
    "details": {"message": "CAT-001 policy error: missing input data"},
}

# Helper: true only when repository.type is explicitly "service".
# Using a helper avoids the OPA undefined-reference pitfall:
# `undefined != "service"` evaluates to false (not true), so the
# not_applicable rule would never fire if repository.type is absent.
is_service_repo if {
    input.repository.type == "service"
}

# ─── NOT APPLICABLE ───────────────────────────────────────────────────────────
# Only service repositories require service contracts.
result := {
    "result": "not_applicable",
    "details": {"message": "CAT-001: not applicable to non-service repositories"},
} if {
    not is_service_repo
}

# ─── NOT APPLICABLE (no files input) ──────────────────────────────────────────
result := {
    "result": "not_applicable",
    "details": {"message": "CAT-001: file list not available — cannot evaluate"},
} if {
    input.repository.type == "service"
    not input.files
}

# ─── PASS ─────────────────────────────────────────────────────────────────────
# At least one YAML file exists under service-contracts/ with content (size > 0).
result := {
    "result": "pass",
    "details": {
        "checked":  sprintf("Service catalog registration in '%v'", [input.repository.name]),
        "found":    sprintf("%v service contract file(s) in service-contracts/", [count(contracts)]),
        "expected": "At least one service contract YAML file in service-contracts/",
        "message":  "CAT-001: service is registered in the service catalog",
    },
} if {
    input.repository.type == "service"
    input.files
    count(contracts) > 0
}

# ─── FAIL ─────────────────────────────────────────────────────────────────────
result := {
    "result": "fail",
    "details": {
        "checked":  sprintf("Service catalog registration in '%v'", [input.repository.name]),
        "found":    "no service contract files found",
        "expected": "at least one YAML file in service-contracts/ (e.g. service-contracts/<service-id>.yaml)",
        "message":  "CAT-001: no service contract found. Add service-contracts/<service-id>.yaml to register this service in the catalog.",
    },
} if {
    input.repository.type == "service"
    input.files
    count(contracts) == 0
}

# ─── Helper ───────────────────────────────────────────────────────────────────
contracts := {f.path |
    f := input.files[_]
    startswith(f.path, "service-contracts/")
    endswith(f.path, ".yaml")
    f.size > 0
}
