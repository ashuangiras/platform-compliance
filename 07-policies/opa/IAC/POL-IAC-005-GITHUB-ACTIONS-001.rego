package platform.iac.iac_005_github_actions

# Control:  IAC-005 — Scheduled Terraform plan must detect infrastructure drift
# Binding:  BIND-IAC-005-GITHUB-ACTIONS
# Standard: SRC-OPENGITOPS-V1 (Principle 2), SRC-CIS-CONTROLS-V8 (Control 4)

import future.keywords.if
import future.keywords.in

terraform_plan_patterns := {
    "hashicorp/setup-terraform",
    "opentofu/setup-opentofu",
}

# Check for a workflow with schedule trigger + terraform setup action
scheduled_terraform_workflows[wf] if {
    some wf in input.workflow_files_detail
    wf.is_reusable != true
    # Has schedule trigger
    triggers := wf.triggers
    is_object(triggers)
    "schedule" in triggers
}

scheduled_terraform_references[action] if {
    some wf in input.workflow_files_detail
    scheduled_terraform_workflows[wf]
    some ref in input.action_references
    ref.workflow == wf.path
    some prefix in terraform_plan_patterns
    startswith(ref.uses, prefix)
    action := ref.uses
}

drift_detection_configured if count(scheduled_terraform_references) > 0

default result := {
    "result": "error",
    "details": {"message": "IAC-005 policy error: missing input data"},
}

result := {
    "result": "pass",
    "details": {
        "checked":  sprintf("Scheduled Terraform drift detection in '%v'", [input.repository.name]),
        "found":    "Scheduled workflow with Terraform setup action detected",
        "expected": "Workflow with schedule trigger + hashicorp/setup-terraform",
        "message":  "IAC-005: Terraform drift detection is configured",
    },
} if {
    count(input.workflow_files) > 0
    drift_detection_configured
}

result := {
    "result": "not_applicable",
    "details": {"message": "IAC-005: No GitHub Actions workflow files found"},
} if {
    count(input.workflow_files) == 0
}

result := {
    "result": "fail",
    "details": {
        "checked":  sprintf("Scheduled Terraform drift detection in '%v'", [input.repository.name]),
        "found":    "No scheduled workflow with Terraform setup action detected",
        "expected": "Workflow with on.schedule + hashicorp/setup-terraform + terraform plan",
        "message":  "IAC-005: No drift detection configured. Add a scheduled terraform plan workflow.",
    },
} if {
    count(input.workflow_files) > 0
    not drift_detection_configured
}
