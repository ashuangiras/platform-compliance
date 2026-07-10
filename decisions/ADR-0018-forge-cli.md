# ADR-0018: `forge` — governed-repository bootstrapping CLI (supersedes ADR-0011)

| Field | Value |
|---|---|
| **ID** | ADR-0018 |
| **Status** | accepted |
| **Date** | 2026-07-10 |
| **Deciders** | platform-team |
| **Supersedes** | ADR-0011 (`plt` CLI — Go, GitHub Releases, platform-plt repo) |

---

## Context

ADR-0011 ratified a CLI tool named `plt` to be built in a separate `platform-plt` repository.
Two aspects of that decision require revision:

1. **Name:** `plt` is a shorthand with no semantic meaning. The tool's primary value proposition
   is **forging a new governed repository** — setting it up with the full compliance backbone
   from the first commit. The name should reflect that.

2. **Repository location:** Hosting the CLI in a separate repository adds release-cadence
   complexity and requires a second governed repository before the tooling pattern is proven.
   The tool belongs in `tools/forge/` inside `platform-compliance`, where it is co-located with
   the schemas, controls, and profiles it operates on. Independent-release-cadence benefits
   can be revisited once the tool is mature.

---

## Decision

### 1. Name: `forge`

The `forge` CLI forges new repositories into the compliance ecosystem. The name is:
- A clear, strong verb that implies creation and craftsmanship
- Memorable and professional — suitable for documentation, onboarding, and developer tooling
- Distinct from any existing tooling in the compliance space

The binary is invoked as `forge`. The primary command is `forge new repo <name>` which creates
a new repository pre-wired with the correct profile, `.compliance-manifest.yaml`, branch
protection, PR template, and agent configuration.

### 2. Repository location: `tools/forge/` in this repository

`forge` lives at `tools/forge/` inside `platform-compliance`. Rationale:
- `forge new repo` scaffolds `.compliance-manifest.yaml` pointing at a specific
  `platform-compliance` version — it must be co-versioned with the schemas and profiles it
  references, and a co-located tool gets that for free
- A single release of `platform-compliance` (e.g. `v2.3.0`) ships `policies.tar.gz` **and**
  the `forge` binary — consumers pin one artifact, not two
- Governance objects (controls, schemas, profiles) and tooling that operates on them belong
  in the same repository per ADR-0003 (no implementation before controls — same repo keeps
  the constraint trivially satisfied)
- A separate `platform-plt` repository would itself need to be governed, adding a bootstrap
  circular dependency before the pattern is proven

### 3. Language: Go (unchanged from ADR-0011)

### 4. Distribution: GitHub Releases binaries for each `platform-compliance` tag

Pre-built binaries attached to each release for `linux/amd64`, `darwin/amd64`, `darwin/arm64`.

```bash
# Install latest
curl -sSfL \
  https://github.com/ashuangiras/platform-compliance/releases/latest/download/forge_$(uname -s)_$(uname -m) \
  -o forge && chmod +x forge && sudo mv forge /usr/local/bin/forge
```

SHA-256 checksum file accompanies each binary (`forge_checksums.txt`).

---

## Primary command: `forge new repo`

This is the killer feature and the first command to implement:

```
forge new repo <name> [flags]

  --profile <id>        Compliance profile (default: PROF-SERVICE-V1)
  --type <type>         Repository type from taxonomy (default: service)
  --owner <github-org>  GitHub org/owner (default: ashuangiras)
  --with-agents         Include agent operating layer (.github/agents/)
  --dry-run             Preview what would be created

What it does:
  1. Creates the GitHub repository via API
  2. Commits the correct .compliance-manifest.yaml for the chosen profile
  3. Adds CODEOWNERS, .github/pull_request_template.md, and branch protection
  4. Optionally installs the agent operating layer from this repo's templates
  5. Opens a PR to main — triggering the first compliance workflow run
```

**Using `forge` to create `platform-plt`** (Phase B): Once `forge new repo` is implemented,
the `platform-plt` Python CLI (if revived) or any downstream service repository is bootstrapped
with `forge new repo platform-something --profile PROF-SERVICE-V1 --with-agents`.

---

## Full command set (v1.0.0 target, unchanged from ADR-0011)

| Command | What it does |
|---|---|
| `forge new repo <name>` | Bootstrap a governed repository |
| `forge new control` | Scaffold a new control in the correct domain directory |
| `forge new adr` | Scaffold an ADR with the next sequential ID |
| `forge new waiver` | Scaffold a waiver from template |
| `forge validate <file>` | Validate a YAML file against its schema |
| `forge validate-repo [path]` | Validate manifest + cross-check profile coverage |
| `forge gate check release\|deploy [repo]` | Evaluate gate from evidence |
| `forge evidence submit <file>` | Validate and submit an evidence record |
| `forge report coverage` | Show standards → controls coverage |
| `forge report status [repo]` | Show compliance posture for a repository |

---

## Implementation sequence

1. `forge validate <file>` — validates CLI architecture (MVP, no API calls)
2. `forge new repo` — primary value-delivery command
3. `forge validate-repo` + `forge gate check` — local developer workflow
4. `forge report` commands — visibility and onboarding

---

## Consequences

- `tools/forge/` is created in this repository with a `go.mod` and the initial `cmd/` structure
- ADR-0011 status updated to `superseded`
- The `release.yml` workflow is extended to build and attach `forge` binaries to each tag
- `tools/README.md` updated to describe `forge` at `tools/forge/`
- No separate `platform-plt` repository is created; downstream repos are bootstrapped using
  `forge new repo` once it is implemented
