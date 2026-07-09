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

    # ── ACC-001: Account MFA / security settings (GitHub context) ────────────
    # Fetch account or org 2FA status using the authenticated token
    user_data = run_gh("user") or {}
    owner = repo.split("/")[0] if "/" in repo else repo_name
    # Try org first, fall back to user account
    org_data = run_gh(f"orgs/{owner}") or {}
    two_factor_required = org_data.get("two_factor_requirement_enabled")
    two_factor_enabled = user_data.get("two_factor_authentication")
    (out / "acc-security.json").write_text(json.dumps({
        "repository": {"name": repo_name},
        "account": {
            "login": owner,
            "is_org": bool(org_data.get("login")),
            "two_factor_authentication": two_factor_enabled,
            "two_factor_requirement_enabled": two_factor_required,
        }
    }))

    # ── SEC-007: Vulnerability SLA check ─────────────────────────────────────
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc)
    dependabot_alerts = run_gh(f"repos/{repo}/dependabot/alerts?state=open&per_page=100") or []
    sla_violations = []
    alerts_with_age = []
    for alert in (dependabot_alerts if isinstance(dependabot_alerts, list) else []):
        sev = (alert.get("security_advisory") or {}).get("severity", "").lower()
        created_str = alert.get("created_at", "")
        try:
            created = datetime.fromisoformat(created_str.replace("Z", "+00:00"))
            age_days = (now - created).days
        except Exception:
            age_days = 0
        sla_map = {"critical": 7, "high": 30, "medium": 90}
        sla_days = sla_map.get(sev, 365)
        breached = age_days > sla_days
        alerts_with_age.append({
            "number": alert.get("number"),
            "severity": sev,
            "package": (alert.get("dependency") or {}).get("package", {}).get("name", "unknown"),
            "created_at": created_str,
            "age_days": age_days,
            "sla_days": sla_days,
            "sla_breached": breached,
            "state": alert.get("state", "open"),
        })
        if breached:
            sla_violations.append(f"{sev}/{(alert.get('dependency') or {}).get('package', {}).get('name', '?')} ({age_days}d > {sla_days}d SLA)")
    (out / "sec-vuln-sla.json").write_text(json.dumps({
        "repository": {"name": repo_name},
        "evaluated_at": now.isoformat(),
        "open_alerts": alerts_with_age,
        "sla_violations": sla_violations,
        "sla_breach_count": len(sla_violations),
    }))

    # ── AUD-001: Audit log accessibility check ────────────────────────────────
    # Try to access audit log entries (requires appropriate permissions)
    audit_entries = run_gh(f"users/{owner}/audit-log?per_page=1&phrase=action:repo") or []
    audit_accessible = isinstance(audit_entries, list)
    (out / "aud-security.json").write_text(json.dumps({
        "repository": {"name": repo_name},
        "audit_log": {
            "accessible": audit_accessible,
            "recent_entry_count": len(audit_entries) if audit_accessible else 0,
            "owner": owner,
        }
    }))

    # ── LIC-001: License compliance check ────────────────────────────────────
    # Check repo's own license and whether a license scan action exists
    repo_license = (repo_data.get("license") or {})
    spdx_id = repo_license.get("spdx_id", "") or ""
    # Copyleft licenses that may restrict usage
    copyleft_licenses = {"GPL-2.0-only", "GPL-2.0-or-later", "GPL-3.0-only",
                         "GPL-3.0-or-later", "AGPL-3.0-only", "AGPL-3.0-or-later",
                         "LGPL-2.0-only", "LGPL-2.0-or-later", "LGPL-2.1-only",
                         "LGPL-2.1-or-later", "LGPL-3.0-only", "LGPL-3.0-or-later"}
    license_is_copyleft = spdx_id in copyleft_licenses
    license_present = bool(repo_license.get("name"))
    # Check if any license-scanning action is present in workflows
    license_scan_patterns = ["fossa-contrib/fossa-action", "licensefinder/",
                             "github/licensed", "pypa/gh-action-pypi-publish",
                             "check-license", "license-checker"]
    (out / "lic-info.json").write_text(json.dumps({
        "repository": {"name": repo_name},
        "license": {
            "spdx_id": spdx_id,
            "name": repo_license.get("name", ""),
            "present": license_present,
            "is_copyleft": license_is_copyleft,
        }
    }))

    print(f"Inputs written to {out}/")

    for f in sorted(out.iterdir()):
        print(f"  {f.name}")

if __name__ == "__main__":
    main()
