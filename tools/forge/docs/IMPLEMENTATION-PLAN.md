# forge — Implementation Plan

**Phase:** B.1 through B.6  
**Architecture reference:** [../../docs/forge-architecture.md](../../docs/forge-architecture.md)  
**Module:** `github.com/ashuangiras/platform-compliance/forge`  
**Go:** 1.26+  
**Status:** pre-implementation

---

## Quick-start for implementers

```bash
cd tools/forge
go build ./...                # confirm module compiles
go test ./...                 # run all tests
go run . --help               # smoke-test the CLI
```

All dependency packages are already pinned in `go.mod`. Key dependencies:

| Package | Purpose |
|---------|---------|
| `github.com/spf13/cobra` | CLI framework |
| `github.com/spf13/viper` | Configuration loading |
| `gopkg.in/yaml.v3` | YAML parsing |
| `github.com/santhosh-tekuri/jsonschema/v5` | JSON Schema validation (offline, no CGO) |
| `github.com/open-policy-agent/opa` | Embedded OPA evaluation |

---

## Phase B.1 — Foundation: `forge validate`

**Goal:** Validate any governance YAML file against its schema. Offline. No API. No OPA.  
**Acceptance criteria:**
- `forge validate schemas/control.schema.json` fails with a clear message
- `forge validate 03-catalogs/controls/SEC/SEC-001.yaml` passes against the schema from `--compliance-dir`
- `forge validate-repo .` validates all governance objects in a directory tree
- Exit 0 = all valid; exit 1 = any failure; exit 2 = config error

---

### B.1.1 — `pkg/config`

**Files:**
- `pkg/config/config.go`
- `pkg/config/loader.go`

**Types to define:**

```go
// config.go
package config

type Config struct {
    GitHubToken    string `mapstructure:"github_token" yaml:"github_token"`
    DefaultOrg     string `mapstructure:"default_org" yaml:"default_org"`
    DefaultProfile string `mapstructure:"default_profile" yaml:"default_profile"`
    ComplianceRef  string `mapstructure:"compliance_ref" yaml:"compliance_ref"`
    ComplianceDir  string `mapstructure:"compliance_dir" yaml:"compliance_dir"` // local override
    OPABinary      string `mapstructure:"opa_binary" yaml:"opa_binary"`
    CacheDir       string `mapstructure:"cache_dir" yaml:"cache_dir"`
    Editor         string `mapstructure:"editor" yaml:"editor"`
}

// Default returns a Config with sensible defaults.
func Default() *Config

// Merge merges src into dst, with dst taking precedence.
func Merge(dst, src *Config) *Config
```

```go
// loader.go
package config

// Load loads the effective config from:
//   1. ~/.forge/config.yaml  (global)
//   2. .forge.yaml           (per-repo, in cwd or any parent)
//   3. Environment vars      (FORGE_GITHUB_TOKEN, FORGE_COMPLIANCE_REF, etc.)
// Later sources override earlier ones. Flags are applied after Load().
func Load() (*Config, error)

// GlobalConfigPath returns the path to ~/.forge/config.yaml.
func GlobalConfigPath() string

// RepoConfigPath walks up from dir looking for .forge.yaml.
func RepoConfigPath(dir string) (string, bool)
```

**Tests:** `pkg/config/config_test.go` — table-driven tests for merge precedence and default values.

---

### B.1.2 — `pkg/taxonomy`

**Files:**
- `pkg/taxonomy/reader.go`
- `pkg/taxonomy/types.go`

**Types:**

```go
// types.go
package taxonomy

type Taxonomy struct {
    ControlDomains      map[string]Domain      // from control-domains.yaml
    TechnologyContexts  map[string]Context     // from technology-contexts.yaml
    RepositoryTypes     map[string]RepoType    // from repository-types.yaml
    EnforcementLevels   []string               // from enforcement-levels.yaml
    ControlTypes        []string               // from control-types.yaml
    RiskLevels          []string               // from risk-levels.yaml
    AutomationStatuses  []string               // from automation-status.yaml
}

type Domain struct {
    Name        string   `yaml:"name"`
    Description string   `yaml:"description"`
}

type Context struct {
    Name        string   `yaml:"name"`
    Description string   `yaml:"description"`
}

type RepoType struct {
    Description        string   `yaml:"description"`
    ApplicableProfiles []string `yaml:"applicable_profiles"`
    ImpliedDomains     []string `yaml:"implied_domains"`
}
```

