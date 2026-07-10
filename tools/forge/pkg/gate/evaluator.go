package gate

import (
	"fmt"
	"strings"

	"github.com/ashuangiras/platform-compliance/forge/pkg/opa"
)

// GateResult holds the outcome of evaluating all gate controls.
type GateResult struct {
	Gate     GateType
	Pass     bool
	Blocking []ControlResult
	Warning  []ControlResult
	Passing  []ControlResult
	NA       []ControlResult
	Error    []ControlResult
}

// ControlResult holds a single control's evaluation outcome.
type ControlResult struct {
	ControlID   string
	PolicyKey   string
	Result      string
	Reason      string
	Enforcement string
}

// Evaluate checks all gate controls against the policy runs.
// A policy run is matched to a gate control by ControlKey prefix
// (e.g. gate control "SRC-001" matches policy run "SRC-001" or "SRC-001-NODE").
func Evaluate(criteria *GateCriteria, runs []*opa.PolicyRun) *GateResult {
	// Index runs by control key for fast lookup
	runByKey := make(map[string]*opa.PolicyRun, len(runs))
	for _, r := range runs {
		runByKey[r.Entry.ControlKey] = r
	}

	gr := &GateResult{Gate: criteria.Type}

	for _, gc := range criteria.RequiredControls {
		cr := ControlResult{
			ControlID:   gc.ControlID,
			Enforcement: gc.Enforcement,
		}

		// Find a matching policy run
		run := findRun(gc.ControlID, runByKey)
		if run == nil {
			// No policy run for this gate control — treat as not evaluated
			cr.Result = "not_applicable"
			cr.Reason = fmt.Sprintf("no policy found for %s", gc.ControlID)
			gr.NA = append(gr.NA, cr)
			continue
		}

		cr.PolicyKey = run.Entry.ControlKey
		cr.Result = run.Result.Result
		cr.Reason = run.Result.Reason
		if cr.Reason == "" {
			if details, ok := run.Result.Details["message"].(string); ok {
				cr.Reason = details
			}
		}

		switch run.Result.Result {
		case "pass":
			gr.Passing = append(gr.Passing, cr)
		case "fail":
			if gc.Enforcement == "block" || gc.Enforcement == "" {
				gr.Blocking = append(gr.Blocking, cr)
			} else {
				gr.Warning = append(gr.Warning, cr)
			}
		case "warn":
			gr.Warning = append(gr.Warning, cr)
		case "not_applicable":
			gr.NA = append(gr.NA, cr)
		default:
			gr.Error = append(gr.Error, cr)
		}
	}

	gr.Pass = len(gr.Blocking) == 0 && len(gr.Error) == 0
	return gr
}

// findRun finds a policy run whose ControlKey matches controlID.
// Handles both exact matches and prefix matches (e.g. "QUA-001" matches "QUA-001-NODE").
func findRun(controlID string, runs map[string]*opa.PolicyRun) *opa.PolicyRun {
	if r, ok := runs[controlID]; ok {
		return r
	}
	// Prefix match
	for key, r := range runs {
		if strings.HasPrefix(key, controlID+"-") {
			return r
		}
	}
	return nil
}

// Summary returns a one-line summary of the gate result.
func (gr *GateResult) Summary() string {
	total := len(gr.Blocking) + len(gr.Warning) + len(gr.Passing) + len(gr.NA) + len(gr.Error)
	if gr.Pass {
		return fmt.Sprintf("PASS — %d controls evaluated, %d passing, %d warning, %d n/a",
			total, len(gr.Passing), len(gr.Warning), len(gr.NA))
	}
	return fmt.Sprintf("FAIL — %d blocking, %d passing, %d warning, %d n/a",
		len(gr.Blocking), len(gr.Passing), len(gr.Warning), len(gr.NA))
}
