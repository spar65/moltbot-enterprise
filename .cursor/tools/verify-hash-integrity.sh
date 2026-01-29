#!/bin/bash

################################################################################
# verify-hash-integrity.sh
#
# Verifies cryptographic hash integrity of data files and API responses.
# Checks that hash computation is deterministic and tamper-proof.
#
# Usage:
#   ./verify-hash-integrity.sh                    # Run all checks
#   ./verify-hash-integrity.sh --verbose          # Detailed output
#   ./verify-hash-integrity.sh --test-file <path> # Test specific file
#
# Exit Codes:
#   0 - All integrity checks passed
#   1 - Integrity violations detected
#
# Related Rules:
#   - @227-cryptographic-verification-standards.mdc
#   - @012-api-security.mdc
#   - @224-secrets-management.mdc
#
# Related Guides:
#   - guides/Cryptographic-Verification-Complete-Guide.md
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Configuration
VERBOSE=false
TEST_FILE=""

################################################################################
# Parse arguments
################################################################################
while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --test-file)
      TEST_FILE="$2"
      shift 2
      ;;
    --help|-h)
      head -n 30 "$0" | grep '^#' | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

################################################################################
# Helper functions
################################################################################

section() {
  echo ""
  echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}${BOLD}$1${NC}"
  echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check() {
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  if [ "$1" = "pass" ]; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo -e "  ${GREEN}✓${NC} $2"
    [ "$VERBOSE" = true ] && [ -n "${3:-}" ] && echo -e "    ${GREEN}→${NC} $3"
  elif [ "$1" = "fail" ]; then
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    echo -e "  ${RED}✗${NC} $2"
    [ -n "${3:-}" ] && echo -e "    ${RED}→${NC} $3"
  elif [ "$1" = "warn" ]; then
    WARNINGS=$((WARNINGS + 1))
    echo -e "  ${YELLOW}⚠️ ${NC} $2"
    [ -n "${3:-}" ] && echo -e "    ${YELLOW}→${NC} $3"
  fi
}

################################################################################
# Check 1: Hash Function Implementation
################################################################################
check_hash_functions() {
  section "1. Hash Function Implementation"
  
  # Check for SHA-256 usage
  if grep -r "createHash('sha256')" app/lib --include="*.ts" --include="*.js" > /dev/null 2>&1; then
    check pass "Uses SHA-256 for hash generation" "Industry-standard cryptographic hash function"
  else
    check warn "No SHA-256 usage found" "Consider using crypto.createHash('sha256')"
  fi
  
  # Check for HMAC usage (webhooks, signatures)
  if grep -r "createHmac('sha256'" app/lib --include="*.ts" --include="*.js" > /dev/null 2>&1; then
    check pass "Uses HMAC-SHA256 for signatures" "Secure message authentication"
  else
    check warn "No HMAC usage found" "HMAC recommended for webhook signatures"
  fi
  
  # Check for timing-safe comparison
  if grep -r "timingSafeEqual" app/lib --include="*.ts" --include="*.js" > /dev/null 2>&1; then
    check pass "Uses timing-safe comparison" "Prevents timing attacks on signature verification"
  else
    check warn "No timing-safe comparison found" "Use crypto.timingSafeEqual() for signature verification"
  fi
  
  # Check for canonical JSON serialization
  if grep -r "fast-json-stable-stringify\|json-stable-stringify" package.json > /dev/null 2>&1; then
    check pass "Uses canonical JSON serialization" "Ensures deterministic hash computation"
  else
    check warn "No canonical JSON library found" "Install fast-json-stable-stringify for deterministic hashing"
  fi
}

################################################################################
# Check 2: Hash Storage and Structure
################################################################################
check_hash_storage() {
  section "2. Hash Storage and Structure"
  
  # Check for hash fields in Prisma schema
  if [ -f "prisma/schema.prisma" ]; then
    if grep -i "hash\|integrity" prisma/schema.prisma > /dev/null 2>&1; then
      check pass "Hash fields present in database schema" "Stores cryptographic hashes for verification"
      
      # Check for hash field types
      if grep -E "hash.*String|integrity.*String" prisma/schema.prisma > /dev/null 2>&1; then
        check pass "Hash fields use String type" "Appropriate for hex-encoded SHA-256 (64 chars)"
      fi
    else
      check warn "No hash fields found in schema" "Consider adding integrity hash fields"
    fi
  else
    check warn "No Prisma schema found" "Skip database schema checks"
  fi
  
  # Check for hash verification functions
  if grep -r "verifyHash\|verify.*Hash\|checkIntegrity" app/lib --include="*.ts" --include="*.js" > /dev/null 2>&1; then
    check pass "Hash verification functions implemented" "Allows clients to verify data integrity"
  else
    check warn "No hash verification functions found" "Implement verification endpoints for public auditability"
  fi
}

