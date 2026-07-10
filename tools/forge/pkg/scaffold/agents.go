package scaffold

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// RenderAgentStubs renders type-appropriate agent stub files from embedded
// templates. Templates live at:
//
//	templates/repo/agents/<repoType>/*.agent.md.tmpl
//
// If no stubs exist for repoType, falls back to templates/repo/agents/_default/.
// Returns an empty slice (no error) when neither directory is present.
func RenderAgentStubs(vars TemplateVars, repoType string) ([]RepoFile, error) {
	dirs := []string{
		"templates/repo/agents/" + repoType,
		"templates/repo/agents/fallback",
	}

	var chosen string
	for _, dir := range dirs {
		if entries, err := templateFS.ReadDir(dir); err == nil && len(entries) > 0 {
			chosen = dir
			break
		}
	}
	if chosen == "" {
		return nil, nil // no stubs for this type; caller may try copyAgentFiles
	}

	entries, err := templateFS.ReadDir(chosen)
	if err != nil {
		return nil, fmt.Errorf("scaffold: read agent stubs dir %s: %w", chosen, err)
	}

	var files []RepoFile
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".agent.md.tmpl") {
			continue
		}
		tmplPath := chosen + "/" + e.Name()
		// Strip leading "templates/" so RenderTemplate can find it
		relPath := strings.TrimPrefix(tmplPath, "templates/")
		content, err := RenderTemplate(relPath, vars)
		if err != nil {
			return nil, fmt.Errorf("scaffold: render agent stub %s: %w", e.Name(), err)
		}
		repoPath := ".github/agents/" + strings.TrimSuffix(e.Name(), ".tmpl")
		files = append(files, RepoFile{RepoPath: repoPath, Content: content})
	}
	return files, nil
}

// copyAgentFiles reads all *.agent.md files from agentSourceDir and returns
// them as RepoFiles destined for .github/agents/ in the new repository.
// Used only for platform-repo type, which replicates the live governance team.
func copyAgentFiles(agentSourceDir string) ([]RepoFile, error) {
	entries, err := os.ReadDir(agentSourceDir)
	if err != nil {
		return nil, fmt.Errorf("scaffold: read agent dir %s: %w", agentSourceDir, err)
	}

	var files []RepoFile
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		// Copy .agent.md files and the copilot-instructions.md
		if !strings.HasSuffix(name, ".agent.md") && name != "copilot-instructions.md" {
			continue
		}
		path := filepath.Join(agentSourceDir, name)
		content, err := os.ReadFile(path)
		if err != nil {
			return nil, fmt.Errorf("scaffold: read agent file %s: %w", path, err)
		}
		files = append(files, RepoFile{
			RepoPath: ".github/agents/" + name,
			Content:  content,
		})
	}
	return files, nil
}
