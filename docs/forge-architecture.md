# `forge` — Complete Architecture

**Version:** 1.0 (design, pre-implementation)  
**ADR:** [ADR-0018](../decisions/ADR-0018-forge-cli.md)  
**Location:** `tools/forge/` in this repository  
**Binary:** `forge` (Go, pre-built per `platform-compliance` release tag)

---

## 1. Vision

`forge` is the developer-facing interface to the entire `platform-compliance` system. It wraps
every governance operation that an engineer would otherwise perform by hand — validating YAML,
running OPA policies, evaluating gates, submitting evidence, scaffolding new objects, and
bootstrapping governed repositories — into a single, discoverable CLI.

> **The primary value proposition:** `forge new repo <name>` creates a fully governed repository
> — correct profile, manifest, branch protection, PR template, and agent operating layer — in
> one command, before any code is written.

`forge` is intentionally a **client of `platform-compliance`, not a replacement for it**. It
reads schemas, controls, profiles, and policies from a pinned `platform-compliance` release (the
"compliance ref") and operates on them locally. The governance objects remain the source of
truth; `forge` makes them usable.

---

## 2. Full command taxonomy

```
forge
│
├── new                          # Scaffold and bootstrap
│   ├── repo <name>              # Bootstrap a complete governed repository on GitHub
│   ├── control                  # Scaffold a control YAML in the correct domain directory
│   ├── binding                  # Scaffold a binding YAML for a control+context pair
│   ├── profile                  # Scaffold a new profile inheriting from a parent
│   ├── mapping                  # Scaffold a mapping-collection YAML
│   ├── standard                 # Scaffold a standard-source registry entry
│   ├── adr                      # Scaffold the next ADR with auto-incremented ID
│   ├── waiver                   # Scaffold a waiver record for a control exception
│   ├── service-contract         # Scaffold a service-contract.yaml
│   └── change-record            # Allocate the next CHG-YYYYMMDD-NNN
│
├── validate                     # Schema validation (offline, no API required)
│   ├── <file>                   # Validate a single file using its $schema field
│   ├── repo [path]              # Validate all governance objects in a repo
│   ├── manifest [path]          # Validate .compliance-manifest.yaml only
│   └── schema <schema> <file>   # Validate against an explicit schema by name
│
├── check                        # Run OPA policies locally
│   ├── policy <id>              # Run a single policy against collected inputs
│   ├── control <id>             # Run all policies for a control
│   └── all                      # Run all applicable policies for this repo
│
├── gate                         # Evaluate compliance gates
│   ├── merge [repo]             # Evaluate the merge gate
│   ├── deploy [repo]            # Evaluate the deployment gate
│   └── release [repo]           # Evaluate the release gate
│
├── evidence                     # Evidence record management
│   ├── collect                  # Run all applicable collectors → assemble JSON inputs
│   ├── submit <file>            # Validate an evidence record and submit it to the ledger
│   ├── list [repo]              # List evidence records for a repository
│   └── show <id>                # Show a specific evidence record
│
├── assess                       # Compliance assessment
│   ├── run                      # Generate a full assessment report for this repository
│   ├── show [id]                # Show an existing assessment report
│   └── diff <id1> <id2>         # Compare two assessment reports (delta view)
│
├── waiver                       # Waiver management
│   ├── list [repo]              # List active waivers for a repository
│   ├── show <id>                # Show a waiver record
│   └── check <id>              # Check validity and expiry of a waiver
│
├── report                       # Visibility and reporting
│   ├── coverage                 # Standards → controls coverage map (which controls satisfy which standards)
│   ├── status [repo]            # Full compliance posture for a repository
│   ├── drift                    # Controls with no binding or no policy (governance gaps)
│   └── profile <id>             # All controls mandated by a profile, with gate placement
│
├── registry                     # Browse governance objects (read-only, offline)
│   ├── list standards           # All registered standards in 01-sources/registry/
│   ├── list controls [domain]   # Controls, optionally filtered by domain (SEC, QUA, etc.)
│   ├── list profiles            # All profiles with applicable_to and parent
│   ├── list bindings [context]  # Bindings, optionally filtered by technology context
│   ├── list domains             # All control domains from taxonomy
│   ├── list contexts            # All technology contexts from taxonomy
│   ├── list repo-types          # All repository types from taxonomy
│   └── show <id>                # Any governance object by ID
│
└── config                       # forge configuration
    ├── init                     # Initialize ~/.forge/config.yaml interactively
    └── show                     # Print current effective configuration
```