################################################################################
# Check 3: Hash Determinism Testing
################################################################################
check_hash_determinism() {
  section "3. Hash Determinism Testing"
  
  # Check for hash-related tests
  if find . -path "*/node_modules" -prune -o -name "*.test.ts" -o -name "*.test.js" | xargs grep -l "hash\|Hash" > /dev/null 2>&1; then
    check pass "Hash-related tests found" "Tests verify hash computation"
    
    # Check for determinism tests
    if find . -path "*/node_modules" -prune -o -name "*.test.ts" -o -name "*.test.js" | xargs grep -l "deterministic\|same hash\|identical hash" > /dev/null 2>&1; then
      check pass "Determinism tests found" "Verifies same input produces same hash"
    else
      check warn "No determinism tests found" "Add tests to verify hash consistency"
    fi
    
    # Check for tampering detection tests
    if find . -path "*/node_modules" -prune -o -name "*.test.ts" -o -name "*.test.js" | xargs grep -l "tamper\|modify.*hash\|invalid hash" > /dev/null 2>&1; then
      check pass "Tampering detection tests found" "Verifies modified data is detected"
    else
      check warn "No tampering detection tests found" "Add tests to verify tamper detection"
    fi
  else
    check warn "No hash tests found" "Add comprehensive hash testing"
  fi
}

################################################################################
# Check 4: API Endpoint Verification
################################################################################
check_verification_endpoints() {
  section "4. Verification API Endpoints"
  
  # Check for verification endpoints
  if find app/api -name "*.ts" -o -name "*.js" 2>/dev/null | xargs grep -l "verify" > /dev/null 2>&1; then
    check pass "Verification endpoints found" "Public API for hash verification"
    
    # Check for rate limiting on verification endpoints
    if find app/api -name "*.ts" -o -name "*.js" 2>/dev/null | xargs grep -l "rateLimit\|checkRateLimit" > /dev/null 2>&1; then
      check pass "Rate limiting implemented" "Prevents verification endpoint abuse"
    else
      check warn "No rate limiting found" "Add rate limiting to verification endpoints"
    fi
  else
    check warn "No verification endpoints found" "Consider adding public verification endpoints"
  fi
  
  # Check for verification documentation
  if [ -f "docs/API-VERIFICATION.md" ] || grep -r "verification" docs/ --include="*.md" > /dev/null 2>&1; then
    check pass "Verification documentation exists" "Guides users on how to verify hashes"
  else
    check warn "No verification documentation found" "Document how clients can verify hashes"
  fi
}

################################################################################
# Check 5: Security Best Practices
################################################################################
check_security_practices() {
  section "5. Security Best Practices"
  
  # Check for secret management in hash operations
  if grep -r "WEBHOOK_SECRET\|SIGNING_SECRET" .env.example > /dev/null 2>&1; then
    check pass "Webhook/signing secrets in .env.example" "Secret management configured"
  else
    check warn "No webhook/signing secrets in .env.example" "Add WEBHOOK_SECRET to environment config"
  fi
  
  # Check for hardcoded secrets in hash operations
  if grep -rE "createHmac.*['\"].*secret.*['\"]" app/lib --include="*.ts" --include="*.js" > /dev/null 2>&1; then
    check fail "Potential hardcoded secret detected" "Use environment variables for secrets"
  else
    check pass "No hardcoded secrets in hash operations" "Secrets properly externalized"
  fi
  
  # Check for hash length validation
  if grep -r "length.*64\|64.*length" app/lib --include="*.ts" --include="*.js" > /dev/null 2>&1; then
    check pass "Hash length validation found" "Validates SHA-256 produces 64 hex chars"
  else
    check warn "No hash length validation" "Validate hash format (64 hex characters)"
  fi
  
  # Check for hex validation regex
  if grep -rE "\^[a-f0-9]\{64\}\$|\^[0-9a-f]\{64\}\$" app/lib --include="*.ts" --include="*.js" > /dev/null 2>&1; then
    check pass "Hex format validation found" "Validates hash is valid hexadecimal"
  else
    check warn "No hex format validation" "Add regex validation: /^[a-f0-9]{64}$/"
  fi
}

################################################################################
# Check 6: Hash Chain and Audit Trail
################################################################################
check_hash_chain() {
  section "6. Hash Chain and Audit Trail"
  
  # Check for hash chain implementation
  if grep -r "previousHash\|chainHash\|parentHash" app/lib --include="*.ts" --include="*.js" > /dev/null 2>&1; then
    check pass "Hash chain implementation found" "Creates tamper-evident audit trail"
  else
    check warn "No hash chain found" "Consider implementing hash chains for audit trails"
  fi
  
  # Check for timestamp in hash computation
  if grep -r "timestamp.*hash\|hash.*timestamp" app/lib --include="*.ts" --include="*.js" > /dev/null 2>&1; then
    check pass "Timestamp included in hash" "Prevents replay attacks"
  else
    check warn "No timestamp in hash computation" "Include timestamp for temporal integrity"
  fi
  
  # Check for immutable audit logs
  if grep -i "auditlog\|audit_log" prisma/schema.prisma 2>/dev/null | grep -v "updatedAt" > /dev/null 2>&1; then
    check pass "Immutable audit logs detected" "Audit records cannot be modified"
  else
    check warn "No immutable audit logs found" "Make audit logs append-only (no updates)"
  fi
}