```go
// reader.go
package taxonomy

// Load reads all taxonomy files from a compliance directory.
func Load(complianceDir string) (*Taxonomy, error)

// IsValidDomain returns true if the domain code exists in the taxonomy.
func (t *Taxonomy) IsValidDomain(code string) bool

// IsValidContext returns true if the context exists in the taxonomy.
func (t *Taxonomy) IsValidContext(ctx string) bool

// IsValidRepoType returns true if the repo type exists in the taxonomy.
func (t *Taxonomy) IsValidRepoType(rt string) bool
```

**Tests:** `pkg/taxonomy/reader_test.go` — load from `testdata/02-taxonomy/` (copy of real taxonomy files).

---

### B.1.3 — `pkg/schema`

**Files:**
- `pkg/schema/registry.go`
- `pkg/schema/validator.go`

**Schema name → file mapping** (all 16 schemas):

```go
// registry.go
package schema

// KnownSchemas maps the base filename (without .schema.json) to the relative
// path from the compliance root.
var KnownSchemas = map[string]string{
    "adr":                    "schemas/adr.schema.json",
    "assessment":             "schemas/assessment.schema.json",
    "binding":                "schemas/binding.schema.json",
    "change-record":          "schemas/change-record.schema.json",
    "control":                "schemas/control.schema.json",
    "evidence":               "schemas/evidence.schema.json",
    "incident-record":        "schemas/incident-record.schema.json",
    "mapping-collection":     "schemas/mapping-collection.schema.json",
    "mapping":                "schemas/mapping.schema.json",
    "policy-check":           "schemas/policy-check.schema.json",
    "profile":                "schemas/profile.schema.json",
    "release-record":         "schemas/release-record.schema.json",
    "repository-compliance":  "schemas/repository-compliance.schema.json",
    "service-contract":       "schemas/service-contract.schema.json",
    "standard-source":        "schemas/standard-source.schema.json",
    "waiver":                 "schemas/waiver.schema.json",
}

// InferSchema attempts to determine the schema for a file from:
//   1. The $schema field in the file's YAML
//   2. The file path pattern (e.g. 03-catalogs/controls/ → control)
func InferSchema(filePath string, content []byte) (string, bool)
```

```go
// validator.go
package schema

import "github.com/santhosh-tekuri/jsonschema/v5"

type ValidationResult struct {
    File   string
    Schema string
    Valid   bool
    Errors  []string
}

// Validate validates content against the named schema loaded from complianceDir.
func Validate(complianceDir, schemaName string, content []byte) (*ValidationResult, error)

// ValidateFile validates a file, inferring the schema automatically.
func ValidateFile(complianceDir, filePath string) (*ValidationResult, error)

// ValidateDir walks dir and validates every YAML file that has a detectable schema.
// Files without a detectable schema are skipped (reported, not errored).
func ValidateDir(complianceDir, dir string) ([]*ValidationResult, error)
```

**Tests:** `pkg/schema/validator_test.go`
- Load real schemas from `../../../../schemas/`
- Load real control files from `../../../../03-catalogs/` as valid fixtures
- Craft deliberately invalid YAML for error cases
- Test `InferSchema` for all 16 schema types by file path pattern

---

### B.1.4 — `pkg/manifest`

**Files:**
- `pkg/manifest/types.go`
- `pkg/manifest/reader.go`
- `pkg/manifest/validator.go`

```go
// types.go
package manifest

type Manifest struct {
    SchemaVersion string     `yaml:"schema_version"`
    Repository    Repository `yaml:"repository"`
    DeclaredProfiles    []string `yaml:"declared_profiles"`
    TechnologyContexts  []string `yaml:"technology_contexts"`
    WaiverIDs           []string `yaml:"waiver_ids"`
}

type Repository struct {
    Name               string `yaml:"name"`
    URL                string `yaml:"url"`
    Type               string `yaml:"type"`
    HasContainerImages bool   `yaml:"has_container_images"`
}
```

```go
// reader.go
package manifest

// Read parses a .compliance-manifest.yaml file.
func Read(path string) (*Manifest, error)

// Find searches for .compliance-manifest.yaml in dir and parent directories.
func Find(dir string) (string, error)
```

