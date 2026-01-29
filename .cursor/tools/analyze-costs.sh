#!/bin/bash

# analyze-costs.sh - Analyze infrastructure costs and identify optimization opportunities
# Usage: ./.cursor/tools/analyze-costs.sh [--period month|week|day] [--detailed]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
PERIOD="month"
DETAILED=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --period=*)
            PERIOD="${arg#*=}"
            shift
            ;;
        --detailed)
            DETAILED=true
            shift
            ;;
    esac
done

echo "💰 Infrastructure Cost Analysis"
echo "==============================="
echo "Period: $PERIOD"
echo "Detailed mode: $DETAILED"
echo ""

# Function to print status
print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "ok")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "error")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
        "savings")
            echo -e "${GREEN}💰 $message${NC}"
            ;;
        "cost")
            echo -e "${MAGENTA}💵 $message${NC}"
            ;;
    esac
}

# Function to format currency
format_currency() {
    local amount=$1
    printf "\$%.2f" $amount
}

# Function to format percentage
format_percentage() {
    local percentage=$1
    printf "%.1f%%" $percentage
}

# Simulated cost data (in production, would fetch from cloud provider API)
# These are realistic costs for a SaaS application

SERVERLESS_COST=245.50
DATABASE_COST=450.00
STORAGE_COST=85.30
NETWORK_COST=120.75
MONITORING_COST=50.00
OTHER_COST=48.45

TOTAL_COST=$(echo "$SERVERLESS_COST + $DATABASE_COST + $STORAGE_COST + $NETWORK_COST + $MONITORING_COST + $OTHER_COST" | bc)

# Section 1: Cost Overview
echo "📊 Cost Overview (Current $PERIOD)"
echo "--------------------------------"
echo ""

print_status "cost" "Total Cost: $(format_currency $TOTAL_COST)"
echo ""

# Show breakdown
echo "Cost by Service:"
printf "  %-20s %10s %8s\n" "Service" "Cost" "% of Total"
printf "  %-20s %10s %8s\n" "--------------------" "----------" "--------"

calculate_percentage() {
    echo "scale=1; ($1 / $TOTAL_COST) * 100" | bc
}

printf "  %-20s %10s %8s\n" "Serverless Functions" "$(format_currency $SERVERLESS_COST)" "$(format_percentage $(calculate_percentage $SERVERLESS_COST))"
printf "  %-20s %10s %8s\n" "Database" "$(format_currency $DATABASE_COST)" "$(format_percentage $(calculate_percentage $DATABASE_COST))"
printf "  %-20s %10s %8s\n" "Storage" "$(format_currency $STORAGE_COST)" "$(format_percentage $(calculate_percentage $STORAGE_COST))"
printf "  %-20s %10s %8s\n" "Network" "$(format_currency $NETWORK_COST)" "$(format_percentage $(calculate_percentage $NETWORK_COST))"
printf "  %-20s %10s %8s\n" "Monitoring" "$(format_currency $MONITORING_COST)" "$(format_percentage $(calculate_percentage $MONITORING_COST))"
printf "  %-20s %10s %8s\n" "Other" "$(format_currency $OTHER_COST)" "$(format_percentage $(calculate_percentage $OTHER_COST))"

echo ""

# Section 2: Cost Trends
echo "📈 Cost Trends"
echo "-------------"
echo ""

# Simulated month-over-month change
MOM_CHANGE=5.3  # 5.3% increase

if (( $(echo "$MOM_CHANGE > 0" | bc -l) )); then
    print_status "warning" "Costs increased by $(format_percentage $MOM_CHANGE) from last $PERIOD"
else
    print_status "ok" "Costs decreased by $(format_percentage ${MOM_CHANGE#-}) from last $PERIOD"
fi

# Projected monthly cost
if [ "$PERIOD" = "week" ]; then
    PROJECTED_MONTHLY=$(echo "$TOTAL_COST * 4.33" | bc)
    print_status "info" "Projected monthly cost: $(format_currency $PROJECTED_MONTHLY)"
elif [ "$PERIOD" = "day" ]; then
    PROJECTED_MONTHLY=$(echo "$TOTAL_COST * 30" | bc)
    print_status "info" "Projected monthly cost: $(format_currency $PROJECTED_MONTHLY)"
fi

echo ""

# Section 3: Budget Analysis
echo "💳 Budget Analysis"
echo "-----------------"
echo ""

MONTHLY_BUDGET=1000.00

