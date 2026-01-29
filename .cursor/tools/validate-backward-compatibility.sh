#!/bin/bash

# Backward Compatibility Validation for v0.3.2 → v0.4.0
# Purpose: Test that v0.4.0 maintains compatibility with v0.3.2
# Usage: ./.cursor/tools/validate-backward-compatibility.sh [base-url]
# Related: docs/SPEC-v0.4.0-06-Migration-Strategy.md

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="${1:-http://localhost:3000}"

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Functions
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_section() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

test_pass() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e "  ${GREEN}✓${NC} $1"
}

test_fail() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo -e "  ${RED}✗${NC} $1"
}

print_summary() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  BACKWARD COMPATIBILITY SUMMARY${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "  Total Tests:     $TOTAL_TESTS"
    echo -e "  ${GREEN}Passed:          $PASSED_TESTS${NC}"
    if [ $FAILED_TESTS -gt 0 ]; then
        echo -e "  ${RED}Failed:          $FAILED_TESTS${NC}"
    fi
    echo ""
}

# Helper: Test HTTP status and optional redirect
test_url() {
    local URL=$1
    local EXPECTED_STATUS=$2
    local EXPECTED_LOCATION=$3
    local DESCRIPTION=$4
    
    # Get headers
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}|%{redirect_url}" "$URL" || echo "000|")
    HTTP_CODE=$(echo "$RESPONSE" | cut -d'|' -f1)
    REDIRECT_URL=$(echo "$RESPONSE" | cut -d'|' -f2)
    
    # Check status code
    if [ "$HTTP_CODE" = "$EXPECTED_STATUS" ]; then
        # If expecting redirect, check redirect URL
        if [ -n "$EXPECTED_LOCATION" ]; then
            if echo "$REDIRECT_URL" | grep -q "$EXPECTED_LOCATION"; then
                test_pass "$DESCRIPTION (HTTP $HTTP_CODE → $EXPECTED_LOCATION)"
            else
                test_fail "$DESCRIPTION - Wrong redirect"
                echo "      Expected: $EXPECTED_LOCATION"
                echo "      Got: $REDIRECT_URL"
            fi
        else
            test_pass "$DESCRIPTION (HTTP $HTTP_CODE)"
        fi
    else
        test_fail "$DESCRIPTION"
        echo "      Expected HTTP $EXPECTED_STATUS, got $HTTP_CODE"
    fi
}

# Start
print_header "🔄 BACKWARD COMPATIBILITY VALIDATION"
echo "Testing v0.4.0 compatibility with v0.3.2"
echo "Base URL: $BASE_URL"
echo ""

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. URL REDIRECTS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "1. Old URL → New URL Redirects"

# Test old home page redirects to dashboard
test_url "$BASE_URL/" "307" "/dashboard" "Old home page → /dashboard"

# Test old auth URLs redirect
test_url "$BASE_URL/auth/signin" "307" "/login" "/auth/signin → /login"

# Test old health check URLs redirect
test_url "$BASE_URL/health-check/test" "307" "/test" "/health-check/test → /test"
test_url "$BASE_URL/health-check/settings" "307" "/settings" "/health-check/settings → /settings"

# Test old health checks URLs redirect
test_url "$BASE_URL/health-checks/history" "307" "/history" "/health-checks/history → /history"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. API ENDPOINTS PRESERVED
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "2. v0.3.2 API Endpoints Still Work"

# Health check endpoint
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/health" || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    test_pass "GET /api/health (HTTP $HTTP_CODE)"
else
    test_fail "GET /api/health (HTTP $HTTP_CODE)"
fi

# Assessments questions endpoint
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/assessments/questions" || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ]; then
    test_pass "GET /api/assessments/questions (HTTP $HTTP_CODE)"
else
    test_fail "GET /api/assessments/questions (HTTP $HTTP_CODE)"
fi

# Health check frameworks endpoint
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/health-check/frameworks" || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    test_pass "GET /api/health-check/frameworks (HTTP $HTTP_CODE)"
else
    test_fail "GET /api/health-check/frameworks (HTTP $HTTP_CODE)"
fi

# Auth session endpoint
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/auth/session" || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ]; then
    test_pass "GET /api/auth/session (HTTP $HTTP_CODE)"
