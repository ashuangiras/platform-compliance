package compliance

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/ashuangiras/platform-compliance/forge/pkg/schema"
	"github.com/ashuangiras/platform-compliance/forge/pkg/taxonomy"
)

// ComplianceDir represents a loaded and validated compliance root directory.
type ComplianceDir struct {
	Root     string            // absolute path to the compliance root
	Ref      string            // version tag or "local"
	Taxonomy *taxonomy.Taxonomy
	Schemas  map[string]string // schema name → absolute path
}

// LoadLocal loads a compliance root from a local directory path.
// This is the mode used for --compliance-dir flag and Phase B.1.
func LoadLocal(dir string) (*ComplianceDir, error) {
	abs, err := filepath.Abs(dir)
	if err != nil {
		return nil, fmt.Errorf("compliance: resolve dir %s: %w", dir, err)
	}

	// Verify it looks like a compliance root
	if err := validateComplianceRoot(abs); err != nil {
		return nil, err
	}

	// Load taxonomy
	tax, err := taxonomy.Load(abs)
	if err != nil {
		return nil, fmt.Errorf("compliance: load taxonomy: %w", err)
	}

	// Build schema map
	schemas := make(map[string]string, len(schema.KnownSchemas))
	for name, rel := range schema.KnownSchemas {
		schemas[name] = filepath.Join(abs, rel)
	}

	return &ComplianceDir{
		Root:     abs,
		Ref:      "local",
		Taxonomy: tax,
		Schemas:  schemas,
	}, nil
}

// ProfilePath returns the absolute path to a profile YAML file.
// Returns ("", false) if the profile does not exist.
func (c *ComplianceDir) ProfilePath(id string) (string, bool) {
	path := filepath.Join(c.Root, "04-profiles", id+".yaml")
	if _, err := os.Stat(path); err == nil {
		return path, true
	}
	return "", false
}

// SchemaPath returns the absolute path to a named schema file.
func (c *ComplianceDir) SchemaPath(name string) (string, bool) {
	path, ok := c.Schemas[name]
	return path, ok
}

// ControlPath returns the absolute path to a control YAML file given its ID.
// Control IDs are of the form "DOMAIN-NNN" e.g. "SEC-001".
// Returns ("", false) if not found.
func (c *ComplianceDir) ControlPath(id string) (string, bool) {
	// Extract domain from ID prefix (e.g. "SEC" from "SEC-001")
	for i, ch := range id {
		if ch == '-' {
			domain := id[:i]
			path := filepath.Join(c.Root, "03-catalogs", "controls", domain, id+".yaml")
			if _, err := os.Stat(path); err == nil {
				return path, true
			}
			return "", false
		}
	}
	return "", false
}

// GatePath returns the absolute path to a gate criteria file.
// gateType should be "merge", "deployment", or "release".
func (c *ComplianceDir) GatePath(gateType string) (string, bool) {
	name := gateType + "-gate.yaml"
	path := filepath.Join(c.Root, "09-assessments", "gates", name)
	if _, err := os.Stat(path); err == nil {
		return path, true
	}
	return "", false
}

// validateComplianceRoot checks that dir has the expected top-level structure.
func validateComplianceRoot(dir string) error {
	required := []string{
		"schemas",
		"02-taxonomy",
		"03-catalogs",
		"04-profiles",
	}
	for _, rel := range required {
		path := filepath.Join(dir, rel)
		if _, err := os.Stat(path); os.IsNotExist(err) {
			return fmt.Errorf("compliance: %s does not look like a platform-compliance root: missing %s", dir, rel)
		}
	}
	return nil
}
