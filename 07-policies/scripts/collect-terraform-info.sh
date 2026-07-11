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
for bin in tofu terraform; do
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
  
  # Find and validate each terraform directory
  validate_dirs=()
  validate_errors=()
  while IFS= read -r tf_dir; do
    validate_dirs+=("$tf_dir")
    result=$("$TF_BIN" -chdir="$tf_dir" init -backend=false -input=false -no-color 2>&1 && \
              "$TF_BIN" -chdir="$tf_dir" validate -no-color -json 2>/dev/null || echo '{"valid":false,"error_count":1}')
    validate_valid=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('valid',False))" 2>/dev/null || echo "false")
    if [ "$validate_valid" != "True" ] && [ "$validate_valid" != "true" ]; then
      validate_errors+=("$tf_dir")
      VALIDATE_EXIT=1
    fi
  done < <(find "$REPO_ROOT" -name "*.tf" -not -path "*/.git/*" -not -path "*/.terraform/*" | xargs -I{} dirname {} | sort -u)
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

output = {
    'repository': {'name': repo_name},
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
}

print(json.dumps(output, indent=2, ensure_ascii=False, default=str))
PYTHON
