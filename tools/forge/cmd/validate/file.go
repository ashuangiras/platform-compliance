package validate

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/ashuangiras/platform-compliance/forge/pkg/compliance"
	"github.com/ashuangiras/platform-compliance/forge/pkg/config"
	"github.com/ashuangiras/platform-compliance/forge/pkg/schema"
	"github.com/spf13/cobra"
)

func newFileCmd(cfg **config.Config, format *string, verbose, quiet *bool) *cobra.Command {
	return &cobra.Command{
		Use:   "file <path>",
		Short: "Validate a single governance YAML file against its schema",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			filePath := args[0]
			compDir, err := resolveComplianceDir(*cfg)
			if err != nil {
				return err
			}

			result, err := schema.ValidateFile(compDir, filePath)
			if err != nil {
				return fmt.Errorf("validate: %w", err)
			}

			if *format == "json" {
				return json.NewEncoder(os.Stdout).Encode(result)
			}

			return printFileResult(result, *verbose)
		},
	}
}

func newRepoCmd(cfg **config.Config, format *string, verbose, quiet *bool) *cobra.Command {
	return &cobra.Command{
		Use:   "repo [path]",
		Short: "Validate all governance YAML files in a directory tree",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			dir := "."
			if len(args) == 1 {
				dir = args[0]
			}

			compDir, err := resolveComplianceDir(*cfg)
			if err != nil {
				return err
			}

			results, err := schema.ValidateDir(compDir, dir)
			if err != nil {
				return fmt.Errorf("validate: %w", err)
			}

			if *format == "json" {
				return json.NewEncoder(os.Stdout).Encode(results)
			}

			return printDirResults(results, *verbose, *quiet)
		},
	}
}

func newManifestCmd(cfg **config.Config, format *string, verbose, quiet *bool) *cobra.Command {
	return &cobra.Command{
		Use:   "manifest [path]",
		Short: "Validate a .compliance-manifest.yaml with deep referential checks",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			manifestPath := ".compliance-manifest.yaml"
			if len(args) == 1 {
				manifestPath = args[0]
			}

			compDir, err := resolveComplianceDir(*cfg)
			if err != nil {
				return err
			}

			c, err := compliance.LoadLocal(compDir)
			if err != nil {
				return fmt.Errorf("validate: %w", err)
			}

			result, err := validateManifestFile(compDir, manifestPath, c)
			if err != nil {
				return err
			}

			if *format == "json" {
				return json.NewEncoder(os.Stdout).Encode(result)
			}

			return printManifestResult(result, manifestPath)
		},
	}
}

// resolveComplianceDir returns the compliance directory from config.
// Returns an error if neither ComplianceDir nor ComplianceRef is set.
func resolveComplianceDir(cfg *config.Config) (string, error) {
	if cfg == nil {
		return "", fmt.Errorf("forge: config not loaded")
	}
	if cfg.ComplianceDir != "" {
		return cfg.ComplianceDir, nil
	}
	return "", fmt.Errorf("forge: --compliance-dir is required for Phase B.1 (remote ref fetching not yet implemented)")
}
