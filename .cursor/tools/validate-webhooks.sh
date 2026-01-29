#!/bin/bash
#
# Webhook Implementation Validator
#
# Validates webhook implementation for security, reliability, and best practices.
# Based on: .cursor/rules/385-webhook-implementation-standards.mdc
#
# Usage:
#   ./cursor/tools/validate-webhooks.sh [--verbose]
#
# Exit codes:
#   0 - All checks passed or only minor warnings
#   1 - Critical security or reliability issues found
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
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNINGS=0
FAILED_CHECKS=0

# Verbose mode
VERBOSE=false
if [[ "${1:-}" == "--verbose" ]]; then
  VERBOSE=true
fi

# Helper functions
print_section() {
  echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}$1${NC}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check_pass() {
  echo -e "  ${GREEN}✓${NC} $1"
  ((PASSED_CHECKS++))
  ((TOTAL_CHECKS++))
}

check_warn() {
  echo -e "  ${YELLOW}⚠️${NC}  $1"
  if [[ "$VERBOSE" == true && -n "${2:-}" ]]; then
    echo -e "    ${YELLOW}→${NC} $2"
  fi
  ((WARNINGS++))
  ((TOTAL_CHECKS++))
}

check_fail() {
  echo -e "  ${RED}✗${NC} $1"
  if [[ "$VERBOSE" == true && -n "${2:-}" ]]; then
    echo -e "    ${RED}→${NC} $2"
  fi
  ((FAILED_CHECKS++))
  ((TOTAL_CHECKS++))
}

# Find project root (look for package.json)
PROJECT_ROOT="."
if [[ -f "package.json" ]]; then
  PROJECT_ROOT="."
elif [[ -f "../package.json" ]]; then
  PROJECT_ROOT=".."
elif [[ -f "../../package.json" ]]; then
  PROJECT_ROOT="../.."
else
  echo -e "${RED}Error: Could not find project root (no package.json found)${NC}"
  exit 1
fi

cd "$PROJECT_ROOT"

echo -e "${BOLD}${BLUE}Webhook Implementation Validator${NC}"
echo -e "Analyzing webhook implementation for security and reliability...\n"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. HMAC Signature Verification
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "1. HMAC Signature Security"

# Check for HMAC generation function
if grep -r "createHmac\|hmac\.new" --include="*.ts" --include="*.js" --include="*.tsx" --include="*.jsx" app/ lib/ 2>/dev/null | grep -q "sha256"; then
  check_pass "Uses HMAC-SHA256 for signature generation"
else
  check_fail "No HMAC-SHA256 signature generation found" \
    "Add: crypto.createHmac('sha256', secret)"
fi

# Check for signature verification function
if grep -r "verifyWebhookSignature\|verify.*signature" --include="*.ts" --include="*.js" app/ lib/ 2>/dev/null | head -1 | grep -q .; then
  check_pass "Webhook signature verification function exists"
else
  check_fail "No signature verification function found" \
    "Implement verifyWebhookSignature() function"
fi

# Check for timing-safe comparison
if grep -r "timingSafeEqual\|compare_digest" --include="*.ts" --include="*.js" --include="*.py" app/ lib/ 2>/dev/null | grep -q .; then
  check_pass "Uses timing-safe comparison (prevents timing attacks)"
else
  check_fail "No timing-safe comparison found" \
    "Use crypto.timingSafeEqual() instead of === for signature comparison"
fi

# Check for webhook secret in environment variables
if grep -r "WEBHOOK_SECRET\|webhook.*secret" .env.example 2>/dev/null | grep -q .; then
  check_pass "Webhook secret configured in environment variables"
else
  check_warn "No WEBHOOK_SECRET in .env.example" \
    "Add WEBHOOK_SECRET=your-secret-here to .env.example"
fi

# Check for hardcoded secrets (security issue)
if grep -r "webhook.*secret.*=.*['\"][a-zA-Z0-9]{20,}" --include="*.ts" --include="*.js" app/ lib/ 2>/dev/null | grep -v "process.env" | grep -q .; then
  check_fail "Hardcoded webhook secret detected" \
    "Move secret to environment variable"
else
  check_pass "No hardcoded webhook secrets detected"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. Retry Logic with Exponential Backoff
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "2. Retry Logic & Reliability"

# Check for retry logic
if grep -r "maxRetries\|max.*attempts\|retry" --include="*.ts" --include="*.js" app/ lib/ 2>/dev/null | grep -i webhook | grep -q .; then
  check_pass "Retry logic implemented"
else
  check_warn "No retry logic found" \
    "Add retry logic with exponential backoff (3 attempts recommended)"
fi