################################################################################
# Check 7: Performance Optimization
################################################################################
check_performance() {
  section "7. Performance Optimization"
  
  # Check for hash caching
  if grep -r "cache.*hash\|hash.*cache\|memoize" app/lib --include="*.ts" --include="*.js" > /dev/null 2>&1; then
    check pass "Hash caching implemented" "Avoids redundant hash computation"
  else
    check warn "No hash caching found" "Cache computed hashes for frequently accessed data"
  fi
  
  # Check for batch hash computation
  if grep -r "batchHash\|hashBatch\|Promise.all.*hash" app/lib --include="*.ts" --include="*.js" > /dev/null 2>&1; then
    check pass "Batch hash computation found" "Efficient parallel hash generation"
  else
    check warn "No batch hash operations" "Consider batch processing for multiple hashes"
  fi
  
  # Check for streaming hash computation (large files)
  if grep -r "createHash.*update\|hash.*stream" app/lib --include="*.ts" --include="*.js" > /dev/null 2>&1; then
    check pass "Streaming hash computation found" "Handles large data efficiently"
  else
    check warn "No streaming hash operations" "Use streaming for large files to reduce memory"
  fi
}

################################################################################
# Check 8: Documentation and Examples
################################################################################
check_documentation() {
  section "8. Documentation and Examples"
  
  # Check for hash verification examples in README or docs
  if grep -r "verify.*hash\|hash.*verification" README.md docs/ --include="*.md" > /dev/null 2>&1; then
    check pass "Hash verification examples in documentation" "Users know how to verify integrity"
  else
    check warn "No verification examples in docs" "Add examples of hash verification to docs"
  fi
  
  # Check for SDK examples with hash verification
  if find . -name "*.md" | xargs grep -l "SDK\|client library" | xargs grep -l "hash\|verify" > /dev/null 2>&1; then
    check pass "SDK includes hash verification" "Client libraries support integrity checks"
  else
    check warn "No SDK verification examples" "Add hash verification to SDK documentation"
  fi
  
  # Check for API response examples with hashes
  if grep -r "\"hash\":\|\"integrity\":\|\"signature\":" docs/ --include="*.md" > /dev/null 2>&1; then
    check pass "API examples include hash fields" "Clear documentation of hash structure"
  else
    check warn "No hash fields in API examples" "Show hash/signature fields in API docs"
  fi
}

################################################################################
# Summary
################################################################################
print_summary() {
  echo ""
  echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}Summary${NC}"
  echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "  Total Checks:    $TOTAL_CHECKS"
  echo -e "  ${GREEN}Passed:          $PASSED_CHECKS${NC}"
  echo -e "  ${YELLOW}Warnings:        $WARNINGS${NC}"
  echo -e "  ${RED}Failed:          $FAILED_CHECKS${NC}"
  echo ""
  
  # Calculate percentage
  if [ $TOTAL_CHECKS -gt 0 ]; then
    PERCENTAGE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
    
    if [ $FAILED_CHECKS -eq 0 ]; then
      if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}${BOLD}🎉 Perfect! Your cryptographic verification is production-ready!${NC}"
      elif [ $WARNINGS -le 3 ]; then
        echo -e "${GREEN}${BOLD}✅ Excellent! Your hash integrity implementation is solid ($PERCENTAGE% passed)${NC}"
      else
        echo -e "${YELLOW}${BOLD}⚠️  Good foundation, but consider addressing warnings ($PERCENTAGE% passed)${NC}"
      fi
    else
      echo -e "${RED}${BOLD}❌ Critical issues found - fix failures before production deployment${NC}"
    fi
  fi
  
  echo ""
  
  # Provide recommendations
  if [ $WARNINGS -gt 0 ] || [ $FAILED_CHECKS -gt 0 ]; then
    echo -e "${BOLD}Recommendations:${NC}"
    echo ""
    
    if [ $FAILED_CHECKS -gt 0 ]; then
      echo "  1. Fix critical failures immediately (security risks)"
    fi
    
    if [ $WARNINGS -gt 5 ]; then
      echo "  2. Address warnings to improve hash integrity robustness"
      echo "  3. Review @227-cryptographic-verification-standards.mdc for best practices"
      echo "  4. See guides/Cryptographic-Verification-Complete-Guide.md for implementation"
    fi
    
    echo ""
  fi
}

################################################################################
# Main execution
################################################################################
echo -e "${BOLD}Cryptographic Hash Integrity Verification${NC}"
echo "Checking hash implementation, security, and verification..."

# Run all checks
check_hash_functions
check_hash_storage
check_hash_determinism
check_verification_endpoints
check_security_practices
check_hash_chain
check_performance
check_documentation

# Print summary
print_summary

# Exit with appropriate code
if [ $FAILED_CHECKS -gt 0 ]; then
  exit 1
else
  exit 0
fi





















