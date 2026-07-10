package scaffold_test

import (
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/ashuangiras/platform-compliance/forge/pkg/scaffold"
)

func complianceRoot(t *testing.T) string {
	t.Helper()
	_, thisFile, _, _ := runtime.Caller(0)
	root := filepath.Join(filepath.Dir(thisFile), "..", "..", "..", "..")
	abs, _ := filepath.Abs(root)
	return abs
}

func defaultVars() scaffold.TemplateVars {
	return scaffold.TemplateVars{
		RepoName:      "my-service",
		RepoType:      "service",
		OwnerOrg:      "acme-corp",
		ComplianceRef: "v2.7.0",
		ProfileID:     "PROF-SERVICE-V1",
		Profiles:      []string{"PROF-SERVICE-V1"},
		TechContexts:  []string{"github", "github-actions", "go"},
		Date:          "2026-07-10",
	}
}

func TestRenderTemplate_ComplianceManifest(t *testing.T) {
	vars := defaultVars()
	out, err := scaffold.RenderTemplate("repo/compliance-manifest.yaml.tmpl", vars)
	if err != nil {
		t.Fatalf("RenderTemplate error: %v", err)
	}
	content := string(out)

	checks := []string{
		"name: my-service",
		"url: \"https://github.com/acme-corp/my-service\"",
		"type: service",
		"PROF-SERVICE-V1",
		"github",
		"last_updated: \"2026-07-10\"",
	}
	for _, check := range checks {
		if !strings.Contains(content, check) {
			t.Errorf("manifest missing %q:\n%s", check, content)
		}
	}
}

func TestRenderTemplate_ForgeYaml(t *testing.T) {
	vars := defaultVars()
	out, err := scaffold.RenderTemplate("repo/forge-yaml.tmpl", vars)
	if err != nil {
		t.Fatalf("RenderTemplate error: %v", err)
	}
	content := string(out)

	if !strings.Contains(content, `compliance_ref: "v2.7.0"`) {
		t.Errorf("forge.yaml missing compliance_ref:\n%s", content)
	}
	if !strings.Contains(content, `profile: "PROF-SERVICE-V1"`) {
		t.Errorf("forge.yaml missing profile:\n%s", content)
	}
}

func TestRenderTemplate_PullRequestTemplate(t *testing.T) {
	vars := defaultVars()
	out, err := scaffold.RenderTemplate("repo/pull_request_template.md.tmpl", vars)
	if err != nil {
		t.Fatalf("RenderTemplate error: %v", err)
	}
	content := string(out)

	if !strings.Contains(content, "AGT-014") {
		t.Error("PR template should reference AGT-014")
	}
	if !strings.Contains(content, "Retrospective") {
		t.Error("PR template should have Retrospective section")
	}
}

func TestRenderRepoFiles_WithoutAgents(t *testing.T) {
	vars := defaultVars()
	files, err := scaffold.RenderRepoFiles(vars, false, "")
	if err != nil {
		t.Fatalf("RenderRepoFiles error: %v", err)
	}

	expected := map[string]bool{
		".compliance-manifest.yaml":        false,
		"CODEOWNERS":                       false,
		".github/pull_request_template.md": false,
		".forge.yaml":                      false,
	}
	for _, f := range files {
		if _, ok := expected[f.RepoPath]; ok {
			expected[f.RepoPath] = true
		}
		if len(f.Content) == 0 {
			t.Errorf("file %s has empty content", f.RepoPath)
		}
	}
	for path, found := range expected {
		if !found {
			t.Errorf("expected file %s not rendered", path)
		}
	}
	// Should not include vscode settings without --with-agents
	for _, f := range files {
		if strings.Contains(f.RepoPath, ".vscode") {
			t.Errorf("unexpected .vscode file without --with-agents: %s", f.RepoPath)
		}
	}
}

func TestRenderRepoFiles_WithAgents(t *testing.T) {
	root := complianceRoot(t)
	agentDir := filepath.Join(root, ".github", "agents")

	vars := defaultVars()
	files, err := scaffold.RenderRepoFiles(vars, true, agentDir)
	if err != nil {
		t.Fatalf("RenderRepoFiles error: %v", err)
	}

	// Should include vscode settings
	hasVSCode := false
	hasAgent := false
	for _, f := range files {
		if f.RepoPath == ".vscode/settings.json" {
			hasVSCode = true
		}
		if strings.HasPrefix(f.RepoPath, ".github/agents/") {
			hasAgent = true
		}
	}
	if !hasVSCode {
		t.Error("expected .vscode/settings.json with --with-agents")
	}
	if !hasAgent {
		t.Error("expected at least one .github/agents/*.agent.md with --with-agents")
	}
}

func TestRenderTemplate_UnknownTemplate_Error(t *testing.T) {
	_, err := scaffold.RenderTemplate("repo/does-not-exist.tmpl", scaffold.DefaultVars())
	if err == nil {
		t.Error("expected error for unknown template")
	}
}
