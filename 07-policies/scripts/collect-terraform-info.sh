#!/usr/bin/env bash
# collect-terraform-info.sh
#
# Parses Terraform/OpenTofu configuration and outputs structured YAML
# suitable as input for OPA policy checks: IAC-001, IAC-002, IAC-003, SUP-001.
#
# Usage: ./collect-terraform-info.sh [repo-root]
# Output: YAML to stdout
# Requirements: terraform or tofu in PATH for fmt/validate checks

set -euo pipefail

REPO_ROOT="${1:-.}"
REPO_NAME=$(basename "$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$REPO_ROOT")")

# Determine terraform binary
TF_BIN=""
for bin in terraform tofu; do
  if command -v "$bin" >/dev/null 2>&1; then
    TF_BIN="$bin"
    break
  fi
done

TF_VERSION=""
FMT_EXIT=0
FMT_DIFF=""
VALIDATE_EXIT=0
VALIDATE_ERRORS="[]"
VALIDATE_DIRS="[]"

if [ -n "$TF_BIN" ]; then
  TF_VERSION=$("$TF_BIN" version -json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('terraform_version','unknown'))" 2>/dev/null || echo "unknown")
  
  # Run fmt check
  FMT_DIFF=$("$TF_BIN" fmt -check -recursive "$REPO_ROOT" 2>&1 || true)
  FMT_EXIT=$("$TF_BIN" fmt -check -recursive "$REPO_ROOT" >/dev/null 2>&1; echo $?)
  
  # Validate ONLY the repo root. Child module directories (data/, identity/, etc.)
  # are not standalone configs — their providers are configured by the root caller.
  # Validating them in isolation produces false-positive failures.
  validate_dirs=()
  validate_errors=()
  if [ -n "$(find "$REPO_ROOT" -maxdepth 1 -name "*.tf" 2>/dev/null | head -1)" ]; then
    validate_dirs+=("$REPO_ROOT")
    "$TF_BIN" -chdir="$REPO_ROOT" init -backend=false -input=false -no-color >/dev/null 2>&1 || true
    result=$("$TF_BIN" -chdir="$REPO_ROOT" validate -no-color -json 2>/dev/null || echo '{"valid":false,"error_count":1}')
    validate_valid=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('valid',False))" 2>/dev/null || echo "false")
    if [ "$validate_valid" != "True" ] && [ "$validate_valid" != "true" ]; then
      validate_errors+=("$REPO_ROOT")
      VALIDATE_EXIT=1
    fi
  fi
fi

python3 - "$REPO_ROOT" "$REPO_NAME" "$TF_VERSION" "$FMT_EXIT" "$VALIDATE_EXIT" <<PYTHON
import sys, os, re, json
from pathlib import Path

repo_root = Path(sys.argv[1])
repo_name = sys.argv[2]
tf_version = sys.argv[3]
fmt_exit = int(sys.argv[4])
validate_exit = int(sys.argv[5])

required_providers = []
module_calls = []
required_version = None

# Parse .tf files for version constraints
for tf_file in repo_root.rglob('*.tf'):
    if '.git' in str(tf_file) or '.terraform' in str(tf_file):
        continue
    try:
        content = tf_file.read_text()
    except Exception:
        continue
    
    # Extract required_version
    rv_match = re.search(r'required_version\s*=\s*"([^"]+)"', content)
    if rv_match and required_version is None:
        required_version = rv_match.group(1)
    
    # Extract provider versions
    for match in re.finditer(r'source\s*=\s*"([^"]+)".*?version\s*=\s*"([^"]+)"', content, re.DOTALL):
        source = match.group(1)
        version = match.group(2)
        name = source.split('/')[-1] if '/' in source else source
        required_providers.append({'name': name, 'source': source, 'version': version})
    
    # Extract module calls
    for match in re.finditer(r'module\s+"([^"]+)"\s*\{[^}]*source\s*=\s*"([^"]+)"(?:[^}]*version\s*=\s*"([^"]+)")?', content, re.DOTALL):
        mod_name = match.group(1)
        mod_source = match.group(2)
        mod_version = match.group(3) or ''
        module_calls.append({'name': mod_name, 'source': mod_source, 'version': mod_version})

# ── Read repository metadata from .compliance-manifest.yaml ──────────────────
# Used by policies to scope checks to the correct repository type.
try:
    import yaml as _yaml_mod  # optional; fallback regex if absent
except ImportError:
    _yaml_mod = None