```go
// validator.go
package manifest

// ValidationResult holds the outcome of a manifest deep validation.
type ValidationResult struct {
    SchemaValid       bool
    ProfilesValid     bool
    ContextsValid     bool
    UnknownProfiles   []string
    UnknownContexts   []string
    ExpiredWaivers    []string
    Errors            []string
    Warnings          []string
}

// Validate performs deep validation:
//   - Schema validation against repository-compliance.schema.json
//   - Profile IDs exist in complianceDir/04-profiles/
//   - Technology contexts registered in taxonomy
//   - Waiver IDs have corresponding files
func Validate(complianceDir, manifestPath string, tax *taxonomy.Taxonomy) (*ValidationResult, error)
```

**Tests:** `pkg/manifest/reader_test.go`, `pkg/manifest/validator_test.go`
- Copy of real `.compliance-manifest.yaml` as valid fixture
- Missing profile, unknown context, expired waiver as error fixtures

---

### B.1.5 — `pkg/compliance` (loader for local path only)

**Files:**
- `pkg/compliance/loader.go`
- `pkg/compliance/registry.go`
- `pkg/compliance/resolver.go`

```go
// loader.go
package compliance

// ComplianceDir represents a loaded compliance root (local or cached remote).
type ComplianceDir struct {
    Root     string            // absolute path to the compliance root
    Ref      string            // version tag or "local"
    Taxonomy *taxonomy.Taxonomy
    Schemas  map[string]string // schema name → absolute path
}

// LoadLocal loads a compliance root from a local directory path.
// This is the only mode required for Phase B.1.
func LoadLocal(dir string) (*ComplianceDir, error)

// ProfilePath returns the absolute path to a profile YAML file.
func (c *ComplianceDir) ProfilePath(id string) (string, bool)

// SchemaPath returns the absolute path to a named schema.
func (c *ComplianceDir) SchemaPath(name string) (string, bool)
```

```go
// resolver.go
package compliance

// Profile represents a loaded and inheritance-resolved profile.
type Profile struct {
    ID              string
    InheritsID      string
    ApplicableTo    []string
    MandatoryControls []string // flattened from all ancestors
    GateControls    map[string][]string // gate name → control IDs
}

// ResolveProfile loads a profile and fully resolves its inheritance chain.
// PROF-GO-SERVICE-V1 → PROF-SERVICE-V1 → PROF-BASE → (empty parent)
func ResolveProfile(c *ComplianceDir, profileID string) (*Profile, error)
```

**Tests:** `pkg/compliance/loader_test.go` — use `../../../../` as the compliance root; resolve PROF-GO-SERVICE-V1 and assert inherited controls are present.

---

### B.1.6 — `cmd/validate` and `cmd/root`

```go
// cmd/root.go
var (
    complianceDir string
    complianceRef string
    outputFormat  string
    verbose       bool
    quiet         bool
)

// rootCmd is the top-level cobra command.
// Persistent flags: --compliance-dir, --compliance-ref, --output, --verbose, --quiet
```

```go
// cmd/validate/file.go
// forge validate <file>
// Infers schema from $schema field or file path. Prints result. Exits 0/1.

// cmd/validate/repo.go
// forge validate repo [path]
// Walks path (default: cwd) and validates all detectable YAML files.
// Prints a summary table.

// cmd/validate/manifest.go
// forge validate manifest [path]
// Validates .compliance-manifest.yaml including deep referential checks.
```

**Output format (default terminal):**
```
Validating 03-catalogs/controls/SEC/SEC-009.yaml (schema: control) ... ✓
Validating 04-profiles/PROF-FRONTEND-V1.yaml (schema: profile) ... ✓
Validating 06-bindings/bindings/frontend/BIND-SEC-009-FRONTEND.yaml (schema: binding) ... ✗

  BIND-SEC-009-FRONTEND.yaml
  └─ Additional property 'unknown_field' is not allowed

1 error in 3 files.
```

**Phase B.1 deliverable checklist:**
- [ ] `go build ./...` — clean compile
- [ ] `go test ./pkg/config/...` — pass
- [ ] `go test ./pkg/schema/...` — pass (validates real governance objects)
- [ ] `go test ./pkg/manifest/...` — pass
- [ ] `go test ./pkg/compliance/...` — pass
- [ ] `forge validate 03-catalogs/controls/SEC/SEC-001.yaml` — outputs pass
- [ ] `forge validate-repo .` — validates all YAML in this repo (with `--compliance-dir .`)
- [ ] `forge validate manifest .compliance-manifest.yaml` — outputs pass

---

## Phase B.2 — `forge new repo` [unlocks Phase C]