---

## 3. Go package architecture

```
tools/forge/
├── main.go                      # Entry point — registers root command, runs cobra
├── go.mod                       # module: github.com/ashuangiras/platform-compliance/forge
├── go.sum
│
├── cmd/                         # Cobra command definitions (thin — delegate to pkg/)
│   ├── root.go                  # Root command, persistent flags (--compliance-ref, --verbose)
│   ├── new/
│   │   ├── new.go               # `forge new` parent command
│   │   ├── repo.go              # `forge new repo`
│   │   ├── control.go           # `forge new control`
│   │   ├── binding.go
│   │   ├── profile.go
│   │   ├── mapping.go
│   │   ├── standard.go
│   │   ├── adr.go
│   │   ├── waiver.go
│   │   ├── service_contract.go
│   │   └── change_record.go
│   ├── validate/
│   │   ├── validate.go
│   │   ├── file.go
│   │   ├── repo.go
│   │   └── manifest.go
│   ├── check/
│   │   ├── check.go
│   │   ├── policy.go
│   │   ├── control.go
│   │   └── all.go
│   ├── gate/
│   │   ├── gate.go
│   │   ├── merge.go
│   │   ├── deploy.go
│   │   └── release.go
│   ├── evidence/
│   │   ├── evidence.go
│   │   ├── collect.go
│   │   ├── submit.go
│   │   ├── list.go
│   │   └── show.go
│   ├── assess/
│   │   ├── assess.go
│   │   ├── run.go
│   │   ├── show.go
│   │   └── diff.go
│   ├── waiver/
│   ├── report/
│   ├── registry/
│   └── config/
│
└── pkg/                         # Core business logic (independently testable)
    │
    ├── compliance/              # platform-compliance repo reader and in-memory registry
    │   ├── loader.go            # Fetch + cache a compliance ref (GitHub API or local path)
    │   ├── registry.go          # In-memory registry: controls, profiles, schemas, taxonomies
    │   ├── resolver.go          # Profile inheritance resolution (PROF-GO-SERVICE-V1 → PROF-SERVICE-V1 → PROF-BASE)
    │   └── cache.go             # ~/.forge/cache/<ref>/ — avoids repeated API calls
    │
    ├── schema/                  # JSON Schema validation
    │   ├── validator.go         # Validate YAML/JSON against a schema
    │   ├── resolver.go          # Autodiscover schema from $schema field or file path pattern
    │   └── registry.go          # Schema name → file mapping (all 16 schemas)
    │
    ├── manifest/                # .compliance-manifest.yaml operations
    │   ├── reader.go            # Parse and validate a manifest
    │   ├── writer.go            # Render a manifest from profile + contexts + waiver_ids
    │   └── validator.go         # Deep validation: profile exists, contexts registered, waivers valid
    │
    ├── github/                  # GitHub API client
    │   ├── client.go            # Authenticated client (token from config or GITHUB_TOKEN env)
    │   ├── repo.go              # CreateRepo, SetTopics, GetRepo
    │   ├── protection.go        # SetBranchProtection, GetBranchProtection
    │   ├── pr.go                # CreatePR, ListPRFiles, GetPRBody
    │   ├── status.go            # PostStatus (Compliance Merge Gate)
    │   ├── settings.go          # SetSecuritySettings, GetActionsPermissions
    │   └── contents.go          # GetFile, CreateFile, UpdateFile (initial commits)
    │
    ├── opa/                     # OPA policy evaluation
    │   ├── engine.go            # Embedded OPA Go library OR subprocess to opa binary
    │   ├── collector.go         # Invoke collect-*.sh scripts → JSON input files
    │   ├── evaluator.go         # Evaluate a single policy → PolicyResult{result, reason, details}
    │   └── runner.go            # POLICY_MAP-aware: run all applicable policies for a repo
    │
    ├── gate/                    # Gate evaluation
    │   ├── criteria.go          # Load gate criteria from deployment-gate.yaml / release-gate.yaml
    │   ├── evaluator.go         # Evaluate all gate controls → GateResult{pass, blocking, warn}
    │   └── formatter.go         # Render gate result table to terminal
    │
    ├── evidence/                # Evidence record assembly and management
    │   ├── assembler.go         # Collect OPA results → evidence record (schema-conformant YAML)
    │   ├── hasher.go            # SHA-256 artifact_hash for evidence records
    │   ├── submitter.go         # Validate + write evidence record to ledger path
    │   └── ledger.go            # List, read, query evidence records from 08-evidence/collected/
    │
    ├── assessment/              # Assessment generation
    │   ├── generator.go         # Assemble evidence → assessment report YAML
    │   ├── waiver_applier.go    # Apply waivers from manifest → adjust assessment results
    │   └── differ.go            # Delta between two assessment reports
    │
    ├── waiver/                  # Waiver lifecycle
    │   ├── checker.go           # Validate a waiver record against its schema
    │   ├── expiry.go            # Check expiry date, warn if within 30 days
    │   └── registry.go          # Load waivers from 09-assessments/waivers/
    │
    ├── scaffold/                # Template rendering for new governance objects
    │   ├── renderer.go          # Go text/template engine
    │   ├── id_allocator.go      # Next control ID, next ADR ID, next CHG record
    │   └── templates/           # Embedded templates (go:embed)
    │       ├── control.yaml.tmpl
    │       ├── binding.yaml.tmpl
    │       ├── profile.yaml.tmpl
    │       ├── mapping-collection.yaml.tmpl
    │       ├── standard-source.yaml.tmpl
    │       ├── adr.md.tmpl
    │       ├── waiver.yaml.tmpl
    │       ├── service-contract.yaml.tmpl
    │       ├── change-record.yaml.tmpl
    │       └── repo/            # Repo bootstrap templates
    │           ├── compliance-manifest.yaml.tmpl
    │           ├── CODEOWNERS.tmpl
    │           ├── pull_request_template.md.tmpl
    │           ├── vscode-settings.json.tmpl  (agent discovery)
    │           └── agents/      # Full agent operating layer (from platform-compliance)
    │               ├── compliance-router.agent.md
    │               ├── control-author.agent.md
    │               └── ...      (copied verbatim from compliance ref)
    │
    ├── report/                  # Report generation
    │   ├── coverage.go          # Standards → controls coverage (which controls satisfy SRC-*)
    │   ├── status.go            # Full posture: profile controls + evidence + gate status
    │   ├── drift.go             # Controls with no binding OR no policy (unimplemented controls)
    │   └── profile.go           # Expand a profile → all controls with domain + enforcement
    │
    ├── taxonomy/                # Taxonomy operations
    │   ├── reader.go            # Load 02-taxonomy/*.yaml into typed structs
    │   └── validator.go         # Validate domain/context/repo-type references
    │
    └── config/                  # forge configuration model
        ├── config.go            # Config struct + merge (global → per-repo → flags)
        ├── loader.go            # Load ~/.forge/config.yaml and .forge.yaml
        └── initializer.go      # Interactive config init
```

