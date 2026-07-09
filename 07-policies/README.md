# 07-policies — Policy-as-Code

This directory contains machine-verifiable rule implementations. Each policy check is the executable counterpart of one or more implementation bindings. Policies run in CI/CD pipelines and produce structured evidence records.

## What this directory owns

- Policy files, organised by engine subdirectory and then by domain
- A companion metadata file (`.check.yaml`) for each policy file

## Policy engine: OPA (Open Policy Agent)

**OPA/Rego has been selected as the primary policy engine.**

Rationale: OPA provides a declarative, language-independent policy evaluation model. Rego policies are testable, versionable, and produce structured JSON output that maps directly to the evidence record schema. The `conftest` CLI wrapper makes OPA policies easy to invoke from CI pipelines against YAML and JSON inputs without custom tooling.

An ADR (ADR-0004) will formally ratify this decision. The `opa/` subdirectory structure is established now to avoid re-laying out policies when the ADR is ratified.

Secondary engine: `scripts/` (shell scripts) for checks that require GitHub API calls or file-system operations that OPA cannot perform natively (e.g., SRC-001 branch protection API check).

## Status

**Not yet populated.** Policy files will be authored after bindings (Phase 6, PC-0040–PC-0047) are complete. The directory structure and OPA README are being established now.

> Note: `../decisions/ADR-0002-github-primary-remote.md` has already been authored. The policy engine ADR will be numbered ADR-0004 or the next available number when authored.

Policy files will be created in Phase 7 of the implementation roadmap (tasks PC-0049 to PC-0059).

## Directory structure

```
07-policies/
├── README.md                  ← this file
├── opa/                       ← OPA/Rego policies (primary engine)
│   ├── README.md
│   └── {DOMAIN}/
│       ├── POL-{ID}-{CONTEXT}.rego
│       └── POL-{ID}-{CONTEXT}.check.yaml
├── scripts/                   ← Shell script policies (GitHub API, file-system checks)
│   ├── README.md
│   └── {DOMAIN}/
│       ├── POL-{ID}-{CONTEXT}.sh
│       └── POL-{ID}-{CONTEXT}.check.yaml
└── tests/
    └── fixtures/
        └── {DOMAIN}/
            ├── {control-id}-pass.json
            └── {control-id}-fail.json
```

## Rules for policy files

1. Every policy file must have a companion `.check.yaml` metadata file
2. The `.check.yaml` must reference a valid binding ID from `../06-bindings/`
3. Every policy must have at least one passing fixture and one failing fixture
4. Policies must produce structured JSON output conforming to the evidence record schema's `details` field
5. No policy may embed repository names, organisation names, or environment-specific values
6. OPA policies must use the package convention: `package platform.{domain}.{control_id_snake_case}`

## Output format contract

Every OPA policy must produce a `result` object matching this structure:

```json
{
  "result": "pass" | "fail" | "not_applicable" | "error",
  "details": {
    "checked": "...",
    "found": "...",
    "expected": "...",
    "message": "Human-readable explanation"
  }
}
```

The `evidence-collect` workflow converts this output into a full evidence record.

## What does NOT belong here

- Binding specifications (those are in `../06-bindings/`)
- Infrastructure code (Terraform, Docker)
- Application logic
- Any policy without a companion `.check.yaml`
- Any policy without a corresponding binding