**Goal:** Create a fully governed repository on GitHub in one command.  
**New dependencies:** `github.com/google/go-github/v60` (GitHub API client)  
**Acceptance criteria:**
- `forge new repo test-governed-repo --profile PROF-SERVICE-V1 --org ashuangiras --dry-run` prints all files that would be created
- `forge new repo test-governed-repo --profile PROF-SERVICE-V1 --org ashuangiras` creates the repo, commits files, sets branch protection
- Created repo has `.compliance-manifest.yaml`, `CODEOWNERS`, `.github/pull_request_template.md`
- `--with-agents` also commits `.github/agents/*.agent.md` and `.vscode/settings.json`
- `forge new repo` with no flags drops into interactive mode

---

### B.2.1 — `pkg/github`

```go
// client.go
package github

type Client struct {
    gh  *gogithub.Client
    org string
}

// New creates an authenticated GitHub client from a token.
func New(token, defaultOrg string) *Client

// FromEnv creates a client using GITHUB_TOKEN env var.
func FromEnv(defaultOrg string) (*Client, error)
```

```go
// repo.go
package github

type CreateRepoOptions struct {
    Name        string
    Org         string
    Description string
    Private     bool
    AutoInit    bool // create with initial empty commit
}

type RepoInfo struct {
    FullName    string
    HTMLURL     string
    CloneURL    string
    DefaultBranch string
}

func (c *Client) CreateRepo(ctx context.Context, opts CreateRepoOptions) (*RepoInfo, error)
func (c *Client) GetRepo(ctx context.Context, owner, name string) (*RepoInfo, error)
func (c *Client) RepoExists(ctx context.Context, owner, name string) (bool, error)
```

```go
// protection.go
package github

// SetMergeGateProtection configures the branch protection that forge sets on
// every new repository: require PR + the "Compliance: Merge Gate" status check.
func (c *Client) SetMergeGateProtection(ctx context.Context, owner, repo, branch string) error

// SetStrictProtection restores full protection (review_count=1, require_code_owner_reviews).
func (c *Client) SetStrictProtection(ctx context.Context, owner, repo, branch string) error

// RelaxProtection drops review_count to 0 for bootstrap-merge.
func (c *Client) RelaxProtection(ctx context.Context, owner, repo, branch string) error
```

```go
// contents.go
package github

// CommitFiles creates or updates multiple files in a single commit.
type FileToCommit struct {
    Path    string
    Content []byte
    Message string // used as commit message for the whole batch
}

func (c *Client) CommitFiles(ctx context.Context, owner, repo, branch string, files []FileToCommit, message string) error
```

---

### B.2.2 — `pkg/scaffold`

```go
// renderer.go
package scaffold

import "embed"

//go:embed templates
var templateFS embed.FS

type TemplateVars struct {
    // Repo-level
    RepoName        string
    RepoType        string
    OwnerOrg        string
    GitHubURL       string

    // Compliance
    ComplianceRef   string
    ComplianceOrg   string
    ProfileID       string
    TechContexts    []string

    // Dates
    Date            string // YYYY-MM-DD

    // Control authoring
    ControlID       string
    ControlDomain   string
    ControlTitle    string

    // ADR
    ADRID           string

    // Waiver
    WaiverID        string
    ControlIDForWaiver string
}

// RenderTemplate renders a named template with vars.
func RenderTemplate(name string, vars TemplateVars) ([]byte, error)

// RenderRepoFiles renders all files for a new repository.
// Returns a map of relative path → content.
func RenderRepoFiles(vars TemplateVars, withAgents bool, complianceDir string) (map[string][]byte, error)
```

**Templates to create** (`pkg/scaffold/templates/`):

| Template file | Output path in new repo |
|---------------|------------------------|
| `repo/compliance-manifest.yaml.tmpl` | `.compliance-manifest.yaml` |
| `repo/CODEOWNERS.tmpl` | `CODEOWNERS` |
| `repo/pull_request_template.md.tmpl` | `.github/pull_request_template.md` |
| `repo/forge-yaml.tmpl` | `.forge.yaml` |
| `repo/vscode-settings.json.tmpl` | `.vscode/settings.json` |
| `control.yaml.tmpl` | `03-catalogs/controls/<DOMAIN>/<ID>.yaml` |
| `binding.yaml.tmpl` | `06-bindings/bindings/<ctx>/<ID>.yaml` |
| `profile.yaml.tmpl` | `04-profiles/<ID>.yaml` |
| `adr.md.tmpl` | `decisions/ADR-<ID>-<slug>.md` |
| `waiver.yaml.tmpl` | `09-assessments/waivers/<ID>.yaml` |
| `standard-source.yaml.tmpl` | `01-sources/registry/<ID>.yaml` |
| `service-contract.yaml.tmpl` | `service-contract.yaml` |
| `change-record.yaml.tmpl` | `09-assessments/changes/<ID>.yaml` |

