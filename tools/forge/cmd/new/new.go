// Package new implements the `forge new` command group for bootstrapping
// governed repositories and scaffolding governance objects.
package new

import (
	"github.com/ashuangiras/platform-compliance/forge/pkg/config"
	"github.com/spf13/cobra"
)

// NewCmd returns the `forge new` parent command with all subcommands attached.
func NewCmd(cfg **config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "new",
		Short: "Bootstrap a governed repository or scaffold a governance object",
		Long: `Create new governed repositories or scaffold governance YAML objects.

  forge new repo <name>          Bootstrap a complete governed repository on GitHub
  forge new control              Scaffold a control YAML in the correct domain directory
  forge new adr                  Scaffold the next ADR with auto-incremented ID
  forge new waiver               Scaffold a waiver record`,
	}

	cmd.AddCommand(newRepoCmd(cfg))

	return cmd
}
