# ADR-0013 Proposal — Compliance Dashboard Architecture

**Priority:** 🟡 MEDIUM  
**Blocks:** Phase D (compliance visibility at scale)

---

## The decision

How is compliance state made visible across all governed repositories?

---

## The problem

Once three or more repositories are governed, manually reading assessment reports to understand the platform's compliance posture becomes impractical. Someone needs to be able to ask "What is the current compliance state of the whole platform?" and get an answer in under 30 seconds.

---

## Options

### Option A — Generated static report (simplest)

A GitHub Actions scheduled workflow runs daily, reads all assessment reports in all governed repositories (via GitHub API), aggregates them, and publishes a generated HTML/Markdown report to GitHub Pages or a `compliance-reports` branch.

**Pros:** Zero additional infrastructure. Works with the distributed evidence model (Option B from ADR-0006). No new services to operate.

**Cons:** Only as current as the last scheduled run. Not real-time. Requires read access to all governed repositories.

**Best for:** v1.1.0 to v2.0.0 range with < 20 repositories.

### Option B — Grafana dashboard backed by a time-series database

A Grafana instance and a time-series database (Prometheus, VictoriaMetrics) collect compliance metrics from CI runs. The compliance workflow pushes metrics as part of the evidence collection step.

**Pros:** Real-time. Historical trends. Visual drill-down per repository and control.

**Cons:** Requires additional infrastructure (Grafana + TSDB) before the compliance data justifies the overhead. This infrastructure must itself be governed — circular dependency.

**Best for:** v2.0.0+ when the platform has operational maturity.

### Option C — `plt report` CLI command (no web interface)

The `plt` CLI includes commands for querying compliance state:
```bash
plt report status               # all repos, current posture
plt report history repo-name    # one repo over time
plt report failing              # all controls currently failing across all repos
```

This is a terminal-based dashboard, not a web one.

**Pros:** No infrastructure. Uses the distributed evidence model directly. Available as soon as Phase B delivers the CLI.

**Cons:** Not persistent. Not shareable. Doesn't serve non-technical stakeholders.

---

## Recommendation

**Phase B/C:** Option C (`plt report`) as the first dashboard — free, immediate, available as soon as the CLI exists.

**Phase C/D:** Option A (generated static report) as the second layer — a generated summary published to GitHub Pages gives a shareable, persistent view.

**Phase D:** Option B (Grafana) only when the platform is running its own observability stack and can host the infrastructure without creating a bootstrapping problem.

---

## What to decide
1. Confirm the three-phase progression above
2. For Option A: where is the static report published? (GitHub Pages, dedicated branch, GitHub Actions artifact)
3. For Option C: what is the minimum set of metrics the `plt report status` command shows? (Suggested: per-repo: overall_result, failing_controls count, waiver count, last assessment date)
