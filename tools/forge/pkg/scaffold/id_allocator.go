package scaffold

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

// NextControlID scans existing control files in a domain directory and returns
// the next unused numeric ID. E.g. if SEC-008 exists → returns "SEC-009".
func NextControlID(complianceDir, domain string) (string, error) {
	dir := filepath.Join(complianceDir, "03-catalogs", "controls", domain)
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return domain + "-001", nil
		}
		return "", fmt.Errorf("scaffold: read controls/%s: %w", domain, err)
	}

	re := regexp.MustCompile(`^` + regexp.QuoteMeta(domain) + `-(\d+)\.yaml$`)
	maxN := 0
	for _, e := range entries {
		m := re.FindStringSubmatch(e.Name())
		if m == nil {
			continue
		}
		n, _ := strconv.Atoi(m[1])
		if n > maxN {
			maxN = n
		}
	}
	return fmt.Sprintf("%s-%03d", domain, maxN+1), nil
}

// NextADRID scans decisions/ and returns the next available ADR ID.
// E.g. if ADR-0018 exists → returns "ADR-0019".
func NextADRID(complianceDir string) (string, error) {
	dir := filepath.Join(complianceDir, "decisions")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return "ADR-0001", nil
	}

	re := regexp.MustCompile(`^ADR-(\d+)-`)
	maxN := 0
	for _, e := range entries {
		m := re.FindStringSubmatch(e.Name())
		if m == nil {
			continue
		}
		n, _ := strconv.Atoi(m[1])
		if n > maxN {
			maxN = n
		}
	}
	return fmt.Sprintf("ADR-%04d", maxN+1), nil
}

// NextChangeRecord generates the next CHG-YYYYMMDD-NNN for today.
func NextChangeRecord(complianceDir string) (string, error) {
	today := time.Now().UTC().Format("20060102")
	dir := filepath.Join(complianceDir, "09-assessments", "changes")
	entries, _ := os.ReadDir(dir)

	prefix := "CHG-" + today + "-"
	re := regexp.MustCompile(`^CHG-` + today + `-(\d+)`)
	maxN := 0
	for _, e := range entries {
		m := re.FindStringSubmatch(e.Name())
		if m == nil {
			continue
		}
		n, _ := strconv.Atoi(m[1])
		if n > maxN {
			maxN = n
		}
	}
	_ = prefix
	return fmt.Sprintf("CHG-%s-%03d", today, maxN+1), nil
}

// NextWaiverID generates WAV-<CONTROLID>-<YYYYMM>-<NNN>.
func NextWaiverID(complianceDir, controlID string) (string, error) {
	month := time.Now().UTC().Format("200601")
	dir := filepath.Join(complianceDir, "09-assessments", "waivers")
	entries, _ := os.ReadDir(dir)

	prefix := "WAV-" + controlID + "-" + month
	re := regexp.MustCompile(`^WAV-` + regexp.QuoteMeta(controlID) + `-` + month + `-(\d+)`)
	maxN := 0
	for _, e := range entries {
		m := re.FindStringSubmatch(e.Name())
		if m == nil {
			continue
		}
		n, _ := strconv.Atoi(m[1])
		if n > maxN {
			maxN = n
		}
	}
	_ = prefix
	return fmt.Sprintf("WAV-%s-%s-%03d", controlID, month, maxN+1), nil
}

// ListDomains returns all control domain codes from the taxonomy.
func ListDomains(complianceDir string) ([]string, error) {
	dir := filepath.Join(complianceDir, "03-catalogs", "controls")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	var domains []string
	for _, e := range entries {
		if e.IsDir() && !strings.HasPrefix(e.Name(), ".") && e.Name() != "README.md" {
			domains = append(domains, e.Name())
		}
	}
	sort.Strings(domains)
	return domains, nil
}