---

## 4. Configuration model

### Global config (`~/.forge/config.yaml`)

```yaml
github_token: ""              # Falls back to GITHUB_TOKEN env var
default_org: "ashuangiras"
default_profile: "PROF-SERVICE-V1"
default_repo_type: "service"
compliance_ref: "v2.4.0"     # Which platform-compliance tag to use
opa_binary: ""                # Path to opa binary; empty = use embedded Go library
cache_dir: "~/.forge/cache"
editor: ""                    # Falls back to $EDITOR
```

### Per-repo config (`.forge.yaml` at repo root)

```yaml
compliance_ref: "v2.4.0"
profile: "PROF-SERVICE-V1"
repo_type: "service"
technology_contexts:
  - github
  - go
```

### Precedence (lowest → highest)

```
global ~/.forge/config.yaml
  ↓ overridden by
.forge.yaml in current directory
  ↓ overridden by
CLI flags (--compliance-ref, --profile, etc.)
  ↓ overridden by
FORGE_* environment variables
```

---

## 5. Key data flows

### `forge new repo <name>`

```
1. Load config (org, compliance_ref, default_profile)
2. Fetch compliance ref from GitHub (cached in ~/.forge/cache/v2.4.0/)
3. Interactive prompts (if not flagged):
   - Repository type? [service, library, terraform-module, ...]
   - Technology contexts? [github, go, node, ...]
   - Profile? (auto-suggested from repo type + contexts)
   - Include agent operating layer? [Y/n]
4. Render templates:
   - .compliance-manifest.yaml  (profile, type, contexts, compliance_ref)
   - CODEOWNERS
   - .github/pull_request_template.md
   - .forge.yaml
   - .vscode/settings.json  (if --with-agents)
   - .github/agents/*.agent.md  (if --with-agents, copied from compliance ref)
5. GitHub API:
   - POST /repos → create repository
   - POST /repos/{owner}/{repo}/contents → commit each file
   - PUT  /repos/{owner}/{repo}/branches/main/protection → require PR + Compliance Merge Gate
6. Print:
   ✓ Created ashuangiras/<name>
   ✓ .compliance-manifest.yaml committed (PROF-SERVICE-V1, compliance_ref: v2.4.0)
   ✓ Branch protection enabled (requires PR, Compliance: Merge Gate)
   ✓ Agent operating layer installed (.github/agents/)
   
   Next: open a PR to trigger the first compliance workflow run.
```

