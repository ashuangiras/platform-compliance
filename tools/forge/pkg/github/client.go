// Package github provides an authenticated GitHub API client for forge operations.
package github

import (
	"context"
	"fmt"
	"net/http"
	"os"

	gh "github.com/google/go-github/v72/github"
	"golang.org/x/oauth2"
)

// Client wraps the go-github client with forge-specific defaults.
type Client struct {
	inner      *gh.Client
	defaultOrg string
}

// New creates an authenticated GitHub client from a personal access token.
func New(token, defaultOrg string) *Client {
	ts := oauth2.StaticTokenSource(&oauth2.Token{AccessToken: token})
	tc := oauth2.NewClient(context.Background(), ts)
	return &Client{
		inner:      gh.NewClient(tc),
		defaultOrg: defaultOrg,
	}
}

// FromEnv creates a client from GITHUB_TOKEN or FORGE_GITHUB_TOKEN env var.
func FromEnv(defaultOrg string) (*Client, error) {
	token := os.Getenv("FORGE_GITHUB_TOKEN")
	if token == "" {
		token = os.Getenv("GITHUB_TOKEN")
	}
	if token == "" {
		return nil, fmt.Errorf("github: GITHUB_TOKEN or FORGE_GITHUB_TOKEN must be set")
	}
	return New(token, defaultOrg), nil
}

// org returns the owner to use, preferring provided value over the default.
func (c *Client) org(owner string) string {
	if owner != "" {
		return owner
	}
	return c.defaultOrg
}

// isNotFound returns true if err is a GitHub 404 response.
func isNotFound(err error) bool {
	if err == nil {
		return false
	}
	if re, ok := err.(*gh.ErrorResponse); ok {
		return re.Response.StatusCode == http.StatusNotFound
	}
	return false
}
