#!/usr/bin/env bash
# collect-workflow-actions.sh
#
# Scans all GitHub Actions workflow files for 'uses:' references and checks
# whether each is pinned to a tag or SHA.
# Output feeds OPA policy check: SUP-001 (GitHub Actions context).
#
# Usage: ./collect-workflow-actions.sh [repo-root]
# Output: YAML to stdout

set -euo pipefail

REPO_ROOT="${1:-.}"
REPO_NAME=$(basename "$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$REPO_ROOT")")

python3 - "$REPO_ROOT" "$REPO_NAME" <<'PYTHON'
import sys, os, re, json
from pathlib import Path

repo_root = Path(sys.argv[1])
repo_name = sys.argv[2]

workflow_files = []
workflow_files_detail = []
action_references = []

workflows_dir = repo_root / '.github' / 'workflows'
if workflows_dir.exists():
    for wf_path in workflows_dir.glob('*.yml'):
        wf_rel = str(wf_path.relative_to(repo_root))
        workflow_files.append(wf_rel)
        
        try:
            content = wf_path.read_text(encoding='utf-8')
        except Exception:
            continue
        
        lines = content.split('\n')
        for i, line in enumerate(lines, 1):
            # Match 'uses: owner/repo@ref' or 'uses: docker://image'
            match = re.search(r'\buses\s*:\s*([^\s#]+)', line)
            if not match:
                continue
            
            uses_value = match.group(1).strip()
            if not uses_value or uses_value.startswith('.'):
                continue  # skip local actions
            
            # Determine pin type
            if '@' in uses_value:
                ref = uses_value.split('@')[-1]
                # SHA: 40 hex chars
                if re.match(r'^[a-f0-9]{40}$', ref):
                    pin_type = 'sha'
                    pinned = True
                # Tag: starts with v or contains dots/digits
                elif re.match(r'^v?\d', ref) or '.' in ref:
                    pin_type = 'tag'
                    pinned = True
                else:
                    pin_type = 'branch'
                    pinned = False
            else:
                pin_type = 'none'
                pinned = False
            
            # Get step name context (look backwards for 'name:')
            step_name = f'line-{i}'
            for j in range(i-2, max(i-10, 0), -1):
                name_match = re.search(r'\bname\s*:\s*(.+)', lines[j])
                if name_match:
                    step_name = name_match.group(1).strip()
                    break
            
            action_references.append({
                'workflow': wf_rel,
                'step': step_name,
                'uses': uses_value,
                'pinned': pinned,
                'pin_type': pin_type
            })

        # ── Parse top-level permissions block (SEC-004) ────────────────────
        try:
            import yaml as _yaml
            wf_data = _yaml.safe_load(content) or {}
        except Exception:
            wf_data = {}

        # Detect if this is a reusable workflow (called via workflow_call)
        triggers = wf_data.get('on', {})
        is_reusable = False
        if isinstance(triggers, dict):
            is_reusable = 'workflow_call' in triggers
        elif isinstance(triggers, list):
            is_reusable = 'workflow_call' in triggers

        top_perms = wf_data.get('permissions', None)
        # Analyse top-level permissions
        if top_perms is None:
            perms_declared = False
            top_level_write = True  # GitHub default grants write to many scopes
            top_level_read_only = False
        elif top_perms == 'read-all':
            perms_declared = True
            top_level_write = False
            top_level_read_only = True
        elif top_perms == 'write-all':
            perms_declared = True
            top_level_write = True
            top_level_read_only = False
        elif isinstance(top_perms, dict):
            perms_declared = True
            write_vals = [v for v in top_perms.values() if v == 'write']
            top_level_write = len(write_vals) > 0
            top_level_read_only = not top_level_write
        else:
            perms_declared = False
            top_level_write = True
            top_level_read_only = False

        workflow_files_detail.append({
            'path': wf_rel,
            'top_level_permissions': top_perms,
            'permissions_declared': perms_declared,
            'top_level_has_write': top_level_write,
            'top_level_read_only': top_level_read_only,
            'is_reusable': is_reusable,
        })

output = {
    'repository': {'name': repo_name},
    'workflow_files': workflow_files,
    'workflow_files_detail': workflow_files_detail,
    'action_references': action_references
}

print(json.dumps(output, indent=2, ensure_ascii=False, default=str))
PYTHON