---

### B.2.3 — `cmd/new/repo.go`

```go
// Flags:
//   --org          GitHub org (default: from config)
//   --profile      Compliance profile ID (default: PROF-SERVICE-V1)
//   --type         Repository type (default: service)
//   --contexts     Comma-separated technology contexts
//   --with-agents  Include agent operating layer
//   --private      Create as private repository
//   --dry-run      Print files without creating

// Interactive mode (when --profile and --type are not set):
//   1. Select repository type from taxonomy list
//   2. Suggest profile based on type (can override)
//   3. Select technology contexts (multi-select from taxonomy)
//   4. Confirm: include agent operating layer? [Y/n]
//   5. Confirm settings before creating
```

**Phase B.2 deliverable checklist:**
- [ ] `forge new repo my-svc --dry-run --compliance-dir . --profile PROF-SERVICE-V1` — prints all 4 files without touching GitHub
- [ ] `forge new repo my-svc --compliance-dir . --profile PROF-SERVICE-V1` — creates real repo with correct files
- [ ] `forge new repo my-svc --with-agents` — commits `.github/agents/*.agent.md` and `.vscode/settings.json`
- [ ] Created repo branch protection requires PR + Compliance Merge Gate
- [ ] `forge new repo` (no flags) — interactive mode works

---

## Phase B.3 — `forge check` and `forge gate`

**Goal:** Run OPA policies locally, evaluate gates.  
**New dependencies:** OPA already in `go.mod` (embedded mode)  
**Acceptance criteria:**
- `forge check all --compliance-dir .` runs all applicable policies for this repo and exits 0
- `forge check policy SRC-001 --compliance-dir .` runs one policy and prints result
- `forge gate merge --compliance-dir .` evaluates the merge gate and exits 0 (all passing)

---

### B.3.1 — `pkg/opa`

```go
// engine.go
package opa

import (
    "github.com/open-policy-agent/opa/rego"
)

type Engine struct {
    policyDir string // path to 07-policies/opa/ in compliance dir
}

func NewEngine(policyDir string) *Engine

// EvalPolicy evaluates a single .rego file against input JSON.
// Returns PolicyResult with result, reason, details.
func (e *Engine) EvalPolicy(ctx context.Context, regoPath string, input map[string]any) (*PolicyResult, error)

type PolicyResult struct {
    Result  string            // "pass" | "fail" | "warn" | "not_applicable" | "error"
    Reason  string
    Details map[string]any
}
```

```go
// collector.go
package opa

// CollectorResult holds the JSON output of a single collector script.
type CollectorResult struct {
    Context  string         // e.g. "go"
    File     string         // e.g. "go-info.json"
    Data     map[string]any // parsed JSON
}

// RunCollector executes a collect-*.sh script and returns its JSON output.
// scriptsDir is the path to 07-policies/scripts/ in the compliance dir.
func RunCollector(ctx context.Context, scriptsDir, scriptName string, env []string) (*CollectorResult, error)

// RunApplicableCollectors runs all collectors for the given technology contexts.
func RunApplicableCollectors(ctx context.Context, scriptsDir string, contexts []string) (map[string]*CollectorResult, error)
```

```go
// runner.go
package opa

// POLICY_MAP_ENTRY describes one entry in the policy engine's map.
// Loaded from run-all-policies.py's POLICY_MAP via parsing (or a companion JSON).
type PolicyMapEntry struct {
    PolicyID    string
    RegoFile    string
    InputFile   string
    QueryPath   string
    Contexts    []string
}

// LoadPolicyMap parses run-all-policies.py and extracts the POLICY_MAP.
// Returns all entries applicable for the given contexts.
func LoadPolicyMap(scriptsDir string, contexts []string) ([]PolicyMapEntry, error)

// RunAll runs all applicable policies for the given contexts and inputs.
func RunAll(ctx context.Context, engine *Engine, entries []PolicyMapEntry, inputs map[string]*CollectorResult) ([]*PolicyRun, error)

type PolicyRun struct {
    Entry   PolicyMapEntry
    Result  *PolicyResult
    Error   error
}
```

