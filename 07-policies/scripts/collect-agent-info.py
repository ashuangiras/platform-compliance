#!/usr/bin/env python3
"""
collect-agent-info.py — Collect AI coding-agent configuration facts for AGT controls.

Scans a repository's agent-configuration surface and emits a single JSON object on stdout
describing: repository instructions (single-sourcing + pre/post-flight), customization-file
frontmatter validity, MCP server configuration (validity + secret scan), lifecycle hooks, and
the agent roster (routing + tool least-privilege signals).

Stdlib-only so it runs on any CI runner. If PyYAML is importable it is used for strict
frontmatter parsing; otherwise a conservative line-based fallback is used.

Usage: python3 collect-agent-info.py [ROOT]   (ROOT defaults to ".")
"""
import json
import os
import re
import sys
from pathlib import Path

try:
    import yaml  # optional; strict frontmatter parse when available
    _HAVE_YAML = True
except Exception:
    _HAVE_YAML = False


# ── Frontmatter parsing ──────────────────────────────────────────────────────

def split_frontmatter(text):
    """Return (present, block_text) for a leading --- ... --- YAML frontmatter block."""
    if not text.startswith("---"):
        return False, None
    # Match: ---\n <block> \n---  at the very start of the file.
    m = re.match(r"^---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(\r?\n|$)", text, re.DOTALL)
    if not m:
        return False, None
    return True, m.group(1)


def parse_frontmatter(block):
    """Parse a frontmatter block into a dict. Returns (data, valid_yaml)."""
    if _HAVE_YAML:
        try:
            data = yaml.safe_load(block)
            if isinstance(data, dict):
                return data, True
            return {}, False
        except Exception:
            return {}, False
    # Fallback: minimal key: value + inline [a, b] list parser (top-level keys only).
    data, valid = {}, True
    for line in block.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = re.match(r"^([A-Za-z0-9_-]+):[ \t]*(.*)$", line)
        if not m:
            continue  # nested/continuation lines ignored in fallback
        key, val = m.group(1), m.group(2).strip()
        if val.startswith("[") and val.endswith("]"):
            items = [x.strip().strip("'\"") for x in val[1:-1].split(",") if x.strip()]
            data[key] = items
        elif val:
            data[key] = val.strip("'\"")
        else:
            data[key] = ""
    return data, valid


def get_tools(data):
    """Normalize the frontmatter `tools` field to a list of strings (or None if absent)."""
    t = data.get("tools")
    if t is None:
        return None
    if isinstance(t, list):
        return [str(x) for x in t]
    if isinstance(t, str):
        return [x.strip().strip("'\"") for x in t.strip("[]").split(",") if x.strip()]
    return None


def scan_file(abs_path, rel_path, kind):
    """Return a fact dict for one customization file.

    abs_path is used to READ the file (robust regardless of cwd); rel_path is what gets
    reported in the output.
    """
    text = ""
    try:
        text = Path(abs_path).read_text(encoding="utf-8", errors="replace")
    except Exception:
        pass
    present, block = split_frontmatter(text)
    data, valid_yaml = ({}, False)
    if present:
        data, valid_yaml = parse_frontmatter(block)
    desc = data.get("description") if isinstance(data, dict) else None
    desc = desc if isinstance(desc, str) else ""
    tools = get_tools(data) if isinstance(data, dict) else None
    apply_to = data.get("applyTo") if isinstance(data, dict) else None
    return {
        "path": rel_path,
        "kind": kind,
        "frontmatter_present": present,
        "frontmatter_valid": bool(present and valid_yaml),
        "has_description": bool(desc and desc.strip()),
        "description_length": len(desc.strip()) if desc else 0,
        "tools_declared": tools is not None,
        "tools": tools if tools is not None else [],
        "name": (data.get("name") if isinstance(data, dict) else None) or Path(rel_path).stem,
        "applyTo": apply_to,
    }


