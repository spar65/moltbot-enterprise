#!/bin/bash
# .cursor/tools/run-lighthouse.sh
# Purpose: Run Lighthouse performance audits with budget checking
# Usage: ./cursor/tools/run-lighthouse.sh [url] [--mobile|--desktop] [--view]

set -e

echo "🔍 Lighthouse Performance Audit Tool"
echo "======================================"
echo ""

# Default configuration
URL="${1:-http://localhost:3000}"
DEVICE="${2:-mobile}"
VIEW_REPORT="false"
OUTPUT_DIR="./lighthouse-reports"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --mobile) DEVICE="mobile"; shift ;;
        --desktop) DEVICE="desktop"; shift ;;
        --view) VIEW_REPORT="true"; shift ;;
        --help|-h)
            echo "Usage: ./cursor/tools/run-lighthouse.sh [url] [options]"
            echo ""
            echo "Options:"
            echo "  --mobile        Run audit for mobile (default)"
            echo "  --desktop       Run audit for desktop"
            echo "  --view          Open report in browser after generation"
            echo "  --help, -h      Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./cursor/tools/run-lighthouse.sh"
            echo "  ./cursor/tools/run-lighthouse.sh http://localhost:3000 --mobile --view"
            echo "  ./cursor/tools/run-lighthouse.sh https://example.com --desktop"
            exit 0
            ;;
        *) URL="$1"; shift ;;
    esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if Lighthouse is installed
if ! command -v lighthouse &> /dev/null; then
    echo "❌ Lighthouse is not installed."
    echo ""
    echo "Installing Lighthouse CLI..."
    npm install -g lighthouse
fi

# Check if URL is accessible
echo "📍 Target URL: $URL"
echo "📱 Device: $DEVICE"
echo ""

# Check if server is running (for localhost)
if [[ "$URL" == *"localhost"* ]] || [[ "$URL" == *"127.0.0.1"* ]]; then
    if ! curl -s --head "$URL" > /dev/null; then
        echo "❌ ERROR: Server not running at $URL"
        echo ""
        echo "Please start your development server:"
        echo "  npm run dev"
        exit 1
    fi
fi

# Lighthouse configuration
LIGHTHOUSE_FLAGS=(
    "--output=html"
    "--output=json"
    "--output-path=$OUTPUT_DIR/lighthouse-$DEVICE-$TIMESTAMP"
)

# Device-specific flags
if [ "$DEVICE" = "mobile" ]; then
    LIGHTHOUSE_FLAGS+=(
        "--preset=perf"
        "--emulated-form-factor=mobile"
        "--throttling-method=simulate"
        "--throttling.rttMs=150"
        "--throttling.throughputKbps=1638.4"
        "--throttling.cpuSlowdownMultiplier=4"
    )
else
    LIGHTHOUSE_FLAGS+=(
        "--preset=desktop"
        "--emulated-form-factor=desktop"
        "--throttling-method=simulate"
        "--throttling.rttMs=40"
        "--throttling.throughputKbps=10240"
        "--throttling.cpuSlowdownMultiplier=1"
    )
fi

# Add budget if exists
if [ -f "./lighthouse-budget.json" ]; then
    LIGHTHOUSE_FLAGS+=("--budget-path=./lighthouse-budget.json")
    echo "📊 Using performance budget: ./lighthouse-budget.json"
fi

# Run Lighthouse
echo "🚀 Running Lighthouse audit..."
echo ""

lighthouse "$URL" "${LIGHTHOUSE_FLAGS[@]}" 2>&1 | tee "$OUTPUT_DIR/lighthouse-$DEVICE-$TIMESTAMP.log"

# Parse JSON results
REPORT_JSON="$OUTPUT_DIR/lighthouse-$DEVICE-$TIMESTAMP.report.json"
REPORT_HTML="$OUTPUT_DIR/lighthouse-$DEVICE-$TIMESTAMP.report.html"

if [ ! -f "$REPORT_JSON" ]; then
    echo "❌ ERROR: Lighthouse report not generated"
    exit 1
fi

echo ""
echo "✅ Lighthouse audit complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 PERFORMANCE SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Extract scores using Python (more reliable than jq)
python3 - <<EOF
import json
import sys

with open('$REPORT_JSON', 'r') as f:
    data = json.load(f)

categories = data['categories']
audits = data['audits']

