#!/bin/bash

# Post-Deployment Validation Script
# Purpose: Validate production deployment health and stability
# Usage: ./.cursor/tools/validate-deployment.sh [deployment-url]
# Related Rules: @203-production-deployment-safety.mdc, @221-application-monitoring.mdc

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEPLOYMENT_URL="${1:-https://yourdomain.com}"
MONITORING_DURATION=300  # 5 minutes default
CHECK_INTERVAL=30        # 30 seconds between checks

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Functions
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_section() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

check_pass() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo -e "  ${GREEN}✓${NC} $1"
}

check_fail() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    echo -e "  ${RED}✗${NC} $1"
}

check_warning() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_summary() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  DEPLOYMENT VALIDATION SUMMARY${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "  Total Checks:    $TOTAL_CHECKS"
    echo -e "  ${GREEN}Passed:          $PASSED_CHECKS${NC}"
    if [ $WARNING_CHECKS -gt 0 ]; then
        echo -e "  ${YELLOW}Warnings:        $WARNING_CHECKS${NC}"
    fi
    if [ $FAILED_CHECKS -gt 0 ]; then
        echo -e "  ${RED}Failed:          $FAILED_CHECKS${NC}"
    fi
    echo ""
}

# Start
print_header "🔍 POST-DEPLOYMENT VALIDATION"
echo "Validating deployment: $DEPLOYMENT_URL"
echo "Related Rules: @203-production-deployment-safety.mdc"
echo ""

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 1: IMMEDIATE CHECKS (0-5 minutes)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "PHASE 1: Immediate Checks (0-5 min) - CRITICAL"

# 1. Site Availability
echo -e "\n${BLUE}1. Site Availability${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$DEPLOYMENT_URL" || echo "000")
RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" "$DEPLOYMENT_URL" || echo "999")

if [ "$HTTP_CODE" = "200" ]; then
    check_pass "Site is accessible (HTTP $HTTP_CODE)"
