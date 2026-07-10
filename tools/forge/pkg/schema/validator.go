package schema

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/santhosh-tekuri/jsonschema/v5"
	"gopkg.in/yaml.v3"
)

// ValidationResult holds the outcome of validating one file against a schema.
type ValidationResult struct {
	File    string
	Schema  string // schema name e.g. "control"
	Valid   bool
	Errors  []string
	Skipped bool   // true when no schema could be determined
	SkipMsg string // reason for skipping
}

// Validate validates yamlContent against the named schema loaded from complianceDir.
func Validate(complianceDir, schemaName string, yamlContent []byte) (*ValidationResult, error) {
	result := &ValidationResult{Schema: schemaName}

	schemaRel, ok := KnownSchemas[schemaName]
	if !ok {
		return nil, fmt.Errorf("schema: unknown schema name %q", schemaName)
	}
	schemaPath := filepath.Join(complianceDir, schemaRel)

	// Convert YAML → JSON (jsonschema library validates JSON)
	jsonBytes, err := yamlToJSON(yamlContent)
	if err != nil {
		return nil, fmt.Errorf("schema: yaml→json conversion: %w", err)
	}

	// Compile schema
	compiler := jsonschema.NewCompiler()
	compiler.Draft = jsonschema.Draft7

	schemaData, err := os.ReadFile(schemaPath)
	if err != nil {
		return nil, fmt.Errorf("schema: read %s: %w", schemaPath, err)
	}
	if err := compiler.AddResource("schema.json", strings.NewReader(string(schemaData))); err != nil {
		return nil, fmt.Errorf("schema: compile %s: %w", schemaPath, err)
	}
	sch, err := compiler.Compile("schema.json")
	if err != nil {
		return nil, fmt.Errorf("schema: compile %s: %w", schemaPath, err)
	}

	// Validate
	var doc any
	if err := json.Unmarshal(jsonBytes, &doc); err != nil {
		return nil, fmt.Errorf("schema: parse json: %w", err)
	}

	if err := sch.Validate(doc); err != nil {
		result.Valid = false
		if ve, ok := err.(*jsonschema.ValidationError); ok {
			for _, cause := range ve.Causes {
				result.Errors = append(result.Errors, cause.Error())
			}
			if len(result.Errors) == 0 {
				result.Errors = append(result.Errors, ve.Error())
			}
		} else {
			result.Errors = append(result.Errors, err.Error())
		}
	} else {
		result.Valid = true
	}
	return result, nil
}

// ValidateFile validates a file, automatically inferring the schema.
func ValidateFile(complianceDir, filePath string) (*ValidationResult, error) {
	result := &ValidationResult{File: filePath}

	content, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("schema: read %s: %w", filePath, err)
	}

	schemaName, ok := InferSchemaName(filePath, content)
	if !ok {
		result.Skipped = true
		result.SkipMsg = "no schema detected"
		return result, nil
	}
	result.Schema = schemaName

	r, err := Validate(complianceDir, schemaName, content)
	if err != nil {
		return nil, err
	}
	result.Valid = r.Valid
	result.Errors = r.Errors
	return result, nil
}

// ValidateDir walks dir and validates every YAML file with a detectable schema.
// Files without a detectable schema are returned with Skipped=true.
func ValidateDir(complianceDir, dir string) ([]*ValidationResult, error) {
	var results []*ValidationResult

	err := filepath.WalkDir(dir, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			// Skip vendor, hidden, and non-governance directories
			name := d.Name()
			if name == "node_modules" || name == "vendor" || strings.HasPrefix(name, ".") {
				return filepath.SkipDir
			}
			return nil
		}
		ext := strings.ToLower(filepath.Ext(path))
		if ext != ".yaml" && ext != ".yml" {
			return nil
		}

		result, err := ValidateFile(complianceDir, path)
		if err != nil {
			results = append(results, &ValidationResult{
				File:   path,
				Valid:  false,
				Errors: []string{err.Error()},
			})
			return nil
		}
		results = append(results, result)
		return nil
	})
	return results, err
}

// yamlToJSON converts YAML bytes to JSON bytes via intermediate Go value.
func yamlToJSON(yamlData []byte) ([]byte, error) {
	var doc any
	if err := yaml.Unmarshal(yamlData, &doc); err != nil {
		return nil, err
	}
	// yaml.v3 unmarshals maps as map[string]any, which json.Marshal handles.
	return json.Marshal(normaliseYAMLDoc(doc))
}

// normaliseYAMLDoc recursively converts map[interface{}]interface{} (yaml.v1 style)
// to map[string]interface{} so json.Marshal works. yaml.v3 already produces
// map[string]interface{} but we normalise defensively.
func normaliseYAMLDoc(v any) any {
	switch val := v.(type) {
	case map[string]any:
		out := make(map[string]any, len(val))
		for k, child := range val {
			out[k] = normaliseYAMLDoc(child)
		}
		return out
	case map[any]any:
		out := make(map[string]any, len(val))
		for k, child := range val {
			out[fmt.Sprintf("%v", k)] = normaliseYAMLDoc(child)
		}
		return out
	case []any:
		for i, item := range val {
			val[i] = normaliseYAMLDoc(item)
		}
		return val
	default:
		return v
	}
}
