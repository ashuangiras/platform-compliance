package manifest

// Manifest represents a parsed .compliance-manifest.yaml file.
// Conforms to schemas/repository-compliance.schema.json.
type Manifest struct {
	SchemaVersion      string     `yaml:"schema_version"`
	Repository         Repository `yaml:"repository"`
	DeclaredProfiles   []string   `yaml:"declared_profiles"`
	TechnologyContexts []string   `yaml:"technology_contexts"`
	WaiverIDs          []string   `yaml:"waiver_ids"`
}

// Repository holds the repository metadata block.
type Repository struct {
	Name               string `yaml:"name"`
	URL                string `yaml:"url"`
	Type               string `yaml:"type"`
	HasContainerImages bool   `yaml:"has_container_images"`
}

// FileName is the canonical name of a compliance manifest file.
const FileName = ".compliance-manifest.yaml"
