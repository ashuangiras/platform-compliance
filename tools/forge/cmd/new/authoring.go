// Package newcmd adds scaffolding subcommands for controls, ADRs, waivers, etc.
// This file extends cmd/new/new.go with the authoring commands.
package new

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/ashuangiras/platform-compliance/forge/pkg/scaffold"
	"github.com/spf13/cobra"
)

// addAuthoringCommands adds the governance object authoring subcommands to cmd.
func addAuthoringCommands(cmd *cobra.Command, cfg interface{ getCompDir() string }) {
	// These are registered by RegisterAuthoringCommands called from NewCmd.
}

// RegisterAuthoringCommands adds all authoring subcommands to the parent new command.
func RegisterAuthoringCommands(parent *cobra.Command, getCompDir func() string) {
	parent.AddCommand(newControlCmd(getCompDir))
	parent.AddCommand(newADRCmd(getCompDir))
	parent.AddCommand(newWaiverCmd(getCompDir))
	parent.AddCommand(newChangeRecordCmd(getCompDir))
}

func newControlCmd(getCompDir func() string) *cobra.Command {
	var domain, title string
	cmd := &cobra.Command{
		Use:   "control",
		Short: "Scaffold a new control YAML in the correct domain directory",
		RunE: func(cmd *cobra.Command, args []string) error {
			compDir := getCompDir()
			if compDir == "" {
				return fmt.Errorf("forge new control: --compliance-dir is required")
			}
			if domain == "" {
				return fmt.Errorf("forge new control: --domain is required (e.g. SEC, QUA)")
			}
			if title == "" {
				return fmt.Errorf("forge new control: --title is required")
			}

			id, err := scaffold.NextControlID(compDir, domain)
			if err != nil {
				return fmt.Errorf("forge new control: %w", err)
			}

			vars := scaffold.DefaultVars()
			vars.ControlID = id
			vars.ControlDomain = domain
			vars.ControlTitle = title

			content, err := scaffold.RenderTemplate("control.yaml.tmpl", vars)
			if err != nil {
				return fmt.Errorf("forge new control: %w", err)
			}

			outDir := filepath.Join(compDir, "03-catalogs", "controls", domain)
			if err := os.MkdirAll(outDir, 0o755); err != nil {
				return fmt.Errorf("forge new control: create dir: %w", err)
			}
			outPath := filepath.Join(outDir, id+".yaml")
			if err := os.WriteFile(outPath, content, 0o644); err != nil {
				return fmt.Errorf("forge new control: write: %w", err)
			}
			fmt.Printf("✓  Created %s\n", outPath)
			fmt.Printf("   Next: add a binding, OPA policy, and POLICY_MAP entry.\n")
			return nil
		},
	}
	cmd.Flags().StringVar(&domain, "domain", "", "Control domain code (e.g. SEC, QUA, TST)")
	cmd.Flags().StringVar(&title, "title", "", "Control title")
	return cmd
}

func newADRCmd(getCompDir func() string) *cobra.Command {
	var title string
	cmd := &cobra.Command{
		Use:   "adr",
		Short: "Scaffold the next ADR with auto-incremented ID",
		RunE: func(cmd *cobra.Command, args []string) error {
			compDir := getCompDir()
			if compDir == "" {
				return fmt.Errorf("forge new adr: --compliance-dir is required")
			}
			if title == "" {
				return fmt.Errorf("forge new adr: --title is required")
			}

			id, err := scaffold.NextADRID(compDir)
			if err != nil {
				return fmt.Errorf("forge new adr: %w", err)
			}

			vars := scaffold.DefaultVars()
			vars.ADRID = id
			vars.ADRTitle = title

			content, err := scaffold.RenderTemplate("adr.md.tmpl", vars)
			if err != nil {
				return fmt.Errorf("forge new adr: %w", err)
			}

			slug := slugify(title)
			outPath := filepath.Join(compDir, "decisions", id+"-"+slug+".md")
			if err := os.WriteFile(outPath, content, 0o644); err != nil {
				return fmt.Errorf("forge new adr: write: %w", err)
			}
			fmt.Printf("✓  Created %s\n", outPath)
			return nil
		},
	}
	cmd.Flags().StringVar(&title, "title", "", "ADR title")
	return cmd
}

func newWaiverCmd(getCompDir func() string) *cobra.Command {
	var controlID, reason string
	cmd := &cobra.Command{
		Use:   "waiver",
		Short: "Scaffold a waiver record for a control exception",
		RunE: func(cmd *cobra.Command, args []string) error {
			compDir := getCompDir()
			if compDir == "" {
				return fmt.Errorf("forge new waiver: --compliance-dir is required")
			}
			if controlID == "" {
				return fmt.Errorf("forge new waiver: --control is required")
			}

			id, err := scaffold.NextWaiverID(compDir, controlID)
			if err != nil {
				return fmt.Errorf("forge new waiver: %w", err)
			}

			vars := scaffold.DefaultVars()
			vars.WaiverID = id
			vars.ControlIDForWaiver = controlID

			content, err := scaffold.RenderTemplate("waiver.yaml.tmpl", vars)
			if err != nil {
				return fmt.Errorf("forge new waiver: %w", err)
			}

			outDir := filepath.Join(compDir, "09-assessments", "waivers")
			if err := os.MkdirAll(outDir, 0o755); err != nil {
				return fmt.Errorf("forge new waiver: create dir: %w", err)
			}
			outPath := filepath.Join(outDir, id+".yaml")
			if err := os.WriteFile(outPath, content, 0o644); err != nil {
				return fmt.Errorf("forge new waiver: write: %w", err)
			}
			fmt.Printf("✓  Created %s\n", outPath)
			_ = reason
			return nil
		},
	}
	cmd.Flags().StringVar(&controlID, "control", "", "Control ID to waive (e.g. SEC-001)")
	cmd.Flags().StringVar(&reason, "reason", "", "Reason for the waiver")
	return cmd
}

func newChangeRecordCmd(getCompDir func() string) *cobra.Command {
	return &cobra.Command{
		Use:   "change-record",
		Short: "Allocate the next CHG-YYYYMMDD-NNN change record ID",
		RunE: func(cmd *cobra.Command, args []string) error {
			compDir := getCompDir()
			if compDir == "" {
				return fmt.Errorf("forge new change-record: --compliance-dir is required")
			}
			id, err := scaffold.NextChangeRecord(compDir)
			if err != nil {
				return fmt.Errorf("forge new change-record: %w", err)
			}
			fmt.Println(id)
			return nil
		},
	}
}

func slugify(s string) string {
	result := make([]byte, 0, len(s))
	for _, c := range s {
		if c >= 'a' && c <= 'z' || c >= '0' && c <= '9' {
			result = append(result, byte(c))
		} else if c >= 'A' && c <= 'Z' {
			result = append(result, byte(c+32))
		} else if c == ' ' || c == '-' || c == '_' {
			result = append(result, '-')
		}
	}
	return string(result)
}
