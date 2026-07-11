package platform.cat.cat_003_manifest

# Control:  CAT-003 — Repository manifest must declare a technology context
#                     for every detected surface
# Binding:  BIND-CAT-003-GITHUB
#
# Input schema (cat-manifest.json):
#   input.repository.name        — repository name
#   input.declared_contexts[]    — technology_contexts from .compliance-manifest.yaml
#   input.detected_surfaces      — { "agent": bool, ... } surfaces found on disk
#   input.surface_evidence.agent — [] list of surface paths detected (for messaging)
#
# This control runs UNCONDITIONALLY (github context, always present). It must not
# be gated on the surface it inspects, otherwise an undeclared surface would never
# be checked — the exact silent failure (SF-3) this control exists to prevent.

import future.keywords.if
import future.keywords.in

default result := {
    "result": "error",
    "details": {"message": "CAT-003 policy error: missing input data"},
}

# An agent surface is present on disk.
agent_surface_present if {
    input.detected_surfaces.agent == true
}

# The manifest declares the agent context.
agent_context_declared if {
    "agent" in input.declared_contexts
}

# ─── NOT APPLICABLE ───────────────────────────────────────────────────────────
# No governed surface detected — nothing to reconcile.
result := {
    "result": "not_applicable",
    "details": {"message": "CAT-003: no governed surface detected requiring a declared context"},
} if {
    input.detected_surfaces
    not agent_surface_present
}

# ─── PASS ─────────────────────────────────────────────────────────────────────
# Agent surface present and the manifest declares the agent context.
result := {
    "result": "pass",
    "details": {
        "checked":  sprintf("Manifest completeness for '%v'", [input.repository.name]),
        "found":    "Agent surface present and 'agent' declared in technology_contexts",
        "expected": "Every detected surface has a matching declared technology_context",
        "message":  "CAT-003: manifest technology_contexts cover all detected surfaces",
    },
} if {
    agent_surface_present
    agent_context_declared
}

# ─── FAIL ─────────────────────────────────────────────────────────────────────
# Agent surface present but the manifest does NOT declare the agent context.
# This is the SF-3 silent failure: agent controls would be skipped as
# not_applicable and the surface would be governed by nothing.
result := {
    "result": "fail",
    "details": {
        "checked":  sprintf("Manifest completeness for '%v'", [input.repository.name]),
        "found":    sprintf("Agent surface detected (%v) but 'agent' is NOT in technology_contexts", [surface_list]),
        "expected": "Add 'agent' to technology_contexts in .compliance-manifest.yaml so AGT-* controls are enforced",
        "message":  "CAT-003: manifest omits 'agent' context for a repository that has an agent surface",
    },
} if {
    agent_surface_present
    not agent_context_declared
}

# Human-readable list of detected agent surface paths for the failure message.
surface_list := concat(", ", input.surface_evidence.agent) if {
    input.surface_evidence.agent
    count(input.surface_evidence.agent) > 0
}

surface_list := ".github/agents, .vscode/mcp.json, or .github/hooks" if {
    not input.surface_evidence.agent
}
