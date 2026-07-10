package new

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/ashuangiras/platform-compliance/forge/pkg/compliance"
	"github.com/ashuangiras/platform-compliance/forge/pkg/config"
	githubpkg "github.com/ashuangiras/platform-compliance/forge/pkg/github"
	"github.com/ashuangiras/platform-compliance/forge/pkg/scaffold"
	"github.com/spf13/cobra"
)

func newRepoCmd(cfg **config.Config) *cobra.Command {
	var (
		org          string
		profileID    string
		repoType     string
		contexts     []string
		withAgents   bool
		noAgents     bool
		private      bool
		dryRun       bool
		description  string
	)

	cmd := &cobra.Command{
		Use:   "repo <name>",
		Short: "Bootstrap a fully governed repository on GitHub",
		Long: `Create a new GitHub repository pre-wired with:
  - .compliance-manifest.yaml for the chosen profile
  - CODEOWNERS pointing at the platform team
  - .github/pull_request_template.md with the AGT-014 retro section
  - .forge.yaml for local forge configuration
  - Branch protection: requires PR + Compliance Merge Gate status check

Agent operating layer (.github/agents/) is included by default. Use --no-agents to skip it.
Use --dry-run to preview all files without touching GitHub.`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			repoName := args[0]
			c := *cfg

			// Resolve org
			if org == "" {
				org = c.DefaultOrg
			}
			if org == "" {
				return fmt.Errorf("forge new repo: --org is required (or set default_org in ~/.forge/config.yaml)")
			}

			// Resolve profile
			if profileID == "" {
				profileID = c.DefaultProfile
			}

			// Resolve compliance dir
			compDir := c.ComplianceDir
			if compDir == "" {
				return fmt.Errorf("forge new repo: --compliance-dir is required for Phase B.2 (remote ref fetching not yet implemented)")
			}

			// Load compliance dir
			comp, err := compliance.LoadLocal(compDir)
			if err != nil {
				return fmt.Errorf("forge new repo: %w", err)
			}

			// Validate profile exists
			if _, ok := comp.ProfilePath(profileID); !ok {
				return fmt.Errorf("forge new repo: profile %q not found in compliance dir", profileID)
			}

			// Validate repo type
			if repoType == "" {
				repoType = inferRepoType(profileID)
			}
			if !comp.Taxonomy.IsValidRepoType(repoType) {
				return fmt.Errorf("forge new repo: unknown repository type %q (valid: %s)",
					repoType, strings.Join(comp.Taxonomy.ContextSlugs(), ", "))
			}

			// Default contexts from profile
			if len(contexts) == 0 {
				contexts = defaultContexts(repoType)
			}

			// Build template vars
			vars := scaffold.DefaultVars()
			vars.RepoName = repoName
			vars.RepoType = repoType
			vars.OwnerOrg = org
			vars.ComplianceRef = c.ComplianceRef
			if vars.ComplianceRef == "" {
				vars.ComplianceRef = "local"
			}
			vars.ProfileID = profileID
			vars.Profiles = []string{profileID}
			vars.TechContexts = contexts
			vars.Date = time.Now().UTC().Format("2006-01-02")

			// --no-agents overrides --with-agents
			if noAgents {
				withAgents = false
			}

			// If withAgents is still true from its default but the "agent" technology
			// context is not in the resolved contexts list, suppress agent file
			// copying unless the user explicitly passed --with-agents on the CLI.
			if withAgents {
				agentInContexts := false
				for _, ctx := range contexts {
					if ctx == "agent" {
						agentInContexts = true
						break
					}
				}
				if !agentInContexts && !cmd.Flags().Changed("with-agents") {
					withAgents = false
				}
			}

			// Determine agent source dir
			agentSourceDir := ""
			if withAgents {
				agentSourceDir = filepath.Join(compDir, ".github", "agents")
			}

			// Render files
			files, err := scaffold.RenderRepoFiles(vars, withAgents, agentSourceDir)
			if err != nil {
				return fmt.Errorf("forge new repo: render templates: %w", err)
			}

			// Dry run: just print
			if dryRun {
				return printDryRun(repoName, org, profileID, files)
			}

			// Real mode: create repo and commit files
			return createRepo(cmd.Context(), c, org, repoName, description, profileID, private, files)
		},
	}

	cmd.Flags().StringVar(&org, "org", "", "GitHub organisation or user (default: from config)")
	cmd.Flags().StringVar(&profileID, "profile", "", "Compliance profile ID (default: PROF-SERVICE-V1)")
	cmd.Flags().StringVar(&repoType, "type", "", "Repository type from taxonomy (inferred from profile if not set)")
	cmd.Flags().StringSliceVar(&contexts, "contexts", nil, "Technology contexts (comma-separated)")
	cmd.Flags().BoolVar(&withAgents, "with-agents", true, "Include agent operating layer (.github/agents/) [default: true]")
	cmd.Flags().BoolVar(&noAgents, "no-agents", false, "Skip the agent operating layer (overrides --with-agents)")
	cmd.Flags().BoolVar(&private, "private", false, "Create as a private repository")
	cmd.Flags().BoolVar(&dryRun, "dry-run", false, "Preview files without creating the repository")
	cmd.Flags().StringVar(&description, "description", "", "Repository description")

	return cmd
}