### `forge check all`

```
1. Load .compliance-manifest.yaml from cwd
2. Fetch applicable policies from compliance ref:
   - Expand declared_profiles → all mandated control IDs via profile inheritance
   - Filter POLICY_MAP by technology_contexts
3. Run each applicable collector:
   - collect-github-branch-protection.sh → github-branch-protection.json
   - collect-go-info.sh → go-info.json
   - collect-workflow-actions.sh → workflow-actions.json
   - ... (only collectors for active contexts)
4. For each policy: opa eval -d <policy>.rego -i <input>.json '<pkg>.result'
5. Print results table:
   ✓ SRC-001  pass    Branch protection enforced
   ✓ QUA-001  pass    golangci-lint clean
   ✗ TST-002  fail    Coverage 58% — below 70% threshold
   ⚠ OBS-004  warn    OpenTelemetry SDK not found in go.sum
   ○ NET-001  n/a     Not a deployed service
6. Exit 1 if any blocking failures
```

### `forge gate release`

```
1. Load release-gate.yaml from compliance ref (09-assessments/gates/release-gate.yaml)
2. Load latest assessment report for this repository (or run forge assess run first)
3. For each control in release_gate.required_controls:
   - Find latest evidence record for this control + repository
   - Check result: pass → ok; fail + enforcement:block → gate blocks
   - Check waivers: if control has active waiver, apply waiver to result
4. Print gate table:
   Required controls: 23   Passing: 21   Blocked: 1   Waived: 1   Warn: 0

   ✗ BLOCKED: DOC-001  fail  README missing (no waiver)

   Gate: FAIL — 1 blocking control must pass before release
5. Exit 1 if gate fails
```

### `forge validate repo`

```
1. Find all YAML files in cwd (recursively)
2. For each file with a $schema field:
   - Identify schema from $schema path (e.g. ../schemas/control.schema.json)
   - Load schema from compliance ref cache (not local — ensures correct version)
   - Run check-jsonschema validation
3. Validate .compliance-manifest.yaml referential integrity:
   - declared_profiles → profiles exist in compliance ref
   - technology_contexts → registered in compliance ref taxonomy
   - waiver_ids → waiver files exist in 09-assessments/waivers/
4. Print file-by-file results
```

---

## 6. Integration points

### GitHub API

Used by: `forge new repo`, `forge check` (PR context), `forge gate` (evidence fetch)