---

### B.3.2 — `pkg/gate`

```go
// criteria.go
package gate

type GateType string
const (
    GateMerge   GateType = "merge"
    GateDeploy  GateType = "deploy"
    GateRelease GateType = "release"
)

type GateCriteria struct {
    Type             GateType
    RequiredControls []GateControl
}

type GateControl struct {
    ControlID   string
    Enforcement string // "block" | "warn"
}

// Load reads the gate criteria file from the compliance dir.
// e.g. 09-assessments/gates/deployment-gate.yaml
func Load(complianceDir string, gateType GateType) (*GateCriteria, error)
```

```go
// evaluator.go
package gate

type GateResult struct {
    Gate     GateType
    Pass     bool
    Blocking []ControlResult
    Warning  []ControlResult
    Passing  []ControlResult
    NA       []ControlResult
}

type ControlResult struct {
    ControlID string
    Result    string
    Reason    string
}

// Evaluate runs all gate controls and returns the gate result.
func Evaluate(ctx context.Context, criteria *GateCriteria, policyRuns []*opa.PolicyRun) *GateResult
```

**Phase B.3 deliverable checklist:**
- [ ] `forge check all --compliance-dir .` — runs all policies, prints table, exits 0
- [ ] `forge check policy SRC-001 --compliance-dir .` — runs one policy, prints result
- [ ] `forge gate merge --compliance-dir .` — evaluates merge gate, exits 0
- [ ] `forge gate merge --output json` — outputs machine-readable JSON
- [ ] Exit 1 when any blocking control fails

---

## Phase B.4 — `forge evidence` and `forge assess`

**Goal:** Collect evidence records, generate assessment reports.  
**Acceptance criteria:**
- `forge evidence collect --compliance-dir .` runs collectors and writes JSON inputs to `./forge-evidence/`
- `forge evidence submit evidence.yaml` validates and writes to `08-evidence/collected/<repo>/`
- `forge assess run --compliance-dir .` generates a schema-valid assessment YAML

---

### B.4.1 — `pkg/evidence`

```go
// assembler.go
package evidence

// EvidenceRecord represents a schema-valid evidence record.
// Conforms to schemas/evidence.schema.json
type EvidenceRecord struct {
    ID            string            `yaml:"id"`
    ControlID     string            `yaml:"control_id"`
    PolicyCheckID string            `yaml:"policy_check_id"`
    Repository    string            `yaml:"repository"`
    CommitSHA     string            `yaml:"commit_sha"`
    CollectedAt   string            `yaml:"collected_at"`
    CollectedBy   string            `yaml:"collected_by"`
    Result        string            `yaml:"result"`
    Reason        string            `yaml:"reason"`
    ArtifactHash  string            `yaml:"artifact_hash"` // SHA-256 of input JSON
    Details       map[string]any    `yaml:"details,omitempty"`
}

// Assemble creates an EvidenceRecord from a policy run result.
func Assemble(run *opa.PolicyRun, repo, commitSHA string) (*EvidenceRecord, error)

// AssembleAll creates evidence records for all policy runs.
func AssembleAll(runs []*opa.PolicyRun, repo, commitSHA string) ([]*EvidenceRecord, error)
```

```go
// submitter.go
package evidence

// Submit validates and writes an evidence record to the ledger directory.
func Submit(complianceDir string, record *EvidenceRecord) (string, error)
```

---

### B.4.2 — `pkg/assessment`

```go
// generator.go
package assessment

// AssessmentReport conforms to schemas/assessment.schema.json
type AssessmentReport struct {
    ID              string                `yaml:"id"`
    Repository      string                `yaml:"repository"`
    Profile         string                `yaml:"profile"`
    AssessedAt      string                `yaml:"assessed_at"`
    ComplianceRef   string                `yaml:"compliance_ref"`
    Controls        []ControlAssessment   `yaml:"controls"`
    OverallResult   string                `yaml:"overall_result"` // "pass" | "fail" | "partial"
}

type ControlAssessment struct {
    ControlID     string `yaml:"control_id"`
    Result        string `yaml:"result"`
    EvidenceID    string `yaml:"evidence_id,omitempty"`
    WaiverID      string `yaml:"waiver_id,omitempty"`
    Reason        string `yaml:"reason,omitempty"`
}

// Generate assembles an assessment report from evidence records and waivers.
func Generate(profile *compliance.Profile, evidence []*evidence.EvidenceRecord, waivers []*waiver.Waiver) (*AssessmentReport, error)
```

