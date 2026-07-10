package schema

import (
	"path/filepath"
	"strings"
)

// KnownSchemas maps schema base name (without extension) to its relative path
// from the compliance root. Both .json and .yaml schema references are handled.
var KnownSchemas = map[string]string{
	"adr":                   "schemas/adr.schema.json",
	"assessment":            "schemas/assessment.schema.json",
	"binding":               "schemas/binding.schema.json",
	"change-record":         "schemas/change-record.schema.json",
	"control":               "schemas/control.schema.json",
	"evidence":              "schemas/evidence.schema.json",
	"incident-record":       "schemas/incident-record.schema.json",
	"mapping-collection":    "schemas/mapping-collection.schema.json",
	"mapping":               "schemas/mapping.schema.json",
	"policy-check":          "schemas/policy-check.schema.json",
	"profile":               "schemas/profile.schema.json",
	"release-record":        "schemas/release-record.schema.json",
	"repository-compliance": "schemas/repository-compliance.schema.json",
	"service-contract":      "schemas/service-contract.schema.json",
	"standard-source":       "schemas/standard-source.schema.json",
	"waiver":                "schemas/waiver.schema.json",
}

// pathPatterns maps directory path segments to schema names.
// Used when a file has no $schema field.
var pathPatterns = []struct {
	segment string
	schema  string
}{
	{"03-catalogs/controls", "control"},
	{"04-profiles", "profile"},
	{"05-mappings", "mapping-collection"},
	{"06-bindings", "binding"},
	{"01-sources/registry", "standard-source"},
	{"07-policies/opa", "policy-check"},
	{"08-evidence", "evidence"},
	{"09-assessments/waivers", "waiver"},
	{"09-assessments/reports", "assessment"},
	{"09-assessments/releases", "release-record"},
	{"09-assessments/changes", "change-record"},
	{"decisions", "adr"},
}

// ExtractSchemaField reads the $schema value from raw YAML bytes.
// Returns the value and true if found, ("", false) otherwise.
func ExtractSchemaField(content []byte) (string, bool) {
	for _, line := range strings.Split(string(content), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "$schema:") {
			val := strings.TrimSpace(strings.TrimPrefix(line, "$schema:"))
			val = strings.Trim(val, `"'`)
			return val, true
		}
	}
	return "", false
}

// SchemaNameFromRef extracts the schema base name from a $schema reference.
// Handles both .json and .yaml extensions, and relative paths.
// e.g. "../../../schemas/control.schema.yaml" → "control"
// e.g. "../schemas/profile.schema.json" → "profile"
func SchemaNameFromRef(ref string) (string, bool) {
	base := filepath.Base(ref)
	// Strip extensions: .schema.json or .schema.yaml
	for _, suffix := range []string{".schema.json", ".schema.yaml", ".json", ".yaml"} {
		if strings.HasSuffix(base, suffix) {
			name := strings.TrimSuffix(base, suffix)
			if _, ok := KnownSchemas[name]; ok {
				return name, true
			}
		}
	}
	return "", false
}

// InferSchemaName attempts to determine the schema name for a file from:
//  1. The $schema field in the YAML content
//  2. The file path pattern (directory segments)
//
// Returns (schemaName, true) on success, ("", false) if not determinable.
func InferSchemaName(filePath string, content []byte) (string, bool) {
	// Try $schema field first
	if ref, ok := ExtractSchemaField(content); ok {
		if name, ok := SchemaNameFromRef(ref); ok {
			return name, true
		}
	}

	// Fall back to path pattern
	normalised := filepath.ToSlash(filePath)
	for _, p := range pathPatterns {
		if strings.Contains(normalised, p.segment) {
			return p.schema, true
		}
	}

	return "", false
}
