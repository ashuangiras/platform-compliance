// Package gate implements `forge gate` — evaluate compliance gates.
package gate

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/ashuangiras/platform-compliance/forge/pkg/compliance"
	"github.com/ashuangiras/platform-compliance/forge/pkg/config"
	"github.com/ashuangiras/platform-compliance/forge/pkg/gate"
	"github.com/ashuangiras/platform-compliance/forge/pkg/manifest"
	"github.com/ashuangiras/platform-compliance/forge/pkg/opa"
	"github.com/spf13/cobra"
)

// NewCmd returns the `forge gate` parent command.
func NewCmd(cfg **config.Config, format *string) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "gate",
		Short: "Evaluate compliance gates",
		Long: `Check whether this repository satisfies a compliance gate.

  forge gate merge    Evaluate the merge gate (required for every PR)
  forge gate deploy   Evaluate the deployment gate
  forge gate release  Evaluate the release gate`,
	}
	cmd.AddCommand(newGateCmd(cfg, format, gate.GateMerge))
	cmd.AddCommand(newGateCmd(cfg, format, gate.GateDeployment))
	cmd.AddCommand(newGateCmd(cfg, format, gate.GateRelease))
	return cmd
}

func newGateCmd(cfg **config.Config, format *string, gateType gate.GateType) *cobra.Command {
	use := string(gateType)
	return &cobra.Command{
		Use:   use,
		Short: fmt.Sprintf("Evaluate the %s gate", gateType),
		RunE: func(cmd *cobra.Command, args []string) error {
			c := *cfg
			if c == nil || c.ComplianceDir == "" {
				return fmt.Errorf("forge gate: --compliance-dir is required")
			}

			comp, err := compliance.LoadLocal(c.ComplianceDir)
			if err != nil {
				return fmt.Errorf("forge gate: %w", err)
			}

			// Load gate criteria
			criteria, err := gate.Load(comp.Root, gateType)
			if err != nil {
				return fmt.Errorf("forge gate: %w", err)
			}

			// Load manifest for contexts
			repoDir, _ := os.Getwd()
			mf, _, err := manifest.FindOrRead(repoDir)
			if err != nil {
				return fmt.Errorf("forge gate: %w", err)
			}

			// Run all applicable policies
			scriptsDir := filepath.Join(comp.Root, "07-policies", "scripts")
			entries, err := opa.LoadPolicyMap(scriptsDir, mf.TechnologyContexts)
			if err != nil {
				return fmt.Errorf("forge gate: %w", err)
			}

			policyDir := filepath.Join(comp.Root, "07-policies", "opa")
			engine := opa.NewEngine(policyDir)
			inputs := opa.CollectForEntries(context.Background(), scriptsDir, repoDir, entries, nil)
			runs := opa.RunAll(context.Background(), engine, entries, inputs)

			// Evaluate the gate
			result := gate.Evaluate(criteria, runs)

			if *format == "json" {
				return json.NewEncoder(os.Stdout).Encode(result)
			}
			return printGateResult(result)
		},
	}
}

func printGateResult(r *gate.GateResult) error {
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

	fmt.Printf("\n  Gate: %s\n\n", r.Gate)

	for _, c := range r.Blocking {
		fmt.Printf("  %s  %-20s  %s\n", col("\033[31m", "✗ BLOCKED"), c.ControlID, c.Reason)
	}
	for _, c := range r.Warning {
		fmt.Printf("  %s  %-20s  %s\n", col("\033[33m", "⚠ WARN   "), c.ControlID, c.Reason)
	}
	for _, c := range r.Passing {
		fmt.Printf("  %s  %-20s\n", col("\033[32m", "✓ PASS   "), c.ControlID)
	}
	for _, c := range r.NA {
		fmt.Printf("  %s  %-20s\n", col("\033[90m", "○ N/A    "), c.ControlID)
	}

	fmt.Printf("\n  %s\n\n", r.Summary())

	if !r.Pass {
		return fmt.Errorf("gate %s: FAIL — %d blocking control(s)", r.Gate, len(r.Blocking))
	}
	return nil
}
