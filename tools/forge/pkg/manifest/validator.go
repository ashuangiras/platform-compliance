package manifest

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/ashuangiras/platform-compliance/forge/pkg/schema"
	"github.com/ashuangiras/platform-compliance/forge/pkg/taxonomy"
)

// ValidationResult holds the deep validation outcome for a manifest.
type ValidationResult struct {
	SchemaValid     bool
	ProfilesValid   bool
	ContextsValid   bool
	RepoTypeValid   bool
	UnknownProfiles []string
	UnknownContexts []string
	UnknownRepoType string
	Errors          []string
	Warnings        []string
}

// IsValid returns true if there are no errors.
func (r *ValidationResult) IsValid() bool {
	return len(r.Errors) == 0
}

// Validate performs deep validation of a manifest:
//  1. JSON Schema validation against repository-compliance.schema.json
//  2. declared_profiles exist in complianceDir/04-profiles/
//  3. technology_contexts are registered in the taxonomy
//  4. repository.type is registered in the taxonomy
//  5. waiver_ids have corresponding files (non-fatal warnings)
func Validate(complianceDir, manifestPath string, tax *taxonomy.Taxonomy) (*ValidationResult, error) {
	result := &ValidationResult{
		ProfilesValid: true,
		ContextsValid: true,
		RepoTypeValid: true,
	}

	content, err := os.ReadFile(manifestPath)
	if err != nil {
		return nil, fmt.Errorf("manifest: read %s: %w", manifestPath, err)
	}

	// 1. Schema validation
	sr, err := schema.Validate(complianceDir, "repository-compliance", content)
	if err != nil {
		return nil, fmt.Errorf("manifest: schema validation: %w", err)
	}
	result.SchemaValid = sr.Valid
	if !sr.Valid {
		for _, e := range sr.Errors {
			result.Errors = append(result.Errors, fmt.Sprintf("schema: %s", e))
		}
	}

	// Parse manifest for deep checks
	m, err := Read(manifestPath)
	if err != nil {
		return result, nil // schema errors already captured
	}

	// 2. Profile existence
	for _, profID := range m.DeclaredProfiles {
		profPath := filepath.Join(complianceDir, "04-profiles", profID+".yaml")
		if _, err := os.Stat(profPath); os.IsNotExist(err) {
			result.ProfilesValid = false
			result.UnknownProfiles = append(result.UnknownProfiles, profID)
			result.Errors = append(result.Errors, fmt.Sprintf("profile not found: %s", profID))
		}
	}

	// 3. Technology context registration
	if tax != nil {
		for _, ctx := range m.TechnologyContexts {
			if !tax.IsValidContext(ctx) {
				result.ContextsValid = false
				result.UnknownContexts = append(result.UnknownContexts, ctx)
				result.Errors = append(result.Errors, fmt.Sprintf("unknown technology context: %s", ctx))
			}
		}

		// 4. Repository type
		if m.Repository.Type != "" && !tax.IsValidRepoType(m.Repository.Type) {
			result.RepoTypeValid = false
			result.UnknownRepoType = m.Repository.Type
			result.Errors = append(result.Errors, fmt.Sprintf("unknown repository type: %s", m.Repository.Type))
		}
	}

	// 5. Waiver IDs (warnings only)
	for _, wID := range m.WaiverIDs {
		waiverPath := filepath.Join(complianceDir, "09-assessments", "waivers", wID+".yaml")
		if _, err := os.Stat(waiverPath); os.IsNotExist(err) {
			result.Warnings = append(result.Warnings, fmt.Sprintf("waiver file not found: %s", wID))
		}
	}

	return result, nil
}
