package config

import (
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// GlobalConfigPath returns the path to ~/.forge/config.yaml.
func GlobalConfigPath() string {
	homeDir, _ := os.UserHomeDir()
	return filepath.Join(homeDir, ".forge", "config.yaml")
}

// RepoConfigPath walks up from dir looking for .forge.yaml.
// Returns the path and true if found, or ("", false) if not found before filesystem root.
func RepoConfigPath(dir string) (string, bool) {
	current := dir
	for {
		candidate := filepath.Join(current, ".forge.yaml")
		if _, err := os.Stat(candidate); err == nil {
			return candidate, true
		}
		parent := filepath.Dir(current)
		if parent == current {
			break
		}
		current = parent
	}
	return "", false
}

// Load builds the effective Config by merging:
//  1. Built-in defaults
//  2. ~/.forge/config.yaml (global)
//  3. .forge.yaml in cwd or any parent (per-repo)
//  4. FORGE_* environment variables
//
// CLI flags are applied by the caller after Load() returns.
func Load() (*Config, error) {
	cfg := Default()

	// 1. Global config
	if global, err := loadFile(GlobalConfigPath()); err == nil {
		cfg = Merge(cfg, global)
	}

	// 2. Per-repo config
	cwd, err := os.Getwd()
	if err == nil {
		if repoPath, ok := RepoConfigPath(cwd); ok {
			if repoCfg, err := loadFile(repoPath); err == nil {
				cfg = Merge(cfg, repoCfg)
			}
		}
	}

	// 3. Environment variables
	if v := os.Getenv("FORGE_GITHUB_TOKEN"); v != "" {
		cfg.GitHubToken = v
	}
	if v := os.Getenv("GITHUB_TOKEN"); v != "" && cfg.GitHubToken == "" {
		cfg.GitHubToken = v
	}
	if v := os.Getenv("FORGE_DEFAULT_ORG"); v != "" {
		cfg.DefaultOrg = v
	}
	if v := os.Getenv("FORGE_COMPLIANCE_REF"); v != "" {
		cfg.ComplianceRef = v
	}
	if v := os.Getenv("FORGE_COMPLIANCE_DIR"); v != "" {
		cfg.ComplianceDir = v
	}
	if v := os.Getenv("FORGE_OPA_BINARY"); v != "" {
		cfg.OPABinary = v
	}

	return cfg, nil
}

func loadFile(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cfg Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}
