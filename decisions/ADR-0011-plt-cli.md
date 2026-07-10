# ADR-0011: `plt` CLI — Go, pre-built binaries, separate repository

| Field | Value |
|---|---|
| **ID** | ADR-0011 |
| **Status** | superseded by ADR-0018 |
| **Date** | 2026-07-10 |
| **Deciders** | platform-team |

---

## Context

The `plt` platform CLI is the developer-facing interface to the compliance system. Engineers use
it locally to validate files, scaffold new governance objects, and evaluate gate posture without
reading raw YAML or running OPA directly. Phase B of the implementation roadmap depends on this
decision before work can start.

The full proposal and options analysis are recorded in
`docs/implementation/decisions-needed/ADR-0011-plt-cli.md`.

Three technology options were evaluated:
- **Option A — Go**: static binary, no runtime dependency, excellent CLI frameworks
- **Option B — Python**: already in use in the workflow, faster iteration but requires Python
- **Option C — Shell scripts**: zero dependency but unmaintainable at scale (~15 commands)

---

## Decision

### 1. Language: Go

Go produces a single static binary per target platform with no runtime dependency for users.
The compliance system is a long-lived, professional tool; Go's type system catches schema
validation logic errors at compile time in a way Python and shell cannot guarantee. The Go
toolchain is only needed by contributors to `platform-plt`, not by users of the CLI.

The existing workflow Python scripts handle operational (CI) tasks. Go handles the user-facing
CLI. These concerns are complementary, not competing.

### 2. Distribution: pre-built binaries via GitHub Releases

Each tagged release of `platform-plt` attaches pre-built binaries for:
- `linux/amd64`
- `darwin/amd64`
- `darwin/arm64`

Installation is a single command:
```bash
curl -sSfL https://github.com/ashuangiras/platform-plt/releases/latest/download/plt_$(uname -s)_$(uname -m) \
  -o plt && chmod +x plt
```

A SHA-256 checksum file accompanies each binary. A Homebrew tap may be added in a future
release but is not required for v1.0.0 of the CLI.

### 3. Repository location: separate `platform-plt` repository

`plt` lives in its own repository (`ashuangiras/platform-plt`), not in `tools/plt/` of this
repo. Rationale:
- Independent release cadence — CLI improvements do not force a new `platform-compliance` tag
- Cleaner contributor experience — Go module boundaries, own CI, own issue tracker
- `platform-compliance` stays a governance/data repository; `platform-plt` is a tooling
  repository; separation of concerns matches ADR-0003 (no implementation before controls)
- The `tools/plt/` stub directory can hold a pointer README linking to `platform-plt`

---

## Implementation plan (Phase B)

The first command is `plt validate <file>` — validates a file against its JSON Schema. This
command validates the CLI architecture before investing in the full command set.

Full command set (v1.0.0 target):
- `plt validate <file>` — validate YAML against schema
- `plt validate-repo [path]` — validate manifest + profile coverage
- `plt new control|adr|waiver` — scaffold from template
- `plt gate check release|deploy [repo]` — evaluate gate from evidence
- `plt evidence submit <file>` — validate and submit evidence
- `plt report coverage|status [repo]` — compliance posture reporting

---

## Consequences

- `platform-plt` repository must be created under `ashuangiras/` with PROF-SERVICE-V1 profile
  and the agent operating layer from day one (governed repository)
- `platform-compliance` release workflow remains unchanged (it already packages `policies.tar.gz`)
- `tools/plt/README.md` in this repo points to `ashuangiras/platform-plt`
- ADR-0003 constraint: the CLI is implemented after controls govern it (the profile exists)
