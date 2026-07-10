// Package registry implements `forge registry list/show`.
package registry

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

// NewCmd returns the `forge registry` parent command.
func NewCmd(cfg **config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "registry",
		Short: "Browse governance objects (read-only)",
		Long: `Browse the platform-compliance governance object registry.

  forge registry list controls [domain]   List all controls
  forge registry list profiles            List all profiles
  forge registry list standards           List all registered standards
  forge registry list contexts            List all technology contexts
  forge registry list domains             List all control domains
  forge registry show <id>                Show any governance object`,
	}

	listCmd := &cobra.Command{Use: "list", Short: "List governance objects"}
	listCmd.AddCommand(newListControlsCmd(cfg))
	listCmd.AddCommand(newListProfilesCmd(cfg))
	listCmd.AddCommand(newListStandardsCmd(cfg))
	listCmd.AddCommand(newListContextsCmd(cfg))
	listCmd.AddCommand(newListDomainsCmd(cfg))

	cmd.AddCommand(listCmd)
	cmd.AddCommand(newShowCmd(cfg))
	return cmd
}

func resolveCompDir(c *config.Config) (string, error) {
	if c != nil && c.ComplianceDir != "" {
		return c.ComplianceDir, nil
	}
	return "", fmt.Errorf("forge registry: --compliance-dir is required")
}

func newListControlsCmd(cfg **config.Config) *cobra.Command {
	var domain string
	cmd := &cobra.Command{
		Use:   "controls [domain]",
		Short: "List all controls, optionally filtered by domain",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			c := *cfg
			compDir, err := resolveCompDir(c)
			if err != nil {
				return err
			}
			if len(args) == 1 {
				domain = args[0]
			}

			base := filepath.Join(compDir, "03-catalogs", "controls")
			var paths []string
			if domain != "" {
				paths = globYAML(filepath.Join(base, domain))
			} else {
				domains, _ := os.ReadDir(base)
				for _, d := range domains {
					if d.IsDir() {
						paths = append(paths, globYAML(filepath.Join(base, d.Name()))...)
					}
				}
			}

			sort.Strings(paths)
			for _, p := range paths {
				printGovernanceObject(p, []string{"id", "title", "enforcement"})
			}
			return nil
		},
	}
	cmd.Flags().StringVar(&domain, "domain", "", "Filter by domain (e.g. SEC)")
	return cmd
}

func newListProfilesCmd(cfg **config.Config) *cobra.Command {
	return &cobra.Command{
		Use:   "profiles",
		Short: "List all compliance profiles",
		RunE: func(cmd *cobra.Command, args []string) error {
			c := *cfg
			compDir, err := resolveCompDir(c)
			if err != nil {
				return err
			}
			paths := globYAML(filepath.Join(compDir, "04-profiles"))
			sort.Strings(paths)
			for _, p := range paths {
				printGovernanceObject(p, []string{"id", "inherits", "applicable_to"})
			}
			return nil
		},
	}
}

func newListStandardsCmd(cfg **config.Config) *cobra.Command {
	return &cobra.Command{
		Use:   "standards",
		Short: "List all registered standards",
		RunE: func(cmd *cobra.Command, args []string) error {
			c := *cfg
			compDir, err := resolveCompDir(c)
			if err != nil {
				return err
			}
			paths := globYAML(filepath.Join(compDir, "01-sources", "registry"))
			sort.Strings(paths)
			for _, p := range paths {
				printGovernanceObject(p, []string{"id", "name", "publisher"})
			}
			return nil
		},
	}
}

