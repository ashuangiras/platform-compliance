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

func TestRenderRepoFiles_WithoutAgentFiles(t *testing.T) {
	vars := defaultVars()
	files, err := scaffold.RenderRepoFiles(vars, false, "")
	if err != nil {
		t.Fatalf("RenderRepoFiles error: %v", err)
	}

	expected := map[string]bool{
		".compliance-manifest.yaml":             false,
		"CODEOWNERS":                            false,
		".github/pull_request_template.md":      false,
		".forge.yaml":                           false,
		".github/workflows/compliance.yml":      false,
		".github/copilot-instructions.md":       false,
		".vscode/settings.json":                 false,
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
	// Agent files should not be present without withAgents=true
	for _, f := range files {
		if strings.HasPrefix(f.RepoPath, ".github/agents/") {
			t.Errorf("unexpected agent file without withAgents: %s", f.RepoPath)
		}
	}
}

func TestRenderRepoFiles_WithAgents(t *testing.T) {
	root := complianceRoot(t)
	agentDir := filepath.Join(root, ".github", "agents")

	// For service type: should use embedded stubs (not copy from agentDir)
	vars := defaultVars() // RepoType = "service"
	files, err := scaffold.RenderRepoFiles(vars, true, agentDir)
	if err != nil {
		t.Fatalf("RenderRepoFiles error: %v", err)
	}

	fileSet := make(map[string]bool, len(files))
	for _, f := range files {
		fileSet[f.RepoPath] = true
	}

	alwaysExpected := []string{
		".vscode/settings.json",
		".github/workflows/compliance.yml",
		".github/copilot-instructions.md",
	}
	for _, path := range alwaysExpected {
		if !fileSet[path] {
			t.Errorf("expected always-rendered file %s not found with withAgents=true", path)
		}
	}

	// Agent files should be present when withAgents=true
	hasAgent := false
	for _, f := range files {
		if strings.HasPrefix(f.RepoPath, ".github/agents/") {
			hasAgent = true
			break
		}
	}
	if !hasAgent {
		t.Error("expected at least one .github/agents/*.agent.md with --with-agents")
	}
}

func TestRenderAgentStubs_TerraformModule(t *testing.T) {
	vars := scaffold.TemplateVars{
		RepoName:      "my-modules",
		RepoType:      "terraform-module",
		OwnerOrg:      "acme",
		ComplianceRef: "v3.3.2",
		ProfileID:     "PROF-TERRAFORM-MODULE-V1",
		ComplianceOrg: "acme",
	}
	files, err := scaffold.RenderAgentStubs(vars, "terraform-module")
	if err != nil {
		t.Fatalf("RenderAgentStubs error: %v", err)
	}
	if len(files) == 0 {
		t.Fatal("expected agent stubs for terraform-module, got none")
	}

	names := make(map[string]bool, len(files))
	for _, f := range files {
		names[f.RepoPath] = true
		if len(f.Content) == 0 {
			t.Errorf("agent stub %s has empty content", f.RepoPath)
		}
		// Every stub must be in .github/agents/ and end with .agent.md
		if !strings.HasPrefix(f.RepoPath, ".github/agents/") {
			t.Errorf("unexpected path for agent stub: %s", f.RepoPath)
		}
		if !strings.HasSuffix(f.RepoPath, ".agent.md") {
			t.Errorf("agent stub path should end in .agent.md: %s", f.RepoPath)
		}
		// Template vars must be resolved — no raw {{ }} in output
		if strings.Contains(string(f.Content), "{{") {
			t.Errorf("agent stub %s contains unresolved template vars", f.RepoPath)
		}
		// Repo name and org must appear
		if !strings.Contains(string(f.Content), "my-modules") && !strings.Contains(string(f.Content), "acme") {
			t.Errorf("agent stub %s does not reference repo name or org", f.RepoPath)
		}
	}

	// Verify the full expected team is scaffolded
	expected := []string{
		".github/agents/module-router.agent.md",
		".github/agents/module-author.agent.md",
		".github/agents/compliance-gate.agent.md",
		".github/agents/pr-engineer.agent.md",
		".github/agents/module-reviewer.agent.md",
		".github/agents/module-qa.agent.md",
	}
	for _, path := range expected {
		if !names[path] {
			t.Errorf("expected agent stub %s not found in output", path)
		}
	}
}

func TestRenderAgentStubs_ServiceType(t *testing.T) {
	vars := scaffold.TemplateVars{
		RepoName:      "my-service",
		RepoType:      "service",
		OwnerOrg:      "acme",
		ComplianceRef: "v3.3.2",
		ProfileID:     "PROF-SERVICE-V1",
		ComplianceOrg: "acme",
	}
	files, err := scaffold.RenderAgentStubs(vars, "service")
	if err != nil {
		t.Fatalf("RenderAgentStubs error: %v", err)
	}
	if len(files) == 0 {
		t.Fatal("expected agent stubs for service, got none")
	}
	for _, f := range files {
		if strings.Contains(string(f.Content), "{{") {
			t.Errorf("agent stub %s contains unresolved template vars", f.RepoPath)
		}
	}
}

func TestRenderAgentStubs_DefaultFallback(t *testing.T) {
	vars := scaffold.TemplateVars{
		RepoName:      "my-docs",
		RepoType:      "documentation",
		OwnerOrg:      "acme",
		ComplianceRef: "v3.3.2",
		ProfileID:     "PROF-PLATFORM-V1",
		ComplianceOrg: "acme",
	}
	// "documentation" has no specific stubs — should fall back to fallback/
	files, err := scaffold.RenderAgentStubs(vars, "documentation")
	if err != nil {
		t.Fatalf("RenderAgentStubs error: %v", err)
	}
	if len(files) == 0 {
		t.Fatal("expected _default fallback stubs for documentation type, got none")
	}
}

func TestRenderRepoFiles_PlatformRepoCopiesFromSource(t *testing.T) {
	root := complianceRoot(t)
	agentDir := filepath.Join(root, ".github", "agents")

	vars := scaffold.TemplateVars{
		RepoName:      "another-governance-repo",
		RepoType:      "platform-repo",
		OwnerOrg:      "acme",
		ComplianceRef: "v3.3.2",
		ProfileID:     "PROF-PLATFORM-V1",
		ComplianceOrg: "acme",
		TechContexts:  []string{"github", "github-actions"},
		Date:          "2026-07-11",
	}
	files, err := scaffold.RenderRepoFiles(vars, true, agentDir)
	if err != nil {
		t.Fatalf("RenderRepoFiles error: %v", err)
	}

	// platform-repo should copy the real governance agents from .github/agents/
	agentCount := 0
	for _, f := range files {
		if strings.HasPrefix(f.RepoPath, ".github/agents/") {
			agentCount++
		}
	}
	if agentCount == 0 {
		t.Error("platform-repo should copy agent files from compliance dir")
	}
}

func TestRenderTemplate_UnknownTemplate_Error(t *testing.T) {
	_, err := scaffold.RenderTemplate("repo/does-not-exist.tmpl", scaffold.DefaultVars())
	if err == nil {
		t.Error("expected error for unknown template")
	}
}