repository_type = "unknown"
manifest_path = repo_root / '.compliance-manifest.yaml'
if manifest_path.exists():
    try:
        manifest_text = manifest_path.read_text()
        # Try PyYAML first, fall back to regex
        if _yaml_mod is not None:
            try:
                manifest_data = _yaml_mod.safe_load(manifest_text)
                repository_type = manifest_data.get('repository', {}).get('type', 'unknown')
            except Exception:
                pass
        if repository_type == "unknown":
            m = re.search(r'^\s+type:\s+(\S+)', manifest_text, re.MULTILINE)
            if m:
                repository_type = m.group(1).strip('"\'')
    except Exception:
        pass

# ── Additional checks for hardening and automation controls ──────────────────

# IAC-006: Does deploy.sh (or equivalent automation script) exist?
has_deploy_script = (repo_root / 'deploy.sh').exists() or (repo_root / 'scripts' / 'deploy.sh').exists()

# IAC-007: Does an integrations/ component exist (writes creds to Vault)?
has_integrations_module = (repo_root / 'integrations').is_dir() and any((repo_root / 'integrations').glob('*.tf'))

# RUN-009: Is a vault_jwt_auth_backend declared (Authentik as Vault IDP)?
has_vault_jwt_backend = False
for tf_file in repo_root.rglob('*.tf'):
    if '.git' in str(tf_file) or '.terraform' in str(tf_file):
        continue
    try:
        c = tf_file.read_text()
        if 'vault_jwt_auth_backend' in c and 'oidc_discovery_url' in c:
            has_vault_jwt_backend = True
            break
    except Exception:
        pass

# RUN-008: Find docker_container resources that declare NO memory limit.
# A compliant container has: memory = <number> or memory_swap = <number>
docker_containers_missing_limits = []
for tf_file in repo_root.rglob('*.tf'):
    if '.git' in str(tf_file) or '.terraform' in str(tf_file):
        continue
    try:
        c = tf_file.read_text()
    except Exception:
        continue
    for m in re.finditer(r'resource\s+"docker_container"\s+"([^"]+)"\s*\{(.*?)\n\}', c, re.DOTALL):
        container_name = m.group(1)
        body = m.group(2)
        has_memory = bool(re.search(r'\bmemory\s*=', body))
        if not has_memory:
            docker_containers_missing_limits.append({
                'file': str(tf_file.relative_to(repo_root)),
                'name': container_name,
                'issue': 'No memory limit declared'
            })

# ── SEC-012: Sensitive files tracked in git ───────────────────────────────────
import subprocess

tfvars_tracked_in_git = False
sensitive_files_in_git = []
try:
    result = subprocess.run(
        ['git', '-C', str(repo_root), 'ls-files'],
        capture_output=True, text=True, timeout=10
    )
    tracked = result.stdout.splitlines()
    sensitive_patterns = ['.tfvars', '.env', '.pem', '.key', 'vault-keys', 'backend.hcl']
    for f in tracked:
        for pat in sensitive_patterns:
            if pat in f and '.example' not in f:
                sensitive_files_in_git.append(f)
                if f.endswith('.tfvars'):
                    tfvars_tracked_in_git = True
                break
except Exception:
    pass

# ── HIGH-003 / IAC-003: Module calls using mutable refs (main, master, HEAD) ──
MUTABLE_REFS = {'main', 'master', 'HEAD', 'develop', 'dev', 'trunk'}
modules_with_mutable_refs = []
for call in module_calls:
    src = call.get('source', '')
    if '?ref=' in src:
        ref = src.split('?ref=')[-1].strip()
        if ref in MUTABLE_REFS or ref.startswith('refs/heads/'):
            modules_with_mutable_refs.append({
                'name': call.get('name', ''),
                'source': src,
                'ref': ref
            })
    elif src.startswith('git::') and '?ref=' not in src:
        # git source with no ref at all is also mutable
        modules_with_mutable_refs.append({
            'name': call.get('name', ''),
            'source': src,
            'ref': '(none — defaults to HEAD)'
        })

# ── SEC-013: TLS disabled / insecure provider configs ─────────────────────────
# Declared environment source (P0-7): the committed .compliance-manifest.yaml
# top-level `environment` field is the single source of truth. terraform.tfvars is
# gitignored and is NO LONGER read for this. Fail-safe: if the field is absent, the
# manifest is missing, or it cannot be parsed, treat the environment as the
# strictest tier "production" (NOT staging). Reuses the optional _yaml_mod import +
# regex fallback pattern already used above for repository_type.
declared_environment = "production"
if manifest_path.exists():
    try:
        manifest_env_text = manifest_path.read_text()
        parsed_env = None
        if _yaml_mod is not None:
            try:
                manifest_env_data = _yaml_mod.safe_load(manifest_env_text)
                if isinstance(manifest_env_data, dict):
                    _env = manifest_env_data.get('environment')
                    if isinstance(_env, str) and _env.strip():
                        parsed_env = _env.strip()
            except Exception:
                parsed_env = None
        if parsed_env is None:
            # Regex fallback: top-level `environment: <value>` (no indentation).
            m = re.search(r'^environment:\s*["\']?([A-Za-z0-9_-]+)["\']?\s*$',
                          manifest_env_text, re.MULTILINE)
            if m:
                parsed_env = m.group(1)
        if parsed_env:
            declared_environment = parsed_env
    except Exception:
        pass

