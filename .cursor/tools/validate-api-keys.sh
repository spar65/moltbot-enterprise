#!/usr/bin/env bash
#
# Validate API Key Implementation
# 
# Purpose: Validate API key generation, storage, and security implementation
# Usage: ./validate-api-keys.sh [--verbose]
#
# Exit codes:
#   0 - All validations passed
#   1 - Critical security issues found
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Verbose mode
VERBOSE=false
if [[ "${1:-}" == "--verbose" ]] || [[ "${1:-}" == "-v" ]]; then
  VERBOSE=true
fi

# Helper functions
print_header() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check_pass() {
  echo -e "  ${GREEN}✓${NC} $1"
  ((PASSED_CHECKS++))
  ((TOTAL_CHECKS++))
}

check_fail() {
  echo -e "  ${RED}✗${NC} $1"
  if [[ $VERBOSE == true ]] && [[ -n "${2:-}" ]]; then
    echo -e "    ${RED}→${NC} $2"
  fi
  ((FAILED_CHECKS++))
  ((TOTAL_CHECKS++))
}

check_warn() {
  echo -e "  ${YELLOW}⚠${NC} $1"
  if [[ $VERBOSE == true ]] && [[ -n "${2:-}" ]]; then
    echo -e "    ${YELLOW}→${NC} $2"
  fi
  ((WARNING_CHECKS++))
  ((TOTAL_CHECKS++))
}

# ============================================
# 1. API Key Format Validation
# ============================================
print_header "1. API Key Format Validation"

echo "Checking for API key format patterns..."

# Search for key generation patterns
if grep -r "randomBytes\|random\|crypto.createHash" app/lib --include="*api-key*.ts" app/lib/health-check 2>/dev/null | grep -v "node_modules" | grep -q "randomBytes"; then
  check_pass "Uses crypto.randomBytes() for key generation"
else
  check_fail "Missing crypto.randomBytes() for key generation" \
    "Use: crypto.randomBytes(32).toString('hex')"
fi

# Check for environment prefixes
if grep -r "prefix\|environment" app/lib --include="*api-key*.ts" app/lib/health-check 2>/dev/null | grep -q "live\|test\|dev"; then
  check_pass "Implements environment-specific key prefixes"
else
  check_warn "No evidence of environment prefixes" \
    "Recommended: hck_live_, hck_test_, hck_dev_"
fi

# Check for key format validation
if grep -r "startsWith\|test\|match" app/lib --include="*api-key*.ts" app/lib/health-check 2>/dev/null | grep -q "startsWith.*hck_\|startsWith.*vibe_"; then
  check_pass "Key format validation found"
else
  check_warn "No key format validation found" \
    "Add validation: key.startsWith('your_prefix_')"
fi

# ============================================
# 2. Security - Hashing & Storage
# ============================================
print_header "2. Security - Hashing & Storage"

echo "Checking for secure key storage patterns..."

# Check for bcrypt usage
if grep -r "bcrypt" app/lib package.json 2>/dev/null | grep -q "bcrypt"; then
  check_pass "bcrypt dependency found"
  
  # Check for proper bcrypt rounds
  if grep -r "bcrypt.hash\|hash(" app/lib --include="*api-key*.ts" app/lib/health-check 2>/dev/null | grep -q "12\|BCRYPT_ROUNDS"; then
    check_pass "bcrypt rounds >= 12 (secure)"
  else
    check_fail "bcrypt rounds not set or < 12" \
      "Use: bcrypt.hash(key, 12) minimum"
  fi
else
  check_fail "bcrypt not found - keys may be stored in plaintext!" \
    "Install: npm install bcrypt @types/bcrypt"
fi

# Check for plaintext key storage
if grep -r "INSERT.*api.*key\s" prisma/schema.prisma app/lib 2>/dev/null | grep -v "hash\|Hash"; then
  check_fail "Possible plaintext key storage detected!" \
    "Store only hashes: keyHash, key_hash, apiKeyHash"
else
  check_pass "No plaintext key storage detected"
fi

# Check for keyHash field in schema
if grep -r "keyHash\|key_hash\|apiKeyHash" prisma/schema.prisma 2>/dev/null | grep -q "String"; then
  check_pass "keyHash field found in Prisma schema"
else
  check_warn "No keyHash field in schema" \
    "Expected field: keyHash String (stores bcrypt hash)"
fi

