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

	"gopkg.in/yaml.v3"
)

// collectorEntry is one entry in collector-map.yaml.
type collectorEntry struct {
	Script      string `yaml:"script"`
	Interpreter string `yaml:"interpreter"`
}

// loadCollectorMap reads 07-policies/scripts/collector-map.yaml from the compliance dir.
// Falls back to an empty map (not fatal) if the file is missing — policies will
// return not_applicable for missing inputs.
func loadCollectorMap(scriptsDir string) map[string]collectorEntry {
	path := filepath.Join(scriptsDir, "collector-map.yaml")
	data, err := os.ReadFile(path)
	if err != nil {
		return make(map[string]collectorEntry)
	}
	var m map[string]collectorEntry
	if err := yaml.Unmarshal(data, &m); err != nil {
		return make(map[string]collectorEntry)
	}
	return m
}

// CollectedInputs holds all collected JSON inputs keyed by input file name.
type CollectedInputs map[string]map[string]any

// RunCollector executes a single collector script and returns its parsed JSON output.
// repoDir is the target repository directory to run the collector against.
// scriptsDir is the path to 07-policies/scripts/ in the compliance directory.
func RunCollector(ctx context.Context, scriptsDir, scriptName, interpreter, repoDir string, extraEnv []string) (map[string]any, error) {
	scriptPath := filepath.Join(scriptsDir, scriptName)

	var cmd *exec.Cmd
	if interpreter == "python3" || strings.HasSuffix(scriptName, ".py") {
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
// The collector-script mapping is read from collector-map.yaml in scriptsDir —
// no Go code change is needed when new collectors are added to the compliance repo.
// Collectors that fail or have no mapping are silently skipped.
func CollectForEntries(ctx context.Context, scriptsDir, repoDir string, entries []PolicyMapEntry, extraEnv []string) CollectedInputs {
	// Load the collector map from the compliance repo (data-driven, not hardcoded)
	cmap := loadCollectorMap(scriptsDir)

	// Collect unique input files needed
	needed := make(map[string]bool)
	for _, e := range entries {
		needed[e.InputFile] = true
	}

	results := make(CollectedInputs)
	for inputFile := range needed {
		entry, ok := cmap[inputFile]
		if !ok || entry.Script == "" {
			continue // no collector defined for this input file yet
		}

		data, err := RunCollector(ctx, scriptsDir, entry.Script, entry.Interpreter, repoDir, extraEnv)
		if err != nil {
			fmt.Fprintf(os.Stderr, "⚠  collector %s failed: %v\n", entry.Script, err)
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
