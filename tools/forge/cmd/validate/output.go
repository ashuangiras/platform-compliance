package validate

import (
	"fmt"
	"os"
	"strings"

	"github.com/ashuangiras/platform-compliance/forge/pkg/manifest"
	"github.com/ashuangiras/platform-compliance/forge/pkg/compliance"
	"github.com/ashuangiras/platform-compliance/forge/pkg/schema"
)

// --- Terminal output helpers ---

const (
	colReset  = "\033[0m"
	colGreen  = "\033[32m"
	colRed    = "\033[31m"
	colYellow = "\033[33m"
	colGray   = "\033[90m"
	colBold   = "\033[1m"
)

func isTerminal() bool {
	fi, err := os.Stdout.Stat()
	if err != nil {
		return false
	}
	return (fi.Mode() & os.ModeCharDevice) != 0
}

func colour(code, s string) string {
	if !isTerminal() {
		return s
	}
	return code + s + colReset
}

func printFileResult(r *schema.ValidationResult, verbose bool) error {
	if r.Skipped {
		if verbose {
			fmt.Printf("%s  %s %s\n",
				colour(colGray, "○"),
				r.File,
				colour(colGray, "(no schema detected)"))
		}
		return nil
	}

	if r.Valid {
		fmt.Printf("%s  %s %s\n",
			colour(colGreen, "✓"),
			r.File,
			colour(colGray, "(schema: "+r.Schema+")"))
		return nil
	}

	fmt.Printf("%s  %s %s\n",
		colour(colRed, "✗"),
		r.File,
		colour(colGray, "(schema: "+r.Schema+")"))
	for _, e := range r.Errors {
		fmt.Printf("   %s\n", colour(colRed, e))
	}
	return fmt.Errorf("validation failed: %s", r.File)
}

func printDirResults(results []*schema.ValidationResult, verbose, quiet bool) error {
	failed := 0
	skipped := 0
	passed := 0

	for _, r := range results {
		if r.Skipped {
			skipped++
			if verbose {
				fmt.Printf("%s  %s\n", colour(colGray, "○"), r.File)
			}
			continue
		}
		if r.Valid {
			passed++
			if !quiet {
				fmt.Printf("%s  %s\n", colour(colGreen, "✓"), r.File)
			}
		} else {
			failed++
			fmt.Printf("%s  %s\n", colour(colRed, "✗"), r.File)
			for _, e := range r.Errors {
				indent := strings.Repeat(" ", 4)
				fmt.Printf("%s%s\n", indent, colour(colRed, e))
			}
		}
	}

	fmt.Printf("\n%s  %s  %s",
		colour(colGreen, fmt.Sprintf("%d passed", passed)),
		colour(colRed, fmt.Sprintf("%d failed", failed)),
		colour(colGray, fmt.Sprintf("%d skipped", skipped)),
	)
	fmt.Println()

	if failed > 0 {
		return fmt.Errorf("%d file(s) failed validation", failed)
	}
	return nil
}

// manifestValidationResult wraps the deep manifest result for display.
type manifestValidationResult struct {
	SchemaValid bool     `json:"schema_valid"`
	DeepValid   bool     `json:"deep_valid"`
	Errors      []string `json:"errors,omitempty"`
	Warnings    []string `json:"warnings,omitempty"`
}

func validateManifestFile(compDir, manifestPath string, c *compliance.ComplianceDir) (*manifestValidationResult, error) {
	result := &manifestValidationResult{}

	mvr, err := manifest.Validate(compDir, manifestPath, c.Taxonomy)
	if err != nil {
		return nil, fmt.Errorf("validate manifest: %w", err)
	}

	result.SchemaValid = mvr.SchemaValid
	result.Errors = mvr.Errors
	result.Warnings = mvr.Warnings
	result.DeepValid = mvr.IsValid()
	return result, nil
}

func printManifestResult(r *manifestValidationResult, path string) error {
	if r.DeepValid {
		fmt.Printf("%s  %s\n", colour(colGreen, "✓"), path)
		for _, w := range r.Warnings {
			fmt.Printf("  %s  %s\n", colour(colYellow, "⚠"), w)
		}
		return nil
	}

	fmt.Printf("%s  %s\n", colour(colRed, "✗"), path)
	for _, e := range r.Errors {
		fmt.Printf("  %s  %s\n", colour(colRed, "✗"), e)
	}
	for _, w := range r.Warnings {
		fmt.Printf("  %s  %s\n", colour(colYellow, "⚠"), w)
	}
	return fmt.Errorf("manifest validation failed: %d error(s)", len(r.Errors))
}