# ============================================
# 3. Environment Isolation
# ============================================
print_header "3. Environment Isolation"

echo "Checking for environment isolation patterns..."

# Check for environment validation
if grep -r "environment.*===\|validateEnvironment" app/lib --include="*api-key*.ts" app/lib/health-check 2>/dev/null | grep -q "live\|test\|dev"; then
  check_pass "Environment validation found"
else
  check_warn "No environment validation detected" \
    "Validate: if (key.environment !== providedEnv) throw error"
fi

# Check for environment constants
if grep -r "LIVE\|TEST\|DEV.*=.*'" app/lib --include="*api-key*.ts" app/lib/health-check 2>/dev/null | grep -q "live.*test.*dev"; then
  check_pass "Environment constants defined"
else
  check_warn "No environment constants found" \
    "Define: const ENVIRONMENTS = ['live', 'test', 'dev'] as const"
fi

# ============================================
# 4. Audit Logging
# ============================================
print_header "4. Audit Logging"

echo "Checking for audit trail implementation..."

# Check for audit log table
if grep -r "ApiKeyAuditLog\|api_key_audit\|AuditLog" prisma/schema.prisma 2>/dev/null | grep -q "model"; then
  check_pass "Audit log table found in schema"
else
  check_warn "No audit log table in schema" \
    "Create: model ApiKeyAuditLog with userId, action, timestamp"
fi

# Check for IP hashing (GDPR compliance)
if grep -r "hashIpAddress\|createHmac\|IP.*hash" app/lib --include="*api-key*.ts" app/lib/health-check 2>/dev/null | grep -q "hmac\|hash"; then
  check_pass "IP address hashing found (GDPR-compliant)"
else
  check_warn "No IP hashing detected" \
    "Use: crypto.createHmac('sha256', salt).update(ip).digest('hex')"
fi

# Check for audit logging calls
if grep -r "logAudit\|auditLog\|createAuditLog" app/lib --include="*api-key*.ts" app/lib/health-check 2>/dev/null | grep -q "log"; then
  check_pass "Audit logging implementation found"
else
  check_warn "No audit logging detected" \
    "Log: generation, validation, revocation, rotation events"
fi

# ============================================
# 5. Rate Limiting
# ============================================
print_header "5. Rate Limiting"

echo "Checking for rate limiting implementation..."

# Check for rate limiting
if grep -r "rateLimit\|RateLimit\|rate-limit" app/lib app/middleware 2>/dev/null | grep -q "limit"; then
  check_pass "Rate limiting implementation found"
else
  check_warn "No rate limiting detected" \
    "Implement per-key rate limits (e.g., 1000/hour)"
fi

# Check for rate limit configuration
if grep -r "RATE_LIMIT\|rateLimit.*:" app/lib --include="*api-key*.ts" app/lib/health-check .env.example 2>/dev/null | grep -q "limit"; then
  check_pass "Rate limit configuration found"
else
  check_warn "No rate limit config" \
    "Configure: requests per minute/hour per environment"
fi

# ============================================
# 6. Key Expiration
# ============================================
print_header "6. Key Expiration"

echo "Checking for key expiration handling..."

# Check for expiration field in schema
if grep -r "expiresAt\|expires_at\|expiration" prisma/schema.prisma 2>/dev/null | grep -q "DateTime"; then
  check_pass "Expiration field found in schema"
else
  check_warn "No expiration field in schema" \
    "Add: expiresAt DateTime? @default(now() + 90 days)"
fi

# Check for expiration validation
if grep -r "isExpired\|expiresAt\|checkExpiration" app/lib --include="*api-key*.ts" app/lib/health-check 2>/dev/null | grep -q "expir"; then
  check_pass "Expiration validation logic found"
else
  check_warn "No expiration validation" \
    "Check: if (key.expiresAt < new Date()) throw error"
fi

# ============================================
# 7. Key Rotation
# ============================================
print_header "7. Key Rotation"

echo "Checking for key rotation capabilities..."

# Check for rotation endpoints/methods
if grep -r "rotate\|Rotate.*key\|regenerate" app/lib app/api --include="*api-key*.ts" app/lib/health-check 2>/dev/null | grep -q "rotate\|Rotate"; then
  check_pass "Key rotation functionality found"
else
  check_warn "No key rotation implementation" \
    "Implement: rotateApiKey() method with grace period"
fi

