# ADR-0004: OPA/Rego is the primary policy engine

| Field | Value |
|---|---|
| **ID** | ADR-0004 |
| **Status** | accepted |
| **Date** | 2026-07-08 |
| **Deciders** | platform-team |

---

## Context

Phase 7 of the roadmap requires a policy-as-code engine that can:
1. Evaluate structured inputs (GitHub API responses, Terraform files, Dockerfiles) against compliance rules
2. Produce structured JSON output suitable for ingestion into the evidence record schema
3. Be unit-tested with fixtures without requiring live infrastructure
4. Be versioned alongside the rest of the compliance system
5. Be executable in CI without complex runtime dependencies

We evaluated the following options:

**Option A — OPA/Rego (via `opa` CLI or `conftest`)**  
- Declarative language; policies express intent rather than procedure
- Structured JSON input and output natively
- `opa test` for unit testing with fixtures; no live services required
- `conftest` wrapper provides easy YAML/JSON file validation in CI
- Widely used in the cloud-native ecosystem; well-documented
- Single binary; no runtime dependency beyond the `opa` or `conftest` binary
- Packages provide clear namespacing: `package platform.src.src_001_github`

**Option B — Shell scripts**  
- No new toolchain; any CI runner executes shell natively
- Flexible enough for any check
- Difficult to unit test in isolation; requires mocking or live API
- Output format must be manually structured; easy to produce inconsistent evidence
- No language-level guarantees about determinism
- Appropriate as a secondary engine for checks that OPA cannot express (e.g., raw GitHub API calls that feed OPA input)

**Option C — Conftest as primary (without direct OPA)**  
- `conftest` wraps OPA; same Rego language
- Slightly simpler CLI for CI use (`conftest test`)
- Less flexibility than direct OPA for complex evaluation patterns
- The distinction between OPA and Conftest is operational, not architectural; both use Rego

**Option D — Terraform/OpenTofu built-in checks**  
- Native to Terraform; no new toolchain for IAC checks
- Only applicable to IAC domain controls
- Cannot evaluate GitHub repository settings, Dockerfiles, or evidence schemas
- Insufficient scope for the platform's full control set

---

## Decision

**We adopt OPA/Rego as the primary policy engine, with shell scripts as the secondary engine.**

- All compliance policy checks that can be expressed as declarative rules against structured input are implemented as OPA/Rego policies in `07-policies/opa/`
- Shell scripts are used exclusively for checks that require native CLI tools, live API calls, or file-system operations that cannot be easily modelled as OPA input (e.g., running `terraform fmt`, executing `git log`, or calling the GitHub REST API to collect input for an OPA policy)
- Shell scripts that call OPA are valid: a shell wrapper collects raw data, formats it as JSON, and passes it to `opa eval` for the rule evaluation
- `conftest` may be used as a CI-friendly alternative to direct `opa eval` where simpler CLI invocation is beneficial

**Package naming convention:** `package platform.{domain_lower}.{control_id_snake_case}_{context_lower}`

Example: SRC-001 in GitHub context → `package platform.src.src_001_github`

---

## Consequences

**Positive:**

- Policies are declarative and testable with `opa test` against JSON fixtures without any live system
- Structured output (JSON) maps directly to the evidence record schema's `details` field
- The `opa` binary is a single static binary; no runtime dependency management in CI
- Policies can be bundled and version-pinned as a tarball distributed with each `platform-compliance` release
- Separation between data collection (shell scripts, GitHub API calls) and rule evaluation (Rego) creates a clean architecture: the shell layer produces input JSON; the Rego layer evaluates it

**Negative / trade-offs:**

- Rego requires learning a new language (though it is purpose-built for this use case and not complex for simple checks)
- OPA is a runtime dependency in CI; consuming repositories must install it
- Complex structural checks (e.g., parsing HCL or Dockerfile ASTs) may require preprocessing into structured input before OPA can evaluate them

**Constraints introduced:**

- All new automated controls must have an OPA Rego policy as their primary implementation
- Shell scripts may not contain rule logic — they are data collection only
- Every policy file must produce output in the documented contract format (see `07-policies/opa/README.md`)
- Policy package names must follow the naming convention; deviations break the CI discovery logic
- OPA version is pinned in `07-policies/opa/README.md` and must be updated explicitly

---

## Relation to platform principles

This ADR implements Platform Principle P3 (compliance is machine-verifiable by default). OPA policies are the primary mechanism by which compliance checks are automated and testable.

The shell-script secondary engine is a pragmatic concession to the reality that some data collection requires native tooling. It is explicitly bounded: data collection only, no rule logic.
