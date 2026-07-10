// forge — Platform compliance CLI
// Forge a governed repository. Validate compliance objects. Evaluate gates.
//
// See: tools/forge/docs/IMPLEMENTATION-PLAN.md for the phased implementation guide
// See: docs/forge-architecture.md for the full architecture
package main

import (
	"fmt"
	"os"

	validatecmd "github.com/ashuangiras/platform-compliance/forge/cmd/validate"
	"github.com/ashuangiras/platform-compliance/forge/pkg/config"
	"github.com/spf13/cobra"
)

// Version is set by -ldflags at build time.
var (
	Version = "dev"
	Commit  = "none"
	Date    = "unknown"
)

var (
	cfg           *config.Config
	complianceDir string
	complianceRef string
	outputFormat  string
	verboseFlag   bool
	quietFlag     bool
)

var rootCmd = &cobra.Command{
	Use:   "forge",
	Short: "Forge governed repositories and validate compliance",
	Long: `forge is the developer-facing interface to the platform-compliance system.

  forge new repo <name>      Bootstrap a fully governed repository on GitHub
  forge validate <file>      Validate a governance YAML against its schema
  forge validate repo [path] Validate all governance objects in a repo
  forge check all            Run all applicable OPA policies locally
  forge gate merge           Evaluate the compliance merge gate

See tools/forge/docs/IMPLEMENTATION-PLAN.md for the full implementation guide.`,
	Version: fmt.Sprintf("%s (commit %s, built %s)", Version, Commit, Date),
	PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
		loaded, err := config.Load()
		if err != nil {
			return fmt.Errorf("config: %w", err)
		}
		cfg = loaded
		if complianceDir != "" {
			cfg.ComplianceDir = complianceDir
		}
		if complianceRef != "" {
			cfg.ComplianceRef = complianceRef
		}
		return nil
	},
}

func init() {
	rootCmd.PersistentFlags().StringVar(&complianceDir, "compliance-dir", "",
		"Path to a local platform-compliance checkout (overrides --compliance-ref)")
	rootCmd.PersistentFlags().StringVar(&complianceRef, "compliance-ref", "",
		"platform-compliance version tag to use (default from config)")
	rootCmd.PersistentFlags().StringVarP(&outputFormat, "output", "o", "text",
		"Output format: text, json")
	rootCmd.PersistentFlags().BoolVarP(&verboseFlag, "verbose", "v", false,
		"Show verbose output including skipped files")
	rootCmd.PersistentFlags().BoolVarP(&quietFlag, "quiet", "q", false,
		"Suppress all output except errors and final verdict")

	rootCmd.AddCommand(validatecmd.NewCmd(&cfg, &outputFormat, &verboseFlag, &quietFlag))
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

