// Package opa provides OPA policy evaluation for forge.
// It parses the POLICY_MAP from run-all-policies.py, invokes input collectors,
// and evaluates Rego policies using the embedded OPA Go library.
package opa

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/open-policy-agent/opa/rego"
)

// PolicyMapEntry describes one entry from the POLICY_MAP in run-all-policies.py.
type PolicyMapEntry struct {
	ControlKey string   // e.g. "SRC-001"
	RegoFile   string   // relative path in 07-policies/opa/
	InputFile  string   // e.g. "github-branch-protection.json"
	QueryPath  string   // e.g. "data.platform.src.src_001_github.result"
	Contexts   []string // e.g. ["github"]
}

// policyMapLineRE matches a single POLICY_MAP entry line.
// Handles multi-context lists like ["github", "github-actions"].
var policyMapLineRE = regexp.MustCompile(
	`"([^"]+)"\s*:\s*\("([^"]+)",\s*"([^"]+)",\s*"([^"]+)",\s*\[([^\]]+)\]\)`,
)

// LoadPolicyMap parses run-all-policies.py and returns all entries,
// filtered to those whose Contexts overlap with the provided set.
// Pass nil for contexts to return all entries.
func LoadPolicyMap(scriptsDir string, contexts []string) ([]PolicyMapEntry, error) {
	path := filepath.Join(scriptsDir, "run-all-policies.py")
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("opa: open POLICY_MAP %s: %w", path, err)
	}
	defer f.Close()

	ctxSet := make(map[string]bool, len(contexts))
	for _, c := range contexts {
		ctxSet[c] = true
	}

	var entries []PolicyMapEntry
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		m := policyMapLineRE.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		controlKey := m[1]
		regoFile := m[2]
		inputFile := m[3]
		queryPath := m[4]
		rawCtxs := m[5]

		// Parse the context list: "github", "github-actions" → ["github", "github-actions"]
		var entryContexts []string
		for _, part := range strings.Split(rawCtxs, ",") {
			ctx := strings.TrimSpace(strings.Trim(part, `"' `))
			if ctx != "" {
				entryContexts = append(entryContexts, ctx)
			}
		}

		// Filter by contexts if specified
		if len(ctxSet) > 0 {
			applicable := false
			for _, c := range entryContexts {
				if ctxSet[c] {
					applicable = true
					break
				}
			}
			if !applicable {
				continue
			}
		}

		entries = append(entries, PolicyMapEntry{
			ControlKey: controlKey,
			RegoFile:   regoFile,
			InputFile:  inputFile,
			QueryPath:  queryPath,
			Contexts:   entryContexts,
		})
	}
	return entries, scanner.Err()
}

// PolicyResult is the structured result returned by every OPA policy.
type PolicyResult struct {
	Result  string         `json:"result"`  // "pass" | "fail" | "warn" | "not_applicable" | "error"
	Reason  string         `json:"reason,omitempty"`
	Details map[string]any `json:"details,omitempty"`
}

// Engine evaluates OPA policies using the embedded OPA Go library.
type Engine struct {
	policyDir string // absolute path to 07-policies/opa/
}

// NewEngine creates an Engine pointing at the given OPA policy directory.
func NewEngine(policyDir string) *Engine {
	return &Engine{policyDir: policyDir}
}

// Eval evaluates a single policy entry against the provided JSON input data.
func (e *Engine) Eval(ctx context.Context, entry PolicyMapEntry, inputData map[string]any) (*PolicyResult, error) {
	regoPath := filepath.Join(e.policyDir, entry.RegoFile)

	r := rego.New(
		rego.Query(entry.QueryPath),
		rego.Load([]string{regoPath}, nil),
		rego.Input(inputData),
	)

	rs, err := r.Eval(ctx)
	if err != nil {
		return &PolicyResult{
			Result: "error",
			Details: map[string]any{
				"message": fmt.Sprintf("OPA eval error: %v", err),
			},
		}, nil
	}

	if len(rs) == 0 || len(rs[0].Expressions) == 0 {
		return &PolicyResult{Result: "error", Details: map[string]any{"message": "empty result"}}, nil
	}

	// The result is a map with "result", and optionally "reason"/"details"
	raw, err := json.Marshal(rs[0].Expressions[0].Value)
	if err != nil {
		return nil, fmt.Errorf("opa: marshal result for %s: %w", entry.ControlKey, err)
	}

	var pr PolicyResult
	if err := json.Unmarshal(raw, &pr); err != nil {
		// If unmarshal fails, try treating value as a plain string
		var s string
		if json.Unmarshal(raw, &s) == nil {
			pr.Result = s
		} else {
			return nil, fmt.Errorf("opa: parse result for %s: %w", entry.ControlKey, err)
		}
	}
	return &pr, nil
}
