// Package evidence implements forge evidence collect/submit/list.
package evidence

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/ashuangiras/platform-compliance/forge/pkg/config"
	"github.com/ashuangiras/platform-compliance/forge/pkg/opa"
	"github.com/spf13/cobra"
	"gopkg.in/yaml.v3"
)

// EvidenceRecord is a single collected evidence record conforming to evidence.schema.json.
type EvidenceRecord struct {
	SchemaVersion string         `yaml:"schema_version"`
	ID            string         `yaml:"id"`
	ControlID     string         `yaml:"control_id"`
	PolicyCheckID string         `yaml:"policy_check_id"`
	Repository    string         `yaml:"repository"`
	CommitSHA     string         `yaml:"commit_sha"`
	CollectedAt   string         `yaml:"collected_at"`
	CollectedBy   string         `yaml:"collected_by"`
	Result        string         `yaml:"result"`
	Reason        string         `yaml:"reason,omitempty"`
	ArtifactHash  string         `yaml:"artifact_hash"`
	Details       map[string]any `yaml:"details,omitempty"`
}

// NewCmd returns the `forge evidence` parent command.
func NewCmd(cfg **config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "evidence",
		Short: "Manage compliance evidence records",
	}
	cmd.AddCommand(newSubmitCmd(cfg))
	cmd.AddCommand(newListCmd(cfg))
	return cmd
}

func newSubmitCmd(cfg **config.Config) *cobra.Command {
	return &cobra.Command{
		Use:   "submit <file>",
		Short: "Validate and submit an evidence record to the ledger",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			c := *cfg
			if c == nil || c.ComplianceDir == "" {
				return fmt.Errorf("forge evidence submit: --compliance-dir is required")
			}

			data, err := os.ReadFile(args[0])
			if err != nil {
				return fmt.Errorf("forge evidence submit: read %s: %w", args[0], err)
			}

			var rec EvidenceRecord
			if err := yaml.Unmarshal(data, &rec); err != nil {
				return fmt.Errorf("forge evidence submit: parse %s: %w", args[0], err)
			}

			// Write to 08-evidence/collected/<repo>/
			ledgerDir := filepath.Join(c.ComplianceDir, "08-evidence", "collected", rec.Repository)
			if err := os.MkdirAll(ledgerDir, 0o755); err != nil {
				return fmt.Errorf("forge evidence submit: create ledger dir: %w", err)
			}
			destPath := filepath.Join(ledgerDir, rec.ID+".yaml")
			if err := os.WriteFile(destPath, data, 0o644); err != nil {
				return fmt.Errorf("forge evidence submit: write evidence: %w", err)
			}
			fmt.Printf("✓  Submitted %s → %s\n", rec.ID, destPath)
			return nil
		},
	}
}

func newListCmd(cfg **config.Config) *cobra.Command {
	return &cobra.Command{
		Use:   "list [repo]",
		Short: "List evidence records for a repository",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			c := *cfg
			if c == nil || c.ComplianceDir == "" {
				return fmt.Errorf("forge evidence list: --compliance-dir is required")
			}

			ledgerBase := filepath.Join(c.ComplianceDir, "08-evidence", "collected")
			var searchDir string
			if len(args) == 1 {
				searchDir = filepath.Join(ledgerBase, args[0])
			} else {
				searchDir = ledgerBase
			}

			entries, err := os.ReadDir(searchDir)
			if err != nil {
				return fmt.Errorf("forge evidence list: %w", err)
			}
			for _, e := range entries {
				fmt.Println(e.Name())
			}
			return nil
		},
	}
}

// AssembleEvidence creates an EvidenceRecord from a policy run.
func AssembleEvidence(run *opa.PolicyRun, repo, commitSHA string) *EvidenceRecord {
	// Compute artifact hash from the input data (if available)
	artifactHash := ""
	if rawInput, err := json.Marshal(run.Result); err == nil {
		h := sha256.Sum256(rawInput)
		artifactHash = hex.EncodeToString(h[:])
	}

	id := fmt.Sprintf("EVD-%s-%s-%s",
		run.Entry.ControlKey,
		time.Now().UTC().Format("20060102"),
		artifactHash[:8])

	return &EvidenceRecord{
		SchemaVersion: "1.0.0",
		ID:            id,
		ControlID:     extractControlID(run.Entry.ControlKey),
		PolicyCheckID: policyCheckID(run.Entry.RegoFile),
		Repository:    repo,
		CommitSHA:     commitSHA,
		CollectedAt:   time.Now().UTC().Format(time.RFC3339),
		CollectedBy:   "forge",
		Result:        run.Result.Result,
		Reason:        run.Result.Reason,
		ArtifactHash:  artifactHash,
		Details:       run.Result.Details,
	}
}

func extractControlID(key string) string {
	// "QUA-001-NODE" → "QUA-001", "SRC-001" → "SRC-001"
	parts := splitAtThirdDash(key)
	return parts
}

func splitAtThirdDash(s string) string {
	count := 0
	for i, c := range s {
		if c == '-' {
			count++
			if count == 2 {
				return s[:i]
			}
		}
	}
	return s
}

func policyCheckID(regoFile string) string {
	base := filepath.Base(regoFile)
	if len(base) > 5 {
		return base[:len(base)-5] // strip .rego
	}
	return base
}
