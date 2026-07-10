#!/usr/bin/env bash
# collect-frontend-info.sh
#
# Detects frontend projects in a repository and collects security and bundle
# signals for the SEC control domain (frontend context).
#
# The collector is defensive: if a required tool is missing it reports
# the check as unavailable and continues.  Policies treat an unavailable
# tool as a warning-level gap, not a hard error.
#
# Usage: ./collect-frontend-info.sh [repo-root]
# Output: JSON to stdout for SEC-009, SEC-010, SEC-011 (frontend context)
#
# JSON field contract:
#   has_frontend_project                    bool
#   tools.curl_available                    bool
#   tools.node_available                    bool
#   tools.npx_available                     bool
#   security.csp_header_present             bool
#   security.csp_source                     "meta-tag"|"config-file"|"none"
#   security.prod_source_maps_found         bool
#   security.source_map_count               number
#   bundle.max_bundle_size_kb_gzipped       number|null
#   bundle.largest_bundle_file              string|null
#   bundle.raw_size_kb                      number|null

set -euo pipefail

REPO_ROOT="${1:-.}"
REPO_NAME=$(basename "$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$REPO_ROOT")")

cd "$REPO_ROOT"

# ── Detect frontend project ───────────────────────────────────────────────────
# Gate: package.json with a "build" script OR known build-output directory present
HAS_FRONTEND_PROJECT="false"
if [ -f "package.json" ] && grep -q '"build"' package.json 2>/dev/null; then
  HAS_FRONTEND_PROJECT="true"
fi
for _fe_dir in dist build .next public; do
  [ -d "$_fe_dir" ] && HAS_FRONTEND_PROJECT="true" && break
done

# ── Tool availability ─────────────────────────────────────────────────────────
CURL_AVAILABLE="false"
NODE_AVAILABLE="false"
NPX_AVAILABLE="false"
command -v curl >/dev/null 2>&1 && CURL_AVAILABLE="true"
command -v node >/dev/null 2>&1 && NODE_AVAILABLE="true"
command -v npx  >/dev/null 2>&1 && NPX_AVAILABLE="true"

# ── SEC-009: CSP header present ───────────────────────────────────────────────
# (1) meta tag in HTML build output  (2) header configured in a framework/server config
CSP_HEADER_PRESENT="false"
CSP_SOURCE="none"

for _html in "dist/index.html" "build/index.html" \
             ".next/server/pages/index.html" "public/index.html"; do
  if [ -f "$_html" ] && grep -q "Content-Security-Policy" "$_html" 2>/dev/null; then
    CSP_HEADER_PRESENT="true"
    CSP_SOURCE="meta-tag"
    break
  fi
done

if [ "$CSP_HEADER_PRESENT" = "false" ]; then
  for _cfg in next.config.js next.config.ts next.config.mjs next.config.cjs \
              vite.config.js vite.config.ts vite.config.mjs \
              webpack.config.js webpack.config.ts \
              netlify.toml vercel.json .htaccess; do
    if [ -f "$_cfg" ] && grep -qiE "Content-Security-Policy|contentSecurityPolicy" "$_cfg" 2>/dev/null; then
      CSP_HEADER_PRESENT="true"
      CSP_SOURCE="config-file"
      break
    fi
  done
fi

# ── SEC-010: Production source maps present ───────────────────────────────────
FIRST_MAP=$(find dist/ build/ .next/static/ public/ -name "*.map" 2>/dev/null | head -1 || true)
PROD_SOURCE_MAPS_FOUND="false"
SOURCE_MAP_COUNT=0
if [ -n "$FIRST_MAP" ]; then
  PROD_SOURCE_MAPS_FOUND="true"
  _ALL_MAPS=$(find dist/ build/ .next/static/ public/ -name "*.map" 2>/dev/null || true)
  SOURCE_MAP_COUNT=$(printf '%s\n' "$_ALL_MAPS" | grep -c . || true)
  SOURCE_MAP_COUNT=${SOURCE_MAP_COUNT:-0}
fi

# ── SEC-011: Bundle size (largest JS file, gzip-approximated KB) ──────────────
LARGEST_JS_FILE=""
_LARGEST_BYTES=0
while IFS= read -r _js; do
  [ -f "$_js" ] || continue
  _BYTES=$(wc -c < "$_js" 2>/dev/null || echo 0)
  _BYTES=$(echo "$_BYTES" | tr -d ' \t')
  _BYTES=${_BYTES:-0}
  if [ "$_BYTES" -gt "$_LARGEST_BYTES" ] 2>/dev/null; then
    _LARGEST_BYTES="$_BYTES"
    LARGEST_JS_FILE="$_js"
  fi
done < <(find dist/ build/ .next/static/chunks/ -name "*.js" 2>/dev/null || true)

RAW_SIZE_KB="null"
GZIP_SIZE_KB="null"

if [ -n "$LARGEST_JS_FILE" ] && [ -f "$LARGEST_JS_FILE" ]; then
  RAW_SIZE_KB=$(( _LARGEST_BYTES / 1024 ))

  # Prefer a pre-existing .gz companion; otherwise approximate via gzip
  if [ -f "${LARGEST_JS_FILE}.gz" ]; then
    _GZ=$(wc -c < "${LARGEST_JS_FILE}.gz" 2>/dev/null || echo 0)
    _GZ=$(echo "$_GZ" | tr -d ' \t'); _GZ=${_GZ:-0}
    GZIP_SIZE_KB=$(( _GZ / 1024 ))
  elif command -v gzip >/dev/null 2>&1; then
    _GZ=$(gzip -c "$LARGEST_JS_FILE" 2>/dev/null | wc -c || echo 0)
    _GZ=$(echo "$_GZ" | tr -d ' \t'); _GZ=${_GZ:-0}
    GZIP_SIZE_KB=$(( _GZ / 1024 ))
  fi
fi

# ── Emit JSON ─────────────────────────────────────────────────────────────────
# Pass LARGEST_JS_FILE as argv[2] to avoid heredoc quoting issues with path chars
python3 - "$REPO_NAME" "$LARGEST_JS_FILE" <<PYTHON
import json, sys

repo_name    = sys.argv[1]
largest_file = sys.argv[2] if len(sys.argv) > 2 else ""

def to_bool(s): return s == "true"
def to_num(s):
    try:    return int(s)
    except (ValueError, TypeError): return None

output = {
    "repository": {"name": repo_name},
    "context": "frontend",
    "has_frontend_project": to_bool("${HAS_FRONTEND_PROJECT}"),
    "tools": {
        "curl_available": to_bool("${CURL_AVAILABLE}"),
        "node_available": to_bool("${NODE_AVAILABLE}"),
        "npx_available":  to_bool("${NPX_AVAILABLE}"),
    },
    "security": {
        "csp_header_present":     to_bool("${CSP_HEADER_PRESENT}"),
        "csp_source":             "${CSP_SOURCE}",
        "prod_source_maps_found": to_bool("${PROD_SOURCE_MAPS_FOUND}"),
        "source_map_count":       ${SOURCE_MAP_COUNT},
    },
    "bundle": {
        "max_bundle_size_kb_gzipped": to_num("${GZIP_SIZE_KB}"),
        "largest_bundle_file":        largest_file or None,
        "raw_size_kb":                to_num("${RAW_SIZE_KB}"),
    },
}
print(json.dumps(output, indent=2, ensure_ascii=False, default=str))
PYTHON