tls_disabled_configs = []
insecure_provider_pattern = re.compile(
    r'(?:tls_disable\s*=\s*true|skip_tls_verify\s*=\s*true|insecure\s*=\s*true)',
    re.IGNORECASE
)
for tf_file in repo_root.rglob('*.tf'):
    if '.git' in str(tf_file) or '.terraform' in str(tf_file):
        continue
    try:
        c = tf_file.read_text()
    except Exception:
        continue
    for m in insecure_provider_pattern.finditer(c):
        line_no = c[:m.start()].count('\n') + 1
        tls_disabled_configs.append({
            'file': str(tf_file.relative_to(repo_root)),
            'line': line_no,
            'pattern': m.group(0).strip()
        })

# ── HIGH-007: Vault audit device declared ─────────────────────────────────────
has_vault_audit_device = False
for tf_file in repo_root.rglob('*.tf'):
    if '.git' in str(tf_file) or '.terraform' in str(tf_file):
        continue
    try:
        c = tf_file.read_text()
        if 'vault_audit' in c:
            has_vault_audit_device = True
            break
    except Exception:
        pass

# ── NET-002: Docker containers bound to all interfaces (0.0.0.0) ──────────────
# Compliant: ports { ip = "127.0.0.1" ... } or no host port binding at all.
# Violation: ports { external = ... } without ip = "127.0.0.1" for internal services.
INTERNAL_SERVICES = {'postgresql', 'postgres', 'redis'}
containers_with_all_interfaces = []
for tf_file in repo_root.rglob('*.tf'):
    if '.git' in str(tf_file) or '.terraform' in str(tf_file):
        continue
    try:
        c = tf_file.read_text()
    except Exception:
        continue
    for m in re.finditer(r'resource\s+"docker_container"\s+"([^"]+)"\s*\{(.*?)\n\}', c, re.DOTALL):
        container_name = m.group(1)
        body = m.group(2)
        # Check if container is an internal service with a host port binding
        is_internal = any(svc in container_name.lower() for svc in INTERNAL_SERVICES)
        has_external_port = bool(re.search(r'\bexternal\s*=', body))
        has_localhost_binding = bool(re.search(r'\bip\s*=\s*"127\.0\.0\.1"', body))
        if is_internal and has_external_port and not has_localhost_binding:
            containers_with_all_interfaces.append({
                'file': str(tf_file.relative_to(repo_root)),
                'name': container_name,
                'issue': 'Internal service bound to 0.0.0.0 — should bind to 127.0.0.1 or remove host port'
            })

# ── HIGH-006 / RUN-009 extension: Grafana OIDC in integrations ────────────────
has_grafana_oidc = False
for tf_file in repo_root.rglob('*.tf'):
    if '.git' in str(tf_file) or '.terraform' in str(tf_file):
        continue
    try:
        c = tf_file.read_text()
        if 'grafana' in c.lower() and ('oidc' in c.lower() or 'oauth' in c.lower() or 'authentik' in c.lower()):
            has_grafana_oidc = True
            break
    except Exception:
        pass

output = {
    'repository': {'name': repo_name, 'type': repository_type},
    'required_version': required_version,
    'required_providers': required_providers,
    'module_calls': module_calls,
    'fmt_result': {
        'exit_code': fmt_exit,
        'diff': '${FMT_DIFF}'.strip(),
        'terraform_version': tf_version
    },
    'validate_result': {
        'exit_code': validate_exit,
        'errors': [],
        'warnings': [],
        'directories_checked': []
    },
    # Hardening and automation control fields
    'has_deploy_script': has_deploy_script,
    'has_integrations_module': has_integrations_module,
    'has_vault_jwt_backend': has_vault_jwt_backend,
    'docker_containers_missing_limits': docker_containers_missing_limits,
    # New fields from audit
    'tfvars_tracked_in_git': tfvars_tracked_in_git,
    'sensitive_files_in_git': sensitive_files_in_git,
    'modules_with_mutable_refs': modules_with_mutable_refs,
    'tls_disabled_configs': tls_disabled_configs,
    'declared_environment': declared_environment,
    'has_vault_audit_device': has_vault_audit_device,
    'containers_with_all_interfaces': containers_with_all_interfaces,
    'has_grafana_oidc': has_grafana_oidc,
}

print(json.dumps(output, indent=2, ensure_ascii=False, default=str))
PYTHON
