# tools — Platform CLI and Tooling

Supporting scripts and the `forge` CLI for interacting with the compliance system.

## `forge` CLI

The `forge` command-line tool lives at **`tools/forge/`** in this repository
(per [ADR-0018](../decisions/ADR-0018-forge-cli.md), supersedes ADR-0011).

**Primary command — bootstrap a governed repository:**
```bash
forge new repo <name> --profile PROF-SERVICE-V1 --with-agents
```

**Install (once the binary is built):**
```bash
curl -sSfL \
  https://github.com/ashuangiras/platform-compliance/releases/latest/download/forge_$(uname -s)_$(uname -m) \
  -o forge && chmod +x forge && sudo mv forge /usr/local/bin/forge
```

**Status:** implementation pending (Phase B) — `tools/forge/` not yet populated.

## Scripts in this directory

| Script | Purpose |
|--------|---------|
| `check-agents.sh` | Run the full AGT suite locally — fails loudly if agent configuration is below standard |
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
