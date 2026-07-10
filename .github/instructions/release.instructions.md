---
description: "Use when merging a PR, cutting a release/tag, updating CHANGELOG.md, allocating a Change Record (CHG-YYYYMMDD-NNN), or performing the single-developer bootstrap-merge for platform-compliance. Covers the exact branch-protection toggle sequence and release verification."
---
# Release & Merge Process

`main` is protected (1 review + CODEOWNERS + `Compliance: Merge Gate`). As a single developer
we use a **bootstrap merge**: temporarily drop the required review count to 0, squash-merge,
then restore protection. `enforce_admins` stays on; the merge gate is always posted as passing
only after CI is genuinely green.

## Pre-flight

- CI (`self-compliance.yml`) is fully green on the PR.
- `CHANGELOG.md` has an entry under the correct version (never leave changes only in a stale
  `Unreleased`). Cite the Change Record.
- Allocate the next Change Record `CHG-YYYYMMDD-NNN` (increment the last used number).

## Bootstrap-merge sequence

```bash
PR=<n>; REPO=ashuangiras/platform-compliance
PR_SHA=$(gh api repos/$REPO/pulls/$PR --jq '.head.sha')
gh api repos/$REPO/statuses/$PR_SHA --method POST --input - <<< '{"state":"success","context":"Compliance: Merge Gate","description":"all gates pass"}'
echo '{"required_status_checks":{"strict":true,"contexts":["Compliance: Merge Gate"]},"enforce_admins":true,"required_pull_request_reviews":{"required_approving_review_count":0,"dismiss_stale_reviews":true},"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}' | gh api repos/$REPO/branches/main/protection --method PUT --input -
gh pr merge $PR --squash --subject "<conventional-commit subject>"
echo '{"required_status_checks":{"strict":true,"contexts":["Compliance: Merge Gate"]},"enforce_admins":true,"required_pull_request_reviews":{"required_approving_review_count":1,"dismiss_stale_reviews":true,"require_code_owner_reviews":true},"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}' | gh api repos/$REPO/branches/main/protection --method PUT --input -
git checkout main && git pull --rebase origin main
```

## Cutting a release

```bash
git tag -a vX.Y.Z -m "vX.Y.Z — <summary>"
git push origin vX.Y.Z
gh release view vX.Y.Z --repo ashuangiras/platform-compliance --json tagName,assets \
  --jq '{tag: .tagName, assets: [.assets[].name]}'   # expect policies.tar.gz(+.sha256), sbom.cdx.json
```

## Post-flight

- Verify the release has all three assets.
- Confirm protection is restored to `required_approving_review_count: 1` +
  `require_code_owner_reviews: true`.
- Mark the corresponding tracker task(s) done under `docs/implementation/tasks/`.