# Print scores
print("📈 SCORES:")
print(f"  Performance:    {int(categories['performance']['score'] * 100)}/100")
print(f"  Accessibility:  {int(categories['accessibility']['score'] * 100)}/100")
print(f"  Best Practices: {int(categories['best-practices']['score'] * 100)}/100")
print(f"  SEO:            {int(categories['seo']['score'] * 100)}/100")
print("")

# Print Core Web Vitals
print("⚡ CORE WEB VITALS:")

lcp = audits['largest-contentful-paint']
lcp_value = lcp['numericValue'] / 1000
lcp_rating = "🟢 GOOD" if lcp_value < 2.5 else "🟡 NEEDS IMPROVEMENT" if lcp_value < 4 else "🔴 POOR"
print(f"  LCP: {lcp_value:.2f}s {lcp_rating}")

if 'interaction-to-next-paint' in audits:
    inp = audits['interaction-to-next-paint']
    inp_value = inp['numericValue']
    inp_rating = "🟢 GOOD" if inp_value < 200 else "🟡 NEEDS IMPROVEMENT" if inp_value < 500 else "🔴 POOR"
    print(f"  INP: {inp_value:.0f}ms {inp_rating}")
elif 'max-potential-fid' in audits:
    fid = audits['max-potential-fid']
    fid_value = fid['numericValue']
    fid_rating = "🟢 GOOD" if fid_value < 100 else "🟡 NEEDS IMPROVEMENT" if fid_value < 300 else "🔴 POOR"
    print(f"  FID: {fid_value:.0f}ms {fid_rating}")

cls = audits['cumulative-layout-shift']
cls_value = cls['numericValue']
cls_rating = "🟢 GOOD" if cls_value < 0.1 else "🟡 NEEDS IMPROVEMENT" if cls_value < 0.25 else "🔴 POOR"
print(f"  CLS: {cls_value:.3f} {cls_rating}")
print("")

# Print other key metrics
print("🔍 OTHER METRICS:")
fcp = audits['first-contentful-paint']
fcp_value = fcp['numericValue'] / 1000
print(f"  FCP:  {fcp_value:.2f}s")

ttfb = audits['server-response-time']
ttfb_value = ttfb['numericValue']
print(f"  TTFB: {ttfb_value:.0f}ms")

si = audits['speed-index']
si_value = si['numericValue'] / 1000
print(f"  SI:   {si_value:.2f}s")

tti = audits['interactive']
tti_value = tti['numericValue'] / 1000
print(f"  TTI:  {tti_value:.2f}s")
print("")

# Print opportunities
print("💡 TOP OPPORTUNITIES:")
opportunities = [(k, v) for k, v in audits.items() if v.get('details', {}).get('type') == 'opportunity']
opportunities.sort(key=lambda x: x[1].get('numericValue', 0), reverse=True)

count = 0
for key, audit in opportunities[:5]:
    if audit.get('numericValue', 0) > 0:
        savings = audit['numericValue'] / 1000
        print(f"  • {audit['title']}: {savings:.2f}s potential savings")
        count += 1

if count == 0:
    print("  No significant opportunities found! 🎉")
print("")

# Check if passed performance budget
if 'performance-budget' in audits:
    budget = audits['performance-budget']
    if budget['score'] == 1:
        print("✅ PASSED performance budget")
    else:
        print("❌ FAILED performance budget")
        print(f"   {budget['description']}")
    print("")

EOF

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📄 Reports saved:"
echo "  HTML: $REPORT_HTML"
echo "  JSON: $REPORT_JSON"
echo ""

# Open report if requested
if [ "$VIEW_REPORT" = "true" ]; then
    echo "🌐 Opening report in browser..."
    if command -v open &> /dev/null; then
        open "$REPORT_HTML"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$REPORT_HTML"
    else
        echo "⚠️  Could not open browser automatically."
        echo "   Please open: $REPORT_HTML"
    fi
fi

# Check if performance score meets threshold
PERF_SCORE=$(python3 -c "import json; data=json.load(open('$REPORT_JSON')); print(int(data['categories']['performance']['score'] * 100))")

echo "🎯 Performance Score: $PERF_SCORE/100"
echo ""

if [ "$PERF_SCORE" -ge 90 ]; then
    echo "🎉 EXCELLENT! Performance score is 90 or above!"
    exit 0
elif [ "$PERF_SCORE" -ge 50 ]; then
    echo "⚠️  WARNING: Performance score is below 90."
    echo "   Review the opportunities above for improvements."
    exit 0
else
    echo "❌ CRITICAL: Performance score is below 50!"
    echo "   Immediate action required to improve performance."
    exit 1
fi

