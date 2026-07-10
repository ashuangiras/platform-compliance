package config

import (
	"os"
	"path/filepath"
)

// Config holds all forge configuration values. Later sources override earlier ones.
// Precedence (lowest → highest): global file → repo file → env vars → CLI flags.
type Config struct {
	GitHubToken    string `mapstructure:"github_token"    yaml:"github_token"`
	DefaultOrg     string `mapstructure:"default_org"     yaml:"default_org"`
	DefaultProfile string `mapstructure:"default_profile" yaml:"default_profile"`
	ComplianceRef  string `mapstructure:"compliance_ref"  yaml:"compliance_ref"`
	// ComplianceDir overrides ComplianceRef for local development.
	// Set via --compliance-dir flag or FORGE_COMPLIANCE_DIR env var.
	ComplianceDir string `mapstructure:"compliance_dir"  yaml:"compliance_dir"`
	OPABinary     string `mapstructure:"opa_binary"      yaml:"opa_binary"`
	CacheDir      string `mapstructure:"cache_dir"       yaml:"cache_dir"`
	Editor        string `mapstructure:"editor"          yaml:"editor"`
}

// Default returns a Config with sensible built-in defaults.
func Default() *Config {
	homeDir, _ := os.UserHomeDir()
	return &Config{
		DefaultOrg:     "ashuangiras",
		DefaultProfile: "PROF-SERVICE-V1",
		ComplianceRef:  "v2.6.0",
		CacheDir:       filepath.Join(homeDir, ".forge", "cache"),
	}
}

// Merge returns a new Config with dst values, overridden by any non-zero src values.
func Merge(dst, src *Config) *Config {
	result := *dst
	if src.GitHubToken != "" {
		result.GitHubToken = src.GitHubToken
	}
	if src.DefaultOrg != "" {
		result.DefaultOrg = src.DefaultOrg
	}
	if src.DefaultProfile != "" {
		result.DefaultProfile = src.DefaultProfile
	}
	if src.ComplianceRef != "" {
		result.ComplianceRef = src.ComplianceRef
	}
	if src.ComplianceDir != "" {
		result.ComplianceDir = src.ComplianceDir
	}
	if src.OPABinary != "" {
		result.OPABinary = src.OPABinary
	}
	if src.CacheDir != "" {
		result.CacheDir = src.CacheDir
	}
	if src.Editor != "" {
		result.Editor = src.Editor
	}
	return &result
}

// EffectiveComplianceSource returns the compliance directory if set, else the ref.
// One of the two is always non-empty after Load().
func (c *Config) EffectiveComplianceSource() (dir string, ref string) {
	return c.ComplianceDir, c.ComplianceRef
}
