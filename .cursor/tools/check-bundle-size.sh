#!/bin/bash
# .cursor/tools/check-bundle-size.sh
# Purpose: Analyze and check bundle size against budgets
# Usage: ./.cursor/tools/check-bundle-size.sh

set -e

echo "📦 Bundle Size Analysis Tool"
echo "============================="
echo ""

# Check if build exists
if [ ! -d ".next" ]; then
    echo "❌ No build found. Running build..."
    npm run build
fi

# Create reports directory
mkdir -p ./bundle-reports
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
REPORT_FILE="./bundle-reports/bundle-analysis-$TIMESTAMP.txt"

echo "🔍 Analyzing bundle sizes..."
echo ""

# Analyze .next/static folder
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee "$REPORT_FILE"
echo "📊 BUNDLE SIZE SUMMARY" | tee -a "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# JavaScript bundles
echo "📜 JAVASCRIPT BUNDLES:" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

if [ -d ".next/static/chunks" ]; then
    # Find all JS files and calculate sizes
    find .next/static/chunks -name "*.js" -type f | while read file; do
        SIZE=$(du -h "$file" | cut -f1)
        SIZE_BYTES=$(du -b "$file" | cut -f1)
        GZIP_SIZE=$(gzip -c "$file" | wc -c)
        GZIP_SIZE_KB=$((GZIP_SIZE / 1024))
        
        FILENAME=$(basename "$file")
        echo "  $FILENAME: $SIZE (${GZIP_SIZE_KB}KB gzipped)" | tee -a "$REPORT_FILE"
    done
else
    echo "  No chunks found" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"

# Calculate totals
echo "📈 TOTALS:" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Total JavaScript size
if [ -d ".next/static/chunks" ]; then
    TOTAL_JS_BYTES=$(find .next/static/chunks -name "*.js" -type f -exec du -b {} + | awk '{sum += $1} END {print sum}')
    TOTAL_JS_KB=$((TOTAL_JS_BYTES / 1024))
    TOTAL_JS_MB=$(echo "scale=2; $TOTAL_JS_KB / 1024" | bc)
    
    # Calculate gzipped size
    TOTAL_GZIP_BYTES=0
    for file in $(find .next/static/chunks -name "*.js" -type f); do
        GZIP_SIZE=$(gzip -c "$file" | wc -c)
        TOTAL_GZIP_BYTES=$((TOTAL_GZIP_BYTES + GZIP_SIZE))
    done
    TOTAL_GZIP_KB=$((TOTAL_GZIP_BYTES / 1024))
    
    echo "  Total JavaScript: ${TOTAL_JS_MB}MB (${TOTAL_GZIP_KB}KB gzipped)" | tee -a "$REPORT_FILE"
else
    TOTAL_GZIP_KB=0
fi

# Total CSS size
if [ -d ".next/static/css" ]; then
    TOTAL_CSS_BYTES=$(find .next/static/css -name "*.css" -type f -exec du -b {} + | awk '{sum += $1} END {print sum}')
    TOTAL_CSS_KB=$((TOTAL_CSS_BYTES / 1024))
    echo "  Total CSS: ${TOTAL_CSS_KB}KB" | tee -a "$REPORT_FILE"
else
    TOTAL_CSS_KB=0
fi

# Total Images
if [ -d ".next/static/media" ]; then
    TOTAL_IMG_BYTES=$(find .next/static/media -type f -exec du -b {} + | awk '{sum += $1} END {print sum}')
    TOTAL_IMG_KB=$((TOTAL_IMG_BYTES / 1024))
    echo "  Total Images: ${TOTAL_IMG_KB}KB" | tee -a "$REPORT_FILE"
else
    TOTAL_IMG_KB=0
fi

TOTAL_SIZE_KB=$((TOTAL_GZIP_KB + TOTAL_CSS_KB + TOTAL_IMG_KB))
echo "" | tee -a "$REPORT_FILE"
echo "  🎯 Total Bundle Size (gzipped): ${TOTAL_SIZE_KB}KB" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Check against budgets
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "🎯 BUDGET CHECK" | tee -a "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

BUDGET_FAILED=0

