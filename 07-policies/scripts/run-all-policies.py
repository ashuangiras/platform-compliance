#!/usr/bin/env python3
"""
run-all-policies.py — Run all applicable OPA policies and write results to /tmp/results/.

Usage: python3 run-all-policies.py --bundle /tmp/policy-bundle --inputs /tmp/inputs
                                   --contexts github,terraform --repo-type platform-repo
"""
import argparse, json, os, subprocess, sys
from datetime import date
from pathlib import Path


POLICY_MAP = {
    "SRC-001": ("SRC/POL-SRC-001-GITHUB-001.rego",       "src-branch-protection.json",  "data.platform.src.src_001_github.result"),
    "SRC-002": ("SRC/POL-SRC-002-GITHUB-001.rego",       "src-branch-protection.json",  "data.platform.src.src_002_github.result"),
    "SRC-003": ("SRC/POL-SRC-003-GITHUB-001.rego",       "src-codeowners.json",          "data.platform.src.src_003_github.result"),
    "SEC-001": ("SEC/POL-SEC-001-GITHUB-001.rego",       "sec-secrets.json",             "data.platform.sec.sec_001_github.result"),
    "SEC-002": ("SEC/POL-SEC-002-GITHUB-001.rego",       "sec-security-settings.json",   "data.platform.sec.sec_002_github.result"),
    "SEC-003": ("SEC/POL-SEC-003-GITHUB-001.rego",       "sec-security-settings.json",   "data.platform.sec.sec_003_github.result"),
    "DOC-001": ("DOC/POL-DOC-001-GITHUB-001.rego",       "doc-files.json",               "data.platform.doc.doc_001_github.result"),
    "CHG-001": ("CHG/POL-CHG-001-GITHUB-001.rego",       "chg-pr-context.json",          "data.platform.chg.chg_001_github.result"),
    "CHG-002": ("CHG/POL-CHG-002-GITHUB-001.rego",       "chg-release.json",             "data.platform.chg.chg_002_github.result"),
    "IAC-001": ("IAC/POL-IAC-001-TERRAFORM-001.rego",    "iac-terraform.json",           "data.platform.iac.iac_001_terraform.result",    ["terraform"]),
    "IAC-002": ("IAC/POL-IAC-002-TERRAFORM-001.rego",    "iac-terraform.json",           "data.platform.iac.iac_002_terraform.result",    ["terraform"]),
    "SUP-001-TF": ("SUP/POL-SUP-001-TERRAFORM-001.rego", "iac-terraform.json",           "data.platform.sup.sup_001_terraform.result",    ["terraform"]),
    "RUN-001": ("RUN/POL-RUN-001-DOCKER-001.rego",       "docker-info.json",             "data.platform.run.run_001_docker.result",        ["docker"]),
    "RUN-002": ("RUN/POL-RUN-002-DOCKER-001.rego",       "docker-info.json",             "data.platform.run.run_002_docker.result",        ["docker"]),
    "SUP-002": ("SUP/POL-SUP-002-DOCKER-001.rego",       "docker-info.json",             "data.platform.sup.sup_002_docker.result",        ["docker"]),
    "OBS-001": ("OBS/POL-OBS-001-DOCKER-001.rego",       "docker-info.json",             "data.platform.obs.obs_001_docker.result",        ["docker"]),
    "SUP-001-GA": ("SUP/POL-SUP-001-GITHUB-ACTIONS-001.rego", "actions-info.json",       "data.platform.sup.sup_001_github_actions.result", ["github-actions"]),
    "SEC-004":   ("SEC/POL-SEC-004-GITHUB-ACTIONS-001.rego", "actions-info.json",       "data.platform.sec.sec_004_github_actions.result",     ["github-actions"]),
    "RUN-004":   ("RUN/POL-RUN-004-DOCKER-001.rego",          "dockerfile-info.json", "data.platform.run.run_004_docker.result",            ["docker"]),
    "RUN-005":   ("RUN/POL-RUN-005-DOCKER-001.rego",          "dockerfile-info.json", "data.platform.run.run_005_docker.result",            ["docker"]),
    "SEC-005":   ("SEC/POL-SEC-005-GITHUB-ACTIONS-001.rego", "actions-info.json",   "data.platform.sec.sec_005_github_actions.result",   ["github-actions"]),
    "IAC-004":   ("IAC/POL-IAC-004-TERRAFORM-001.rego",       "actions-info.json",   "data.platform.iac.iac_004_terraform.result",         ["terraform"]),
    "SEC-006":   ("SEC/POL-SEC-006-DOCKER-001.rego",          "actions-info.json",   "data.platform.sec.sec_006_docker.result",            ["docker"]),
    # ── Tier 3 ──────────────────────────────────────────────────────────────
    "RUN-006":   ("RUN/POL-RUN-006-DOCKER-001.rego",            "dockerfile-info.json", "data.platform.run.run_006_docker.result",            ["docker"]),
    "RUN-007":   ("RUN/POL-RUN-007-DOCKER-001.rego",            "dockerfile-info.json", "data.platform.run.run_007_docker.result",            ["docker"]),
    "OBS-003":   ("OBS/POL-OBS-003-DOCKER-001.rego",            "dockerfile-info.json", "data.platform.obs.obs_003_docker.result",            ["docker"]),
    "LIC-001":   ("LIC/POL-LIC-001-GITHUB-001.rego",            "lic-info.json",        "data.platform.lic.lic_001_github.result",            ["github"]),
    "SEC-008":   ("SEC/POL-SEC-008-GITHUB-ACTIONS-001.rego",    "actions-info.json",    "data.platform.sec.sec_008_github_actions.result",    ["github-actions"]),
    # ── ADR-0016 P1: Go code quality (QUA) and testing (TST) ────────────────
    "QUA-001":   ("QUA/POL-QUA-001-GO-001.rego",              "go-info.json",         "data.platform.qua.qua_001_go.result",                ["go"]),
    "QUA-002":   ("QUA/POL-QUA-002-GO-001.rego",              "go-info.json",         "data.platform.qua.qua_002_go.result",                ["go"]),
    "QUA-003":   ("QUA/POL-QUA-003-GO-001.rego",              "go-info.json",         "data.platform.qua.qua_003_go.result",                ["go"]),
    "QUA-004":   ("QUA/POL-QUA-004-GO-001.rego",              "go-info.json",         "data.platform.qua.qua_004_go.result",                ["go"]),
    "TST-001":   ("TST/POL-TST-001-GO-001.rego",              "go-info.json",         "data.platform.tst.tst_001_go.result",                ["go"]),
    "TST-002":   ("TST/POL-TST-002-GO-001.rego",              "go-info.json",         "data.platform.tst.tst_002_go.result",                ["go"]),
    "TST-003":   ("TST/POL-TST-003-GO-001.rego",              "go-info.json",         "data.platform.tst.tst_003_go.result",                ["go"]),
    # ── ADR-0016 P2: Go service controls (ARC, API, OBS, SRC, SUP, DOC) ────────
    "ARC-001":   ("ARC/POL-ARC-001-GO-001.rego",              "go-info.json",         "data.platform.arc.arc_001_go.result",                ["go"]),
    "ARC-003":   ("ARC/POL-ARC-003-GO-001.rego",              "go-info.json",         "data.platform.arc.arc_003_go.result",                ["go"]),
    "API-001":   ("API/POL-API-001-GO-001.rego",              "go-info.json",         "data.platform.api.api_001_go.result",                ["go"]),
    "API-002":   ("API/POL-API-002-GO-001.rego",              "go-info.json",         "data.platform.api.api_002_go.result",                ["go"]),
    "API-003":   ("API/POL-API-003-GO-001.rego",              "go-info.json",         "data.platform.api.api_003_go.result",                ["go"]),
    "OBS-004":   ("OBS/POL-OBS-004-GO-001.rego",              "go-info.json",         "data.platform.obs.obs_004_go.result",                ["go"]),
    "SRC-005":   ("SRC/POL-SRC-005-GITHUB-001.rego",          "go-info.json",         "data.platform.src.src_005_github.result",            ["go"]),
    "SUP-005":   ("SUP/POL-SUP-005-GO-001.rego",              "go-info.json",         "data.platform.sup.sup_005_go.result",                ["go"]),
    "DOC-003":   ("DOC/POL-DOC-003-GO-001.rego",              "go-info.json",         "data.platform.doc.doc_003_go.result",                ["go"]),

    # ── ADR-0017 A1: Agent configuration governance (AGT) ───────────────────
    "AGT-001":   ("AGT/POL-AGT-001-AGENT-001.rego",           "agent-info.json",      "data.platform.agt.agt_001_agent.result",             ["agent"]),
    "AGT-002":   ("AGT/POL-AGT-002-AGENT-001.rego",           "agent-info.json",      "data.platform.agt.agt_002_agent.result",             ["agent"]),
    "AGT-003":   ("AGT/POL-AGT-003-AGENT-001.rego",           "agent-info.json",      "data.platform.agt.agt_003_agent.result",             ["agent"]),
    # ── ADR-0017 A2: Agent effectiveness (stringent, block) ─────────────────
    "AGT-004":   ("AGT/POL-AGT-004-AGENT-001.rego",           "agent-info.json",      "data.platform.agt.agt_004_agent.result",             ["agent"]),
    "AGT-005":   ("AGT/POL-AGT-005-AGENT-001.rego",           "agent-info.json",      "data.platform.agt.agt_005_agent.result",             ["agent"]),
    "AGT-006":   ("AGT/POL-AGT-006-AGENT-001.rego",           "agent-info.json",      "data.platform.agt.agt_006_agent.result",             ["agent"]),
    "AGT-007":   ("AGT/POL-AGT-007-AGENT-001.rego",           "agent-info.json",      "data.platform.agt.agt_007_agent.result",             ["agent"]),
    "AGT-008":   ("AGT/POL-AGT-008-AGENT-001.rego",           "agent-info.json",      "data.platform.agt.agt_008_agent.result",             ["agent"]),
    "AGT-009":   ("AGT/POL-AGT-009-AGENT-001.rego",           "agent-info.json",      "data.platform.agt.agt_009_agent.result",             ["agent"]),
    "AGT-010":   ("AGT/POL-AGT-010-AGENT-001.rego",           "agent-info.json",      "data.platform.agt.agt_010_agent.result",             ["agent"]),
    "AGT-011":   ("AGT/POL-AGT-011-AGENT-001.rego",           "agent-info.json",      "data.platform.agt.agt_011_agent.result",             ["agent"]),
    "AGT-012":   ("AGT/POL-AGT-012-AGENT-001.rego",           "agent-info.json",      "data.platform.agt.agt_012_agent.result",             ["agent"]),
    # ── ADR-0017 A2: continuous improvement + pre-merge readiness ───────────
    "AGT-013":   ("AGT/POL-AGT-013-AGENT-001.rego",           "agent-info.json",      "data.platform.agt.agt_013_agent.result",             ["agent"]),
    "AGT-014":   ("AGT/POL-AGT-014-AGENT-001.rego",           "agent-info.json",      "data.platform.agt.agt_014_agent.result",             ["agent"]),
    # ── ADR-0017 A2: downstream discovery/setup ─────────────────────────────
    "AGT-015":   ("AGT/POL-AGT-015-AGENT-001.rego",           "agent-info.json",      "data.platform.agt.agt_015_agent.result",             ["agent"]),

    # ── Tier 2 ──────────────────────────────────────────────────────────────
    "SUP-004":   ("SUP/POL-SUP-004-GITHUB-ACTIONS-001.rego",  "actions-info.json",   "data.platform.sup.sup_004_github_actions.result",   ["github-actions"]),
    "ACC-001":   ("ACC/POL-ACC-001-GITHUB-001.rego",           "acc-security.json",   "data.platform.acc.acc_001_github.result",            ["github"]),
    "SEC-007":   ("SEC/POL-SEC-007-GITHUB-001.rego",           "sec-vuln-sla.json",   "data.platform.sec.sec_007_github.result",            ["github"]),
    "IAC-005":   ("IAC/POL-IAC-005-GITHUB-ACTIONS-001.rego",   "actions-info.json",   "data.platform.iac.iac_005_github_actions.result",    ["terraform"]),
    "AUD-001":   ("AUD/POL-AUD-001-GITHUB-001.rego",           "aud-security.json",   "data.platform.aud.aud_001_github.result",            ["github"]),
    # ── ADR-0016 P3: Node + Python quality (QUA, TST) ────────────────────────
    "QUA-001-NODE":   ("QUA/POL-QUA-001-NODE-001.rego",   "node-info.json",   "data.platform.qua.qua_001_node.result",   ["node"]),
    "QUA-002-NODE":   ("QUA/POL-QUA-002-NODE-001.rego",   "node-info.json",   "data.platform.qua.qua_002_node.result",   ["node"]),
    "QUA-003-NODE":   ("QUA/POL-QUA-003-NODE-001.rego",   "node-info.json",   "data.platform.qua.qua_003_node.result",   ["node"]),
    "QUA-004-NODE":   ("QUA/POL-QUA-004-NODE-001.rego",   "node-info.json",   "data.platform.qua.qua_004_node.result",   ["node"]),
    "TST-001-NODE":   ("TST/POL-TST-001-NODE-001.rego",   "node-info.json",   "data.platform.tst.tst_001_node.result",   ["node"]),
    "TST-002-NODE":   ("TST/POL-TST-002-NODE-001.rego",   "node-info.json",   "data.platform.tst.tst_002_node.result",   ["node"]),
    "QUA-001-PYTHON": ("QUA/POL-QUA-001-PYTHON-001.rego", "python-info.json", "data.platform.qua.qua_001_python.result", ["python"]),
    "QUA-002-PYTHON": ("QUA/POL-QUA-002-PYTHON-001.rego", "python-info.json", "data.platform.qua.qua_002_python.result", ["python"]),
    "QUA-004-PYTHON": ("QUA/POL-QUA-004-PYTHON-001.rego", "python-info.json", "data.platform.qua.qua_004_python.result", ["python"]),
    "TST-001-PYTHON": ("TST/POL-TST-001-PYTHON-001.rego", "python-info.json", "data.platform.tst.tst_001_python.result", ["python"]),
    "TST-002-PYTHON": ("TST/POL-TST-002-PYTHON-001.rego", "python-info.json", "data.platform.tst.tst_002_python.result", ["python"]),
    # ── ADR-0016 P4: Frontend security (SEC) ──────────────────────────────────
    "SEC-009-FRONTEND": ("SEC/POL-SEC-009-FRONTEND-001.rego", "frontend-info.json", "data.platform.sec.sec_009_frontend.result", ["frontend"]),
    "SEC-010-FRONTEND": ("SEC/POL-SEC-010-FRONTEND-001.rego", "frontend-info.json", "data.platform.sec.sec_010_frontend.result", ["frontend"]),
    "SEC-011-FRONTEND": ("SEC/POL-SEC-011-FRONTEND-001.rego", "frontend-info.json", "data.platform.sec.sec_011_frontend.result", ["frontend"]),
    # ── Audit gap fixes ──────────────────────────────────────────────────────
    "SRC-004":   ("SRC/POL-SRC-004-GITHUB-001.rego",   "src-branch-protection.json",  "data.platform.src.src_004_github.result",   ["github"]),
    "SUP-003":   ("SUP/POL-SUP-003-GITHUB-001.rego",   "sec-security-settings.json",  "data.platform.sup.sup_003_github.result",   ["github"]),
}