# Check for exponential backoff
if grep -r "Math\.pow\|exponential\|backoff\|\*\*" --include="*.ts" --include="*.js" app/ lib/ 2>/dev/null | grep -i -A5 -B5 retry | grep -q .; then
  check_pass "Exponential backoff pattern detected"
else
  check_warn "No exponential backoff detected" \
    "Use exponential backoff: Math.pow(4, attempt) * 1000"
fi

# Check for jitter (randomization to prevent thundering herd)
if grep -r "Math\.random\|jitter" --include="*.ts" --include="*.js" app/ lib/ 2>/dev/null | grep -i -A5 -B5 retry | grep -q .; then
  check_pass "Jitter implemented (prevents thundering herd)"
else
  check_warn "No jitter detected in retry logic" \
    "Add random jitter: baseDelay + Math.random() * 1000"
fi

# Check for timeout configuration
if grep -r "AbortSignal\.timeout\|timeout.*=.*[0-9]" --include="*.ts" --include="*.js" app/ lib/ 2>/dev/null | grep -i webhook | grep -q .; then
  check_pass "Request timeout configured"
else
  check_warn "No timeout configuration found" \
    "Add timeout: AbortSignal.timeout(30000)"
fi

# Check for 4xx vs 5xx retry logic
if grep -r "status.*>=.*400.*&&.*status.*<.*500" --include="*.ts" --include="*.js" app/ lib/ 2>/dev/null | grep -q .; then
  check_pass "Differentiates 4xx (don't retry) from 5xx (retry)"
else
  check_warn "No differentiation between 4xx and 5xx errors" \
    "Don't retry 4xx errors (permanent failures)"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. Idempotency
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "3. Idempotency (Duplicate Prevention)"

# Check for idempotency key in payload
if grep -r "idempotencyKey\|idempotency.*key" --include="*.ts" --include="*.js" app/ lib/ 2>/dev/null | grep -q .; then
  check_pass "Idempotency key included in webhook payload"
else
  check_fail "No idempotency key found" \
    "Add idempotencyKey to every webhook payload"
fi

# Check for idempotency tracking (database or cache)
if grep -r "processedWebhooks\|webhook.*processed\|idempotency" --include="*.prisma" --include="*.ts" --include="*.js" prisma/ app/ lib/ 2>/dev/null | grep -q .; then
  check_pass "Idempotency tracking implemented"
else
  check_warn "No idempotency tracking found" \
    "Create processedWebhooks table to track delivered webhooks"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. Delivery Tracking & Observability
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "4. Delivery Tracking & Observability"

# Check for webhook delivery tracking schema
if grep -r "WebhookDelivery\|webhook.*delivery" --include="*.prisma" prisma/ 2>/dev/null | grep -q "model"; then
  check_pass "Webhook delivery tracking schema exists"
else
  check_warn "No webhook delivery tracking schema" \
    "Create WebhookDelivery model to track attempts and status"
fi

# Check for delivery status logging
if grep -r "console\.log.*webhook\|logger.*webhook" --include="*.ts" --include="*.js" app/ lib/ 2>/dev/null | grep -q .; then
  check_pass "Webhook delivery logging implemented"
else
  check_warn "No webhook delivery logging found" \
    "Add logging for all webhook attempts (success and failure)"
fi

# Check for attempts tracking
if grep -r "attempts\|attempt.*count" --include="*.ts" --include="*.js" --include="*.prisma" app/ lib/ prisma/ 2>/dev/null | grep -i webhook | grep -q .; then
  check_pass "Delivery attempts tracking implemented"
else
  check_warn "No attempts tracking found" \
    "Track number of delivery attempts per webhook"
fi

# Check for error message storage
if grep -r "lastError\|error.*message" --include="*.prisma" --include="*.ts" prisma/ app/ lib/ 2>/dev/null | grep -i webhook | grep -q .; then
  check_pass "Error messages stored for failed deliveries"
else
  check_warn "No error message storage" \
    "Store lastError for debugging failed webhooks"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5. Configuration & Security
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "5. URL Validation & Security"

# Check for webhook URL validation
if grep -r "validateWebhookUrl\|validate.*url" --include="*.ts" --include="*.js" app/ lib/ 2>/dev/null | grep -q .; then
  check_pass "Webhook URL validation function exists"
else
  check_warn "No URL validation found" \
    "Implement validateWebhookUrl() to prevent SSRF attacks"
fi

# Check for HTTPS enforcement
if grep -r "protocol.*===.*'https'" --include="*.ts" --include="*.js" app/ lib/ 2>/dev/null | grep -q .; then
  check_pass "HTTPS enforcement in production"
