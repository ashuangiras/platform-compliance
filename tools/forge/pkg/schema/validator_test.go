package schema_test

import (
	"path/filepath"
	"runtime"
	"testing"

	"github.com/ashuangiras/platform-compliance/forge/pkg/schema"
)

// complianceRoot returns the absolute path to the platform-compliance root.
func complianceRoot(t *testing.T) string {
	t.Helper()
	_, thisFile, _, _ := runtime.Caller(0)
	// tools/forge/pkg/schema/validator_test.go → ../../../../
	root := filepath.Join(filepath.Dir(thisFile), "..", "..", "..", "..")
	abs, err := filepath.Abs(root)
	if err != nil {
		t.Fatalf("resolve root: %v", err)
	}
	return abs
}

func TestValidate_RealControl_Passes(t *testing.T) {
	root := complianceRoot(t)
	file := filepath.Join(root, "03-catalogs", "controls", "SEC", "SEC-001.yaml")

	result, err := schema.ValidateFile(root, file)
	if err != nil {
		t.Fatalf("ValidateFile error: %v", err)
	}
	if result.Skipped {
		t.Fatalf("file was skipped (schema not detected): %s", file)
	}
	if !result.Valid {
		t.Errorf("expected PASS, got FAIL: %v", result.Errors)
	}
}

func TestValidate_RealProfile_Passes(t *testing.T) {
	root := complianceRoot(t)
	file := filepath.Join(root, "04-profiles", "PROF-SERVICE-V1.yaml")

	result, err := schema.ValidateFile(root, file)
	if err != nil {
		t.Fatalf("ValidateFile error: %v", err)
	}
	if result.Skipped {
		t.Fatalf("file was skipped: %s", file)
	}
	if !result.Valid {
		t.Errorf("expected PASS, got FAIL: %v", result.Errors)
	}
}

func TestValidate_RealBinding_Passes(t *testing.T) {
	root := complianceRoot(t)
	file := filepath.Join(root, "06-bindings", "bindings", "go", "BIND-QUA-001-GO.yaml")

	result, err := schema.ValidateFile(root, file)
	if err != nil {
		t.Fatalf("ValidateFile error: %v", err)
	}
	if result.Skipped {
		t.Fatalf("file was skipped: %s", file)
	}
	if !result.Valid {
		t.Errorf("expected PASS, got FAIL: %v", result.Errors)
	}
}

func TestInferSchemaName_FromSchemaField(t *testing.T) {
	tests := []struct {
		content    string
		expectName string
		expectOK   bool
	}{
		{`$schema: "../../../schemas/control.schema.yaml"`, "control", true},
		{`$schema: "../schemas/profile.schema.json"`, "profile", true},
		{`$schema: "../../schemas/binding.schema.json"`, "binding", true},
		{`$schema: "../schemas/standard-source.schema.json"`, "standard-source", true},
		{`# no schema field`, "", false},
	}

	for _, tt := range tests {
		name, ok := schema.InferSchemaName("any/path.yaml", []byte(tt.content))
		if ok != tt.expectOK {
			t.Errorf("content=%q: got ok=%v want ok=%v", tt.content, ok, tt.expectOK)
			continue
		}
		if ok && name != tt.expectName {
			t.Errorf("content=%q: got name=%q want name=%q", tt.content, name, tt.expectName)
		}
	}
}

func TestInferSchemaName_FromPath(t *testing.T) {
	tests := []struct {
		path       string
		expectName string
		expectOK   bool
	}{
		{"03-catalogs/controls/SEC/SEC-001.yaml", "control", true},
		{"04-profiles/PROF-SERVICE-V1.yaml", "profile", true},
		{"06-bindings/bindings/go/BIND-QUA-001.yaml", "binding", true},
		{"01-sources/registry/SRC-GO-STYLE.yaml", "standard-source", true},
		{"09-assessments/waivers/WAV-001.yaml", "waiver", true},
		{"random/file.yaml", "", false},
	}

	for _, tt := range tests {
		// Pass empty content so $schema field detection fails → path fallback
		name, ok := schema.InferSchemaName(tt.path, []byte("id: test"))
		if ok != tt.expectOK {
			t.Errorf("path=%q: got ok=%v want ok=%v", tt.path, ok, tt.expectOK)
			continue
		}
		if ok && name != tt.expectName {
			t.Errorf("path=%q: got name=%q want name=%q", tt.path, name, tt.expectName)
		}
	}
}

func TestValidateDir_AllControls_Pass(t *testing.T) {
	root := complianceRoot(t)
	dir := filepath.Join(root, "03-catalogs", "controls")

	results, err := schema.ValidateDir(root, dir)
	if err != nil {
		t.Fatalf("ValidateDir error: %v", err)
	}

	var failed []string
	for _, r := range results {
		if !r.Skipped && !r.Valid {
			failed = append(failed, r.File+": "+r.Errors[0])
		}
	}
	if len(failed) > 0 {
		t.Errorf("%d controls failed validation:\n  %v", len(failed), failed)
	}
}