# ── MCP secret scanning ──────────────────────────────────────────────────────

SECRET_PATTERNS = [
    (r"ghp_[A-Za-z0-9]{20,}", "github-pat-classic"),
    (r"github_pat_[A-Za-z0-9_]{20,}", "github-pat-fine-grained"),
    (r"gh[osru]_[A-Za-z0-9]{20,}", "github-token"),
    (r"sk-[A-Za-z0-9]{20,}", "openai-key"),
    (r"xox[baprs]-[A-Za-z0-9-]{10,}", "slack-token"),
    (r"AKIA[0-9A-Z]{16}", "aws-access-key"),
    (r"AIza[0-9A-Za-z_\-]{35}", "google-api-key"),
    (r"-----BEGIN [A-Z ]*PRIVATE KEY-----", "private-key"),
    # A literal value on a secret-ish key that is NOT a ${...} reference.
    (r"(?i)\"(?:authorization|token|secret|password|api[_-]?key|access[_-]?key)\"\s*:\s*\"(?!\$\{)[^\"]{8,}\"",
     "literal-secret-value"),
    (r"(?i)\"Bearer\s+(?!\$\{)[A-Za-z0-9._\-]{10,}\"", "literal-bearer-token"),
]


def scan_mcp_secrets(raw):
    findings = []
    for pattern, label in SECRET_PATTERNS:
        if re.search(pattern, raw):
            findings.append(label)
    return findings


def collect_mcp(root):
    cfg = root / ".vscode" / "mcp.json"
    info = {
        "config_present": cfg.exists(),
        "config_valid": False,
        "servers": [],
        "server_count": 0,
        "hardcoded_secret_suspected": False,
        "secret_findings": [],
    }
    if not cfg.exists():
        return info
    raw = ""
    try:
        raw = cfg.read_text(encoding="utf-8", errors="replace")
        data = json.loads(raw)
        info["config_valid"] = True
        servers = data.get("servers") or data.get("mcpServers") or {}
        if isinstance(servers, dict):
            info["servers"] = sorted(servers.keys())
            info["server_count"] = len(servers)
    except Exception:
        info["config_valid"] = False
    findings = scan_mcp_secrets(raw)
    info["secret_findings"] = findings
    info["hardcoded_secret_suspected"] = bool(findings)
    return info


# ── Hooks ────────────────────────────────────────────────────────────────────

def collect_hooks(root):
    hooks_dir = root / ".github" / "hooks"
    info = {"config_present": False, "files": [], "events": [], "has_destructive_guard": False}
    if not hooks_dir.is_dir():
        return info
    events = set()
    files = sorted(str(p.relative_to(root)) for p in hooks_dir.glob("*.json"))
    info["config_present"] = bool(files)
    info["files"] = files
    for p in hooks_dir.glob("*.json"):
        try:
            data = json.loads(p.read_text(encoding="utf-8", errors="replace"))
            hk = data.get("hooks", {})
            if isinstance(hk, dict):
                events.update(hk.keys())
        except Exception:
            continue
    info["events"] = sorted(events)
    info["has_destructive_guard"] = "PreToolUse" in events
    return info


# ── Agents / instructions rosters ────────────────────────────────────────────