else
  check_warn "No HTTPS enforcement found" \
    "Enforce HTTPS for webhook URLs in production"
fi

# Check for localhost/private IP blocking
if grep -r "localhost\|127\.0\.0\.1\|192\.168\|10\.\|172\." --include="*.ts" --include="*.js" app/ lib/ 2>/dev/null | grep -i "block\|prevent\|deny\|reject" | grep -q .; then
  check_pass "Localhost/private IP blocking (SSRF protection)"
else
  check_warn "No SSRF protection detected" \
    "Block localhost and private IPs in webhook URLs"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 6. Testing
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "6. Testing Coverage"

# Check for webhook tests
WEBHOOK_TEST_FILES=$(find . -name "*.test.ts" -o -name "*.test.js" 2>/dev/null | xargs grep -l "webhook" 2>/dev/null | wc -l)
if [[ $WEBHOOK_TEST_FILES -gt 0 ]]; then
  check_pass "Webhook tests exist ($WEBHOOK_TEST_FILES test files)"
else
  check_warn "No webhook tests found" \
    "Create tests for signature verification, retry logic, idempotency"
fi

# Check for signature verification tests
if grep -r "verifyWebhookSignature\|verify.*signature" --include="*.test.ts" --include="*.test.js" . 2>/dev/null | grep -q .; then
  check_pass "Signature verification tests exist"
else
  check_warn "No signature verification tests" \
    "Test both valid and invalid signatures"
fi

# Check for retry logic tests
if grep -r "retry\|retries" --include="*.test.ts" --include="*.test.js" . 2>/dev/null | grep -i webhook | grep -q .; then
  check_pass "Retry logic tests exist"
else
  check_warn "No retry logic tests" \
    "Test retry behavior with 5xx errors"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 7. Documentation
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "7. Documentation"

# Check for webhook documentation
if [[ -f "docs/webhooks.md" ]] || [[ -f "docs/WEBHOOKS.md" ]] || [[ -f "README.md" ]] && grep -q -i webhook README.md; then
  check_pass "Webhook documentation exists"
else
  check_warn "No webhook documentation found" \
    "Create docs/webhooks.md with integration guide"
fi

# Check for example webhook receiver
if grep -r "example.*webhook\|webhook.*example" --include="*.md" --include="*.ts" --include="*.js" docs/ examples/ 2>/dev/null | grep -q .; then
  check_pass "Example webhook receiver provided"
else
  check_warn "No example webhook receiver found" \
    "Provide example code for users to implement webhook receivers"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Summary
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Summary${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\nTotal Checks:    ${BOLD}$TOTAL_CHECKS${NC}"
echo -e "Passed:          ${GREEN}✓ $PASSED_CHECKS${NC}"
echo -e "Warnings:        ${YELLOW}⚠️  $WARNINGS${NC}"
echo -e "Failed:          ${RED}✗ $FAILED_CHECKS${NC}"

# Calculate pass rate
PASS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

echo ""
if [[ $FAILED_CHECKS -eq 0 ]]; then
  if [[ $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}🎉 Perfect! Your webhook implementation is excellent!${NC}"
    echo -e "${GREEN}All security and reliability checks passed.${NC}"
    EXIT_CODE=0
  else
    echo -e "${YELLOW}${BOLD}✅ Good! Your webhook implementation is solid ($PASS_RATE% passed)${NC}"
    echo -e "${YELLOW}Address warnings to achieve excellence.${NC}"
    EXIT_CODE=0
  fi
else
  echo -e "${RED}${BOLD}⚠️  Issues Found ($PASS_RATE% passed)${NC}"
  echo -e "${RED}Fix critical issues before deploying webhooks.${NC}"
  EXIT_CODE=1
fi

echo ""
echo -e "${BOLD}Recommendations:${NC}"
echo ""

if [[ $FAILED_CHECKS -gt 0 ]]; then
  echo -e "  ${RED}1.${NC} Fix all failed checks (critical for security/reliability)"
fi

if [[ $WARNINGS -gt 0 ]]; then
  echo -e "  ${YELLOW}2.${NC} Review warnings and implement recommended improvements"
fi

echo -e "  ${BLUE}3.${NC} Review comprehensive guide: ${BOLD}guides/Webhook-Implementation-Complete-Guide.md${NC}"
echo -e "  ${BLUE}4.${NC} Test webhook delivery: ${BOLD}.cursor/tools/test-webhook-delivery.sh${NC}"
echo -e "  ${BLUE}5.${NC} Review rule: ${BOLD}.cursor/rules/385-webhook-implementation-standards.mdc${NC}"

echo ""
exit $EXIT_CODE

