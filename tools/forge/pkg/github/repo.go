package github

import (
	"context"
	"fmt"

	gh "github.com/google/go-github/v72/github"
)

// RepoInfo holds key repository metadata returned after creation or lookup.
type RepoInfo struct {
	FullName      string
	HTMLURL       string
	CloneURL      string
	SSHURL        string
	DefaultBranch string
	Private       bool
}

// CreateRepoOptions controls how a new repository is created.
type CreateRepoOptions struct {
	Name        string
	Org         string // defaults to client.defaultOrg
	Description string
	Private     bool
	AutoInit    bool // create with an initial empty commit so branch exists
}

// isUserAccount returns true when the given login belongs to a personal (User)
// account rather than an Organisation. go-github's Repositories.Create must
// receive an empty string for personal accounts (routes to POST /user/repos);
// passing the username sends it to POST /orgs/{login}/repos which returns 404.
func (c *Client) isUserAccount(ctx context.Context, login string) (bool, error) {
	u, _, err := c.inner.Users.Get(ctx, login)
	if err != nil {
		return false, fmt.Errorf("github: lookup account type for %s: %w", login, err)
	}
	return u.GetType() == "User", nil
}

// CreateRepo creates a new GitHub repository under the given org/user.
func (c *Client) CreateRepo(ctx context.Context, opts CreateRepoOptions) (*RepoInfo, error) {
	owner := c.org(opts.Org)
	req := &gh.Repository{
		Name:        gh.Ptr(opts.Name),
		Description: gh.Ptr(opts.Description),
		Private:     gh.Ptr(opts.Private),
		AutoInit:    gh.Ptr(opts.AutoInit),
	}

	// go-github routes to POST /orgs/{owner}/repos when owner is non-empty.
	// For personal accounts that endpoint returns 404; pass "" instead so it
	// uses POST /user/repos.
	createOwner := owner
	if owner != "" {
		isUser, err := c.isUserAccount(ctx, owner)
		if err != nil {
			return nil, err
		}
		if isUser {
			createOwner = ""
		}
	}

	repo, _, err := c.inner.Repositories.Create(ctx, createOwner, req)
	if err != nil {
		return nil, fmt.Errorf("github: create repo %s/%s: %w", owner, opts.Name, err)
	}
	return toRepoInfo(repo), nil
}

// GetRepo fetches metadata for an existing repository.
func (c *Client) GetRepo(ctx context.Context, owner, name string) (*RepoInfo, error) {
	o := c.org(owner)
	repo, _, err := c.inner.Repositories.Get(ctx, o, name)
	if err != nil {
		return nil, fmt.Errorf("github: get repo %s/%s: %w", o, name, err)
	}
	return toRepoInfo(repo), nil
}

// RepoExists returns true if the repository already exists.
func (c *Client) RepoExists(ctx context.Context, owner, name string) (bool, error) {
	o := c.org(owner)
	_, _, err := c.inner.Repositories.Get(ctx, o, name)
	if err != nil {
		if isNotFound(err) {
			return false, nil
		}
		return false, fmt.Errorf("github: check repo %s/%s: %w", o, name, err)
	}
	return true, nil
}

func toRepoInfo(r *gh.Repository) *RepoInfo {
	info := &RepoInfo{}
	if r.FullName != nil {
		info.FullName = *r.FullName
	}
	if r.HTMLURL != nil {
		info.HTMLURL = *r.HTMLURL
	}
	if r.CloneURL != nil {
		info.CloneURL = *r.CloneURL
	}
	if r.SSHURL != nil {
		info.SSHURL = *r.SSHURL
	}
	if r.DefaultBranch != nil {
		info.DefaultBranch = *r.DefaultBranch
	}
	if r.Private != nil {
		info.Private = *r.Private
	}
	return info
}
