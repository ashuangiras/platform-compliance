package taxonomy_test

import (
	"path/filepath"
	"runtime"
	"testing"

	"github.com/ashuangiras/platform-compliance/forge/pkg/taxonomy"
)

func complianceRoot(t *testing.T) string {
	t.Helper()
	_, thisFile, _, _ := runtime.Caller(0)
	root := filepath.Join(filepath.Dir(thisFile), "..", "..", "..", "..")
	abs, _ := filepath.Abs(root)
	return abs
}

func TestLoad_RealTaxonomy(t *testing.T) {
	root := complianceRoot(t)
	tax, err := taxonomy.Load(root)
	if err != nil {
		t.Fatalf("Load error: %v", err)
	}

	// Domains
	if len(tax.ControlDomains) == 0 {
		t.Error("expected control domains to be loaded")
	}
	for _, code := range []string{"SEC", "QUA", "TST", "AGT", "SRC", "IAC"} {
		if !tax.IsValidDomain(code) {
			t.Errorf("expected domain %q to be registered", code)
		}
	}

	// Contexts
	if len(tax.TechnologyContexts) == 0 {
		t.Error("expected technology contexts to be loaded")
	}
	for _, ctx := range []string{"github", "go", "node", "python", "frontend", "agent"} {
		if !tax.IsValidContext(ctx) {
			t.Errorf("expected context %q to be registered", ctx)
		}
	}

	// Repo types
	if len(tax.RepositoryTypes) == 0 {
		t.Error("expected repository types to be loaded")
	}
	for _, rt := range []string{"service", "library", "terraform-module", "frontend-app"} {
		if !tax.IsValidRepoType(rt) {
			t.Errorf("expected repo type %q to be registered", rt)
		}
	}
}

func TestIsValidDomain_Unknown(t *testing.T) {
	root := complianceRoot(t)
	tax, _ := taxonomy.Load(root)
	if tax.IsValidDomain("NOTADOMAIN") {
		t.Error("expected unknown domain to return false")
	}
}
