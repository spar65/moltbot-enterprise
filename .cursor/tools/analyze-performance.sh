#!/bin/bash
# .cursor/tools/analyze-performance.sh
# Purpose: Comprehensive performance analysis combining multiple tools
# Usage: ./.cursor/tools/analyze-performance.sh [url]

set -e

echo "🔬 Comprehensive Performance Analysis"
echo "======================================"
echo ""

URL="${1:-http://localhost:3000}"

# Check if server is running (for localhost)
if [[ "$URL" == *"localhost"* ]] || [[ "$URL" == *"127.0.0.1"* ]]; then
    echo "📍 Checking if server is running at $URL..."
    if ! curl -s --head "$URL" > /dev/null; then
        echo "❌ ERROR: Server not running at $URL"
        echo ""
        echo "Please start your development server:"
        echo "  npm run dev"
        exit 1
    fi
    echo "✅ Server is running"
    echo ""
fi

# Create reports directory
REPORTS_DIR="./performance-reports"
mkdir -p "$REPORTS_DIR"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
REPORT_FILE="$REPORTS_DIR/performance-analysis-$TIMESTAMP.txt"

echo "🎯 Target: $URL" | tee "$REPORT_FILE"
echo "⏰ Time: $(date)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# 1. Run Lighthouse (Mobile & Desktop)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "📱 STEP 1: LIGHTHOUSE MOBILE AUDIT" | tee -a "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

./.cursor/tools/run-lighthouse.sh "$URL" --mobile 2>&1 | tee -a "$REPORT_FILE"

echo "" | tee -a "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "💻 STEP 2: LIGHTHOUSE DESKTOP AUDIT" | tee -a "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

./.cursor/tools/run-lighthouse.sh "$URL" --desktop 2>&1 | tee -a "$REPORT_FILE"

# 2. Check bundle size
echo "" | tee -a "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "📦 STEP 3: BUNDLE SIZE ANALYSIS" | tee -a "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

if [ -d ".next" ]; then
    ./.cursor/tools/check-bundle-size.sh 2>&1 | tee -a "$REPORT_FILE"
else
    echo "⚠️  No build found. Run 'npm run build' to analyze bundle size." | tee -a "$REPORT_FILE"
fi

# 3. Network analysis
echo "" | tee -a "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "🌐 STEP 4: NETWORK ANALYSIS" | tee -a "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "Fetching page to analyze headers..." | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Use curl to check headers
CURL_OUTPUT=$(curl -s -I -L "$URL" -w "\nTotal Time: %{time_total}s\nDNS Lookup: %{time_namelookup}s\nTCP Connect: %{time_connect}s\nTLS Handshake: %{time_appconnect}s\nTTFB: %{time_starttransfer}s\nSize: %{size_download} bytes\n")

echo "$CURL_OUTPUT" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Check for important headers
echo "🔍 Critical Headers Check:" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

if echo "$CURL_OUTPUT" | grep -i "cache-control" > /dev/null; then
    CACHE_CONTROL=$(echo "$CURL_OUTPUT" | grep -i "cache-control" | head -1)
    echo "  ✅ Cache-Control: $CACHE_CONTROL" | tee -a "$REPORT_FILE"
else
    echo "  ❌ Cache-Control: NOT SET" | tee -a "$REPORT_FILE"
fi

if echo "$CURL_OUTPUT" | grep -i "content-encoding" > /dev/null; then
    ENCODING=$(echo "$CURL_OUTPUT" | grep -i "content-encoding" | head -1)
    echo "  ✅ Content-Encoding: $ENCODING" | tee -a "$REPORT_FILE"
else
    echo "  ❌ Content-Encoding: NOT SET (no compression)" | tee -a "$REPORT_FILE"
fi

if echo "$CURL_OUTPUT" | grep -i "x-frame-options\|content-security-policy" > /dev/null; then
    echo "  ✅ Security headers present" | tee -a "$REPORT_FILE"
else
    echo "  ⚠️  Security headers missing" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"

# 4. Performance recommendations
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "💡 STEP 5: RECOMMENDATIONS" | tee -a "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Parse latest Lighthouse mobile report
LATEST_MOBILE_REPORT=$(ls -t ./lighthouse-reports/lighthouse-mobile-*.report.json 2>/dev/null | head -1)

