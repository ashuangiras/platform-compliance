package github

import (
	"context"
	"fmt"

	gh "github.com/google/go-github/v72/github"
)

// FileToCommit describes a single file to create or update in a repository.
type FileToCommit struct {
	Path    string // repository-relative path e.g. ".compliance-manifest.yaml"
	Content []byte // file content
}

// CommitFiles creates or updates multiple files in a single commit on the given branch.
// All files are committed atomically using the GitHub Contents API sequential calls.
// For an AutoInit repo, the initial commit SHA is fetched automatically.
func (c *Client) CommitFiles(ctx context.Context, owner, repo, branch, message string, files []FileToCommit) error {
	o := c.org(owner)

	for _, f := range files {
		// Check if file exists to decide create vs update
		existing, _, _, err := c.inner.Repositories.GetContents(ctx, o, repo, f.Path,
			&gh.RepositoryContentGetOptions{Ref: branch})

		opts := &gh.RepositoryContentFileOptions{
			Message: gh.Ptr(message),
			Content: f.Content,
			Branch:  gh.Ptr(branch),
		}

		if err == nil && existing != nil {
			// File exists — update it
			opts.SHA = existing.SHA
			_, _, err = c.inner.Repositories.UpdateFile(ctx, o, repo, f.Path, opts)
		} else if isNotFound(err) || err != nil {
			// File does not exist — create it
			_, _, err = c.inner.Repositories.CreateFile(ctx, o, repo, f.Path, opts)
		}

		if err != nil {
			return fmt.Errorf("github: commit %s to %s/%s: %w", f.Path, o, repo, err)
		}
	}
	return nil
}

// GetDefaultBranch returns the default branch name for a repository.
func (c *Client) GetDefaultBranch(ctx context.Context, owner, repo string) (string, error) {
	o := c.org(owner)
	r, _, err := c.inner.Repositories.Get(ctx, o, repo)
	if err != nil {
		return "", fmt.Errorf("github: get default branch %s/%s: %w", o, repo, err)
	}
	if r.DefaultBranch == nil {
		return "main", nil
	}
	return *r.DefaultBranch, nil
}