else
    test_fail "GET /api/auth/session (HTTP $HTTP_CODE)"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. AUTHENTICATION FLOW
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "3. Authentication Flow Compatibility"

# Login page accessible
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/login" || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    test_pass "Login page accessible (HTTP $HTTP_CODE)"
else
    test_fail "Login page accessible (HTTP $HTTP_CODE)"
fi

# Signup redirect works (if /signup → /login)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/signup" || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "307" ]; then
    test_pass "Signup page accessible (HTTP $HTTP_CODE)"
else
    test_fail "Signup page accessible (HTTP $HTTP_CODE)"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. STATIC ASSETS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "4. Static Assets Available"

# Favicon
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/favicon.ico" || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    test_pass "Favicon accessible (HTTP $HTTP_CODE)"
else
    test_fail "Favicon accessible (HTTP $HTTP_CODE)"
fi

# Next.js static files
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/_next/static/" || echo "000")
if [ "$HTTP_CODE" != "404" ]; then
    test_pass "Next.js static files accessible (HTTP $HTTP_CODE)"
else
    test_fail "Next.js static files accessible (HTTP $HTTP_CODE)"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5. DATABASE SCHEMA COMPATIBILITY
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "5. Database Schema Unchanged"

# Check if schema.prisma exists
if [ -f "prisma/schema.prisma" ]; then
    test_pass "Prisma schema file exists"
    
    # Check for new migrations (should be none for v0.4.0)
    if [ -d "prisma/migrations" ]; then
        NEW_MIGRATIONS=$(find prisma/migrations -type d -name "2024*" -o -name "2025*" | wc -l)
        if [ "$NEW_MIGRATIONS" -eq 0 ]; then
            test_pass "No new database migrations (schema unchanged)"
        else
            test_fail "New migrations detected - schema changed!"
            echo "      v0.4.0 should NOT change database schema"
        fi
    fi
else
    test_fail "Prisma schema file not found"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 6. TEST SUITE STILL PASSES
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "6. Existing Tests Still Pass"

# Project structure is now flat - no need to cd into app/

if command -v npm &> /dev/null && [ -f "package.json" ]; then
    echo "  Running test suite..."
    TEST_OUTPUT=$(npm test -- --passWithNoTests 2>&1 || true)
    
    if echo "$TEST_OUTPUT" | grep -q "Tests:.*passed"; then
        PASSED_COUNT=$(echo "$TEST_OUTPUT" | grep -oP '\d+(?= passed)' | head -1)
        TOTAL_COUNT=$(echo "$TEST_OUTPUT" | grep -oP '\d+ total' | grep -oP '\d+' | head -1)
        
        if [ "$PASSED_COUNT" = "$TOTAL_COUNT" ]; then
            test_pass "All tests passing ($PASSED_COUNT/$TOTAL_COUNT)"
        elif [ "$PASSED_COUNT" -ge 390 ]; then
            test_fail "Some tests failing ($PASSED_COUNT/$TOTAL_COUNT)"
            echo "      Expected: All tests should still pass in v0.4.0"
        else
            test_fail "Many tests failing ($PASSED_COUNT/$TOTAL_COUNT)"
            echo "      v0.4.0 broke backward compatibility!"
        fi
    else
        test_fail "Could not run tests"
    fi
else
    test_fail "npm or package.json not found"
fi

cd - > /dev/null 2>&1 || true

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SUMMARY & RECOMMENDATION
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_summary

# Determine compatibility
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ BACKWARD COMPATIBLE${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "v0.4.0 is fully backward compatible with v0.3.2!\n"
    echo -e "  ✓ All old URLs redirect correctly"
    echo -e "  ✓ All API endpoints preserved"
    echo -e "  ✓ Authentication flow intact"
    echo -e "  ✓ Database schema unchanged"
    echo -e "  ✓ All tests passing"
    echo ""
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ❌ COMPATIBILITY ISSUES DETECTED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "Fix compatibility issues before deploying:\n"
    echo -e "  1. Review failed tests above"
    echo -e "  2. Fix each compatibility issue"
    echo -e "  3. Re-run validation"
    echo ""
    exit 1
fi
