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
    """Return (present, block_text, body_text) for a leading --- ... --- YAML frontmatter block."""
    if not text.startswith("---"):
        return False, None, text
    # Match: ---\n <block> \n---  at the very start of the file.
    m = re.match(r"^---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(\r?\n|$)", text, re.DOTALL)
    if not m:
        return False, None, text
    return True, m.group(1), text[m.end():]


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


# Quality thresholds and body heuristics (stringent A2 signals).
WEAK_DESC_MIN = 40  # a discoverable description must be at least this many characters
ROLE_RE = re.compile(r"\byou are\b|\byour job\b|\byour role\b|\byou specialize\b|\bpersona\b", re.IGNORECASE)
CONSTRAINTS_RE = re.compile(r"constraint|do not|don't|must not|\bnever\b|boundaries|\brules\b|forbidden|prohibit", re.IGNORECASE)


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
    present, block, body = split_frontmatter(text)
    data, valid_yaml = ({}, False)
    if present:
        data, valid_yaml = parse_frontmatter(block)
    desc = data.get("description") if isinstance(data, dict) else None
    desc = desc if isinstance(desc, str) else ""
    desc_len = len(desc.strip()) if desc else 0
    tools = get_tools(data) if isinstance(data, dict) else None
    apply_to = data.get("applyTo") if isinstance(data, dict) else None
    body_l = (body or "").lower()
    return {
        "path": rel_path,
        "kind": kind,
        "frontmatter_present": present,
        "frontmatter_valid": bool(present and valid_yaml),
        "has_description": bool(desc and desc.strip()),
        "description_length": desc_len,
        "description_weak": desc_len < WEAK_DESC_MIN,
        "tools_declared": tools is not None,
        "tools": tools if tools is not None else [],
        "name": (data.get("name") if isinstance(data, dict) else None) or Path(rel_path).stem,
        "applyTo": apply_to,
        "body_length": len((body or "").strip()),
        "has_role_statement": bool(ROLE_RE.search(body_l)),
        "has_constraints": bool(CONSTRAINTS_RE.search(body_l)),
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


_LAUNCHERS = ("npx", "uvx", "npm", "pnpm", "bunx", "pipx")


def _server_is_pinned(spec):
    """A server is 'pinned' if its endpoint is a fixed URL, or its stdio command is version-pinned.

    http/sse servers: pinned by their URL. stdio servers launched via npx/uvx/etc. must pin an
    explicit @version; docker must reference a non-latest tag. A concrete binary path is accepted.
    """
    if not isinstance(spec, dict):
        return False
    stype = str(spec.get("type") or "").lower()
    if spec.get("url"):
        return stype in ("http", "sse", "")
    cmd = str(spec.get("command") or "").lower()
    args = spec.get("args") if isinstance(spec.get("args"), list) else []
    args_str = " ".join(str(a) for a in args).lower()
    if not cmd:
        return False
    base = cmd.rsplit("/", 1)[-1]
    if base in _LAUNCHERS:
        return "@" in args_str  # requires an explicit @version pin
    if base == "docker":
        return (":" in args_str) and (":latest" not in args_str)
    return True  # concrete binary path


def collect_mcp(root):
    cfg = root / ".vscode" / "mcp.json"
    info = {
        "config_present": cfg.exists(),
        "config_valid": False,
        "servers": [],
        "server_count": 0,
        "server_details": [],
        "servers_missing_type": [],
        "unpinned_servers": [],
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
            for name, spec in servers.items():
                spec = spec if isinstance(spec, dict) else {}
                stype = spec.get("type")
                pinned = _server_is_pinned(spec)
                info["server_details"].append({
                    "name": name,
                    "type": stype,
                    "has_endpoint": bool(spec.get("url") or spec.get("command")),
                    "pinned": pinned,
                })
                if not stype:
                    info["servers_missing_type"].append(name)
                if not pinned:
                    info["unpinned_servers"].append(name)
    except Exception:
        info["config_valid"] = False
    findings = scan_mcp_secrets(raw)
    info["secret_findings"] = findings
    info["hardcoded_secret_suspected"] = bool(findings)
    return info


# ── Hooks ────────────────────────────────────────────────────────────────────

def collect_hooks(root):
    hooks_dir = root / ".github" / "hooks"
    info = {
        "config_present": False,
        "files": [],
        "events": [],
        "has_destructive_guard": False,
        "commands": [],
        "missing_command_scripts": [],
        "non_executable_scripts": [],
        "guard_ok": False,
    }
    if not hooks_dir.is_dir():
        return info
    events = set()
    commands = []
    files = sorted(str(p.relative_to(root)) for p in hooks_dir.glob("*.json"))
    info["config_present"] = bool(files)
    info["files"] = files
    for p in hooks_dir.glob("*.json"):
        try:
            data = json.loads(p.read_text(encoding="utf-8", errors="replace"))
            hk = data.get("hooks", {})
            if not isinstance(hk, dict):
                continue
            for event, entries in hk.items():
                events.add(event)
                if not isinstance(entries, list):
                    continue
                for e in entries:
                    if isinstance(e, dict) and e.get("command"):
                        commands.append(e["command"])
        except Exception:
            continue
    # Validate that each hook command's script exists and (for shell scripts) is executable.
    for cmd in commands:
        script = str(cmd).split()[0] if str(cmd).strip() else ""
        if not script or ("/" not in script and not script.endswith((".sh", ".py"))):
            continue  # a bare binary (e.g. "python3") — not a repo script path
        sp = root / script
        if not sp.exists():
            info["missing_command_scripts"].append(script)
        elif script.endswith(".sh") and not os.access(sp, os.X_OK):
            info["non_executable_scripts"].append(script)
    info["events"] = sorted(events)
    info["commands"] = commands
    info["has_destructive_guard"] = "PreToolUse" in events
    info["guard_ok"] = (
        "PreToolUse" in events
        and not info["missing_command_scripts"]
        and not info["non_executable_scripts"]
    )
    return info


# ── Discovery settings (AGT-015) ─────────────────────────────────────────────

def collect_discovery(root):
    """Whether the workspace explicitly enables agent discovery for the whole team.

    `.github/agents` is a default location, but a committed `.vscode/settings.json` that enables
    `chat.agentFilesLocations` guarantees discovery for every clone (and every downstream repo
    that adopts the pattern), independent of a user's personal defaults.
    """
    cfg = root / ".vscode" / "settings.json"
    info = {"settings_file_present": cfg.exists(), "agent_location_enabled": False}
    if not cfg.exists():
        return info
    try:
        raw = cfg.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return info
    # Regex check (tolerant of JSONC comments / trailing commas / other settings).
    has_key = re.search(r'"chat\.agentFilesLocations"', raw)
    agents_on = re.search(r'"\.github/agents"\s*:\s*true', raw)
    info["agent_location_enabled"] = bool(has_key and agents_on)
    return info


# ── Agents / instructions rosters ────────────────────────────────────────────

ROUTER_RE = re.compile(r"rout|coordinat|orchestrat|dispatch", re.IGNORECASE)
REVIEW_RE = re.compile(r"read-?only|review|verif|validat|audit", re.IGNORECASE)
# A review/read-only agent must not be able to MUTATE files. `execute` is permitted because
# reviewers legitimately run validators (opa check, check-jsonschema); `edit` is the crisp
# file-mutation capability that a read-only role must not hold.
WRITE_TOOLS = {"edit"}

# Continuous-improvement ledger candidates (AGT-013).
LEDGER_CANDIDATES = [
    ".github/AGENT_LEARNINGS.md",
    "docs/agent-learnings.md",
]


def _is_agent_config_path(cf):
    return (
        cf.startswith(".github/agents/")
        or cf.startswith(".github/instructions/")
        or cf.startswith(".github/prompts/")
        or cf.startswith(".github/hooks/")
        or cf in (".vscode/mcp.json", ".github/copilot-instructions.md", "AGENTS.md", ".github/AGENTS.md")
    )


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
    has_build_test = any(k in low for k in ("build", "test", "validate", "lint", "compile"))
    has_conventions = any(k in low for k in ("convention", "architecture", "structure", "repository map", "guideline", "pattern"))
    has_safety = any(k in low for k in ("safety", "destructive", "irreversible", "secret", "do not"))
    instructions_complete = bool(root_instr_file) and has_build_test and has_conventions and has_safety

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
    agents_missing_role = [a["path"] for a in agents if not a["has_role_statement"]]
    agents_missing_constraints = [a["path"] for a in agents if not a["has_constraints"]]
    weak_description_files = [c["path"] for c in cust if c["description_weak"]]

    # Instruction scoping hygiene (AGT-006)
    instr = [c for c in cust if c["kind"] == "instruction"]
    broad_apply_to = [c["path"] for c in instr if c["applyTo"] in ("**", ["**"])]
    instr_missing_desc = [c["path"] for c in instr if not c["has_description"]]

    has_agent_config = bool(
        copilot_present or agents_md_present or cust
        or (root / ".vscode" / "mcp.json").exists()
        or (root / ".github" / "hooks").is_dir()
    )

    # ── Continuous-improvement + pre-merge readiness (AGT-013, AGT-014) ───────
    # PR context is passed by collect-all-inputs.py via environment variables so this offline,
    # stdlib-only collector needs no GitHub API access.
    pr_number = os.environ.get("AGENT_PR_NUMBER", "").strip()
    pr_body = os.environ.get("AGENT_PR_BODY", "")
    changed_files = [c.strip() for c in os.environ.get("AGENT_CHANGED_FILES", "").splitlines() if c.strip()]
    is_pull_request = bool(pr_number)

    ledger_path = None
    for rel in LEDGER_CANDIDATES:
        if (root / rel).exists():
            ledger_path = rel
            break
    ledger_present = ledger_path is not None
    ledger_entry_count = 0
    if ledger_present:
        try:
            ledger_text = (root / ledger_path).read_text(encoding="utf-8", errors="replace")
            ledger_entry_count = len(re.findall(r"(?m)^##\s+", ledger_text))
        except Exception:
            ledger_entry_count = 0

    ledger_updated_in_pr = bool(ledger_path) and any(
        cf == ledger_path or cf.endswith("/" + os.path.basename(ledger_path)) for cf in changed_files
    )
    agent_config_updated_in_pr = any(_is_agent_config_path(cf) for cf in changed_files)

    body_low = pr_body.lower()

    # AGT-014 readiness: the "Agent Readiness & Retro" section must exist AND at least
    # one [x] checkbox must appear within that section (not just anywhere in the body).
    readiness_section_match = re.search(
        r"agent readiness.*?retro.*?\n(.*?)(?=\n##|\Z)",
        pr_body, re.IGNORECASE | re.DOTALL
    )
    readiness_section_text = readiness_section_match.group(1) if readiness_section_match else ""
    pr_has_readiness = (
        "readiness" in body_low
        and bool(re.search(r"\[x\]", readiness_section_text or pr_body, re.IGNORECASE))
    )

    # AGT-014 retro: the retrospective section must contain at least one non-placeholder
    # bullet point (a line starting with "- " that is not the comment placeholder "-\n"
    # and has more than a single dash/whitespace).
    retro_section_match = re.search(
        r"(?:retrospective|retro)[^\n]*\n(.*?)(?=\n##|\Z)",
        pr_body, re.IGNORECASE | re.DOTALL
    )
    retro_section_text = retro_section_match.group(1) if retro_section_match else ""
    retro_bullets = re.findall(r"^[-*]\s+\S.+", retro_section_text, re.MULTILINE)
    pr_has_retro = bool(retro_bullets)  # at least one substantive bullet after the retro header

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
            "has_build_test": has_build_test,
            "has_conventions": has_conventions,
            "has_safety": has_safety,
            "complete": instructions_complete,
        },
        "frontmatter": {
            "total_files": total,
            "valid_count": valid_count,
            "all_valid": total == 0 or valid_count == total,
            "invalid_files": invalid_files,
        },
        "descriptions": {
            "weak_min": WEAK_DESC_MIN,
            "weak_files": weak_description_files,
        },
        "customization_files": cust,
        "agents": {
            "count": len(agents),
            "names": agent_names,
            "router_present": router_present,
            "agents_missing_tools": agents_missing_tools,
            "readonly_agents_with_write_tools": readonly_with_write,
            "agents_missing_role": agents_missing_role,
            "agents_missing_constraints": agents_missing_constraints,
        },
        "instruction_files": {
            "count": len(instr),
            "broad_applyto_files": broad_apply_to,
            "missing_description_files": instr_missing_desc,
        },
        "mcp": collect_mcp(root),
        "hooks": collect_hooks(root),
        "discovery": collect_discovery(root),
        "improvement": {
            "ledger_present": ledger_present,
            "ledger_path": ledger_path,
            "ledger_entry_count": ledger_entry_count,
            "is_pull_request": is_pull_request,
            "ledger_updated_in_pr": ledger_updated_in_pr,
            "agent_config_updated_in_pr": agent_config_updated_in_pr,
            "pr_has_readiness": pr_has_readiness,
            "pr_has_retro": pr_has_retro,
        },
    }
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