**Phase B.4 deliverable checklist:**
- [ ] `forge evidence collect --compliance-dir .` — writes JSON inputs to `./forge-evidence/`
- [ ] `forge evidence submit ./forge-evidence/SRC-001-evidence.yaml` — validates + writes to ledger
- [ ] `forge assess run --compliance-dir .` — generates assessment YAML that validates against `schemas/assessment.schema.json`
- [ ] `forge assess show ASSESS-<id>` — prints a formatted assessment

---

## Phase B.5 — `forge new` authoring scaffolds

**Goal:** Scaffold any governance object from a template.  
**Acceptance criteria:**
- `forge new control` — interactive, produces a valid control YAML with correct ID (e.g. `SEC-012`)
- `forge new adr` — produces the next sequential ADR file
- `forge new waiver` — produces a schema-valid waiver with correct ID format

---

### B.5.1 — `pkg/scaffold/id_allocator.go`

```go
// id_allocator.go
package scaffold

// NextControlID scans existing control files in a domain directory and returns
// the next unused ID. E.g. SEC-009 exists → returns "SEC-010".
func NextControlID(complianceDir, domain string) (string, error)

// NextADRID scans existing ADRs in decisions/ and returns the next formatted ID.
// E.g. ADR-0018 exists → returns "ADR-0019".
func NextADRID(complianceDir string) (string, error)

// NextChangeRecord generates the next CHG-YYYYMMDD-NNN for today's date.
// Scans 09-assessments/changes/ to find the last used NNN for today.
func NextChangeRecord(complianceDir string) (string, error)

// NextWaiverID generates a formatted waiver ID: WAV-<CONTROLID>-<YYYYMM>-<NNN>
func NextWaiverID(complianceDir, controlID string) (string, error)
```

---

### B.5.2 — Interactive prompts

All `forge new <type>` commands use interactive prompts when required fields are not provided
via flags. Use `github.com/charmbracelet/huh` or stdlib `bufio.Scanner` for prompts.

Interaction pattern for `forge new control`:
```
Domain? [SEC/QUA/TST/...] > SEC
Next available ID: SEC-012
Title? > Container images must be signed before deployment
Type? [preventive/detective/corrective] > preventive
Enforcement? [block/warn] > block
Technology context? [docker/github/...] > docker
Standard source? (optional) > SRC-COSIGN
Creating: 03-catalogs/controls/SEC/SEC-012.yaml ... ✓
```

**Phase B.5 deliverable checklist:**
- [ ] `forge new control --domain SEC --title "..." --type preventive` — non-interactive
- [ ] `forge new control` — interactive mode
- [ ] `forge new adr --title "..."` — creates next ADR file
- [ ] `forge new waiver --control SEC-001 --reason "..." --expiry 2026-10-07`
- [ ] All outputs are schema-valid

---

## Phase B.6 — `forge registry` and `forge report`

**Goal:** Read-only browsing and reporting of the compliance system.  
**Acceptance criteria:**
- `forge registry list controls --domain SEC` — lists all SEC controls with title and enforcement
- `forge registry show SEC-001` — prints the full control YAML with colour
- `forge report coverage` — table showing standards → controls coverage
- `forge report drift --compliance-dir .` — controls with no binding or no policy

---

### B.6.1 — `pkg/report`

```go
// coverage.go
package report

// CoverageEntry maps a standard to the controls that implement it.
type CoverageEntry struct {
    StandardID  string
    StandardName string
    Controls    []string
    MappedVia   []string // mapping collection IDs
}

// Coverage computes the standards → controls coverage map.
func Coverage(complianceDir string) ([]CoverageEntry, error)
```

```go
// drift.go
package report

// DriftEntry represents a control that is missing a binding or policy.
type DriftEntry struct {
    ControlID   string
    Domain      string
    MissingWhat []string // "binding", "policy", "collector"
}

// Drift finds controls with no binding or no OPA policy.
func Drift(complianceDir string) ([]DriftEntry, error)
```

**Phase B.6 deliverable checklist:**
- [ ] `forge registry list controls` — all controls, sorted by domain + ID
- [ ] `forge registry list profiles` — all profiles with parent and applicable_to
- [ ] `forge registry show PROF-SERVICE-V1` — full profile with resolved inherited controls
- [ ] `forge report coverage --compliance-dir .` — coverage table
- [ ] `forge report drift --compliance-dir .` — zero drift in this repo (or correct list)
- [ ] `forge report status --compliance-dir . --repo ashuangiras/platform-compliance` — full posture

