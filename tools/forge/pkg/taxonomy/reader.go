package taxonomy

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// rawDomains matches the structure of control-domains.yaml
type rawDomains struct {
	Domains map[string]Domain `yaml:"domains"`
}

// rawContexts matches the structure of technology-contexts.yaml
type rawContexts struct {
	Contexts map[string]struct {
		Code        string `yaml:"code"`
		Description string `yaml:"description"`
	} `yaml:"contexts"`
}

// rawRepoTypes matches the structure of repository-types.yaml
type rawRepoTypes struct {
	Types map[string]struct {
		Code               string   `yaml:"code"`
		Description        string   `yaml:"description"`
		ApplicableProfiles []string `yaml:"applicable_profiles"`
		ImpliedDomains     []string `yaml:"implied_domains"`
	} `yaml:"types"`
}

// rawLevels matches enforcement-levels.yaml (list of level codes under "levels:")
type rawLevels struct {
	Levels map[string]struct {
		Code string `yaml:"code"`
	} `yaml:"levels"`
}

// Load reads all taxonomy files from complianceDir/02-taxonomy/ and returns a Taxonomy.
func Load(complianceDir string) (*Taxonomy, error) {
	base := filepath.Join(complianceDir, "02-taxonomy")
	tax := &Taxonomy{
		ControlDomains:     make(map[string]Domain),
		TechnologyContexts: make(map[string]Context),
		RepositoryTypes:    make(map[string]RepoType),
	}

	// control-domains.yaml
	if err := loadDomains(filepath.Join(base, "control-domains.yaml"), tax); err != nil {
		return nil, fmt.Errorf("taxonomy: control-domains: %w", err)
	}

	// technology-contexts.yaml
	if err := loadContexts(filepath.Join(base, "technology-contexts.yaml"), tax); err != nil {
		return nil, fmt.Errorf("taxonomy: technology-contexts: %w", err)
	}

	// repository-types.yaml
	if err := loadRepoTypes(filepath.Join(base, "repository-types.yaml"), tax); err != nil {
		return nil, fmt.Errorf("taxonomy: repository-types: %w", err)
	}

	// enforcement-levels.yaml (optional — non-fatal if absent)
	_ = loadLevels(filepath.Join(base, "enforcement-levels.yaml"), tax)

	return tax, nil
}

func loadDomains(path string, tax *Taxonomy) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var raw rawDomains
	if err := yaml.Unmarshal(data, &raw); err != nil {
		return err
	}
	for code, d := range raw.Domains {
		tax.ControlDomains[code] = Domain{Name: d.Name, Description: d.Description}
	}
	return nil
}

func loadContexts(path string, tax *Taxonomy) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var raw rawContexts
	if err := yaml.Unmarshal(data, &raw); err != nil {
		return err
	}
	for slug, c := range raw.Contexts {
		tax.TechnologyContexts[slug] = Context{Name: c.Code, Description: c.Description}
	}
	return nil
}

func loadRepoTypes(path string, tax *Taxonomy) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var raw rawRepoTypes
	if err := yaml.Unmarshal(data, &raw); err != nil {
		return err
	}
	for slug, rt := range raw.Types {
		tax.RepositoryTypes[slug] = RepoType{
			Description:        rt.Description,
			ApplicableProfiles: rt.ApplicableProfiles,
			ImpliedDomains:     rt.ImpliedDomains,
		}
	}
	return nil
}

func loadLevels(path string, tax *Taxonomy) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil // non-fatal
	}
	var raw rawLevels
	if err := yaml.Unmarshal(data, &raw); err != nil {
		return nil
	}
	for code := range raw.Levels {
		tax.EnforcementLevels = append(tax.EnforcementLevels, code)
	}
	return nil
}
