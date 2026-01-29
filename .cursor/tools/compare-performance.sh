#!/bin/bash

# Performance Comparison Tool
# Purpose: Compare v0.3.2 vs v0.4.0 performance metrics
# Usage: ./.cursor/tools/compare-performance.sh <v0.3.2-url> <v0.4.0-url>
# Related: docs/SPEC-v0.4.0-06-Migration-Strategy.md

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
V032_URL="${1}"
V040_URL="${2}"

# Help message
if [ -z "$V032_URL" ] || [ -z "$V040_URL" ]; then
    echo "Usage: $0 <v0.3.2-url> <v0.4.0-url>"
    echo ""
    echo "Example:"
    echo "  $0 https://compsi-v0-3-2.vercel.app https://compsi-v0-4-0.vercel.app"
    echo ""
    echo "Or for local testing:"
    echo "  $0 http://localhost:3000 http://localhost:3001"
    exit 1
fi

# Functions
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_section() {
    echo -e "\n${CYAN}▶ $1${NC}"
}

# Start
print_header "⚡ PERFORMANCE COMPARISON: v0.3.2 vs v0.4.0"
echo "v0.3.2 URL: $V032_URL"
echo "v0.4.0 URL: $V040_URL"
echo ""

# Create reports directory
REPORT_DIR="performance-reports"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/comparison-$(date +%Y%m%d-%H%M%S).md"

# Create report header
cat > "$REPORT_FILE" << EOF
# Performance Comparison Report

**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**v0.3.2 URL**: $V032_URL
**v0.4.0 URL**: $V040_URL

---

EOF

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. RESPONSE TIME COMPARISON
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "1. Response Time Comparison"

PAGES=("/" "/dashboard" "/test" "/history")

cat >> "$REPORT_FILE" << EOF
## Response Time Comparison

| Page | v0.3.2 | v0.4.0 | Change | Status |
|------|---------|---------|--------|--------|
EOF

for page in "${PAGES[@]}"; do
    echo -e "  Testing: ${page}"
    
    # Test v0.3.2
    V032_TIME=$(curl -s -o /dev/null -w "%{time_total}" "$V032_URL$page" 2>/dev/null || echo "999.999")
    V032_TIME_MS=$(echo "$V032_TIME * 1000" | bc | cut -d'.' -f1)
    
    # Test v0.4.0
    V040_TIME=$(curl -s -o /dev/null -w "%{time_total}" "$V040_URL$page" 2>/dev/null || echo "999.999")
    V040_TIME_MS=$(echo "$V040_TIME * 1000" | bc | cut -d'.' -f1)
    
    # Calculate change
    if [ "$V032_TIME_MS" -gt 0 ]; then
        CHANGE=$(echo "scale=2; (($V040_TIME_MS - $V032_TIME_MS) / $V032_TIME_MS) * 100" | bc)
        CHANGE_ABS=$(echo "$CHANGE" | sed 's/-//')
        
        # Determine status
        if (( $(echo "$CHANGE < -10" | bc -l) )); then
            STATUS="🟢 Faster"
        elif (( $(echo "$CHANGE > 10" | bc -l) )); then
            STATUS="🔴 Slower"
        else
            STATUS="🟡 Similar"
        fi
    else
        CHANGE="N/A"
        STATUS="⚪ Unknown"
    fi
    
    # Display
    if [ "$STATUS" = "🟢 Faster" ]; then
        echo -e "    ${GREEN}✓${NC} $page: ${V032_TIME_MS}ms → ${V040_TIME_MS}ms (${CHANGE}%)"
    elif [ "$STATUS" = "🔴 Slower" ]; then
        echo -e "    ${RED}✗${NC} $page: ${V032_TIME_MS}ms → ${V040_TIME_MS}ms (+${CHANGE}%)"
    else
        echo -e "    ${YELLOW}•${NC} $page: ${V032_TIME_MS}ms → ${V040_TIME_MS}ms (${CHANGE}%)"
    fi
    
    # Add to report
    echo "| $page | ${V032_TIME_MS}ms | ${V040_TIME_MS}ms | ${CHANGE}% | $STATUS |" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" << EOF

