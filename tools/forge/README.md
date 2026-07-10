# forge

forge is the developer CLI for the `platform-compliance` system. It turns the
compliance governance chain (standards → controls → profiles → bindings → policies)
into actionable developer tooling: bootstrapping governed repositories, scaffolding
governance objects, running OPA policies locally, and evaluating compliance gates
without leaving your terminal.

The primary command is `forge new repo`, which creates a fully governed repository
pre-wired to the right profile, CODEOWNERS, and agent layer.

---

## Install

### Option 1 — Download binary from GitHub Releases

```bash
# Linux (x86_64)
curl -Lo forge \
  https://github.com/ashuangiras/platform-compliance/releases/latest/download/forge_Linux_x86_64
chmod +x forge
sudo mv forge /usr/local/bin/

# macOS (Apple Silicon)
curl -Lo forge \
  https://github.com/ashuangiras/platform-compliance/releases/latest/download/forge_Darwin_arm64
chmod +x forge
sudo mv forge /usr/local/bin/

# macOS (Intel)
curl -Lo forge \
  https://github.com/ashuangiras/platform-compliance/releases/latest/download/forge_Darwin_x86_64
chmod +x forge
sudo mv forge /usr/local/bin/
```

Verify the SHA-256 checksum against `forge_checksums.txt` published alongside each release.

### Option 2 — Build from source

Requires Go 1.22+.

```bash
git clone https://github.com/ashuangiras/platform-compliance.git
cd platform-compliance/tools/forge
go build ./...
sudo mv forge /usr/local/bin/
```

---

## Quick start

```bash
# 1. Validate any governance file
forge validate 03-catalogs/controls/SEC/SEC-001.yaml --compliance-dir .

# 2. Preview a new governed repo (no API calls)
forge new repo my-service --profile PROF-SERVICE-V1 --org myorg --compliance-dir . --dry-run

# 3. Create it for real (requires GITHUB_TOKEN)
GITHUB_TOKEN=... forge new repo my-service --profile PROF-SERVICE-V1 --org myorg --compliance-dir .
```

---

## Configuration

forge looks for configuration in two places (in precedence order):

### Per-repo — `.forge.yaml` (project root)

```yaml
compliance-dir: /path/to/platform-compliance
org: myorg
default-profile: PROF-SERVICE-V1
```

### Global — `~/.forge/config.yaml`

```yaml
compliance-dir: /path/to/platform-compliance
org: myorg
github-token: ghp_...          # or set GITHUB_TOKEN in env
```

All flags can be overridden at the command line. Environment variables follow the
pattern `FORGE_<FLAG_NAME_UPPERCASED>` (e.g., `FORGE_ORG=myorg`).

---

## Command reference

| Command | Description |
|---|---|
| `forge new repo` | Bootstrap a governed repository with CODEOWNERS, profile binding, and optional agent layer |
| `forge new control` | Scaffold a new control YAML from a template |
| `forge new adr` | Scaffold an architectural decision record |
| `forge new waiver` | Scaffold a compliance waiver record |
| `forge new change-record` | Scaffold a Change Record (`CHG-YYYYMMDD-NNN`) |
| `forge validate <file>` | Validate a governance object against its JSON schema |
| `forge validate repo` | Validate all governance objects in the current repo |
| `forge validate manifest` | Validate `.compliance-manifest.yaml` |
| `forge check all` | Run all applicable OPA policies locally against the current repo |
| `forge check policy <id>` | Run a single OPA policy by control ID |
| `forge gate merge` | Evaluate the merge compliance gate |
| `forge gate deploy` | Evaluate the deploy compliance gate |
| `forge gate release` | Evaluate the release compliance gate |
| `forge evidence collect` | Collect evidence for all bound controls |
| `forge evidence submit` | Submit collected evidence to the evidence ledger |
| `forge evidence list` | List evidence entries for the current repo |
| `forge assess run` | Generate an assessment report |
| `forge assess show` | Display the latest assessment report |
| `forge registry list` | Browse registered governance objects (controls, profiles, standards) |
| `forge registry show` | Display a specific governance object |
| `forge report coverage` | Report control coverage for the current repo |
| `forge report drift` | Report controls that have drifted from their bound implementations |
| `forge report profile` | Report profile compliance summary |

---

## How it works

1. **Governance ref** — forge reads standards, controls, profiles, and policies from a
   compliance ref: either a pinned release tag (e.g., `v1.2.0`) or a local directory
   via `--compliance-dir`. This means the governance source of truth is always
   versioned and auditable.

2. **Collectors** — for commands like `forge check` and `forge gate`, forge runs the
   input collectors (`07-policies/scripts/collect-*.sh` / `collect-*.py`) against the
   target repository. These emit structured JSON facts about the repo's actual state.

3. **OPA evaluation** — collected facts are fed into the OPA policy engine, which
   evaluates the Rego policies under `07-policies/opa/`. Each policy returns
   `pass`, `fail`, or `not_applicable`.

4. **Gates** — gate commands (`forge gate merge|deploy|release`) aggregate policy
   results across all controls bound to the repo's profile and return a pass/fail
   verdict with a full evidence trace.

---

## How new repos use forge (Phase C)

forge is the entry point for bootstrapping every new governed repository in the platform.

```bash
# Create platform-modules (Terraform module repo)
forge new repo platform-modules \
  --profile PROF-TERRAFORM-MODULE-V1 \
  --type terraform-module \
  --org ashuangiras \
  --compliance-dir /path/to/platform-compliance \
  --dry-run

# Create a Go service repo with the full agent operating layer
forge new repo my-api \
  --profile PROF-GO-SERVICE-V1 \
  --contexts github,github-actions,go \
  --with-agents \
  --compliance-dir /path/to/platform-compliance
```

`forge new repo` will:
- Create the GitHub repository with the correct team permissions
- Write `.compliance-manifest.yaml` bound to the specified profile
- Write `CODEOWNERS` from the profile's ownership rules
- Scaffold the reusable compliance workflow caller
- Optionally scaffold the `.github/agents/` directory (`--with-agents`)

---

## Adding a new collector

forge uses a **data-driven collector pattern** — adding support for a new technology
context requires no forge code changes.

1. Write `07-policies/scripts/collect-<context>-info.sh` (or `.py`).
   The script must emit a JSON object to stdout following the collector output contract.

2. Add an entry to `07-policies/scripts/collector-map.yaml` mapping the technology
   context name to the collector script path.

3. Add `POLICY_MAP` entries to `07-policies/scripts/run-all-policies.py` wiring the
   new context's policies to the collector output keys.

The next run of `forge check all` (or the CI compliance workflow) will automatically
invoke the new collector and evaluate the associated policies.

---

## Development

```bash
cd tools/forge

# Build the binary
make build

# Run tests
make test

# Build release binaries for all platforms
make release-binaries
```

The `Makefile` targets mirror the CI steps in `.github/workflows/forge-ci.yml`.
Cross-compilation targets (`forge_Linux_x86_64`, `forge_Darwin_x86_64`,
`forge_Darwin_arm64`) are built and checksummed by the release workflow automatically
on every version tag push.