- Authentication: `GITHUB_TOKEN` env var or `github_token` in `~/.forge/config.yaml`
- Rate limiting: cached responses for read operations (TTL: 5 minutes)
- Required scopes: `repo` (create repos, push files, set branch protection)

### OPA evaluation

Two modes, selected at build time or by config:

**Mode A — embedded** (`github.com/open-policy-agent/opa` Go package)
- Self-contained, no external binary needed
- Larger binary size (~30 MB)
- Preferred for distribution

**Mode B — subprocess** (external `opa` binary)
- Smaller forge binary
- Requires `opa` on PATH or configured via `opa_binary`
- Used in development / CI where `opa` is already present

### Input collectors

`forge check` and `forge evidence collect` invoke the same shell collectors from the compliance
ref (`07-policies/scripts/collect-*.sh`). The collectors are fetched from the compliance ref
cache and executed as subprocesses.

Context → collector mapping (derived from `run-all-policies.py` POLICY_MAP):

| Context | Collector |
|---------|-----------|
| `github` | `collect-github-branch-protection.sh`, `collect-github-security-settings.sh` |
| `github-actions` | `collect-workflow-actions.sh` |
| `docker` | `collect-dockerfile-info.sh` |
| `terraform` | `collect-terraform-info.sh` |
| `go` | `collect-go-info.sh` |
| `node` | `collect-node-info.sh` |
| `python` | `collect-python-info.sh` |
| `frontend` | `collect-frontend-info.sh` |
| `agent` | `collect-agent-info.py` |

### Compliance ref cache

Compliance objects are fetched from a `platform-compliance` tag once and cached:

```
~/.forge/cache/
└── v2.4.0/
    ├── schemas/          # 16 schema files
    ├── 02-taxonomy/      # taxonomy YAML files
    ├── 03-catalogs/      # all control YAML files
    ├── 04-profiles/      # all profile YAML files
    ├── 05-mappings/      # mapping collections
    ├── 06-bindings/      # binding files
    ├── 07-policies/      # opa/ tree + scripts/
    ├── 09-assessments/   # gates/
    └── manifest.json     # cache metadata (fetched_at, ref, sha)
```

`forge` fetches the compliance ref using the GitHub API (archive download) or locally if
`--compliance-dir <path>` is passed. The local path option allows testing against a local
checkout of `platform-compliance`.

---

## 7. Output format

All commands support `--output` / `-o`:

| Flag | Description |
|------|-------------|
| (default) | Human-readable, coloured terminal output |
| `--output json` | Machine-readable JSON (for CI integration) |
| `--output yaml` | YAML (for piping to forge validate) |
| `--quiet` / `-q` | Suppress all output except errors + final verdict |
| `--verbose` / `-v` | Full detail including OPA evaluation traces |

Exit codes:
- `0` — success / all gates pass
- `1` — validation error / gate failure / policy failure
- `2` — configuration error (missing token, unknown profile, etc.)
- `3` — network / API error

---

## 8. Implementation phases

### Phase B.1 — Foundation (MVP for `forge validate`)

**Scope:** offline validation — no API calls, no OPA

| Package | Deliverable |
|---------|-------------|
| `pkg/compliance` | `loader.go` (local path), `registry.go`, `resolver.go` |
| `pkg/schema` | `validator.go`, `resolver.go` |
| `pkg/manifest` | `reader.go`, `validator.go` |
| `pkg/taxonomy` | `reader.go`, `validator.go` |
| `pkg/config` | `config.go`, `loader.go` |
| `cmd/validate` | `file.go`, `repo.go`, `manifest.go` |

**Commands available after B.1:** `forge validate <file>`, `forge validate repo`, `forge config show`

**Test coverage:** unit tests for each pkg; fixture tests using existing `schemas/fixtures/`

---

### Phase B.2 — Repo bootstrapping (`forge new repo`) **[unlocks Phase C]**

**Scope:** GitHub API + template rendering

| Package | Deliverable |
|---------|-------------|
| `pkg/github` | full client |
| `pkg/scaffold` | `renderer.go`, `id_allocator.go`, all `templates/repo/` |
| `pkg/compliance` | extend `loader.go` with GitHub API fetch + cache |
| `cmd/new` | `repo.go` |

