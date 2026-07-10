// Package check implements `forge check` — run OPA policies locally.
package check

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"github.com/ashuangiras/platform-compliance/forge/pkg/compliance"
	"github.com/ashuangiras/platform-compliance/forge/pkg/config"
	"github.com/ashuangiras/platform-compliance/forge/pkg/manifest"
	"github.com/ashuangiras/platform-compliance/forge/pkg/opa"
	"github.com/spf13/cobra"
)

// NewCmd returns the `forge check` parent command.
func NewCmd(cfg **config.Config, format *string) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "check",
		Short: "Run OPA policies locally against this repository",
		Long: `Evaluate compliance policies for this repository without opening a PR.

  forge check all             Run all applicable policies
  forge check policy SRC-001  Run a single policy`,
	}
	cmd.AddCommand(newAllCmd(cfg, format))
	cmd.AddCommand(newPolicyCmd(cfg, format))
	return cmd
}

func newAllCmd(cfg **config.Config, format *string) *cobra.Command {
	var repoDir string
	cmd := &cobra.Command{
		Use:   "all",
		Short: "Run all applicable OPA policies for this repository",
		RunE: func(cmd *cobra.Command, args []string) error {
			c := *cfg
			compDir, err := resolveCompDir(c)
			if err != nil {
				return err
			}
			if repoDir == "" {
				repoDir, _ = os.Getwd()
			}

			// Load manifest to get technology contexts
			mf, _, err := manifest.FindOrRead(repoDir)
			if err != nil {
				return fmt.Errorf("forge check: %w", err)
			}

			comp, err := compliance.LoadLocal(compDir)
			if err != nil {
				return fmt.Errorf("forge check: %w", err)
			}

			// Load applicable policy entries
			scriptsDir := filepath.Join(comp.Root, "07-policies", "scripts")
			entries, err := opa.LoadPolicyMap(scriptsDir, mf.TechnologyContexts)
			if err != nil {
				return fmt.Errorf("forge check: %w", err)
			}

			if len(entries) == 0 {
				fmt.Println("No applicable policies found for contexts:", mf.TechnologyContexts)
				return nil
			}

			// Collect inputs
			fmt.Printf("Running %d applicable policies for contexts: %v\n\n",
				len(entries), mf.TechnologyContexts)

			policyDir := filepath.Join(comp.Root, "07-policies", "opa")
			engine := opa.NewEngine(policyDir)
			inputs := opa.CollectForEntries(cmd.Context(), scriptsDir, repoDir, entries, nil)
			runs := opa.RunAll(context.Background(), engine, entries, inputs)

			if *format == "json" {
				return json.NewEncoder(os.Stdout).Encode(runs)
			}
			return printRuns(runs)
		},
	}
	cmd.Flags().StringVar(&repoDir, "repo-dir", "", "Target repository directory (default: cwd)")
	return cmd
}

func newPolicyCmd(cfg **config.Config, format *string) *cobra.Command {
	return &cobra.Command{
		Use:   "policy <control-key>",
		Short: "Run a single policy by control key (e.g. SRC-001)",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			controlKey := args[0]
			c := *cfg
			compDir, err := resolveCompDir(c)
			if err != nil {
				return err
			}

			comp, err := compliance.LoadLocal(compDir)
			if err != nil {
				return fmt.Errorf("forge check: %w", err)
			}

			scriptsDir := filepath.Join(comp.Root, "07-policies", "scripts")
			entries, err := opa.LoadPolicyMap(scriptsDir, nil) // all entries
			if err != nil {
				return fmt.Errorf("forge check: %w", err)
			}

			// Find the matching entry
			var target *opa.PolicyMapEntry
			for i, e := range entries {
				if e.ControlKey == controlKey {
					target = &entries[i]
					break
				}
			}
			if target == nil {
				return fmt.Errorf("forge check: no policy found for control key %q", controlKey)
			}

			repoDir, _ := os.Getwd()
			policyDir := filepath.Join(comp.Root, "07-policies", "opa")
			engine := opa.NewEngine(policyDir)
			inputs := opa.CollectForEntries(cmd.Context(), scriptsDir, repoDir, []opa.PolicyMapEntry{*target}, nil)
			runs := opa.RunAll(context.Background(), engine, []opa.PolicyMapEntry{*target}, inputs)

			if *format == "json" {
				return json.NewEncoder(os.Stdout).Encode(runs)
			}
			return printRuns(runs)
		},
	}
}

func printRuns(runs []*opa.PolicyRun) error {
	// Sort by result: fail first, then warn, then pass, then n/a
	sort.Slice(runs, func(i, j int) bool {
		return resultOrder(runs[i].Result.Result) < resultOrder(runs[j].Result.Result)
	})

	failed := 0
	for _, r := range runs {
		icon, colour := resultIcon(r.Result.Result)
		reason := r.Result.Reason
		if reason == "" {
			if msg, ok := r.Result.Details["message"].(string); ok {
				reason = msg
			}
		}
		if reason != "" {
			fmt.Printf("%s  %-20s  %s\n", colour(icon), r.Entry.ControlKey, reason)
		} else {
			fmt.Printf("%s  %-20s\n", colour(icon), r.Entry.ControlKey)
		}
		if r.Result.Result == "fail" || r.Result.Result == "error" {
			failed++
		}
	}

	fmt.Printf("\n%d policies evaluated  %d failed\n", len(runs), failed)
	if failed > 0 {
		return fmt.Errorf("%d policy failure(s)", failed)
	}
	return nil
}

func resultOrder(result string) int {
	switch result {
	case "fail", "error":
		return 0
	case "warn":
		return 1
	case "pass":
		return 2
	default:
		return 3
	}
}

func resultIcon(result string) (string, func(string) string) {
	isTerminal := func() bool {
		fi, err := os.Stdout.Stat()
		return err == nil && (fi.Mode()&os.ModeCharDevice) != 0
	}
	col := func(code, s string) string {
		if !isTerminal() {
			return s
		}
		return code + s + "\033[0m"
	}
	switch result {
	case "pass":
		return "✓", func(s string) string { return col("\033[32m", s) }
	case "fail", "error":
		return "✗", func(s string) string { return col("\033[31m", s) }
	case "warn":
		return "⚠", func(s string) string { return col("\033[33m", s) }
	default:
		return "○", func(s string) string { return col("\033[90m", s) }
	}
}

func resolveCompDir(c *config.Config) (string, error) {
	if c != nil && c.ComplianceDir != "" {
		return c.ComplianceDir, nil
	}
	return "", fmt.Errorf("forge check: --compliance-dir is required")
}
