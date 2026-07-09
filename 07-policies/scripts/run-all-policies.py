#!/usr/bin/env python3
"""
run-all-policies.py — Run all applicable OPA policies and write results to /tmp/results/.

Usage: python3 run-all-policies.py --bundle /tmp/policy-bundle --inputs /tmp/inputs
                                   --contexts github,terraform --repo-type platform-repo
"""
import argparse, json, os, subprocess, sys
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

    total, passed, failed, skipped = 0, 0, 0, 0

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

        if not os.path.exists(rego_path):
            (results / f"{control_id}.json").write_text(json.dumps({
                "result": "error",
                "details": {"message": f"Policy file not found: {rego_path}"}
            }))
            failed += 1
            continue

        if not os.path.exists(input_path):
            (results / f"{control_id}.json").write_text(json.dumps({
                "result": "error",
                "details": {"message": f"Input file not found: {input_path}"}
            }))
            failed += 1
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
        else:
            failed += 1
            msg = result.get("details", {}).get("message", "") if isinstance(result, dict) else str(result)
            print(f"  ✗ {control_id}: {r} — {msg[:80]}")

    print(f"\nResults: {passed} pass, {failed} fail/error, {skipped} not_applicable")
    print(f"Written to: {results}/")
    return 1 if failed > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
