// Package assess implements `forge assess run/show`.
package assess

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/ashuangiras/platform-compliance/forge/pkg/config"
	"github.com/spf13/cobra"
	"gopkg.in/yaml.v3"
)

// AssessmentReport is a schema-valid assessment report.
type AssessmentReport struct {
	SchemaVersion string              `yaml:"schema_version"`
	ID            string              `yaml:"id"`
	Repository    string              `yaml:"repository"`
	Profile       string              `yaml:"profile"`
	ComplianceRef string              `yaml:"compliance_ref"`
	AssessedAt    string              `yaml:"assessed_at"`
	AssessedBy    string              `yaml:"assessed_by"`
	Controls      []ControlAssessment `yaml:"controls"`
	OverallResult string              `yaml:"overall_result"`
}

// ControlAssessment is a single control's result in an assessment.
type ControlAssessment struct {
	ControlID  string `yaml:"control_id"`
	Result     string `yaml:"result"`
	EvidenceID string `yaml:"evidence_id,omitempty"`
	WaiverID   string `yaml:"waiver_id,omitempty"`
	Reason     string `yaml:"reason,omitempty"`
}

// NewCmd returns the `forge assess` parent command.
func NewCmd(cfg **config.Config) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "assess",
		Short: "Generate and view compliance assessment reports",
	}
	cmd.AddCommand(newRunCmd(cfg))
	cmd.AddCommand(newShowCmd(cfg))
	return cmd
}

func newRunCmd(cfg **config.Config) *cobra.Command {
	var repo, profile, ref string
	cmd := &cobra.Command{
		Use:   "run",
		Short: "Generate an assessment report from evidence in the ledger",
		RunE: func(cmd *cobra.Command, args []string) error {
			c := *cfg
			if c == nil || c.ComplianceDir == "" {
				return fmt.Errorf("forge assess run: --compliance-dir is required")
			}
			if repo == "" {
				return fmt.Errorf("forge assess run: --repo is required (e.g. ashuangiras/platform-compliance)")
			}

			// Collect evidence records for this repo
			ledgerDir := filepath.Join(c.ComplianceDir, "08-evidence", "collected",
				strings.ReplaceAll(repo, "/", "-"))

			entries, err := os.ReadDir(ledgerDir)
			if err != nil && !os.IsNotExist(err) {
				return fmt.Errorf("forge assess run: read ledger: %w", err)
			}

			var controls []ControlAssessment
			overallResult := "pass"
			for _, e := range entries {
				if !strings.HasSuffix(e.Name(), ".yaml") {
					continue
				}
				data, _ := os.ReadFile(filepath.Join(ledgerDir, e.Name()))
				var rec map[string]any
				_ = yaml.Unmarshal(data, &rec)

				ca := ControlAssessment{
					ControlID:  str(rec, "control_id"),
					Result:     str(rec, "result"),
					EvidenceID: str(rec, "id"),
					Reason:     str(rec, "reason"),
				}
				controls = append(controls, ca)
				if ca.Result == "fail" {
					overallResult = "fail"
				} else if ca.Result == "warn" && overallResult == "pass" {
					overallResult = "partial"
				}
			}

			id := fmt.Sprintf("ASSESS-%s-%s-001",
				strings.ToUpper(strings.ReplaceAll(repo, "/", "-")),
				time.Now().UTC().Format("20060102"))

			report := AssessmentReport{
				SchemaVersion: "1.0.0",
				ID:            id,
				Repository:    repo,
				Profile:       profile,
				ComplianceRef: ref,
				AssessedAt:    time.Now().UTC().Format(time.RFC3339),
				AssessedBy:    "forge",
				Controls:      controls,
				OverallResult: overallResult,
			}

			// Write to 09-assessments/reports/
			reportsDir := filepath.Join(c.ComplianceDir, "09-assessments", "reports")
			_ = os.MkdirAll(reportsDir, 0o755)
			outPath := filepath.Join(reportsDir, id+".yaml")
			data, err := yaml.Marshal(report)
			if err != nil {
				return fmt.Errorf("forge assess run: marshal report: %w", err)
			}
			if err := os.WriteFile(outPath, data, 0o644); err != nil {
				return fmt.Errorf("forge assess run: write report: %w", err)
			}
			fmt.Printf("✓  Assessment %s → %s\n", id, outPath)
			fmt.Printf("   Controls assessed: %d  Overall: %s\n", len(controls), overallResult)
			return nil
		},
	}
	cmd.Flags().StringVar(&repo, "repo", "", "Repository name (e.g. ashuangiras/platform-compliance)")
	cmd.Flags().StringVar(&profile, "profile", "", "Profile ID used for this assessment")
	cmd.Flags().StringVar(&ref, "compliance-ref", "", "Compliance ref version")
	return cmd
}

func newShowCmd(cfg **config.Config) *cobra.Command {
	return &cobra.Command{
		Use:   "show [id]",
		Short: "Show an existing assessment report",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			c := *cfg
			if c == nil || c.ComplianceDir == "" {
				return fmt.Errorf("forge assess show: --compliance-dir is required")
			}
			reportsDir := filepath.Join(c.ComplianceDir, "09-assessments", "reports")
			if len(args) == 0 {
				entries, _ := os.ReadDir(reportsDir)
				for _, e := range entries {
					if strings.HasSuffix(e.Name(), ".yaml") {
						fmt.Println(strings.TrimSuffix(e.Name(), ".yaml"))
					}
				}
				return nil
			}
			path := filepath.Join(reportsDir, args[0]+".yaml")
			data, err := os.ReadFile(path)
			if err != nil {
				return fmt.Errorf("forge assess show: %w", err)
			}
			fmt.Print(string(data))
			return nil
		},
	}
}

func str(m map[string]any, key string) string {
	if v, ok := m[key]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}
