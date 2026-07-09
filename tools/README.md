# tools — Platform CLI and Tooling

This directory contains the `plt` command-line tool and supporting scripts for interacting with the compliance system programmatically.

## What this directory owns

- Source code for the `plt` platform CLI
- Supporting shell scripts for operations too simple to warrant CLI commands

## Status

**Not yet populated.** CLI design and implementation is deferred to a future phase. Supporting scripts for schema validation will be added when Phase 4 (schemas) is complete.

## Planned structure

```
tools/
├── README.md           ← this file
├── plt/                ← platform CLI source code
│   ├── cmd/
│   │   ├── validate.go
│   │   ├── assess.go
│   │   ├── evidence.go
│   │   └── report.go
│   ├── go.mod
│   └── go.sum
└── scripts/
    ├── validate-schemas.sh
    ├── check-profile-coverage.sh
    └── generate-dashboard-data.sh
```

## Planned CLI commands

| Command | Purpose |
|---|---|
| `plt validate <file>` | Validate a YAML file against its schema |
| `plt validate-repo <path>` | Validate a repository's compliance manifest and profile coverage |
| `plt new control` | Scaffold a new control from the template |
| `plt new adr` | Scaffold a new ADR from the template |
| `plt new profile` | Scaffold a new profile from the template |
| `plt assess <repo>` | Generate an assessment report for a repository |
| `plt evidence submit <file>` | Submit an evidence record to the ledger |
| `plt gate check release <repo>` | Evaluate the release gate for a repository |
| `plt gate check deploy <repo>` | Evaluate the deployment gate |
| `plt report coverage` | Report standards coverage across the control catalog |

## Technology choice

The CLI language will be decided when tooling work begins. Go is the current candidate for its single-binary distribution model. This choice will be documented in an ADR when the decision is made.

## What does NOT belong here

- Policy files (those are in `../07-policies/`)
- Workflow definitions (those are in `../workflows/`)
- Infrastructure code or application code
- Scripts that manage infrastructure directly (those belong in infrastructure repos)
