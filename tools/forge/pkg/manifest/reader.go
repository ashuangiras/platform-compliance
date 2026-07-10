package manifest

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// Read parses a .compliance-manifest.yaml file at path.
func Read(path string) (*Manifest, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("manifest: read %s: %w", path, err)
	}
	var m Manifest
	if err := yaml.Unmarshal(data, &m); err != nil {
		return nil, fmt.Errorf("manifest: parse %s: %w", path, err)
	}
	return &m, nil
}

// Find searches dir and its parents for a .compliance-manifest.yaml file.
// Returns the absolute path if found, or an error if not found before the root.
func Find(dir string) (string, error) {
	abs, err := filepath.Abs(dir)
	if err != nil {
		return "", fmt.Errorf("manifest: resolve dir %s: %w", dir, err)
	}

	current := abs
	for {
		candidate := filepath.Join(current, FileName)
		if _, err := os.Stat(candidate); err == nil {
			return candidate, nil
		}
		parent := filepath.Dir(current)
		if parent == current {
			break
		}
		current = parent
	}
	return "", fmt.Errorf("manifest: %s not found in %s or any parent directory", FileName, dir)
}

// FindOrRead is a convenience that calls Find then Read.
func FindOrRead(dir string) (*Manifest, string, error) {
	path, err := Find(dir)
	if err != nil {
		return nil, "", err
	}
	m, err := Read(path)
	return m, path, err
}
