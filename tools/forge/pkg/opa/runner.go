package opa

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// collectorMap maps input file names to the collector scripts that produce them.
var collectorMap = map[string]string{
	"github-branch-protection.json": "collect-github-branch-protection.sh",
	"github-security.json":          "collect-github-security-settings.sh",
	"dockerfile-info.json":          "collect-dockerfile-info.sh",
	"go-info.json":                  "collect-go-info.sh",
	"node-info.json":                "collect-node-info.sh",
	"python-info.json":              "collect-python-info.sh",
	"frontend-info.json":            "collect-frontend-info.sh",
	"terraform-info.json":           "collect-terraform-info.sh",
	"actions-info.json":             "collect-workflow-actions.sh",
	"agent-info.json":               "collect-agent-info.py",
	// Additional mappings for tier-2 collectors
	"acc-security.json":  "collect-github-security-settings.sh",
	"aud-security.json":  "collect-github-security-settings.sh",
	"sec-vuln-sla.json":  "collect-github-security-settings.sh",
}

// CollectedInputs holds all collected JSON inputs keyed by input file name.
type CollectedInputs map[string]map[string]any

// RunCollector executes a single collector script and returns its parsed JSON output.
// repoDir is the target repository directory to run the collector against.
// scriptsDir is the path to 07-policies/scripts/ in the compliance directory.
func RunCollector(ctx context.Context, scriptsDir, scriptName, repoDir string, extraEnv []string) (map[string]any, error) {
	scriptPath := filepath.Join(scriptsDir, scriptName)

	var cmd *exec.Cmd
	if strings.HasSuffix(scriptName, ".py") {
		cmd = exec.CommandContext(ctx, "/tmp/penv/bin/python3", scriptPath)
	} else {
		cmd = exec.CommandContext(ctx, "bash", scriptPath)
	}

	cmd.Dir = repoDir
	cmd.Env = append(os.Environ(), extraEnv...)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("opa: collector %s: %w (stderr: %s)", scriptName, err, stderr.String())
	}

	var result map[string]any
	if err := json.Unmarshal(stdout.Bytes(), &result); err != nil {
		return nil, fmt.Errorf("opa: parse output from %s: %w", scriptName, err)
	}
	return result, nil
}

// CollectForEntries runs all unique collectors needed for the given policy entries.
// Results are keyed by input file name (e.g. "go-info.json").
// Collectors that fail are silently skipped — the policy will see missing input and
// return not_applicable or error, which is the correct behaviour.
func CollectForEntries(ctx context.Context, scriptsDir, repoDir string, entries []PolicyMapEntry, extraEnv []string) CollectedInputs {
	// Collect unique input files needed
	needed := make(map[string]bool)
	for _, e := range entries {
		needed[e.InputFile] = true
	}

	results := make(CollectedInputs)
	for inputFile := range needed {
		scriptName, ok := collectorMap[inputFile]
		if !ok {
			continue // no known collector for this input file
		}

		data, err := RunCollector(ctx, scriptsDir, scriptName, repoDir, extraEnv)
		if err != nil {
			// Non-fatal: log to stderr and continue
			fmt.Fprintf(os.Stderr, "⚠  collector %s failed: %v\n", scriptName, err)
			continue
		}
		results[inputFile] = data
	}
	return results
}

// PolicyRun holds the result of evaluating one policy entry.
type PolicyRun struct {
	Entry  PolicyMapEntry
	Result *PolicyResult
	Error  error
}

// RunAll evaluates all policy entries against the collected inputs.
func RunAll(ctx context.Context, engine *Engine, entries []PolicyMapEntry, inputs CollectedInputs) []*PolicyRun {
	var runs []*PolicyRun
	for _, entry := range entries {
		run := &PolicyRun{Entry: entry}

		inputData, ok := inputs[entry.InputFile]
		if !ok {
			run.Result = &PolicyResult{
				Result: "not_applicable",
				Details: map[string]any{
					"message": fmt.Sprintf("input %s not collected (collector unavailable or not applicable)", entry.InputFile),
				},
			}
			runs = append(runs, run)
			continue
		}

		result, err := engine.Eval(ctx, entry, inputData)
		if err != nil {
			run.Error = err
			run.Result = &PolicyResult{Result: "error", Details: map[string]any{"message": err.Error()}}
		} else {
			run.Result = result
		}
		runs = append(runs, run)
	}
	return runs
}
