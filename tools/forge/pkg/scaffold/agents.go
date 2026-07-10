package scaffold

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// copyAgentFiles reads all *.agent.md files from agentSourceDir and returns
// them as RepoFiles destined for .github/agents/ in the new repository.
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
