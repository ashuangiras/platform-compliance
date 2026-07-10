package taxonomy

// Taxonomy holds all controlled vocabularies loaded from 02-taxonomy/.
type Taxonomy struct {
	ControlDomains     map[string]Domain     // key: domain code e.g. "SEC"
	TechnologyContexts map[string]Context    // key: context slug e.g. "go"
	RepositoryTypes    map[string]RepoType   // key: type slug e.g. "service"
	EnforcementLevels  []string
	ControlTypes       []string
	RiskLevels         []string
	AutomationStatuses []string
}

// Domain represents a control domain entry.
type Domain struct {
	Name        string `yaml:"name"`
	Description string `yaml:"description"`
}

// Context represents a technology context entry.
type Context struct {
	Name        string `yaml:"name"`
	Description string `yaml:"description"`
}

// RepoType represents a repository type entry.
type RepoType struct {
	Description        string   `yaml:"description"`
	ApplicableProfiles []string `yaml:"applicable_profiles"`
	ImpliedDomains     []string `yaml:"implied_domains"`
}

// IsValidDomain returns true if the domain code exists in the taxonomy.
func (t *Taxonomy) IsValidDomain(code string) bool {
	_, ok := t.ControlDomains[code]
	return ok
}

// IsValidContext returns true if the context slug exists in the taxonomy.
func (t *Taxonomy) IsValidContext(ctx string) bool {
	_, ok := t.TechnologyContexts[ctx]
	return ok
}

// IsValidRepoType returns true if the repository type exists in the taxonomy.
func (t *Taxonomy) IsValidRepoType(rt string) bool {
	_, ok := t.RepositoryTypes[rt]
	return ok
}

// DomainCodes returns all registered domain codes.
func (t *Taxonomy) DomainCodes() []string {
	codes := make([]string, 0, len(t.ControlDomains))
	for k := range t.ControlDomains {
		codes = append(codes, k)
	}
	return codes
}

// ContextSlugs returns all registered technology context slugs.
func (t *Taxonomy) ContextSlugs() []string {
	slugs := make([]string, 0, len(t.TechnologyContexts))
	for k := range t.TechnologyContexts {
		slugs = append(slugs, k)
	}
	return slugs
}
