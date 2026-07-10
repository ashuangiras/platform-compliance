// Package scaffold renders governance object templates for new repositories and
// governance object authoring.
package scaffold

import (
	"bytes"
	"embed"
	"fmt"
	"strings"
	"text/template"
	"time"
)

//go:embed templates
var templateFS embed.FS

// TemplateVars holds the values injected into all scaffold templates.
type TemplateVars struct {
	// Repository-level
	RepoName string
	RepoType string
	OwnerOrg string

	// Compliance
	ComplianceRef string
	ComplianceOrg string
	ProfileID     string
	Profiles      []string // declared_profiles list (includes ProfileID + overlays)
	TechContexts  []string

	// Dates
	Date string // YYYY-MM-DD

	// Control authoring
	ControlID     string
	ControlDomain string
	ControlTitle  string

	// ADR
	ADRID    string
	ADRTitle string
	ADRSlug  string

	// Waiver
	WaiverID           string
	ControlIDForWaiver string
}

// DefaultVars returns a TemplateVars with the Date field set to today.
func DefaultVars() TemplateVars {
	return TemplateVars{
		Date: time.Now().UTC().Format("2006-01-02"),
	}
}

// RenderTemplate renders a named template (relative to the templates/ embed root) with vars.
func RenderTemplate(name string, vars TemplateVars) ([]byte, error) {
	path := "templates/" + name
	data, err := templateFS.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("scaffold: template %s not found: %w", name, err)
	}

	tmpl, err := template.New(name).Funcs(template.FuncMap{
		"TechContextsStr": func(ctxs []string) string {
			return strings.Join(ctxs, ",")
		},
	}).Parse(string(data))
	if err != nil {
		return nil, fmt.Errorf("scaffold: parse template %s: %w", name, err)
	}

	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, vars); err != nil {
		return nil, fmt.Errorf("scaffold: render template %s: %w", name, err)
	}
	return buf.Bytes(), nil
}

// RepoFile represents one file to be committed to a new repository.
type RepoFile struct {
	// RepoPath is the path relative to the repository root.
	RepoPath string
	// Content is the rendered file content.
	Content []byte
}

// RenderRepoFiles renders all files required for a new governed repository.
// withAgents=true also renders the agent operating layer files.
// agentSourceDir is the path to .github/agents/ in the local compliance dir
// (used to copy agent files verbatim).
func RenderRepoFiles(vars TemplateVars, withAgents bool, agentSourceDir string) ([]RepoFile, error) {
	type tmplEntry struct {
		template string
		repoPath string
	}

	entries := []tmplEntry{
		{"repo/compliance-manifest.yaml.tmpl", ".compliance-manifest.yaml"},
		{"repo/CODEOWNERS.tmpl", "CODEOWNERS"},
		{"repo/pull_request_template.md.tmpl", ".github/pull_request_template.md"},
		{"repo/forge-yaml.tmpl", ".forge.yaml"},
		{"repo/compliance-workflow.yml.tmpl", ".github/workflows/compliance.yml"},
		{"repo/copilot-instructions.md.tmpl", ".github/copilot-instructions.md"},
		{"repo/vscode-settings.json.tmpl", ".vscode/settings.json"},
	}

	var files []RepoFile
	for _, e := range entries {
		content, err := RenderTemplate(e.template, vars)
		if err != nil {
			return nil, err
		}
		files = append(files, RepoFile{RepoPath: e.repoPath, Content: content})
	}

	// Copy agent files verbatim from the local compliance directory
	if withAgents && agentSourceDir != "" {
		agentFiles, err := copyAgentFiles(agentSourceDir)
		if err != nil {
			// Non-fatal: warn but continue
			fmt.Printf("⚠  could not copy agent files from %s: %v\n", agentSourceDir, err)
		} else {
			files = append(files, agentFiles...)
		}
	}

	return files, nil
}