---

EOF

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. LIGHTHOUSE COMPARISON (if available)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "2. Lighthouse Performance Scores"

if command -v lighthouse &> /dev/null; then
    echo -e "  Running Lighthouse audits (this may take a few minutes)..."
    
    # Run v0.3.2 Lighthouse
    V032_LIGHTHOUSE="$REPORT_DIR/v032-lighthouse.json"
    lighthouse "$V032_URL" --output=json --output-path="$V032_LIGHTHOUSE" --quiet >/dev/null 2>&1 || true
    
    # Run v0.4.0 Lighthouse
    V040_LIGHTHOUSE="$REPORT_DIR/v040-lighthouse.json"
    lighthouse "$V040_URL" --output=json --output-path="$V040_LIGHTHOUSE" --quiet >/dev/null 2>&1 || true
    
    if [ -f "$V032_LIGHTHOUSE" ] && [ -f "$V040_LIGHTHOUSE" ]; then
        # Extract scores
        V032_PERF=$(cat "$V032_LIGHTHOUSE" | grep -o '"performance":[^,]*' | grep -o '[0-9.]*' | head -1)
        V032_A11Y=$(cat "$V032_LIGHTHOUSE" | grep -o '"accessibility":[^,]*' | grep -o '[0-9.]*' | head -1)
        V032_BP=$(cat "$V032_LIGHTHOUSE" | grep -o '"best-practices":[^,]*' | grep -o '[0-9.]*' | head -1)
        
        V040_PERF=$(cat "$V040_LIGHTHOUSE" | grep -o '"performance":[^,]*' | grep -o '[0-9.]*' | head -1)
        V040_A11Y=$(cat "$V040_LIGHTHOUSE" | grep -o '"accessibility":[^,]*' | grep -o '[0-9.]*' | head -1)
        V040_BP=$(cat "$V040_LIGHTHOUSE" | grep -o '"best-practices":[^,]*' | grep -o '[0-9.]*' | head -1)
        
        # Convert to percentage
        V032_PERF_PCT=$(echo "$V032_PERF * 100" | bc | cut -d'.' -f1)
        V032_A11Y_PCT=$(echo "$V032_A11Y * 100" | bc | cut -d'.' -f1)
        V032_BP_PCT=$(echo "$V032_BP * 100" | bc | cut -d'.' -f1)
        
        V040_PERF_PCT=$(echo "$V040_PERF * 100" | bc | cut -d'.' -f1)
        V040_A11Y_PCT=$(echo "$V040_A11Y * 100" | bc | cut -d'.' -f1)
        V040_BP_PCT=$(echo "$V040_BP * 100" | bc | cut -d'.' -f1)
        
        # Display
        echo -e "  Performance:    ${V032_PERF_PCT}% → ${V040_PERF_PCT}%"
        echo -e "  Accessibility:  ${V032_A11Y_PCT}% → ${V040_A11Y_PCT}%"
        echo -e "  Best Practices: ${V032_BP_PCT}% → ${V040_BP_PCT}%"
        
        # Add to report
        cat >> "$REPORT_FILE" << EOF
## Lighthouse Scores

| Metric | v0.3.2 | v0.4.0 | Change | Status |
|--------|---------|---------|--------|--------|
| Performance | ${V032_PERF_PCT}% | ${V040_PERF_PCT}% | $(($V040_PERF_PCT - $V032_PERF_PCT)) | $([ $V040_PERF_PCT -ge $V032_PERF_PCT ] && echo "✅" || echo "⚠️") |
| Accessibility | ${V032_A11Y_PCT}% | ${V040_A11Y_PCT}% | $(($V040_A11Y_PCT - $V032_A11Y_PCT)) | $([ $V040_A11Y_PCT -ge $V032_A11Y_PCT ] && echo "✅" || echo "⚠️") |
| Best Practices | ${V032_BP_PCT}% | ${V040_BP_PCT}% | $(($V040_BP_PCT - $V032_BP_PCT)) | $([ $V040_BP_PCT -ge $V032_BP_PCT ] && echo "✅" || echo "⚠️") |