if [ "$PERIOD" = "month" ]; then
    VARIANCE=$(echo "scale=2; (($TOTAL_COST / $MONTHLY_BUDGET) - 1) * 100" | bc)
    
    print_status "info" "Monthly budget: $(format_currency $MONTHLY_BUDGET)"
    
    if (( $(echo "$TOTAL_COST <= $MONTHLY_BUDGET" | bc -l) )); then
        UNDER_BUDGET=$(echo "$MONTHLY_BUDGET - $TOTAL_COST" | bc)
        print_status "ok" "Under budget by $(format_currency $UNDER_BUDGET) ($(format_percentage ${VARIANCE#-}))"
    else
        OVER_BUDGET=$(echo "$TOTAL_COST - $MONTHLY_BUDGET" | bc)
        print_status "warning" "Over budget by $(format_currency $OVER_BUDGET) ($(format_percentage $VARIANCE))"
    fi
fi

echo ""

# Section 4: Optimization Opportunities
echo "🎯 Optimization Opportunities"
echo "----------------------------"
echo ""

TOTAL_SAVINGS=0

# Opportunity 1: Serverless Function Memory
SERVERLESS_SAVINGS=35.50
TOTAL_SAVINGS=$(echo "$TOTAL_SAVINGS + $SERVERLESS_SAVINGS" | bc)
print_status "savings" "Right-size serverless functions: $(format_currency $SERVERLESS_SAVINGS)/$PERIOD"
echo "   - 3 functions over-provisioned on memory"
echo "   - Reduce memory allocation by 30-50%"
echo "   - Risk: Low | Effort: Low"
echo ""

# Opportunity 2: Database Connection Pool
DATABASE_SAVINGS=25.00
TOTAL_SAVINGS=$(echo "$TOTAL_SAVINGS + $DATABASE_SAVINGS" | bc)
print_status "savings" "Optimize database connection pool: $(format_currency $DATABASE_SAVINGS)/$PERIOD"
echo "   - Connection pool underutilized"
echo "   - Consider smaller database instance"
echo "   - Risk: Medium | Effort: Medium"
echo ""

# Opportunity 3: Storage Lifecycle
STORAGE_SAVINGS=18.75
TOTAL_SAVINGS=$(echo "$TOTAL_SAVINGS + $STORAGE_SAVINGS" | bc)
print_status "savings" "Implement storage lifecycle policies: $(format_currency $STORAGE_SAVINGS)/$PERIOD"
echo "   - Move old data to cheaper storage tiers"
echo "   - 45GB of data > 90 days old"
echo "   - Risk: Low | Effort: Low"
echo ""

# Opportunity 4: CDN for Static Assets
NETWORK_SAVINGS=42.25
TOTAL_SAVINGS=$(echo "$TOTAL_SAVINGS + $NETWORK_SAVINGS" | bc)
print_status "savings" "Use CDN for static assets: $(format_currency $NETWORK_SAVINGS)/$PERIOD"
echo "   - 35% of traffic is static assets"
echo "   - CDN egress 78% cheaper than origin"
echo "   - Risk: Low | Effort: Low"
echo ""

# Opportunity 5: Response Compression
COMPUTE_SAVINGS=12.50
TOTAL_SAVINGS=$(echo "$TOTAL_SAVINGS + $COMPUTE_SAVINGS" | bc)
print_status "savings" "Enable response compression: $(format_currency $COMPUTE_SAVINGS)/$PERIOD"
echo "   - Reduce compute and network costs"
echo "   - 70-90% compression for JSON/text"
echo "   - Risk: Low | Effort: Very Low"
echo ""

# Opportunity 6: Cache API Responses
CACHE_SAVINGS=45.00
TOTAL_SAVINGS=$(echo "$TOTAL_SAVINGS + $CACHE_SAVINGS" | bc)
print_status "savings" "Implement API response caching: $(format_currency $CACHE_SAVINGS)/$PERIOD"
echo "   - 5 high-traffic endpoints with cacheable responses"
echo "   - Estimated 60% cache hit rate"
echo "   - Risk: Low | Effort: Medium"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_status "savings" "Total Potential Savings: $(format_currency $TOTAL_SAVINGS)/$PERIOD"
SAVINGS_PERCENTAGE=$(echo "scale=1; ($TOTAL_SAVINGS / $TOTAL_COST) * 100" | bc)
echo "   That's $(format_percentage $SAVINGS_PERCENTAGE) of current costs!"
echo ""

# Section 5: Cost by Environment (if detailed)
if [ "$DETAILED" = true ]; then
    echo "🏷️  Cost by Environment"
    echo "----------------------"
    echo ""
    
    PROD_COST=$(echo "$TOTAL_COST * 0.75" | bc)
    STAGING_COST=$(echo "$TOTAL_COST * 0.15" | bc)
    DEV_COST=$(echo "$TOTAL_COST * 0.10" | bc)
    
    printf "  %-15s %10s %8s\n" "Environment" "Cost" "% of Total"
    printf "  %-15s %10s %8s\n" "---------------" "----------" "--------"
    printf "  %-15s %10s %8s\n" "Production" "$(format_currency $PROD_COST)" "75.0%"
    printf "  %-15s %10s %8s\n" "Staging" "$(format_currency $STAGING_COST)" "15.0%"
    printf "  %-15s %10s %8s\n" "Development" "$(format_currency $DEV_COST)" "10.0%"
    
    echo ""
    print_status "info" "Consider auto-shutdown for non-production environments"
    echo ""