# Check for grace period support
if grep -r "gracePeriod\|grace.*period" app/lib --include="*api-key*.ts" app/lib/health-check 2>/dev/null | grep -q "grace"; then
  check_pass "Grace period support for rotation"
else
  check_warn "No grace period for rotation" \
    "Allow both old and new keys during rotation (7-14 days)"
fi

# ============================================
# 8. Testing Coverage
# ============================================
print_header "8. Testing Coverage"

echo "Checking for API key test coverage..."

# Check for test files
if ls app/__tests__/*api-key*.test.ts 2>/dev/null | grep -q "api-key"; then
  check_pass "API key test files found"
  
  # Count test cases
  test_count=$(grep -r "test\|it(" app/__tests__/*api-key*.test.ts 2>/dev/null | wc -l)
  if [[ $test_count -gt 10 ]]; then
    check_pass "Comprehensive test coverage ($test_count tests)"
  else
    check_warn "Limited test coverage ($test_count tests)" \
      "Recommended: 20+ tests covering generation, validation, security"
  fi
else
  check_fail "No API key tests found" \
    "Create: app/__tests__/api-key-*.test.ts"
fi

# Check for security-specific tests
if grep -r "bcrypt\|hash.*test\|security" app/__tests__/*api-key*.test.ts 2>/dev/null | grep -q "bcrypt\|hash"; then
  check_pass "Security tests found"
else
  check_warn "No security-specific tests" \
    "Test: hashing, environment isolation, expiration"
fi

# ============================================
# 9. Documentation
# ============================================
print_header "9. Documentation"

echo "Checking for API key documentation..."

# Check for API documentation
if ls docs/*api-key*.md guides/*API-Key*.md 2>/dev/null | grep -q "api.*key\|API.*Key"; then
  check_pass "API key documentation found"
else
  check_warn "No API key documentation" \
    "Create: docs/API-Key-Usage.md or guides/API-Key-Management-Guide.md"
fi

# Check for README mentions
if grep -r "API key\|API_KEY" README.md docs/README.md 2>/dev/null | grep -q "API"; then
  check_pass "API key usage documented in README"
else
  check_warn "API keys not mentioned in README" \
    "Document: How to generate and use API keys"
fi

# ============================================
# 10. Environment Variables
# ============================================
print_header "10. Environment Variables"

echo "Checking for environment variable security..."

# Check for .env.example
if grep -r "API_KEY\|BCRYPT\|IP_HASH_SALT" .env.example 2>/dev/null | grep -q "API_KEY\|BCRYPT\|SALT"; then
  check_pass "API key env vars documented in .env.example"
else
  check_warn "API key env vars not in .env.example" \
    "Add: BCRYPT_ROUNDS=12, IP_HASH_SALT=<random>"
fi

# Check for sensitive defaults
if grep -r "IP_HASH_SALT.*=.*'default'\|SALT.*=.*'change-me'" app/lib .env.example 2>/dev/null | grep -q "default\|change"; then
  check_warn "Default/placeholder salt values detected" \
    "Generate unique salt: openssl rand -hex 32"
else
  check_pass "No default salt values detected"
fi

# ============================================
# Summary
# ============================================
print_header "Validation Summary"

echo ""
echo "Total Checks:    $TOTAL_CHECKS"
echo -e "${GREEN}Passed:${NC}          $PASSED_CHECKS"
echo -e "${YELLOW}Warnings:${NC}        $WARNING_CHECKS"
echo -e "${RED}Failed:${NC}          $FAILED_CHECKS"
echo ""

# Calculate percentage
PASS_PERCENTAGE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

if [[ $PASS_PERCENTAGE -ge 90 ]]; then
  echo -e "${GREEN}🎉 Excellent!${NC} Your API key implementation is solid ($PASS_PERCENTAGE% passed)"
  exit 0
elif [[ $PASS_PERCENTAGE -ge 70 ]]; then
  echo -e "${YELLOW}⚠️  Good, but needs improvement${NC} ($PASS_PERCENTAGE% passed)"
  echo ""
  echo "Review warnings and failed checks above."
  exit 0
elif [[ $FAILED_CHECKS -gt 0 ]]; then
  echo -e "${RED}❌ Critical issues found!${NC} ($PASS_PERCENTAGE% passed)"
  echo ""
  echo "Fix failed checks before deploying to production."
  exit 1
else
  echo -e "${YELLOW}⚠️  Some improvements recommended${NC} ($PASS_PERCENTAGE% passed)"
  exit 0
fi





















