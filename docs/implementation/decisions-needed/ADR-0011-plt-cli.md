# ADR-0011 Proposal — `plt` CLI Technology Selection

**Priority:** 🟡 MEDIUM  
**Blocks:** Phase B implementation start

---

## The decision

Which programming language and distribution model for the `plt` platform CLI?

---

## Requirements

The `plt` CLI must:
- Run on macOS (arm64, amd64) and Linux (amd64) with zero runtime installation
- Read YAML files and validate against JSON Schema
- Make simple HTTP calls (GitHub API) for the `gate check` commands
- Install with a single command (no package manager dependency for the basic case)
- Be fast enough to use locally in a pre-commit hook (< 2 seconds for `plt validate`)

---

## Options

### Option A — Go

**Pros:**
- Single static binary per platform — zero runtime dependency
- First-class YAML and JSON Schema libraries (`gopkg.in/yaml.v3`, `github.com/xeipuuv/gojsonschema`)
- Excellent CLI framework (`cobra` + `viper`)
- Cross-compilation to all targets from one machine
- Strong type safety catches schema bugs at compile time

**Cons:**
- Go compilation adds toolchain dependency for contributors
- Build artefacts must be pre-built and distributed (or users must install Go)

**Distribution:** `curl -sSfL .../plt_{os}_{arch} -o plt && chmod +x plt`

### Option B — Python

**Pros:**
- Already in use in the reusable workflow (evidence assembly Python scripts)
- Rich YAML/JSON Schema libraries (`pyyaml`, `jsonschema`, `check-jsonschema`)
- Faster iteration for small teams
- No separate compilation step

**Cons:**
- Requires Python 3.10+ installation — not zero-dependency
- `pyinstaller` or `cx_Freeze` for single-binary distribution adds complexity
- Slower startup time than Go for simple operations

**Distribution:** `pip install plt-platform` (requires Python) or `pyinstaller` binary

### Option C — Shell scripts

**Pros:**
- Zero dependency — runs anywhere with bash, curl, yq
- Simplest implementation path

**Cons:**
- No static typing — schema validation errors are harder to produce clearly
- JSON Schema validation requires `check-jsonschema` as an external dependency
- Maintenance and testing are significantly harder than a typed language
- Not suitable for a tool that will grow to ~15 commands

---

## Recommendation

**Option A (Go)**

Reasoning:
- The compliance system is a long-lived, professional tool. Go's static binary distribution removes all friction for users — `curl` and done.
- The toolchain (Go compiler) is only needed by contributors, not users.
- The existing workflow Python scripts handle operational tasks; Go handles the user-facing CLI.
- Go's type system makes schema validation logic correct by construction in a way that Python and shell cannot guarantee.

**Start:** Write `plt validate` first (validates a file against its schema). This is the most-used command and validates the CLI architecture before investing in other commands.

---

## What to decide
1. Go, Python, or Shell?
2. Distribution model: pre-built binaries via GitHub releases, or package manager (homebrew tap, pip)?
3. Repository location: in `tools/plt/` of this repo (current) or a separate `platform-plt` repo?
