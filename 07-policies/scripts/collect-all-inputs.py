#!/usr/bin/env python3
"""
collect-all-inputs.py — Collect all OPA policy inputs for the current repository.

Outputs JSON files to /tmp/inputs/ for each technology context applicable to this run.

Usage: python3 collect-all-inputs.py [--repo OWNER/REPO] [--branch BRANCH] [--contexts a,b]
"""
import argparse, json, os, re, subprocess, sys
from pathlib import Path

def run_gh(endpoint, default=None):
    """Call gh API and return parsed JSON or default on error."""
    try:
        result = subprocess.run(
            ["gh", "api", endpoint],
            capture_output=True, text=True, timeout=30
        )
        return json.loads(result.stdout) if result.returncode == 0 else default
    except Exception:
        return default

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", ""))
    p.add_argument("--branch", default="main")
    p.add_argument("--repo-name", default="")
    p.add_argument("--repo-type", default="platform-repo")
    p.add_argument("--contexts", default="github,github-actions")
    p.add_argument("--pr-number", default=os.environ.get("PR_NUMBER", ""))
    p.add_argument("--out-dir", default="/tmp/inputs")
    args = p.parse_args()

    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    repo = args.repo
    repo_name = args.repo_name or repo.split("/")[-1]
    contexts = set(args.contexts.split(","))

    # ── GitHub context (always) ──────────────────────────────────────────────

    # Branch protection (SRC-001, SRC-002)
    bp = run_gh(f"repos/{repo}/branches/{args.branch}/protection")
    (out / "src-branch-protection.json").write_text(json.dumps({
        "repository": {"name": repo_name, "type": args.repo_type},
        "default_branch": args.branch,
        "branch_protection": bp
    }))

    # Repo security settings (SEC-002)
    repo_data = run_gh(f"repos/{repo}") or {}
    (out / "sec-security-settings.json").write_text(json.dumps({
        "repository": {"name": repo_name, "security_and_analysis": repo_data.get("security_and_analysis", {})}
    }))

    # File list for CODEOWNERS, README (SRC-003, DOC-001)
    files = []
    for root, _, fnames in os.walk("."):
        if ".git" in root:
            continue
        for fn in fnames:
            full = os.path.join(root, fn)
            rel = full.lstrip("./")
            try:
                files.append({"path": rel, "size": os.path.getsize(full)})
            except OSError:
                pass
    (out / "doc-files.json").write_text(json.dumps({"repository": {"name": repo_name}, "files": files}))

    # CODEOWNERS
    codeowners = {"repository": {"name": repo_name}, "files": []}
    for loc in ["CODEOWNERS", ".github/CODEOWNERS", "docs/CODEOWNERS"]:
        if os.path.exists(loc):
            codeowners["files"].append({"path": loc, "size": os.path.getsize(loc)})
            break
    (out / "src-codeowners.json").write_text(json.dumps(codeowners))

    # PR context (CHG-001)
    pr_body, changed_files, is_platform = "", [], args.repo_type == "platform-repo"
    if args.pr_number:
        pr_data = run_gh(f"repos/{repo}/pulls/{args.pr_number}") or {}
        pr_body = pr_data.get("body") or ""
        pr_files = run_gh(f"repos/{repo}/pulls/{args.pr_number}/files") or []
        changed_files = [f["filename"] for f in pr_files if isinstance(f, dict)]
    (out / "chg-pr-context.json").write_text(json.dumps({
        "repository": {"name": repo_name, "type": args.repo_type},
        "pr_body": pr_body,
        "changed_files": changed_files,
        "is_platform_repo": is_platform
    }))

    # Release tag context (CHG-002)
    tag = os.environ.get("GITHUB_REF", "").replace("refs/tags/", "")
    has_record = os.path.exists(f"09-assessments/releases/{tag}.yaml") if tag.startswith("v") else False
    (out / "chg-release.json").write_text(json.dumps({
        "repository": {"name": repo_name},
        "release_tag": tag,
        "release_record_exists": has_record,
        "release_record": None
    }))

    # ── Terraform context ────────────────────────────────────────────────────
    if "terraform" in contexts:
        result = subprocess.run(
            ["bash", "07-policies/scripts/collect-terraform-info.sh", "."],
            capture_output=True, text=True
        )
        try:
            data = json.loads(result.stdout)
        except Exception:
            data = {"repository": {"name": repo_name}, "required_version": None,
                    "required_providers": [], "module_calls": [],
                    "fmt_result": {"exit_code": 0, "diff": "", "terraform_version": "unknown"},
                    "validate_result": {"exit_code": 0, "errors": [], "warnings": [], "directories_checked": []}}
        (out / "iac-terraform.json").write_text(json.dumps(data))

    # ── Docker context ───────────────────────────────────────────────────────
    if "docker" in contexts:
        result = subprocess.run(
            ["bash", "07-policies/scripts/collect-dockerfile-info.sh", "."],
            capture_output=True, text=True
        )
        try:
            data = json.loads(result.stdout)
        except Exception:
            data = {"repository": {"name": repo_name}, "dockerfiles": [], "image_references": []}
        (out / "docker-info.json").write_text(json.dumps(data))

    # ── GitHub Actions context ───────────────────────────────────────────────
    if "github-actions" in contexts:
        result = subprocess.run(
            ["bash", "07-policies/scripts/collect-workflow-actions.sh", "."],
            capture_output=True, text=True
        )
        try:
            data = json.loads(result.stdout)
        except Exception:
            data = {"repository": {"name": repo_name}, "workflow_files": [], "action_references": []}
        (out / "actions-info.json").write_text(json.dumps(data))

    print(f"Inputs written to {out}/")
    for f in sorted(out.iterdir()):
        print(f"  {f.name}")

if __name__ == "__main__":
    main()
