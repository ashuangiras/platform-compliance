package gate

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// GateType identifies a compliance gate.
type GateType string

const (
	GateMerge      GateType = "merge"
	GateDeployment GateType = "deployment"
	GateRelease    GateType = "release"
)

// GateCriteria holds the required controls for a gate.
type GateCriteria struct {
	Type             GateType
	RequiredControls []GateControl
}

// GateControl describes one control's requirement at a gate.
type GateControl struct {
	ControlID   string `yaml:"id"`
	Enforcement string `yaml:"enforcement"`
}

// rawGate matches the YAML structure of the gate criteria files.
type rawGate struct {
	Gate struct {
		RequiredControls []GateControl `yaml:"required_controls"`
		BlockOn          []string      `yaml:"block_on"`
	} `yaml:"merge_gate"`
	Deploy struct {
		RequiredControls []GateControl `yaml:"required_controls"`
	} `yaml:"deployment_gate"`
	Release struct {
		RequiredControls []GateControl `yaml:"required_controls"`
	} `yaml:"release_gate"`
}

// Load reads a gate criteria file from the compliance directory.
// Supports merge (merge-gate.yaml), deployment (deployment-gate.yaml),
// and release (release-gate.yaml) gates.
func Load(complianceDir string, gateType GateType) (*GateCriteria, error) {
	var filename string
	switch gateType {
	case GateMerge:
		filename = "merge-gate.yaml"
	case GateDeployment:
		filename = "deployment-gate.yaml"
	case GateRelease:
		filename = "release-gate.yaml"
	default:
		return nil, fmt.Errorf("gate: unknown gate type %q", gateType)
	}

	path := filepath.Join(complianceDir, "09-assessments", "gates", filename)
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("gate: read %s: %w", path, err)
	}

	// Parse as a generic map first to handle varying YAML structures
	var raw map[string]any
	if err := yaml.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("gate: parse %s: %w", path, err)
	}

	criteria := &GateCriteria{Type: gateType}

	// Extract required_controls from the top-level key that matches the gate type
	for key, val := range raw {
		if !isGateSection(key, gateType) {
			continue
		}
		section, ok := val.(map[string]any)
		if !ok {
			continue
		}
		if ctrls, ok := section["required_controls"]; ok {
			if list, ok := ctrls.([]any); ok {
				for _, item := range list {
					if m, ok := item.(map[string]any); ok {
						gc := GateControl{}
						if id, ok := m["id"].(string); ok {
							gc.ControlID = id
						}
						if enf, ok := m["enforcement"].(string); ok {
							gc.Enforcement = enf
						} else {
							gc.Enforcement = "block" // default
						}
						if gc.ControlID != "" {
							criteria.RequiredControls = append(criteria.RequiredControls, gc)
						}
					}
				}
			}
		}
	}

	return criteria, nil
}

func isGateSection(key string, gateType GateType) bool {
	switch gateType {
	case GateMerge:
		return key == "merge_gate" || key == "merge"
	case GateDeployment:
		return key == "deployment_gate" || key == "deployment"
	case GateRelease:
		return key == "release_gate" || key == "release"
	}
	return false
}