**Commands available after B.2:** `forge new repo`

**Phase C can start** once `forge new repo` works:
- `forge new repo platform-modules --profile PROF-TERRAFORM-MODULE-V1`
- `forge new repo platform-infrastructure --profile PROF-TERRAFORM-ROOT-V1`
- `forge new repo platform-services --profile PROF-SERVICE-V1 --with-agents`

---

### Phase B.3 — Policy execution (`forge check`, `forge gate`)

**Scope:** OPA evaluation + collector invocation

| Package | Deliverable |
|---------|-------------|
| `pkg/opa` | `engine.go` (embedded), `collector.go`, `evaluator.go`, `runner.go` |
| `pkg/gate` | `criteria.go`, `evaluator.go`, `formatter.go` |
| `cmd/check` | all subcommands |
| `cmd/gate` | all subcommands |

**Commands available after B.3:** `forge check all`, `forge check policy <id>`, `forge gate merge|deploy|release`

---

### Phase B.4 — Evidence and assessment (`forge evidence`, `forge assess`)

**Scope:** evidence record assembly, assessment generation

| Package | Deliverable |
|---------|-------------|
| `pkg/evidence` | full package |
| `pkg/assessment` | full package |
| `pkg/waiver` | full package |
| `cmd/evidence` | all subcommands |
| `cmd/assess` | all subcommands |
| `cmd/waiver` | all subcommands |

**Commands available after B.4:** `forge evidence collect|submit|list`, `forge assess run|show|diff`, `forge waiver list|show|check`

---

### Phase B.5 — Authoring scaffolds (`forge new control|adr|waiver|...`)

**Scope:** scaffold templates for all governance object types

| Package | Deliverable |
|---------|-------------|
| `pkg/scaffold` | all non-repo templates, `id_allocator.go` |
| `cmd/new` | all non-repo subcommands |
| `cmd/config` | `init.go` |

**Commands available after B.5:** full `forge new` suite

---

### Phase B.6 — Registry and reporting (`forge registry`, `forge report`)

**Scope:** read-only browsing and reporting

| Package | Deliverable |
|---------|-------------|
| `pkg/report` | full package |
| `cmd/registry` | all subcommands |
| `cmd/report` | all subcommands |

**Commands available after B.6:** full `forge registry` and `forge report` suite — v1.0.0 complete

---

## 9. Release pipeline integration

Each `platform-compliance` release tag triggers `release.yml` which is extended to:

1. Build `forge` binaries for all targets:
   ```yaml
   - name: Build forge binaries
     run: |
       cd tools/forge
       GOOS=linux  GOARCH=amd64  go build -ldflags="-X main.Version=${{ github.ref_name }}" -o forge_Linux_x86_64
       GOOS=darwin GOARCH=amd64  go build -ldflags="-X main.Version=${{ github.ref_name }}" -o forge_Darwin_x86_64
       GOOS=darwin GOARCH=arm64  go build -ldflags="-X main.Version=${{ github.ref_name }}" -o forge_Darwin_arm64
       sha256sum forge_* > forge_checksums.txt
   ```
2. Attach all four files to the GitHub release alongside `policies.tar.gz`

The `--version` flag in forge reads the embedded version string baked in at build time.

---

## 10. Testing strategy

| Layer | What is tested | How |
|-------|---------------|-----|
| `pkg/schema` | Schema validation correctness | Unit tests using `schemas/fixtures/` YAML pairs |
| `pkg/compliance` | Registry loading, profile inheritance | Unit tests with local compliance dir |
| `pkg/opa` | Policy evaluation | Reuse `07-policies/tests/fixtures/` YAML fixtures |
| `pkg/gate` | Gate evaluation logic | Unit tests with mock evidence records |
| `pkg/github` | API calls | Mock HTTP server in tests; real integration test in CI |
| `cmd/*` | CLI flag parsing, output format | Table-driven tests with golden files |
| End-to-end | `forge new repo` + `forge check all` + `forge gate merge` | CI job with real `GITHUB_TOKEN`, creates a test repo, runs checks, deletes repo on teardown |
