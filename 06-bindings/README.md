# 06-bindings — Implementation Bindings

This directory contains implementation binding specifications. A binding describes **how** a control is satisfied in a specific technology context. Bindings are prose specifications, not executable code.

## What this directory owns

- Binding YAML files, organised by technology context subdirectory

## File format

All binding files conform to `../schemas/binding.schema.yaml`.

File naming: `BIND-{CONTROL-ID}-{CONTEXT}.yaml` within the context subdirectory.

Example: `bindings/github/BIND-SRC-001-GITHUB.yaml`

## Technology contexts

Context subdirectory names correspond to values in `../02-taxonomy/technology-contexts.yaml`:

| Subdirectory | Context |
|---|---|
| `github/` | GitHub repository settings, GitHub Actions, branch protection |
| `terraform/` | Terraform and OpenTofu code, providers, modules |
| `docker/` | Dockerfiles, Docker Compose, container images |
| `github-actions/` | GitHub Actions workflow files |
| `runtime-linux/` | Linux host runtime configuration |

## Status

**Not yet populated.** Binding files will be authored in Phase 6 of the implementation roadmap (tasks PC-0040 to PC-0047).

## What a binding specifies

Each binding provides:
- The control it implements (`control_id`)
- The technology context it applies to
- A prose `specification`: what observable artifact or condition satisfies the control
- The `observable_artifact`: the specific, machine-locatable thing to check
- References to `policy_check_ids` that verify the binding

## Relationship between bindings and controls

The same control may have multiple bindings for different contexts. For example, SUP-001 (dependency versions must be pinned) has separate bindings for: `terraform` (provider/module pinning), `docker` (image tag pinning), and `github-actions` (action pinning). All three bindings implement the same abstract control requirement.

## What does NOT belong here

- Policy code (that is in `../07-policies/`)
- Control definitions (those are in `../03-catalogs/`)
- Bindings for technology contexts not defined in `../02-taxonomy/technology-contexts.yaml`
- Any binding for a deferred control