if [ -f "$LATEST_MOBILE_REPORT" ]; then
    python3 - <<EOF | tee -a "$REPORT_FILE"
import json
import sys

with open('$LATEST_MOBILE_REPORT', 'r') as f:
    data = json.load(f)

categories = data['categories']
perf_score = int(categories['performance']['score'] * 100)

print("Based on your Lighthouse audit:\n")

# Performance-based recommendations
if perf_score < 90:
    print("🎯 PRIORITY IMPROVEMENTS (Score: {}/100):".format(perf_score))
    print("")
    
    audits = data['audits']
    
    # Check LCP
    lcp = audits['largest-contentful-paint']
    lcp_value = lcp['numericValue'] / 1000
    if lcp_value > 2.5:
        print("  1. 🔴 CRITICAL: Optimize LCP (currently {:.2f}s)".format(lcp_value))
        print("     → Use Next.js Image with priority prop for hero")
        print("     → Enable ISR/SSG for faster server response")
        print("     → Preload critical resources")
        print("")
    
    # Check CLS
    cls = audits['cumulative-layout-shift']
    cls_value = cls['numericValue']
    if cls_value > 0.1:
        print("  2. 🟡 Fix Layout Shifts (currently {:.3f})".format(cls_value))
        print("     → Add width/height to all images")
        print("     → Use font-display: swap for fonts")
        print("     → Reserve space for dynamic content")
        print("")
    
    # Check render-blocking resources
    if 'render-blocking-resources' in audits:
        render_blocking = audits['render-blocking-resources']
        if render_blocking['score'] < 1:
            print("  3. ⚠️  Remove Render-Blocking Resources")
            print("     → Inline critical CSS")
            print("     → Defer non-critical JavaScript")
            print("     → Use next/font for font optimization")
            print("")
    
    # Check unused JavaScript
    if 'unused-javascript' in audits:
        unused_js = audits['unused-javascript']
        if unused_js.get('numericValue', 0) > 100000:  # > 100KB savings
            savings_kb = unused_js['numericValue'] / 1024
            print("  4. 📦 Reduce Unused JavaScript ({:.0f}KB potential savings)".format(savings_kb))
            print("     → Use dynamic imports for heavy components")
            print("     → Code split by route")
            print("     → Remove unused dependencies")
            print("")
    
    # Check image optimization
    if 'modern-image-formats' in audits:
        modern_images = audits['modern-image-formats']
        if modern_images['score'] < 1:
            print("  5. 🖼️  Optimize Images")
            print("     → Use Next.js Image component")
            print("     → Serve WebP/AVIF formats")
            print("     → Lazy load below-fold images")
            print("")

else:
    print("🎉 EXCELLENT! Performance score is 90+")
    print("")
    print("Continue monitoring:")
    print("  → Run this analysis before each deployment")
    print("  → Set up Lighthouse CI in GitHub Actions")
    print("  → Monitor real user metrics (RUM)")
    print("")

EOF
else
    echo "⚠️  Lighthouse report not found. Run Lighthouse first." | tee -a "$REPORT_FILE"
fi

# 5. Quick wins summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "⚡ QUICK WINS (< 1 HOUR)" | tee -a "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "  1. Add 'priority' prop to hero images" | tee -a "$REPORT_FILE"
echo "  2. Use next/font for font optimization" | tee -a "$REPORT_FILE"
echo "  3. Add preconnect to critical origins" | tee -a "$REPORT_FILE"
echo "  4. Set width/height on all images" | tee -a "$REPORT_FILE"
echo "  5. Enable ISR for static pages (export const revalidate = N)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "📄 ANALYSIS COMPLETE" | tee -a "$REPORT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "Reports saved:" | tee -a "$REPORT_FILE"
echo "  • Full Analysis: $REPORT_FILE" | tee -a "$REPORT_FILE"
echo "  • Lighthouse Reports: ./lighthouse-reports/" | tee -a "$REPORT_FILE"
echo "  • Bundle Reports: ./bundle-reports/" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "Next Steps:" | tee -a "$REPORT_FILE"
echo "  1. Review recommendations above" | tee -a "$REPORT_FILE"
echo "  2. Implement quick wins first" | tee -a "$REPORT_FILE"
echo "  3. Set up continuous monitoring" | tee -a "$REPORT_FILE"
echo "  4. Rerun analysis after changes" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "✅ Performance analysis complete!"