ROUTER_RE = re.compile(r"rout|coordinat|orchestrat|dispatch", re.IGNORECASE)
REVIEW_RE = re.compile(r"read-?only|review|verif|validat|audit", re.IGNORECASE)
# A review/read-only agent must not be able to MUTATE files. `execute` is permitted because
# reviewers legitimately run validators (opa check, check-jsonschema); `edit` is the crisp
# file-mutation capability that a read-only role must not hold.
WRITE_TOOLS = {"edit"}


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    repo_env = os.environ.get("GITHUB_REPOSITORY", "")
    repo_name = repo_env.split("/")[-1] if repo_env else root.name

    # Repository instruction sources
    copilot = root / ".github" / "copilot-instructions.md"
    agents_md_root = root / "AGENTS.md"
    agents_md_github = root / ".github" / "AGENTS.md"
    copilot_present = copilot.exists()
    agents_md_present = agents_md_root.exists() or agents_md_github.exists()
    instruction_sources = int(copilot_present) + int(agents_md_present)

    root_instr_text = ""
    root_instr_file = None
    if copilot_present:
        root_instr_file = str(copilot.relative_to(root))
        root_instr_text = copilot.read_text(encoding="utf-8", errors="replace")
    elif agents_md_present:
        f = agents_md_root if agents_md_root.exists() else agents_md_github
        root_instr_file = str(f.relative_to(root))
        root_instr_text = f.read_text(encoding="utf-8", errors="replace")
    low = root_instr_text.lower()
    has_preflight = ("pre-flight" in low) or ("preflight" in low)
    has_postflight = ("post-flight" in low) or ("postflight" in low)

    # Customization files
    cust = []
    agents = []
    for p in sorted((root / ".github" / "agents").glob("*.agent.md")):
        rec = scan_file(p, str(p.relative_to(root)), "agent")
        cust.append(rec)
        agents.append(rec)
    for p in sorted((root / ".github" / "instructions").glob("*.instructions.md")):
        cust.append(scan_file(p, str(p.relative_to(root)), "instruction"))
    for p in sorted((root / ".github" / "prompts").glob("*.prompt.md")):
        cust.append(scan_file(p, str(p.relative_to(root)), "prompt"))

    total = len(cust)
    valid_count = sum(1 for c in cust if c["frontmatter_valid"] and c["has_description"])
    invalid_files = [c["path"] for c in cust if not (c["frontmatter_valid"] and c["has_description"])]

    # Agent roster: routing + least-privilege signals
    agent_names = [a["name"] for a in agents]
    router_present = any(
        ("agent" in a["tools"]) or ROUTER_RE.search(a["name"] or "") or ROUTER_RE.search(a["path"])
        for a in agents
    )
    readonly_with_write = [
        a["path"] for a in agents
        if REVIEW_RE.search((a["name"] or "") + " " + a["path"]) and (set(a["tools"]) & WRITE_TOOLS)
    ]
    agents_missing_tools = [a["path"] for a in agents if not a["tools_declared"]]

    # Instruction scoping hygiene (AGT-006)
    instr = [c for c in cust if c["kind"] == "instruction"]
    broad_apply_to = [c["path"] for c in instr if c["applyTo"] in ("**", ["**"])]
    instr_missing_desc = [c["path"] for c in instr if not c["has_description"]]

    has_agent_config = bool(
        copilot_present or agents_md_present or cust
        or (root / ".vscode" / "mcp.json").exists()
        or (root / ".github" / "hooks").is_dir()
    )

    result = {
        "repository": {"name": repo_name},
        "context": "agent",
        "has_agent_config": has_agent_config,
        "instructions": {
            "copilot_instructions_present": copilot_present,
            "agents_md_present": agents_md_present,
            "instruction_source_count": instruction_sources,
            "single_source": instruction_sources == 1,
            "root_instructions_file": root_instr_file,
            "has_preflight": has_preflight,
            "has_postflight": has_postflight,
        },
        "frontmatter": {
            "total_files": total,
            "valid_count": valid_count,
            "all_valid": total == 0 or valid_count == total,
            "invalid_files": invalid_files,
        },
        "customization_files": cust,
        "agents": {
            "count": len(agents),
            "names": agent_names,
            "router_present": router_present,
            "agents_missing_tools": agents_missing_tools,
            "readonly_agents_with_write_tools": readonly_with_write,
        },
        "instruction_files": {
            "count": len(instr),
            "broad_applyto_files": broad_apply_to,
            "missing_description_files": instr_missing_desc,
        },
        "mcp": collect_mcp(root),
        "hooks": collect_hooks(root),
    }
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
