#!/bin/bash

# Accessibility Audit Tool
# Purpose: Automated accessibility testing with axe-core
# Usage: ./.cursor/tools/run-accessibility-audit.sh [url]
# Related Rules: @054-accessibility-requirements.mdc, @381-react-testing-library-patterns.mdc

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="${1:-http://localhost:3000}"
PAGES=(
    "/"
    "/dashboard"
    "/test"
    "/history"
    "/settings"
    "/login"
)

# Counters
TOTAL_PAGES=0
PASSED_PAGES=0
FAILED_PAGES=0
TOTAL_VIOLATIONS=0

# Functions
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_section() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

page_pass() {
    TOTAL_PAGES=$((TOTAL_PAGES + 1))
    PASSED_PAGES=$((PASSED_PAGES + 1))
    echo -e "  ${GREEN}✓${NC} $1"
}

page_fail() {
    TOTAL_PAGES=$((TOTAL_PAGES + 1))
    FAILED_PAGES=$((FAILED_PAGES + 1))
    echo -e "  ${RED}✗${NC} $1"
}

print_summary() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  ACCESSIBILITY AUDIT SUMMARY${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "  Total Pages:     $TOTAL_PAGES"
    echo -e "  ${GREEN}Passed:          $PASSED_PAGES${NC}"
    if [ $FAILED_PAGES -gt 0 ]; then
        echo -e "  ${RED}Failed:          $FAILED_PAGES${NC}"
    fi
    echo -e "  ${RED}Total Violations: $TOTAL_VIOLATIONS${NC}"
    echo ""
}

# Check for required tools
command -v node >/dev/null 2>&1 || {
    echo -e "${RED}Error: node is required but not installed.${NC}"
    exit 1
}

# Create temporary axe script
AXE_SCRIPT=$(mktemp /tmp/axe-audit.XXXXXX.js)

cat > "$AXE_SCRIPT" << 'EOF'
const puppeteer = require('puppeteer');
const { AxePuppeteer } = require('@axe-core/puppeteer');

async function runAudit(url) {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });
  
  try {
    const page = await browser.newPage();
    await page.goto(url, { waitUntil: 'networkidle2', timeout: 30000 });
    
    const results = await new AxePuppeteer(page).analyze();
    
    return {
      url: url,
      violations: results.violations,
      passes: results.passes.length,
      incomplete: results.incomplete.length,
    };
  } catch (error) {
    return {
      url: url,
      error: error.message,
    };
  } finally {
    await browser.close();
  }
}

// Get URL from command line
const url = process.argv[2];
if (!url) {
  console.error('Usage: node axe-audit.js <url>');
  process.exit(1);
}

runAudit(url).then(results => {
  console.log(JSON.stringify(results, null, 2));
}).catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
EOF

# Start
print_header "♿ ACCESSIBILITY AUDIT"
echo "Testing pages at: $BASE_URL"
echo "Target: WCAG 2.1 AA Compliance"
echo ""

# Check if dependencies are installed
print_section "Checking Dependencies"

# Project structure is now flat - no need to cd into app/

if [ -f "package.json" ]; then
    if npm list puppeteer @axe-core/puppeteer >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Required packages installed"
    else
        echo -e "  ${YELLOW}⚠${NC} Installing required packages..."
        npm install --save-dev puppeteer @axe-core/puppeteer
    fi
else
    echo -e "  ${RED}✗${NC} package.json not found"
    exit 1
fi

cd - > /dev/null 2>&1 || true

# Run audits
print_section "Running Accessibility Audits"

REPORT_DIR="accessibility-reports"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/audit-$(date +%Y%m%d-%H%M%S).md"

# Create report header
cat > "$REPORT_FILE" << EOF
# Accessibility Audit Report

**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Base URL**: $BASE_URL
**Standard**: WCAG 2.1 AA

---

EOF

for page in "${PAGES[@]}"; do
    URL="$BASE_URL$page"
    echo "  Testing: $URL"
    
    # Run axe audit
    RESULT=$(node "$AXE_SCRIPT" "$URL" 2>/dev/null || echo '{"error": "Failed to run audit"}')
    
    # Check for errors
    if echo "$RESULT" | grep -q '"error"'; then
        page_fail "$page - Error running audit"
        echo "    $(echo "$RESULT" | grep -o '"error"[^}]*')"
        
        # Add to report
        cat >> "$REPORT_FILE" << EOF
## ❌ $page

**Status**: Error  
**URL**: $URL

\`\`\`
$(echo "$RESULT" | grep -o '"error"[^}]*')
\`\`\`

---

EOF
        continue
    fi
    
    # Parse results
    VIOLATIONS=$(echo "$RESULT" | grep -c '"id":' || echo "0")
    PASSES=$(echo "$RESULT" | grep -o '"passes":[^,]*' | grep -o '[0-9]*' || echo "0")
    
    if [ "$VIOLATIONS" -eq 0 ]; then
        page_pass "$page - No violations ($PASSES checks passed)"
        
        # Add to report
        cat >> "$REPORT_FILE" << EOF
## ✅ $page

**Status**: Pass  
**URL**: $URL  
**Checks Passed**: $PASSES  
**Violations**: 0

---

EOF
    else
        page_fail "$page - $VIOLATIONS violation(s) found"
        TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + VIOLATIONS))
        
        # Add to report
        cat >> "$REPORT_FILE" << EOF
## ❌ $page

**Status**: Fail  
**URL**: $URL  
**Violations**: $VIOLATIONS

### Violations

\`\`\`json
$(echo "$RESULT" | grep -A 1000 '"violations"')
\`\`\`

---

EOF
        
        # Show violation details
        echo "$RESULT" | grep -o '"description":"[^"]*"' | head -3 | while read -r line; do
            DESC=$(echo "$line" | sed 's/"description":"\(.*\)"/\1/')
            echo "      - $DESC"
        done
    fi
done

# Cleanup
rm -f "$AXE_SCRIPT"

# Summary
print_summary

# Add summary to report
cat >> "$REPORT_FILE" << EOF

## Summary

- **Total Pages Tested**: $TOTAL_PAGES
- **Passed**: $PASSED_PAGES
- **Failed**: $FAILED_PAGES
- **Total Violations**: $TOTAL_VIOLATIONS

EOF

echo -e "Detailed report saved to: ${BLUE}$REPORT_FILE${NC}\n"

# Final verdict
if [ $FAILED_PAGES -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ ACCESSIBILITY AUDIT PASSED${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "All pages meet WCAG 2.1 AA standards!\n"
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ❌ ACCESSIBILITY AUDIT FAILED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "Fix violations before deploying:\n"
    echo -e "  1. Review report: $REPORT_FILE"
    echo -e "  2. Fix violations"
    echo -e "  3. Re-run audit: ./.cursor/tools/run-accessibility-audit.sh"
    echo ""
    exit 1
fi
