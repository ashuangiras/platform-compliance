# 06-bindings/bindings — Implementation Binding Files by Context

This directory contains implementation bindings organised into technology context subdirectories.

## Structure

```
bindings/
├── docker/          — Docker, Dockerfile, docker-compose
├── github/          — GitHub repository settings, APIs
├── github-actions/  — GitHub Actions workflow files
├── runtime-linux/   — Linux host runtime (future)
└── terraform/       — Terraform and OpenTofu code
```

## Naming convention

`BIND-{CONTROL_ID}-{CONTEXT}.yaml` — e.g., `BIND-SRC-001-GITHUB.yaml`

## Schema

All files conform to `../../schemas/binding.schema.json`.

## What does NOT belong here

- Policy code (those are in `../../07-policies/`)
- Controls (those are in `../../03-catalogs/controls/`)
- Bindings for technology contexts not defined in `../../02-taxonomy/technology-contexts.yaml`