func newListContextsCmd(cfg **config.Config) *cobra.Command {
	return &cobra.Command{
		Use:   "contexts",
		Short: "List all technology contexts",
		RunE: func(cmd *cobra.Command, args []string) error {
			c := *cfg
			compDir, err := resolveCompDir(c)
			if err != nil {
				return err
			}
			data, err := os.ReadFile(filepath.Join(compDir, "02-taxonomy", "technology-contexts.yaml"))
			if err != nil {
				return err
			}
			var raw map[string]map[string]any
			_ = yaml.Unmarshal(data, &raw)
			if contexts, ok := raw["contexts"]; ok {
				var keys []string
				for k := range contexts {
					keys = append(keys, k)
				}
				sort.Strings(keys)
				for _, k := range keys {
					fmt.Println(k)
				}
			}
			return nil
		},
	}
}

func newListDomainsCmd(cfg **config.Config) *cobra.Command {
	return &cobra.Command{
		Use:   "domains",
		Short: "List all control domains",
		RunE: func(cmd *cobra.Command, args []string) error {
			c := *cfg
			compDir, err := resolveCompDir(c)
			if err != nil {
				return err
			}
			entries, _ := os.ReadDir(filepath.Join(compDir, "03-catalogs", "controls"))
			var domains []string
			for _, e := range entries {
				if e.IsDir() {
					domains = append(domains, e.Name())
				}
			}
			sort.Strings(domains)
			for _, d := range domains {
				fmt.Println(d)
			}
			return nil
		},
	}
}

func newShowCmd(cfg **config.Config) *cobra.Command {
	return &cobra.Command{
		Use:   "show <id>",
		Short: "Show any governance object by ID",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			c := *cfg
			compDir, err := resolveCompDir(c)
			if err != nil {
				return err
			}
			path := findByID(compDir, args[0])
			if path == "" {
				return fmt.Errorf("forge registry show: no object found with ID %q", args[0])
			}
			data, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			fmt.Print(string(data))
			return nil
		},
	}
}

// findByID searches common locations for a governance object by ID.
func findByID(compDir, id string) string {
	searchDirs := []string{
		filepath.Join(compDir, "04-profiles"),
		filepath.Join(compDir, "01-sources", "registry"),
		filepath.Join(compDir, "06-bindings"),
	}

	// Controls: extract domain from ID prefix
	for _, c := range id {
		if c == '-' {
			break
		}
	}
	// Add all control domain dirs
	domains, _ := os.ReadDir(filepath.Join(compDir, "03-catalogs", "controls"))
	for _, d := range domains {
		if d.IsDir() {
			searchDirs = append(searchDirs, filepath.Join(compDir, "03-catalogs", "controls", d.Name()))
		}
	}

	for _, dir := range searchDirs {
		path := filepath.Join(dir, id+".yaml")
		if _, err := os.Stat(path); err == nil {
			return path
		}
		// Also try walking subdirs (bindings have context subdirs)
		filepath.WalkDir(dir, func(p string, d os.DirEntry, _ error) error {
			if !d.IsDir() && strings.HasSuffix(d.Name(), ".yaml") {
				data, _ := os.ReadFile(p)
				if strings.Contains(string(data), "\nid: "+id+"\n") ||
					strings.HasPrefix(string(data), "id: "+id+"\n") {
					path = p
				}
			}
			return nil
		})
		if path != "" && path != filepath.Join(dir, id+".yaml") {
			return path
		}
	}
	return ""
}

func globYAML(dir string) []string {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var paths []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".yaml") {
			paths = append(paths, filepath.Join(dir, e.Name()))
		}
	}
	return paths
}

func printGovernanceObject(path string, fields []string) {
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	var obj map[string]any
	_ = yaml.Unmarshal(data, &obj)

	parts := make([]string, 0, len(fields))
	for _, f := range fields {
		if v, ok := obj[f]; ok {
			switch val := v.(type) {
			case string:
				parts = append(parts, val)
			case []any:
				var ss []string
				for _, item := range val {
					if s, ok := item.(string); ok {
						ss = append(ss, s)
					}
				}
				parts = append(parts, strings.Join(ss, ","))
			}
		}
	}
	fmt.Println(strings.Join(parts, "  "))
}
