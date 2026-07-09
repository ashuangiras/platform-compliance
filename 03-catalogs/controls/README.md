# 03-catalogs/controls — Control Files by Domain

This directory contains the platform control catalog organised into domain subdirectories. Each subdirectory contains one YAML file per control in that domain.

## Directory structure

```
controls/
├── BAK/  — Backup and Recovery
├── CHG/  — Change and Release
├── DOC/  — Documentation and Decisions
├── IAC/  — Infrastructure as Code
├── INC/  — Incident and Problem
├── NET/  — Network and Exposure
├── OBS/  — Observability
├── RUN/  — Runtime / Docker
├── SEC/  — Security and Secrets
├── SRC/  — Source Control
└── SUP/  — Supply Chain
```

## Naming convention

`{DOMAIN}-{NNN}.yaml` — e.g., `SRC-001.yaml`, `SEC-002.yaml`

Control IDs are permanent. A deprecated control retains its file with `lifecycle_status: deprecated`.

## Schema

All files conform to `../../../schemas/control.schema.json`.

## What does NOT belong here

- Bindings (those are in `06-bindings/`)
- Policies (those are in `07-policies/`)
- Profile definitions (those are in `04-profiles/`)