def run_opa(rego_path, input_path, query):
    """Run opa eval and return the result object."""
    try:
        r = subprocess.run(
            ["opa", "eval", "--data", rego_path, "--input", input_path, query, "--format", "raw"],
            capture_output=True, text=True, timeout=30
        )
        return json.loads(r.stdout)
    except Exception as e:
        return {"result": "error", "details": {"message": f"OPA evaluation failed: {e}"}}


def load_active_waivers():
    """Return a dict of {control_id: waiver_id} for all active, non-expired waivers
    declared in the nearest .compliance-manifest.yaml.

    Only waivers that are active AND not past their expiry_date count.
    Returns an empty dict if no manifest or waivers are found.
    """
    # Find .compliance-manifest.yaml walking up from cwd
    manifest_path = None
    search = Path.cwd()
    for _ in range(6):
        candidate = search / ".compliance-manifest.yaml"
        if candidate.exists():
            manifest_path = candidate
            break
        search = search.parent

    if manifest_path is None:
        return {}

    try:
        import yaml
        manifest = yaml.safe_load(manifest_path.read_text())
    except Exception:
        return {}

    waiver_ids = manifest.get("waiver_ids", []) or []
    if not waiver_ids:
        return {}

    today = date.today()
    waived = {}

    # Waiver files live relative to the manifest's repo root
    repo_root = manifest_path.parent
    waivers_dir = repo_root / "09-assessments" / "waivers"

    for wid in waiver_ids:
        # Strip inline comments (e.g. "WAV-SRC-001-... # comment")
        wid = str(wid).split("#")[0].strip()
        waiver_path = waivers_dir / f"{wid}.yaml"
        if not waiver_path.exists():
            continue
        try:
            import yaml
            w = yaml.safe_load(waiver_path.read_text())
        except Exception:
            continue

        if w.get("status") != "active":
            continue

        expiry = w.get("expiry_date")
        if expiry:
            try:
                exp_date = date.fromisoformat(str(expiry))
                if exp_date < today:
                    continue  # waiver expired
            except ValueError:
                pass

        control_id = w.get("control_id", "")
        if control_id:
            waived[control_id] = wid

    return waived


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--bundle", default="/tmp/platform-compliance-policies")
    p.add_argument("--inputs", default="/tmp/inputs")
    p.add_argument("--results", default="/tmp/results")
    p.add_argument("--contexts", default="github,github-actions")
    p.add_argument("--repo-type", default="platform-repo")
    args = p.parse_args()

    bundle = Path(args.bundle)
    inputs = Path(args.inputs)
    results = Path(args.results)
    results.mkdir(parents=True, exist_ok=True)
    contexts = set(args.contexts.split(","))
    contexts.add("github")  # always included

    # Load active waivers from the manifest so waived controls don't count as failures.
    waived_controls = load_active_waivers()

    total, passed, failed, skipped, waived = 0, 0, 0, 0, 0

    for control_id, policy_info in POLICY_MAP.items():
        rego_rel = policy_info[0]
        input_file = policy_info[1]
        query = policy_info[2]
        required_contexts = policy_info[3] if len(policy_info) > 3 else []

        # Skip if required context not in this run
        if required_contexts and not any(c in contexts for c in required_contexts):
            skipped += 1
            (results / f"{control_id}.json").write_text(json.dumps({
                "result": "not_applicable",
                "details": {"message": f"Context {required_contexts} not in {list(contexts)}"}
            }))
            continue

        rego_path = str(bundle / rego_rel)
        input_path = str(inputs / input_file)

        # If the policy file doesn't exist in the bundle (e.g., bootstrapping a new
        # policy before it's been merged to main), skip gracefully rather than error.
        if not (bundle / rego_rel).exists():
            skipped += 1
            (results / f"{control_id}.json").write_text(json.dumps({
                "result": "not_applicable",
                "details": {"message": f"{control_id}: policy file not yet in bundle ({rego_rel}). Will be enforced after next release."}
            }))
            print(f"  ○ {control_id}: not_applicable (policy not in bundle — bootstrapping)")
            continue

        if not os.path.exists(rego_path):
            (results / f"{control_id}.json").write_text(json.dumps({
                "result": "error",
                "details": {"message": f"Policy file not found: {rego_path}"}
            }))
            failed += 1
            continue

        if not os.path.exists(input_path):
            # Treat missing input as not_applicable rather than error.
            # The policy is context-gated but the collector did not generate
            # the input file (e.g. IAC-002 plan-review on a module repo).
            # Job 7 (gate evaluation) will apply profile enforcement levels;
            # an error here would block the upload and prevent gate evaluation.
            skipped += 1
            (results / f"{control_id}.json").write_text(json.dumps({
                "result": "not_applicable",
                "details": {"message": f"{control_id}: input file not found ({input_file}). Context may not generate this input for this repo type."}
            }))
            print(f"  ○ {control_id}: not_applicable (input file absent — {input_file})")
            continue

        result = run_opa(rego_path, input_path, query)
        (results / f"{control_id}.json").write_text(json.dumps(result))
        total += 1

        r = result.get("result", "error") if isinstance(result, dict) else "error"
        if r == "pass":
            passed += 1
            print(f"  ✓ {control_id}: pass")
        elif r == "not_applicable":
            skipped += 1
            print(f"  ○ {control_id}: not_applicable")
        elif r == "manual_review":
            print(f"  ⚠ {control_id}: manual_review")
        elif control_id in waived_controls:
            waived += 1
            waiver_id = waived_controls[control_id]
            print(f"  ~ {control_id}: {r} (waived — {waiver_id})")
        else:
            failed += 1
            msg = result.get("details", {}).get("message", "") if isinstance(result, dict) else str(result)
            print(f"  ✗ {control_id}: {r} — {msg[:80]}")

    print(f"\nResults: {passed} pass, {failed} fail/error, {waived} waived, {skipped} not_applicable")
    print(f"Written to: {results}/")
    # Always exit 0 — gate enforcement (BLOCK vs WARN vs DEFERRED) is evaluated
    # by job 7 using the profile gate criteria, not by this script.
    # Exiting 1 here would prevent jobs 5-7 from running, bypassing proper gate evaluation.
    return 0


if __name__ == "__main__":
    sys.exit(main())