---

EOF
    else
        echo -e "  ${YELLOW}⚠${NC} Lighthouse audits failed"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Lighthouse not installed (npm install -g lighthouse)"
    cat >> "$REPORT_FILE" << EOF
## Lighthouse Scores

Lighthouse not available. Install with: \`npm install -g lighthouse\`

---

EOF
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. BUNDLE SIZE COMPARISON
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "3. Bundle Size Comparison"

# Check for .next build directories
if [ -d "app/.next" ]; then
    echo -e "  Analyzing bundle size..."
    
    # Get total bundle size
    BUNDLE_SIZE=$(du -sh app/.next 2>/dev/null | awk '{print $1}')
    
    echo -e "  Current build size: ${BUNDLE_SIZE}"
    
    cat >> "$REPORT_FILE" << EOF
## Bundle Size

- **v0.4.0 Build**: $BUNDLE_SIZE

> Note: Compare with v0.3.2 baseline if available in docs/

---

EOF
else
    echo -e "  ${YELLOW}⚠${NC} Build directory not found"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. SUMMARY
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
cat >> "$REPORT_FILE" << EOF
## Summary

### Performance Analysis

EOF

# Calculate overall verdict
VERDICT="PENDING"

if [ -n "$V040_PERF_PCT" ]; then
    if [ $V040_PERF_PCT -ge 90 ]; then
        VERDICT="✅ EXCELLENT"
    elif [ $V040_PERF_PCT -ge 80 ]; then
        VERDICT="🟢 GOOD"
    elif [ $V040_PERF_PCT -ge 70 ]; then
        VERDICT="🟡 ACCEPTABLE"
    else
        VERDICT="🔴 NEEDS IMPROVEMENT"
    fi
fi

cat >> "$REPORT_FILE" << EOF
**Overall Performance**: $VERDICT

### Recommendations

EOF

if [ "$VERDICT" = "🔴 NEEDS IMPROVEMENT" ] || [ "$VERDICT" = "🟡 ACCEPTABLE" ]; then
    cat >> "$REPORT_FILE" << EOF
1. Review slow pages and optimize
2. Run \`./.cursor/tools/analyze-performance.sh\` for detailed analysis
3. Check bundle size with \`./.cursor/tools/check-bundle-size.sh\`
4. Consider code splitting and lazy loading

EOF
else
    cat >> "$REPORT_FILE" << EOF
1. Performance is good, no major concerns
2. Monitor performance after deployment
3. Set up performance budgets for future changes

EOF
fi

cat >> "$REPORT_FILE" << EOF
---

**Report Generated**: $(date '+%Y-%m-%d %H:%M:%S')
EOF

# Display summary
print_header "📊 COMPARISON SUMMARY"

echo -e "Detailed report saved to: ${BLUE}$REPORT_FILE${NC}\n"

if [ -n "$V040_PERF_PCT" ]; then
    echo -e "Overall Performance: $VERDICT\n"
    
    if [ $V040_PERF_PCT -ge 90 ]; then
        echo -e "${GREEN}✅ v0.4.0 performance is excellent!${NC}"
        echo -e "Safe to deploy to production.\n"
        exit 0
    elif [ $V040_PERF_PCT -ge 80 ]; then
        echo -e "${GREEN}🟢 v0.4.0 performance is good.${NC}"
        echo -e "Safe to deploy, monitor after launch.\n"
        exit 0
    elif [ $V040_PERF_PCT -ge 70 ]; then
        echo -e "${YELLOW}🟡 v0.4.0 performance is acceptable.${NC}"
        echo -e "Consider optimization before deploying.\n"
        exit 0
    else
        echo -e "${RED}🔴 v0.4.0 performance needs improvement.${NC}"
        echo -e "Optimize before deploying to production.\n"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Could not complete full performance comparison.${NC}"
    echo -e "Review report for available metrics: $REPORT_FILE\n"
    exit 0
fi
