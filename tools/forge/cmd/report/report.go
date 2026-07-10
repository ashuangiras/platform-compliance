// Package report implements `forge report coverage/status/drift`.
package report

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/ashuangiras/platform-compliance/forge/pkg/config"
	"github.com/spf13/cobra"
	"gopkg.in/yaml.v3"
)

// NewCmd returns the `forge report` parent command.
func NewCmd(cfg **config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "report",
		Short: "Compliance reporting and visibility",
		Long: `Generate compliance reports for the governance system.

  forge report coverage   Standards → controls coverage map
  forge report drift      Controls without bindings or policies
  forge report profile <id>  All controls mandated by a profile`,
	}
	cmd.AddCommand(newCoverageCmd(cfg))
	cmd.AddCommand(newDriftCmd(cfg))
	cmd.AddCommand(newProfileCmd(cfg))
	return cmd
}

func resolveCompDir(c *config.Config) (string, error) {
	if c != nil && c.ComplianceDir != "" {
		return c.ComplianceDir, nil
	}
	return "", fmt.Errorf("forge report: --compliance-dir is required")
}

func newCoverageCmd(cfg **config.Config) *cobra.Command {
	return &cobra.Command{
		Use:   "coverage",
		Short: "Show which standards are covered by which controls",
		RunE: func(cmd *cobra.Command, args []string) error {
			c := *cfg
			compDir, err := resolveCompDir(c)
			if err != nil {
				return err
			}

			// Read all mapping collections from 05-mappings/
			mappingsDir := filepath.Join(compDir, "05-mappings", "mappings")
			entries, _ := os.ReadDir(mappingsDir)

			type coverage struct {
				source   string
				controls []string
			}
			var rows []coverage

			for _, e := range entries {
				if !strings.HasSuffix(e.Name(), ".yaml") {
					continue
				}
				data, _ := os.ReadFile(filepath.Join(mappingsDir, e.Name()))
				var obj map[string]any
				_ = yaml.Unmarshal(data, &obj)

				sourceID, _ := obj["source_id"].(string)
				if sourceID == "" {
					continue
				}

				var controls []string
				if mappings, ok := obj["mappings"].([]any); ok {
					for _, m := range mappings {
						if mm, ok := m.(map[string]any); ok {
							if cid, ok := mm["control_id"].(string); ok {
								controls = append(controls, cid)
							}
						}
					}
				}
				rows = append(rows, coverage{source: sourceID, controls: controls})
			}

			sort.Slice(rows, func(i, j int) bool { return rows[i].source < rows[j].source })

			fmt.Printf("%-30s  %s\n", "Standard", "Controls")
			fmt.Println(strings.Repeat("-", 70))
			for _, r := range rows {
				fmt.Printf("%-30s  %s\n", r.source, strings.Join(r.controls, ", "))
			}
			return nil
		},
	}
}

func newDriftCmd(cfg **config.Config) *cobra.Command {
	return &cobra.Command{
		Use:   "drift",
		Short: "Show controls that have no binding or no OPA policy",
		RunE: func(cmd *cobra.Command, args []string) error {
			c := *cfg
			compDir, err := resolveCompDir(c)
			if err != nil {
				return err
			}

			// Collect all control IDs
			controlIDs := make(map[string]bool)
			controlsBase := filepath.Join(compDir, "03-catalogs", "controls")
			domains, _ := os.ReadDir(controlsBase)
			for _, d := range domains {
				if !d.IsDir() {
					continue
				}
				entries, _ := os.ReadDir(filepath.Join(controlsBase, d.Name()))
				for _, e := range entries {
					if strings.HasSuffix(e.Name(), ".yaml") {
						id := strings.TrimSuffix(e.Name(), ".yaml")
						controlIDs[id] = true
					}
				}
			}

			// Collect bound control IDs
			bound := make(map[string]bool)
			bindingsBase := filepath.Join(compDir, "06-bindings", "bindings")
			filepath.WalkDir(bindingsBase, func(path string, d os.DirEntry, _ error) error {
				if d.IsDir() || !strings.HasSuffix(d.Name(), ".yaml") {
					return nil
				}
				data, _ := os.ReadFile(path)
				var obj map[string]any
				_ = yaml.Unmarshal(data, &obj)
				if cid, ok := obj["control_id"].(string); ok {
					bound[cid] = true
				}
				return nil
			})

			// Collect policied control IDs (from check.yaml files)
			policied := make(map[string]bool)
			filepath.WalkDir(filepath.Join(compDir, "07-policies", "opa"), func(path string, d os.DirEntry, _ error) error {
				if d.IsDir() || !strings.HasSuffix(d.Name(), ".check.yaml") {
					return nil
				}
				data, _ := os.ReadFile(path)
				var obj map[string]any
				_ = yaml.Unmarshal(data, &obj)
				if cid, ok := obj["control_id"].(string); ok {
					policied[cid] = true
				}
				return nil
			})

			// Report drift
			var drifted []string
			for id := range controlIDs {
				missing := []string{}
				if !bound[id] {
					missing = append(missing, "binding")
				}
				if !policied[id] {
					missing = append(missing, "policy")
				}
				if len(missing) > 0 {
					drifted = append(drifted, fmt.Sprintf("%-20s  missing: %s", id, strings.Join(missing, ", ")))
				}
			}
			sort.Strings(drifted)

			if len(drifted) == 0 {
				fmt.Println("✓  No drift — all controls have bindings and policies")
				return nil
			}
			fmt.Printf("%-20s  %s\n", "Control", "Missing")
			fmt.Println(strings.Repeat("-", 60))
			for _, d := range drifted {
				fmt.Println(d)
			}
			fmt.Printf("\n%d control(s) have drift\n", len(drifted))
			return nil
		},
	}
}

func newProfileCmd(cfg **config.Config) *cobra.Command {
	return &cobra.Command{
		Use:   "profile <id>",
		Short: "Show all controls mandated by a profile",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			c := *cfg
			compDir, err := resolveCompDir(c)
			if err != nil {
				return err
			}

			path := filepath.Join(compDir, "04-profiles", args[0]+".yaml")
			data, err := os.ReadFile(path)
			if err != nil {
				return fmt.Errorf("forge report profile: %s not found", args[0])
			}
			var obj map[string]any
			_ = yaml.Unmarshal(data, &obj)

			fmt.Printf("Profile: %s\n", args[0])
			if inherits, ok := obj["inherits"].(string); ok && inherits != "" {
				fmt.Printf("Inherits: %s\n", inherits)
			}
			fmt.Println()

			if cats, ok := obj["categories"].(map[string]any); ok {
				if mand, ok := cats["mandatory"].(map[string]any); ok {
					if ctrls, ok := mand["controls"].([]any); ok {
						fmt.Println("Mandatory controls:")
						for _, ctrl := range ctrls {
							if m, ok := ctrl.(map[string]any); ok {
								id, _ := m["id"].(string)
								enf, _ := m["enforcement"].(string)
								if enf == "" {
									enf = "block"
								}
								fmt.Printf("  %-20s  %s\n", id, enf)
							}
						}
					}
				}
			}
			return nil
		},
	}
}