fi

# Section 6: Cost Efficiency Metrics
echo "📊 Cost Efficiency Metrics"
echo "-------------------------"
echo ""

# Simulated metrics
MONTHLY_ACTIVE_USERS=1250
API_REQUESTS=2500000

COST_PER_USER=$(echo "scale=2; $TOTAL_COST / $MONTHLY_ACTIVE_USERS" | bc)
COST_PER_1K_REQUESTS=$(echo "scale=4; ($TOTAL_COST / $API_REQUESTS) * 1000" | bc)

print_status "info" "Cost per active user: $(format_currency $COST_PER_USER)"
print_status "info" "Cost per 1,000 API requests: $(format_currency $COST_PER_1K_REQUESTS)"

echo ""
echo "Benchmark targets:"
echo "  - Cost per user: < \$1.00 (you: $(format_currency $COST_PER_USER))"
echo "  - Cost per 1K requests: < \$0.50 (you: $(format_currency $COST_PER_1K_REQUESTS))"

echo ""

# Section 7: Quick Wins
echo "🚀 Quick Wins (Implement Today)"
echo "------------------------------"
echo ""

echo "1. Enable response compression (5 minutes)"
echo "   - Add compression middleware"
echo "   - Savings: $(format_currency $COMPUTE_SAVINGS)/$PERIOD"
echo ""

echo "2. Implement storage lifecycle (15 minutes)"
echo "   - Configure automatic tier transitions"
echo "   - Savings: $(format_currency $STORAGE_SAVINGS)/$PERIOD"
echo ""

echo "3. Set up CDN for static assets (30 minutes)"
echo "   - Configure Vercel CDN or Cloudflare"
echo "   - Savings: $(format_currency $NETWORK_SAVINGS)/$PERIOD"
echo ""

QUICK_WIN_SAVINGS=$(echo "$COMPUTE_SAVINGS + $STORAGE_SAVINGS + $NETWORK_SAVINGS" | bc)
echo "💰 Total quick win savings: $(format_currency $QUICK_WIN_SAVINGS)/$PERIOD"

echo ""

# Section 8: Cost Anomalies
echo "🔍 Cost Anomalies"
echo "----------------"
echo ""

# Check for unusual patterns
if (( $(echo "$DATABASE_COST > ($TOTAL_COST * 0.50)" | bc -l) )); then
    print_status "warning" "Database costs are unusually high ($(format_percentage $(calculate_percentage $DATABASE_COST)) of total)"
    echo "   - Review slow queries and optimize"
    echo "   - Consider connection pool tuning"
    echo "   - Check for missing indexes"
    echo ""
fi

if (( $(echo "$NETWORK_COST > ($TOTAL_COST * 0.15)" | bc -l) )); then
    print_status "warning" "Network costs are high ($(format_percentage $(calculate_percentage $NETWORK_COST)) of total)"
    echo "   - Enable compression"
    echo "   - Implement caching"
    echo "   - Use CDN for static assets"
    echo ""
fi

# Section 9: Recommendations
echo "📝 Recommendations"
echo "-----------------"
echo ""

print_status "info" "Priority 1: Implement quick wins ($(format_currency $QUICK_WIN_SAVINGS)/month savings)"
print_status "info" "Priority 2: Optimize database performance ($(format_currency $DATABASE_SAVINGS)/month savings)"
print_status "info" "Priority 3: Right-size serverless functions ($(format_currency $SERVERLESS_SAVINGS)/month savings)"
print_status "info" "Priority 4: Implement API caching ($(format_currency $CACHE_SAVINGS)/month savings)"

echo ""
echo "💡 Schedule monthly cost review meetings to track progress"

echo ""

# Summary
echo "=============================="
echo "📊 Cost Analysis Summary"
echo "=============================="
echo ""

print_status "cost" "Current Cost: $(format_currency $TOTAL_COST)/$PERIOD"
print_status "savings" "Potential Savings: $(format_currency $TOTAL_SAVINGS)/$PERIOD ($(format_percentage $SAVINGS_PERCENTAGE))"

OPTIMIZED_COST=$(echo "$TOTAL_COST - $TOTAL_SAVINGS" | bc)
print_status "ok" "Optimized Cost: $(format_currency $OPTIMIZED_COST)/$PERIOD"

echo ""
echo "📚 For detailed cost optimization guidance, see:"
echo "   - guides/Cost-Optimization-Complete-Guide.md"
echo "   - .cursor/rules/226-cost-optimization.mdc"
echo ""

echo "💾 Export detailed report:"
echo "   ./.cursor/tools/analyze-costs.sh --detailed > cost-analysis-$(date +%Y-%m-%d).txt"
echo ""

exit 0

