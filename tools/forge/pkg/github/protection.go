package github

import (
	"context"
	"fmt"

	gh "github.com/google/go-github/v72/github"
)

// SetMergeGateProtection configures the branch protection that forge sets on
// every new repository: require PR + the "Compliance: Merge Gate" status check.
// Allows one approving review (full protection from day one).
func (c *Client) SetMergeGateProtection(ctx context.Context, owner, repo, branch string) error {
	o := c.org(owner)
	req := &gh.ProtectionRequest{
		RequiredStatusChecks: &gh.RequiredStatusChecks{
			Strict:   true,
			Contexts: &[]string{"Compliance: Merge Gate"},
		},
		RequiredPullRequestReviews: &gh.PullRequestReviewsEnforcementRequest{
			RequiredApprovingReviewCount: 1,
			RequireCodeOwnerReviews:      true,
			DismissStaleReviews:          true,
		},
		EnforceAdmins:     true,
		AllowForcePushes:  gh.Ptr(false),
		AllowDeletions:    gh.Ptr(false),
	}
	_, _, err := c.inner.Repositories.UpdateBranchProtection(ctx, o, repo, branch, req)
	if err != nil {
		return fmt.Errorf("github: set branch protection %s/%s@%s: %w", o, repo, branch, err)
	}
	return nil
}

// RelaxProtection drops the required approving review count to 0 for bootstrap-merge.
func (c *Client) RelaxProtection(ctx context.Context, owner, repo, branch string) error {
	o := c.org(owner)
	req := &gh.ProtectionRequest{
		RequiredStatusChecks: &gh.RequiredStatusChecks{
			Strict:   true,
			Contexts: &[]string{"Compliance: Merge Gate"},
		},
		RequiredPullRequestReviews: &gh.PullRequestReviewsEnforcementRequest{
			RequiredApprovingReviewCount: 0,
			DismissStaleReviews:          true,
		},
		EnforceAdmins:    true,
		AllowForcePushes: gh.Ptr(false),
		AllowDeletions:   gh.Ptr(false),
	}
	_, _, err := c.inner.Repositories.UpdateBranchProtection(ctx, o, repo, branch, req)
	if err != nil {
		return fmt.Errorf("github: relax protection %s/%s@%s: %w", o, repo, branch, err)
	}
	return nil
}

// RestoreProtection re-applies full protection after a bootstrap-merge.
func (c *Client) RestoreProtection(ctx context.Context, owner, repo, branch string) error {
	return c.SetMergeGateProtection(ctx, owner, repo, branch)
}

// PostStatus posts a commit status to a specific SHA.
// Used during bootstrap-merge to satisfy the Compliance: Merge Gate check.
func (c *Client) PostStatus(ctx context.Context, owner, repo, sha, state, description, context_ string) error {
	o := c.org(owner)
	req := &gh.RepoStatus{
		State:       gh.Ptr(state),
		Description: gh.Ptr(description),
		Context:     gh.Ptr(context_),
	}
	_, _, err := c.inner.Repositories.CreateStatus(ctx, o, repo, sha, req)
	if err != nil {
		return fmt.Errorf("github: post status %s/%s@%s: %w", o, repo, sha, err)
	}
	return nil
}
