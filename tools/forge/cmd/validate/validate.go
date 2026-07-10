// Package validate implements the `forge validate` command group.
package validate

import (
	"github.com/ashuangiras/platform-compliance/forge/pkg/config"
	"github.com/spf13/cobra"
)

// NewCmd returns the `forge validate` parent command with all subcommands attached.
func NewCmd(cfg **config.Config, format *string, verbose, quiet *bool) *cobra.Command {
	cmd := &cobra.Command{
		Use:     "validate",
		Short:   "Validate governance YAML files against their schemas",
		Aliases: []string{"v"},
	}

	cmd.AddCommand(newFileCmd(cfg, format, verbose, quiet))
	cmd.AddCommand(newRepoCmd(cfg, format, verbose, quiet))
	cmd.AddCommand(newManifestCmd(cfg, format, verbose, quiet))

	cmd.RunE = func(c *cobra.Command, args []string) error {
		if len(args) == 1 {
			return newFileCmd(cfg, format, verbose, quiet).RunE(c, args)
		}
		return c.Help()
	}
	cmd.Args = cobra.MaximumNArgs(1)

	return cmd
}
