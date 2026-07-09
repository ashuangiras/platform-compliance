#!/usr/bin/env bash
# collect-dockerfile-info.sh
#
# Parses all Dockerfiles in the repository and outputs structured YAML
# suitable as input for OPA policy checks: RUN-001, RUN-002, SUP-002, OBS-001.
#
# Usage: ./collect-dockerfile-info.sh [repo-root]
# Output: YAML to stdout

set -euo pipefail

REPO_ROOT="${1:-.}"
REPO_NAME=$(basename "$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$REPO_ROOT")")

python3 - "$REPO_ROOT" "$REPO_NAME" <<'PYTHON'
import sys, os, re, json
from pathlib import Path

repo_root = Path(sys.argv[1])
repo_name = sys.argv[2]

dockerfiles = []
image_references = []

# Find all Dockerfiles
for df_path in repo_root.rglob('Dockerfile*'):
    if '.git' in str(df_path):
        continue
    rel_path = str(df_path.relative_to(repo_root))
    
    try:
        content = df_path.read_text(encoding='utf-8')
    except Exception:
        continue
    
    lines = content.split('\n')
    instructions = []
    user_value = ''
    user_before_entrypoint = False
    found_user = False
    found_entrypoint = False
    healthcheck_present = False
    
    for i, line in enumerate(lines, 1):
        stripped = line.strip().upper()
        if not stripped or stripped.startswith('#'):
            continue
        
        parts = line.strip().split(None, 1)
        instr = parts[0].upper()
        value = parts[1] if len(parts) > 1 else ''
        
        instructions.append({'instruction': instr, 'value': value, 'line': i})
        
        if instr == 'USER':
            user_value = value.strip()
            found_user = True
            if not found_entrypoint:
                user_before_entrypoint = True
        elif instr in ('ENTRYPOINT', 'CMD'):
            found_entrypoint = True
        elif instr == 'HEALTHCHECK' and value.upper() != 'NONE':
            healthcheck_present = True
    
    user_is_root = user_value.lower() in ('root', '0', '')
    
    dockerfiles.append({
        'path': rel_path,
        'instructions': instructions,
        'user_value': user_value,
        'user_before_entrypoint': user_before_entrypoint,
        'user_is_root': user_is_root,
        'healthcheck_present': healthcheck_present,
    })
    
    # Find all FROM image references
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.upper().startswith('FROM '):
            ref = stripped[5:].split()[0]  # FROM <image> [AS name]
            if ref.upper() == 'SCRATCH':
                continue
            is_digest = '@sha256:' in ref
            tag = ''
            if ':' in ref and not is_digest:
                tag = ref.split(':')[-1]
            image_references.append({
                'file': rel_path,
                'line': i,
                'reference': ref,
                'tag': tag,
                'is_digest': is_digest
            })

# Also scan docker-compose files
for compose_path in list(repo_root.rglob('docker-compose*.yml')) + list(repo_root.rglob('docker-compose*.yaml')):
    if '.git' in str(compose_path):
        continue
    try:
        compose = json.loads(__import__("subprocess").check_output(["python3", "-c", f"import yaml,json; print(json.dumps(yaml.safe_load(open(\"{compose_path}\"))))"], text=True))
    except Exception:
        continue
    if not isinstance(compose, dict):
        continue
    rel_path = str(compose_path.relative_to(repo_root))
    for svc_name, svc in (compose.get('services') or {}).items():
        if not isinstance(svc, dict):
            continue
        image = svc.get('image', '')
        if not image:
            continue
        is_digest = '@sha256:' in image
        tag = image.split(':')[-1] if ':' in image and not is_digest else ''
        image_references.append({
            'file': rel_path,
            'line': 0,
            'reference': image,
            'tag': tag,
            'is_digest': is_digest
        })

output = {
    'repository': {'name': repo_name},
    'dockerfiles': dockerfiles,
    'image_references': image_references
}

print(json.dumps(output, indent=2, ensure_ascii=False, default=str))
PYTHON
