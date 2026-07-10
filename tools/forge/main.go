// forge — Platform compliance CLI
// Forge a governed repository. Validate compliance objects. Evaluate gates.
//
// See: docs/IMPLEMENTATION-PLAN.md for the phased implementation guide
// See: ../../docs/forge-architecture.md for the full architecture
package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

// Version is set by -ldflags at build time.
var (
	Version = "dev"
	Commit  = "none"
	Date    = "unknown"
)

var rootCmd = &cobra.Command{
	Use:   "forge",
	Short: "Forge governed repositories and validate compliance",
	Long: `forge is the developer-facing interface to the platform-compliance system.

  forge new repo <name>    Bootstrap a fully governed repository
  forge validate <file>    Validate a governance YAML against its schema
  forge check all          Run all applicable OPA policies locally
  forge gate merge         Evaluate the compliance merge gate

See https://github.com/ashuangiras/platform-compliance/tree/main/tools/forge
for documentation and the implementation plan.`,
	Version: fmt.Sprintf("%s (commit %s, built %s)", Version, Commit, Date),
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}
