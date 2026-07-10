package manifest_test

import (
	"path/filepath"
	"runtime"
	"testing"

	"github.com/ashuangiras/platform-compliance/forge/pkg/manifest"
	"github.com/ashuangiras/platform-compliance/forge/pkg/taxonomy"
)

func complianceRoot(t *testing.T) string {
	t.Helper()
	_, thisFile, _, _ := runtime.Caller(0)
	root := filepath.Join(filepath.Dir(thisFile), "..", "..", "..", "..")
	abs, _ := filepath.Abs(root)
	return abs
}

func TestRead_RealManifest(t *testing.T) {
	root := complianceRoot(t)
	path := filepath.Join(root, ".compliance-manifest.yaml")

	m, err := manifest.Read(path)
	if err != nil {
		t.Fatalf("Read error: %v", err)
	}
	if m.Repository.Name == "" {
		t.Error("expected repository.name to be non-empty")
	}
	if len(m.DeclaredProfiles) == 0 {
		t.Error("expected at least one declared_profile")
	}
}

func TestValidate_RealManifest_Passes(t *testing.T) {
	root := complianceRoot(t)
	path := filepath.Join(root, ".compliance-manifest.yaml")

	tax, err := taxonomy.Load(root)
	if err != nil {
		t.Fatalf("taxonomy load: %v", err)
	}

	result, err := manifest.Validate(root, path, tax)
	if err != nil {
		t.Fatalf("Validate error: %v", err)
	}
	if !result.IsValid() {
		t.Errorf("expected manifest to be valid, got errors: %v", result.Errors)
	}
}

func TestFind_FindsManifest(t *testing.T) {
	root := complianceRoot(t)
	// Start from a subdirectory — Find should walk up to root
	startDir := filepath.Join(root, "03-catalogs", "controls")

	path, err := manifest.Find(startDir)
	if err != nil {
		t.Fatalf("Find error: %v", err)
	}
	if path == "" {
		t.Error("expected a non-empty path")
	}
}
