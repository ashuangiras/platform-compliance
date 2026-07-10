package compliance

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// Profile represents a loaded and fully resolved profile (inheritance chain flattened).
type Profile struct {
	ID                string
	Name              string
	Version           string
	InheritsID        string
	ApplicableTo      []string
	MandatoryControls []string            // flattened from all ancestors
	GateControls      map[string][]string // gate name → control IDs
}

// rawProfile matches the YAML structure of profile files.
type rawProfile struct {
	ID           string   `yaml:"id"`
	Name         string   `yaml:"name"`
	Version      string   `yaml:"version"`
	Inherits     string   `yaml:"inherits"`
	ApplicableTo []string `yaml:"applicable_to"`
	Categories   struct {
		Mandatory []rawControl `yaml:"mandatory"`
	} `yaml:"categories"`
	Gates map[string]struct {
		RequiredControls []rawControl `yaml:"required_controls"`
	} `yaml:"gates"`
}

type rawControl struct {
	ID          string `yaml:"id"`
	Enforcement string `yaml:"enforcement"`
}

// ResolveProfile loads a profile and fully resolves its inheritance chain.
// The flattened mandatory control list contains controls from all ancestors.
func ResolveProfile(c *ComplianceDir, profileID string) (*Profile, error) {
	return resolveChain(c, profileID, make(map[string]bool))
}

func resolveChain(c *ComplianceDir, profileID string, visited map[string]bool) (*Profile, error) {
	if visited[profileID] {
		return nil, fmt.Errorf("compliance: profile inheritance cycle detected at %s", profileID)
	}
	visited[profileID] = true

	profPath, ok := c.ProfilePath(profileID)
	if !ok {
		return nil, fmt.Errorf("compliance: profile %s not found", profileID)
	}

	data, err := os.ReadFile(profPath)
	if err != nil {
		return nil, fmt.Errorf("compliance: read profile %s: %w", profPath, err)
	}

	var raw rawProfile
	if err := yaml.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("compliance: parse profile %s: %w", profPath, err)
	}

	prof := &Profile{
		ID:           raw.ID,
		Name:         raw.Name,
		Version:      raw.Version,
		InheritsID:   raw.Inherits,
		ApplicableTo: raw.ApplicableTo,
		GateControls: make(map[string][]string),
	}

	// Collect this profile's mandatory controls
	myControls := make(map[string]bool)
	for _, ctrl := range raw.Categories.Mandatory {
		if ctrl.ID != "" {
			myControls[ctrl.ID] = true
		}
	}

	// Collect gate controls
	for gateName, gate := range raw.Gates {
		for _, ctrl := range gate.RequiredControls {
			if ctrl.ID != "" {
				prof.GateControls[gateName] = append(prof.GateControls[gateName], ctrl.ID)
			}
		}
	}

	// Resolve parent chain
	if raw.Inherits != "" {
		parent, err := resolveChain(c, raw.Inherits, visited)
		if err != nil {
			return nil, err
		}
		// Merge: parent controls first, then this profile's additions
		seen := make(map[string]bool)
		for _, ctrl := range parent.MandatoryControls {
			if !seen[ctrl] {
				prof.MandatoryControls = append(prof.MandatoryControls, ctrl)
				seen[ctrl] = true
			}
		}
		for ctrl := range myControls {
			if !seen[ctrl] {
				prof.MandatoryControls = append(prof.MandatoryControls, ctrl)
				seen[ctrl] = true
			}
		}
		// Merge gate controls from parent
		for gate, ctrls := range parent.GateControls {
			seen := make(map[string]bool)
			for _, c := range prof.GateControls[gate] {
				seen[c] = true
			}
			for _, c := range ctrls {
				if !seen[c] {
					prof.GateControls[gate] = append(prof.GateControls[gate], c)
				}
			}
		}
	} else {
		for ctrl := range myControls {
			prof.MandatoryControls = append(prof.MandatoryControls, ctrl)
		}
	}

	return prof, nil
}

// ListProfiles returns all profile IDs found in complianceDir/04-profiles/.
func ListProfiles(c *ComplianceDir) ([]string, error) {
	dir := filepath.Join(c.Root, "04-profiles")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("compliance: list profiles: %w", err)
	}
	var ids []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".yaml") {
			ids = append(ids, strings.TrimSuffix(e.Name(), ".yaml"))
		}
	}
	return ids, nil
}
