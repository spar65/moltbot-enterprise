#!/bin/bash
#
# Rate Limiting Implementation Tester
#
# Tests rate limiting implementation with actual HTTP requests.
# Based on: .cursor/rules/355-rate-limiting-implementation.mdc
#
# Usage:
#   ./.cursor/tools/test-rate-limits.sh <base-url> [--api-key <key>]
#
# Examples:
#   ./.cursor/tools/test-rate-limits.sh http://localhost:3000
#   ./.cursor/tools/test-rate-limits.sh https://api.example.com --api-key hck_test_123
#
# Exit codes:
#   0 - All tests passed
#   1 - Tests failed or rate limiting not working correctly
#

set -euo pipefail

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Configuration
BASE_URL=""
API_KEY=""
RATE_LIMIT_ENDPOINT="/api/health-check/test"
STATUS_ENDPOINT="/api/health-check/status"

# Parse arguments
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <base-url> [--api-key <key>]"
  echo ""
  echo "Examples:"
  echo "  $0 http://localhost:3000"
  echo "  $0 https://api.example.com --api-key hck_test_123"
  exit 1
fi

BASE_URL="$1"
shift

while [[ $# -gt 0 ]]; do
  case $1 in
    --api-key)
      API_KEY="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Helper functions
print_section() {
  echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}$1${NC}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

test_pass() {
  echo -e "  ${GREEN}✓${NC} $1"
  ((PASSED_TESTS++))
  ((TOTAL_TESTS++))
}

test_fail() {
  echo -e "  ${RED}✗${NC} $1"
  if [[ -n "${2:-}" ]]; then
    echo -e "    ${RED}→${NC} $2"
  fi
  ((FAILED_TESTS++))
  ((TOTAL_TESTS++))
}

# Make HTTP request
make_request() {
  local endpoint="$1"
  local method="${2:-GET}"
  local body="${3:-}"
  
  local headers=("-H" "Content-Type: application/json")
  
  if [[ -n "$API_KEY" ]]; then
    headers+=("-H" "Authorization: Bearer $API_KEY")
  fi
  
  if [[ -n "$body" ]]; then
    curl -s -w "\n%{http_code}" -X "$method" "${headers[@]}" -d "$body" "${BASE_URL}${endpoint}"
  else
    curl -s -w "\n%{http_code}" -X "$method" "${headers[@]}" "${BASE_URL}${endpoint}"
  fi
}

# Extract HTTP status code from response
get_status_code() {
  echo "$1" | tail -n 1
}

# Extract response body
get_body() {
  echo "$1" | sed '$d'
}

# Extract header value
get_header() {
  local endpoint="$1"
  local header_name="$2"
  local method="${3:-GET}"
  
  local headers=()
  if [[ -n "$API_KEY" ]]; then
    headers+=("-H" "Authorization: Bearer $API_KEY")
  fi
  
  curl -s -I -X "$method" "${headers[@]}" "${BASE_URL}${endpoint}" | grep -i "^${header_name}:" | cut -d' ' -f2- | tr -d '\r'
}

echo -e "${BOLD}${BLUE}Rate Limiting Implementation Tester${NC}"
echo -e "Testing: ${BOLD}${BASE_URL}${NC}\n"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. Basic Connectivity
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "1. Basic Connectivity"

response=$(make_request "/api/health" "GET" 2>&1 || echo "FAILED")
status=$(get_status_code "$response")

if [[ "$status" == "200" ]]; then
  test_pass "Server is reachable and responding"
else
  test_fail "Server not reachable" "Status: $status"
  echo -e "\n${RED}Cannot proceed with tests - server not accessible${NC}\n"
  exit 1
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. Rate Limit Headers
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "2. Rate Limit Headers"

limit_header=$(get_header "$RATE_LIMIT_ENDPOINT" "X-RateLimit-Limit" "POST")
remaining_header=$(get_header "$RATE_LIMIT_ENDPOINT" "X-RateLimit-Remaining" "POST")
reset_header=$(get_header "$RATE_LIMIT_ENDPOINT" "X-RateLimit-Reset" "POST")

if [[ -n "$limit_header" ]]; then
  test_pass "X-RateLimit-Limit header present (value: $limit_header)"
else
  test_fail "X-RateLimit-Limit header missing" \
    "Add header: X-RateLimit-Limit with max requests per window"
fi

if [[ -n "$remaining_header" ]]; then
  test_pass "X-RateLimit-Remaining header present (value: $remaining_header)"
else
  test_fail "X-RateLimit-Remaining header missing" \
    "Add header: X-RateLimit-Remaining with requests left"
fi

if [[ -n "$reset_header" ]]; then
  test_pass "X-RateLimit-Reset header present (value: $reset_header)"
else
  test_fail "X-RateLimit-Reset header missing" \
    "Add header: X-RateLimit-Reset with timestamp when limit resets"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. Rate Limiting Behavior
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "3. Rate Limiting Behavior"

# If we have a limit, test exceeding it
if [[ -n "$limit_header" && "$limit_header" =~ ^[0-9]+$ ]]; then
  echo "  Testing rate limit enforcement (limit: $limit_header requests)..."
  
  # Make requests up to the limit
  success_count=0
  for i in $(seq 1 "$limit_header"); do
    response=$(make_request "$RATE_LIMIT_ENDPOINT" "POST" '{"test": true}' 2>&1 || echo "FAILED")
    status=$(get_status_code "$response")
    
    if [[ "$status" == "200" || "$status" == "201" ]]; then
      ((success_count++))
    fi
  done
  
  if [[ $success_count -eq $limit_header ]]; then
    test_pass "Allowed $limit_header requests (up to limit)"
  else
    test_fail "Expected $limit_header successful requests, got $success_count"
  fi
  
  # Try one more request (should be rate limited)
  response=$(make_request "$RATE_LIMIT_ENDPOINT" "POST" '{"test": true}' 2>&1 || echo "FAILED")
  status=$(get_status_code "$response")
  
  if [[ "$status" == "429" ]]; then
    test_pass "Returns 429 Too Many Requests when limit exceeded"
    
    # Check for Retry-After header
    retry_after=$(get_header "$RATE_LIMIT_ENDPOINT" "Retry-After" "POST")
    if [[ -n "$retry_after" ]]; then
      test_pass "Includes Retry-After header (value: $retry_after)"
    else
      test_fail "Missing Retry-After header" \
        "Add Retry-After header to tell clients when to retry"
    fi
  else
    test_fail "Did not return 429 when limit exceeded" \
      "Status: $status (expected: 429)"
  fi
else
  echo "  ${YELLOW}⚠️${NC}  Skipping rate limit enforcement test (no limit header)"
  ((TOTAL_TESTS++))
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. Error Response Format
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "4. Error Response Format"

if [[ -n "$limit_header" && "$limit_header" =~ ^[0-9]+$ ]]; then
  # Trigger rate limit
  for i in $(seq 1 "$((limit_header + 1))"); do
    response=$(make_request "$RATE_LIMIT_ENDPOINT" "POST" '{"test": true}' 2>&1 || echo "FAILED")
  done
  
  # Check error response
  response=$(make_request "$RATE_LIMIT_ENDPOINT" "POST" '{"test": true}' 2>&1 || echo "FAILED")
  status=$(get_status_code "$response")
  body=$(get_body "$response")
  
  if [[ "$status" == "429" ]]; then
    if echo "$body" | grep -q "error"; then
      test_pass "Error response includes 'error' field"
    else
      test_fail "Error response missing 'error' field" \
        "Include { error: 'Rate limit exceeded' } in 429 response"
    fi
    
    if echo "$body" | grep -q "rate.*limit\|Rate.*limit"; then
      test_pass "Error message mentions rate limiting"
    else
      test_fail "Error message doesn't mention rate limiting" \
        "Make error message clear: 'Rate limit exceeded'"
    fi
  else
    echo "  ${YELLOW}⚠️${NC}  Skipping error format test (could not trigger rate limit)"
    ((TOTAL_TESTS += 2))
  fi
else
  echo "  ${YELLOW}⚠️${NC}  Skipping error format test (no rate limit)"
  ((TOTAL_TESTS += 2))
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5. Per-Organization Isolation
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "5. Per-Organization Isolation"

# This test requires two different API keys
if [[ -n "$API_KEY" ]]; then
  echo "  ${YELLOW}⚠️${NC}  Per-organization isolation test requires manual verification"
  echo "    Use two different API keys from different organizations to verify"
  echo "    that rate limits are isolated per organization"
  ((TOTAL_TESTS++))
else
  echo "  ${YELLOW}⚠️${NC}  Skipping per-org test (no API key provided)"
  ((TOTAL_TESTS++))
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 6. Sliding Window Behavior
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "6. Sliding Window Algorithm"

echo "  ${BLUE}ℹ${NC}  Testing sliding window (this may take a minute)..."

if [[ -n "$limit_header" && "$limit_header" =~ ^[0-9]+$ ]]; then
  # Make requests to fill the window
  for i in $(seq 1 "$limit_header"); do
    make_request "$RATE_LIMIT_ENDPOINT" "POST" '{"test": true}' >/dev/null 2>&1 || true
  done
  
  # Should be rate limited now
  response=$(make_request "$RATE_LIMIT_ENDPOINT" "POST" '{"test": true}' 2>&1 || echo "FAILED")
  status_before=$(get_status_code "$response")
  
  if [[ "$status_before" == "429" ]]; then
    test_pass "Rate limit enforced when window is full"
    
    # Wait for a small amount of time (sliding window should allow new requests)
    echo "    Waiting 10 seconds for window to slide..."
    sleep 10
    
    # Try again - with sliding window, oldest requests should have aged out
    response=$(make_request "$RATE_LIMIT_ENDPOINT" "POST" '{"test": true}' 2>&1 || echo "FAILED")
    status_after=$(get_status_code "$response")
    
    if [[ "$status_after" != "429" ]]; then
      test_pass "Sliding window allows new requests after time passes"
    else
      test_fail "Window doesn't slide (may be fixed window)" \
        "Implement sliding window: count requests in last N minutes"
    fi
  else
    echo "  ${YELLOW}⚠️${NC}  Could not trigger rate limit to test sliding window"
    ((TOTAL_TESTS += 2))
  fi
else
  echo "  ${YELLOW}⚠️${NC}  Skipping sliding window test (no rate limit)"
  ((TOTAL_TESTS += 2))
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Summary
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Summary${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\nTotal Tests:     ${BOLD}$TOTAL_TESTS${NC}"
echo -e "Passed:          ${GREEN}✓ $PASSED_TESTS${NC}"
echo -e "Failed:          ${RED}✗ $FAILED_TESTS${NC}"

# Calculate pass rate
if [[ $TOTAL_TESTS -gt 0 ]]; then
  PASS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
else
  PASS_RATE=0
fi

echo ""
if [[ $FAILED_TESTS -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}🎉 Excellent! Rate limiting is working correctly!${NC}"
  echo -e "${GREEN}All tests passed ($PASS_RATE%).${NC}"
  EXIT_CODE=0
else
  echo -e "${YELLOW}${BOLD}⚠️  Some tests failed ($PASS_RATE% passed)${NC}"
  echo -e "${YELLOW}Review failed tests and fix issues.${NC}"
  EXIT_CODE=1
fi

echo ""
echo -e "${BOLD}Recommendations:${NC}"
echo ""

if [[ -z "$limit_header" ]]; then
  echo -e "  ${YELLOW}•${NC} Implement rate limiting headers (X-RateLimit-*)"
fi

if [[ $FAILED_TESTS -gt 0 ]]; then
  echo -e "  ${RED}•${NC} Fix failed tests before deploying to production"
fi

echo -e "  ${BLUE}•${NC} Review implementation guide: ${BOLD}guides/Rate-Limiting-Implementation-Complete-Guide.md${NC}"
echo -e "  ${BLUE}•${NC} Review rule: ${BOLD}.cursor/rules/355-rate-limiting-implementation.mdc${NC}"
echo -e "  ${BLUE}•${NC} Validate code: ${BOLD}.cursor/tools/validate-webhooks.sh${NC} (if using webhooks)"

if [[ -n "$API_KEY" ]]; then
  echo ""
  echo -e "${BOLD}Rate Limit Status:${NC}"
  echo "  Limit:     $limit_header requests"
  echo "  Remaining: $remaining_header requests"
  echo "  Reset:     $(date -r $((reset_header / 1000)) 2>/dev/null || echo 'N/A')"
fi

echo ""
exit $EXIT_CODE