# JavaScript budget: 300KB gzipped
JS_BUDGET_KB=300
if [ $TOTAL_GZIP_KB -le $JS_BUDGET_KB ]; then
    echo "  ✅ JavaScript: ${TOTAL_GZIP_KB}KB / ${JS_BUDGET_KB}KB" | tee -a "$REPORT_FILE"
else
    echo "  ❌ JavaScript: ${TOTAL_GZIP_KB}KB / ${JS_BUDGET_KB}KB (OVER BUDGET by $((TOTAL_GZIP_KB - JS_BUDGET_KB))KB)" | tee -a "$REPORT_FILE"
    BUDGET_FAILED=1
fi

# CSS budget: 50KB
CSS_BUDGET_KB=50
if [ $TOTAL_CSS_KB -le $CSS_BUDGET_KB ]; then
    echo "  ✅ CSS: ${TOTAL_CSS_KB}KB / ${CSS_BUDGET_KB}KB" | tee -a "$REPORT_FILE"
else
    echo "  ❌ CSS: ${TOTAL_CSS_KB}KB / ${CSS_BUDGET_KB}KB (OVER BUDGET by $((TOTAL_CSS_KB - CSS_BUDGET_KB))KB)" | tee -a "$REPORT_FILE"
    BUDGET_FAILED=1
fi

# Total budget: 500KB
TOTAL_BUDGET_KB=500
if [ $TOTAL_SIZE_KB -le $TOTAL_BUDGET_KB ]; then
    echo "  ✅ Total: ${TOTAL_SIZE_KB}KB / ${TOTAL_BUDGET_KB}KB" | tee -a "$REPORT_FILE"
else
    echo "  ❌ Total: ${TOTAL_SIZE_KB}KB / ${TOTAL_BUDGET_KB}KB (OVER BUDGET by $((TOTAL_SIZE_KB - TOTAL_BUDGET_KB))KB)" | tee -a "$REPORT_FILE"
    BUDGET_FAILED=1
fi

echo "" | tee -a "$REPORT_FILE"

# Top largest files
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "📊 TOP 10 LARGEST FILES (gzipped)" | tee -a "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

if [ -d ".next/static/chunks" ]; then
    find .next/static/chunks -name "*.js" -type f | while read file; do
        GZIP_SIZE=$(gzip -c "$file" | wc -c)
        GZIP_SIZE_KB=$((GZIP_SIZE / 1024))
        FILENAME=$(basename "$file")
        echo "$GZIP_SIZE_KB $FILENAME"
    done | sort -rn | head -10 | while read size name; do
        echo "  ${size}KB - $name" | tee -a "$REPORT_FILE"
    done
fi

echo "" | tee -a "$REPORT_FILE"

# Recommendations
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "💡 RECOMMENDATIONS" | tee -a "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

if [ $BUDGET_FAILED -eq 1 ]; then
    echo "  Bundle size exceeds budget! Consider:" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    echo "  1. Use dynamic imports for heavy components:" | tee -a "$REPORT_FILE"
    echo "     const Heavy = dynamic(() => import('./Heavy'))" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    echo "  2. Check for duplicate dependencies:" | tee -a "$REPORT_FILE"
    echo "     npm dedupe" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    echo "  3. Use lighter alternatives:" | tee -a "$REPORT_FILE"
    echo "     • date-fns instead of moment" | tee -a "$REPORT_FILE"
    echo "     • preact instead of react (if possible)" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    echo "  4. Remove unused dependencies:" | tee -a "$REPORT_FILE"
    echo "     npm prune" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    echo "  5. Analyze bundle composition:" | tee -a "$REPORT_FILE"
    echo "     ANALYZE=true npm run build" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
else
    echo "  ✅ Bundle size is within budget! Great job!" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    echo "  Continue monitoring bundle size on every build." | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "📄 Full report saved to: $REPORT_FILE"
echo ""

# Exit with appropriate code
if [ $BUDGET_FAILED -eq 1 ]; then
    echo "❌ Bundle size check FAILED - exceeds budget"
    exit 1
else
    echo "✅ Bundle size check PASSED"
    exit 0
fi

