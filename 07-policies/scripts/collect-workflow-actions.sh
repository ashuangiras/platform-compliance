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

output = {
    'repository': {'name': repo_name},
    'workflow_files': workflow_files,
    'action_references': action_references
}

print(json.dumps(output, indent=2, ensure_ascii=False, default=str))
PYTHON