// printDryRun shows all files that would be committed without touching GitHub.
func printDryRun(repoName, org, profileID string, files []scaffold.RepoFile) error {
	fmt.Printf("\n%s  Dry run — forge new repo %s/%s (profile: %s)\n\n",
		colYellow("▶"), org, repoName, profileID)
	fmt.Printf("  Files that would be committed:\n\n")
	for _, f := range files {
		fmt.Printf("  %s  %s (%d bytes)\n", colGreen("✓"), f.RepoPath, len(f.Content))
	}
	fmt.Printf("\n  %s  Branch protection: Compliance Merge Gate + 1 required review\n", colGreen("✓"))
	fmt.Printf("\n  Run without --dry-run to create the repository.\n\n")
	return nil
}

// createRepo creates the GitHub repository and commits all scaffold files.
func createRepo(ctx context.Context, c *config.Config, org, repoName, description, profileID string, private bool, files []scaffold.RepoFile) error {
	if c.GitHubToken == "" {
		return fmt.Errorf("forge new repo: GITHUB_TOKEN is not set")
	}

	client := githubpkg.New(c.GitHubToken, c.DefaultOrg)

	// Check if repo already exists
	exists, err := client.RepoExists(ctx, org, repoName)
	if err != nil {
		return fmt.Errorf("forge new repo: check existence: %w", err)
	}
	if exists {
		return fmt.Errorf("forge new repo: repository %s/%s already exists", org, repoName)
	}

	// Create the repository
	fmt.Printf("Creating %s/%s ... ", org, repoName)
	repo, err := client.CreateRepo(ctx, githubpkg.CreateRepoOptions{
		Name:        repoName,
		Org:         org,
		Description: description,
		Private:     private,
		AutoInit:    true, // creates initial commit so branch exists
	})
	if err != nil {
		return err
	}
	fmt.Printf("%s\n", colGreen("✓"))

	// Commit all scaffold files
	branch, err := client.GetDefaultBranch(ctx, org, repoName)
	if err != nil {
		branch = "main"
	}

	toCommit := make([]githubpkg.FileToCommit, 0, len(files))
	for _, f := range files {
		toCommit = append(toCommit, githubpkg.FileToCommit{
			Path:    f.RepoPath,
			Content: f.Content,
		})
	}

	commitMsg := fmt.Sprintf("chore(init): bootstrap governed repository (profile: %s)", profileID)
	fmt.Printf("Committing %d files to %s ... ", len(toCommit), branch)
	if err := client.CommitFiles(ctx, org, repoName, branch, commitMsg, toCommit); err != nil {
		return err
	}
	fmt.Printf("%s\n", colGreen("✓"))

	// Set branch protection
	fmt.Printf("Configuring branch protection ... ")
	if err := client.SetMergeGateProtection(ctx, org, repoName, branch); err != nil {
		fmt.Printf("%s (non-fatal: %v)\n", colYellow("⚠"), err)
	} else {
		fmt.Printf("%s\n", colGreen("✓"))
	}

	// Summary
	fmt.Printf("\n%s  Created %s\n", colGreen("✓"), repo.HTMLURL)
	fmt.Printf("  Profile:  %s\n", profileID)
	fmt.Printf("  Branch:   %s (protected: Compliance Merge Gate + 1 review)\n", branch)
	fmt.Printf("\n  Next: open a PR to trigger the first compliance workflow run.\n\n")
	return nil
}

// inferRepoType maps common profile IDs to their repository type.
func inferRepoType(profileID string) string {
	m := map[string]string{
		"PROF-SERVICE-V1":          "service",
		"PROF-GO-SERVICE-V1":       "service",
		"PROF-NODE-SERVICE-V1":     "service",
		"PROF-PYTHON-SERVICE-V1":   "service",
		"PROF-LIBRARY-V1":          "library",
		"PROF-FRONTEND-V1":         "frontend-app",
		"PROF-TERRAFORM-MODULE-V1": "terraform-module",
		"PROF-TERRAFORM-ROOT-V1":   "terraform-root",
		"PROF-PLATFORM-V1":         "platform-repo",
	}
	if rt, ok := m[profileID]; ok {
		return rt
	}
	return "service"
}

// defaultContexts returns sensible technology contexts for a repository type.
func defaultContexts(repoType string) []string {
	m := map[string][]string{
		"service":          {"github", "github-actions", "agent"},
		"library":          {"github", "github-actions", "agent"},
		"frontend-app":     {"github", "github-actions", "frontend", "agent"},
		"terraform-module": {"github", "github-actions", "terraform"},
		"terraform-root":   {"github", "github-actions", "terraform"},
		"platform-repo":    {"github", "github-actions", "agent"},
	}
	if ctxs, ok := m[repoType]; ok {
		return ctxs
	}
	return []string{"github"}
}

// Minimal colour helpers (duplicated from validate to avoid an internal dep for now).
func colGreen(s string) string {
	if !isTerminal() {
		return s
	}
	return "\033[32m" + s + "\033[0m"
}

func colYellow(s string) string {
	if !isTerminal() {
		return s
	}
	return "\033[33m" + s + "\033[0m"
}

func isTerminal() bool {
	fi, err := os.Stdout.Stat()
	if err != nil {
		return false
	}
	return (fi.Mode() & os.ModeCharDevice) != 0
}