elif [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    check_warning "Site returns redirect (HTTP $HTTP_CODE)"
else
    check_fail "Site is not accessible (HTTP $HTTP_CODE)"
    echo -e "    ${RED}🚨 CRITICAL: Consider immediate rollback!${NC}"
    echo "    Run: vercel rollback"
fi

# Check response time
if (( $(echo "$RESPONSE_TIME < 2.0" | bc -l) )); then
    check_pass "Response time acceptable (${RESPONSE_TIME}s)"
elif (( $(echo "$RESPONSE_TIME < 5.0" | bc -l) )); then
    check_warning "Response time slow (${RESPONSE_TIME}s)"
else
    check_fail "Response time too slow (${RESPONSE_TIME}s)"
    echo -e "    ${RED}🚨 Performance issue detected${NC}"
fi

# 2. HTTPS & Security Headers
echo -e "\n${BLUE}2. HTTPS & Security Headers${NC}"

# Test HTTPS
if curl -s -I "$DEPLOYMENT_URL" | grep -q "strict-transport-security"; then
    check_pass "HTTPS enforced (HSTS header present)"
else
    check_warning "HSTS header not found"
fi

# Check security headers
HEADERS=$(curl -s -I "$DEPLOYMENT_URL")

if echo "$HEADERS" | grep -q "x-content-type-options"; then
    check_pass "X-Content-Type-Options header present"
else
    check_warning "X-Content-Type-Options header missing"
fi

if echo "$HEADERS" | grep -q "x-frame-options"; then
    check_pass "X-Frame-Options header present"
else
    check_warning "X-Frame-Options header missing"
fi

# 3. Critical API Endpoints
echo -e "\n${BLUE}3. Critical API Endpoints${NC}"

# Health check endpoint
HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$DEPLOYMENT_URL/api/health" || echo "000")
if [ "$HEALTH_CODE" = "200" ]; then
    check_pass "Health check endpoint responding (HTTP $HEALTH_CODE)"
else
    check_fail "Health check endpoint failed (HTTP $HEALTH_CODE)"
    echo -e "    ${RED}🚨 API health check failed${NC}"
fi

# Auth session endpoint
AUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$DEPLOYMENT_URL/api/auth/session" || echo "000")
if [ "$AUTH_CODE" = "200" ] || [ "$AUTH_CODE" = "401" ]; then
    check_pass "Auth endpoint responding (HTTP $AUTH_CODE)"
else
    check_fail "Auth endpoint failed (HTTP $AUTH_CODE)"
    echo -e "    ${RED}🚨 CRITICAL: Authentication may be broken!${NC}"
    echo "    Consider immediate rollback"
fi

# 4. Database Connectivity
echo -e "\n${BLUE}4. Database Connectivity${NC}"

# Try to access a database-dependent endpoint
# This assumes you have a simple endpoint that tests DB connectivity
DB_TEST_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$DEPLOYMENT_URL/api/health" || echo "000")
if [ "$DB_TEST_CODE" = "200" ]; then
    check_pass "Database connectivity verified"
else
    check_warning "Database connectivity unclear"
    echo "    Manually verify database operations"
fi

# 5. Environment Configuration
echo -e "\n${BLUE}5. Environment Configuration${NC}"

# Check if debug endpoint exists (should be internal only!)
ENV_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$DEPLOYMENT_URL/api/debug/env-check" || echo "000")
if [ "$ENV_CODE" = "401" ] || [ "$ENV_CODE" = "403" ]; then
    check_pass "Debug endpoint properly secured"
elif [ "$ENV_CODE" = "404" ]; then
    check_pass "Debug endpoint not in production (good)"
elif [ "$ENV_CODE" = "200" ]; then
    check_warning "Debug endpoint accessible (verify it's internal only)"
    echo "    Ensure this endpoint is properly secured"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 2: FUNCTIONAL TESTS (5-15 minutes)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "PHASE 2: Functional Tests (5-15 min)"

echo -e "\n${BLUE}6. Critical User Flows${NC}"
echo "  Manual testing required:"
echo "    [ ] Login flow"
echo "    [ ] Logout flow"
echo "    [ ] Core CRUD operations"
echo "    [ ] Payment processing (if applicable)"
echo "    [ ] AI generation (if applicable)"
echo ""
echo "  Open browser and test: $DEPLOYMENT_URL"
check_warning "Manual testing required for complete validation"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 3: MONITORING SETUP
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "PHASE 3: Monitoring & Alerting"

echo -e "\n${BLUE}7. Monitoring Dashboards${NC}"
echo "  Open these dashboards for monitoring:"
echo "    • Vercel Dashboard: https://vercel.com/dashboard"
echo "    • Vercel Analytics: https://vercel.com/analytics"
echo "    • Vercel Logs: https://vercel.com/logs"
if command -v vercel &> /dev/null; then
    echo ""
    echo "  Or use CLI:"
    echo "    vercel logs --follow"
fi
check_warning "Monitor dashboards actively for 30+ minutes"

echo -e "\n${BLUE}8. Error Monitoring${NC}"
echo "  Watch for:"
echo "    • Error rate < 1% (rollback if > 5%)"
echo "    • Response time < 2s (rollback if > 5s)"
echo "    • Memory usage stable (not climbing)"
echo "    • Database query performance"
check_warning "Active monitoring required"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 4: CONTINUOUS MONITORING
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "PHASE 4: Continuous Monitoring (30+ min)"

echo -e "\n${BLUE}9. Extended Monitoring${NC}"
echo "  Monitor these metrics over the next 30-60 minutes:"
echo ""
echo "  📊 Performance Metrics:"
echo "    • Avg response time trending"
echo "    • 95th percentile response time"
echo "    • Memory usage trends"
echo "    • CPU usage trends"
echo ""
echo "  ❌ Error Metrics:"
echo "    • Error rate by endpoint"
echo "    • Error types and patterns"
echo "    • Failed database queries"
echo "    • Failed API calls"
echo ""
echo "  👥 User Metrics:"
echo "    • Active user sessions"
echo "    • User flow completion rates"
echo "    • Feature usage patterns"
check_warning "Monitor for 30+ minutes minimum"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ROLLBACK DECISION TREE
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "Rollback Decision Tree"

echo -e "\n${RED}🚨 IMMEDIATE ROLLBACK TRIGGERS:${NC}"
echo "  • Site returns 5xx errors"
echo "  • Authentication completely broken"
echo "  • Database connection failures"
echo "  • Error rate > 10% in first 5 minutes"
echo ""
echo -e "${YELLOW}⚠️  CONSIDER ROLLBACK TRIGGERS (5-30 min):${NC}"
echo "  • Error rate > 5%"
echo "  • Response time > 5s average"
echo "  • Memory leak detected"
echo "  • Critical user flows broken"
echo ""
echo -e "${GREEN}✅ DEPLOYMENT STABLE INDICATORS:${NC}"
echo "  • Error rate < 1%"
echo "  • Response time < 2s"
echo "  • All critical flows working"
echo "  • No new error patterns"
echo ""
echo -e "Rollback command (if needed):"
echo -e "  ${BLUE}vercel rollback [previous-deployment-url]${NC}"
echo ""

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SUMMARY
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_summary

# Final decision
if [ $FAILED_CHECKS -gt 0 ]; then
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  🚨 CRITICAL ISSUES DETECTED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "${RED}RECOMMENDATION: Consider immediate rollback!${NC}\n"
    echo -e "Rollback command:"
    echo -e "  ${BLUE}vercel rollback${NC}\n"
    echo -e "See: @202-rollback-procedures.mdc\n"
    exit 1
elif [ $WARNING_CHECKS -gt 0 ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  ⚠️  DEPLOYMENT NEEDS MONITORING${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "${YELLOW}Warnings detected. Monitor closely for next 30+ minutes.${NC}\n"
    echo -e "Next steps:"
    echo -e "  1. Complete manual testing of critical flows"
    echo -e "  2. Monitor error rates and response times"
    echo -e "  3. Watch for unusual patterns in logs"
    echo -e "  4. Be ready to rollback if issues arise\n"
    echo -e "Monitoring commands:"
    echo -e "  ${BLUE}vercel logs --follow${NC}"
    echo -e "  ${BLUE}vercel logs --since 30m${NC}\n"
    exit 0
else
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ DEPLOYMENT VALIDATED${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "${GREEN}Initial checks passed! Continue monitoring.${NC}\n"
    echo -e "Next steps:"
    echo -e "  1. Complete manual testing (login, core flows)"
    echo -e "  2. Monitor for 30+ minutes"
    echo -e "  3. Watch error rates and response times"
    echo -e "  4. Document any issues or lessons learned\n"
    echo -e "Monitoring commands:"
    echo -e "  ${BLUE}vercel logs --follow${NC}"
    echo -e "  ${BLUE}vercel logs --since 30m${NC}\n"
    echo -e "Related:"
    echo -e "  • @221-application-monitoring.mdc - Application monitoring"
    echo -e "  • @222-metrics-alerting.mdc - Metrics and alerting"
    echo -e "  • guides/Incident-Response-Complete-Guide.md\n"
    exit 0
fi