---

## Cross-cutting concerns

### Error handling convention

```go
// All pkg/ functions return (result, error).
// Errors are wrapped with context using fmt.Errorf("pkg/schema: %w", err).
// cmd/ layer translates errors to exit codes and user messages.
// Never os.Exit() from pkg/ — only from cmd/.
```

### Output formatting

All commands that produce tabular output use a shared `internal/output` package:

```go
// internal/output/table.go
package output

// PrintTable renders a table to stdout or JSON to stdout.
type Column struct{ Header string; Key string }
func PrintTable(columns []Column, rows []map[string]string, format string)

// PrintResult prints a single pass/fail result with colour.
func PrintResult(label, result, reason string, format string)
```

### Logging

Use `log/slog` (stdlib, Go 1.21+). Structured JSON logging when `--output json`. Coloured text when TTY.

### Version embedding

```go
// main.go
var (
    Version = "dev"    // set by -ldflags at build time
    Commit  = "none"
    Date    = "unknown"
)
```

---

## File creation order (strict dependency sequence)

```
1.  tools/forge/go.mod + go.sum          ← already done
2.  tools/forge/main.go                  ← entry point
3.  cmd/root.go                          ← persistent flags
4.  pkg/config/                          ← no deps
5.  pkg/taxonomy/                        ← no deps
6.  pkg/schema/                          ← no deps
7.  pkg/manifest/                        ← depends on schema, taxonomy
8.  pkg/compliance/                      ← depends on schema, taxonomy, manifest
9.  cmd/validate/                        ← depends on pkg/schema, manifest, compliance
10. pkg/scaffold/id_allocator.go         ← depends on compliance
11. pkg/scaffold/templates/              ← static files
12. pkg/scaffold/renderer.go             ← depends on templates
13. pkg/github/                          ← no local deps
14. cmd/new/repo.go                      ← depends on github, scaffold, compliance
15. pkg/opa/engine.go                    ← embedded opa dep
16. pkg/opa/collector.go                 ← shell subprocess
17. pkg/opa/runner.go                    ← depends on engine, collector
18. pkg/gate/                            ← depends on opa
19. cmd/check/ + cmd/gate/               ← depends on opa, gate, compliance
20. pkg/evidence/ + pkg/waiver/          ← depends on opa, compliance
21. pkg/assessment/                      ← depends on evidence, waiver
22. cmd/evidence/ + cmd/assess/ + cmd/waiver/
23. cmd/new/ (non-repo subcommands)      ← depends on scaffold, compliance
24. pkg/report/                          ← depends on compliance
25. cmd/registry/ + cmd/report/          ← depends on report, compliance
```

---

## Makefile targets

```makefile
# tools/forge/Makefile
.PHONY: build test lint clean install

VERSION ?= $(shell git describe --tags --always --dirty)
LDFLAGS  = -X main.Version=$(VERSION) -X main.Commit=$(shell git rev-parse --short HEAD)

build:
	go build -ldflags "$(LDFLAGS)" -o bin/forge .

test:
	go test -race ./...

test-integration:
	FORGE_INTEGRATION=1 go test -race -tags=integration ./...

lint:
	golangci-lint run ./...

clean:
	rm -rf bin/

install: build
	cp bin/forge /usr/local/bin/forge

# Cross-platform builds for release
release-binaries:
	GOOS=linux  GOARCH=amd64  go build -ldflags "$(LDFLAGS)" -o dist/forge_Linux_x86_64 .
	GOOS=darwin GOARCH=amd64  go build -ldflags "$(LDFLAGS)" -o dist/forge_Darwin_x86_64 .
	GOOS=darwin GOARCH=arm64  go build -ldflags "$(LDFLAGS)" -o dist/forge_Darwin_arm64 .
	cd dist && sha256sum forge_* > forge_checksums.txt
```

---

## First PR target (Phase B.1 complete)

After Phase B.1 is implemented, open a PR with:
- `tools/forge/` containing all B.1 code + tests
- `go test ./...` green in CI (add a `forge-ci.yml` workflow to `.github/workflows/`)
- `forge validate-repo . --compliance-dir .` runs cleanly on this repo in CI

This becomes the first downstream usage of `forge` validating `platform-compliance` itself.
