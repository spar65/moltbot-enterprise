#!/usr/bin/env bash
#
# Audit API Key Usage
# 
# Purpose: Audit API key usage patterns, detect security issues, and identify hardcoded keys
# Usage: ./audit-api-key-usage.sh [--fix] [--verbose]
#
# Exit codes:
#   0 - No issues found
#   1 - Critical security issues detected
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
VERBOSE=false
FIX=false
ISSUES_FOUND=0

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --fix)
      FIX=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--verbose] [--fix]"
      exit 1
      ;;
  esac
done

# Helper functions
print_header() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

issue_critical() {
  echo -e "  ${RED}🚨 CRITICAL:${NC} $1"
  if [[ $VERBOSE == true ]] && [[ -n "${2:-}" ]]; then
    echo -e "    ${RED}→${NC} $2"
  fi
  ((ISSUES_FOUND++))
}

issue_warn() {
  echo -e "  ${YELLOW}⚠️  WARNING:${NC} $1"
  if [[ $VERBOSE == true ]] && [[ -n "${2:-}" ]]; then
    echo -e "    ${YELLOW}→${NC} $2"
  fi
}

issue_info() {
  echo -e "  ${BLUE}ℹ️  INFO:${NC} $1"
}

check_ok() {
  echo -e "  ${GREEN}✓${NC} $1"
}

# ============================================
# 1. Scan for Hardcoded API Keys
# ============================================
print_header "1. Scanning for Hardcoded API Keys"

echo "Searching for potential hardcoded API keys..."

# Common API key patterns
PATTERNS=(
  "hck_[a-zA-Z0-9_-]{20,}"       # Health check keys
  "vibe_[a-zA-Z0-9_-]{20,}"      # VibeCoder keys
  "sk-[a-zA-Z0-9]{20,}"          # OpenAI/Anthropic keys
  "['\"]api[_-]?key['\"]:\s*['\"][a-zA-Z0-9_-]{20,}['\"]"  # Generic API keys
  "ANTHROPIC_API_KEY=sk-"        # Env vars in code
  "OPENAI_API_KEY=sk-"
)

FOUND_KEYS=false
for pattern in "${PATTERNS[@]}"; do
  if grep -rE "$pattern" app/ lib/ src/ --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null | grep -v "node_modules" | grep -v ".test." | grep -v "example" | grep -v "placeholder"; then
    FOUND_KEYS=true
  fi
done

if [[ $FOUND_KEYS == true ]]; then
  issue_critical "Hardcoded API keys detected in source code!" \
    "NEVER commit API keys. Use environment variables instead."
  
  if [[ $FIX == true ]]; then
    echo ""
    echo "🔧 Suggested fixes:"
    echo "   1. Move keys to .env file"
    echo "   2. Add .env to .gitignore"
    echo "   3. Use process.env.API_KEY_NAME"
    echo "   4. Rotate compromised keys immediately"
  fi
else
  check_ok "No hardcoded API keys detected in source code"
fi

# Check if keys exist in git history
echo ""
echo "Checking git history for leaked keys..."
if git log --all --full-history --source --pretty=format:"%H" -- . | head -100 | xargs -I {} git grep -E "sk-[a-zA-Z0-9]{20,}" {} 2>/dev/null | grep -q "sk-"; then
  issue_critical "API keys found in git history!" \
    "Keys may have been committed previously. Rotate all keys and use git-filter-branch or BFG Repo-Cleaner"
  ((ISSUES_FOUND++))
else
  check_ok "No API keys found in recent git history"
fi

# ============================================
# 2. Check Environment Variable Usage
# ============================================
print_header "2. Environment Variable Security"

echo "Checking for proper environment variable usage..."

# Check for .env in .gitignore
if grep -q "^\.env$" .gitignore 2>/dev/null; then
  check_ok ".env is in .gitignore"
else
  issue_critical ".env not in .gitignore!" \
    "Add '.env' to .gitignore to prevent committing secrets"
fi

# Check for .env.example
if [[ -f .env.example ]]; then
  check_ok ".env.example exists"
  
  # Check if it has placeholder values
  if grep -E "=sk-|=hck_.*[a-zA-Z0-9]{20}" .env.example 2>/dev/null; then
    issue_warn "Real API keys in .env.example" \
      "Use placeholders: API_KEY=your_key_here"
  else
    check_ok ".env.example uses placeholders"
  fi
else
  issue_warn ".env.example not found" \
    "Create .env.example with placeholder values for documentation"
fi

# Check for client-side exposure
echo ""
echo "Checking for client-side API key exposure..."

CLIENT_EXPOSED=false
if grep -rE "NEXT_PUBLIC.*API.*KEY" app/ src/ --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -q "NEXT_PUBLIC"; then
  issue_critical "API keys exposed to client-side code!" \
    "Never use NEXT_PUBLIC_ prefix for API keys. Keep them server-side only."
  CLIENT_EXPOSED=true
fi

if grep -rE "process\.env\.[A-Z_]*KEY" app/ --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v "// server-side" | grep -q "process.env"; then
  issue_warn "Possible client-side env var usage" \
    "Ensure API keys are only used in Server Components or API routes"
fi

if [[ $CLIENT_EXPOSED == false ]]; then
  check_ok "No client-side API key exposure detected"
fi

# ============================================
# 3. API Key Validation Patterns
# ============================================
print_header "3. API Key Validation Patterns"

echo "Checking for proper API key validation..."

# Check for validation before use
if grep -r "validateApiKey\|verifyApiKey\|authenticateApiKey" app/lib app/middleware --include="*.ts" 2>/dev/null | grep -q "validate\|verify\|authenticate"; then
  check_ok "API key validation functions found"
else
  issue_warn "No API key validation functions detected" \
    "Implement: validateApiKey() before processing requests"
fi

# Check for error handling
if grep -r "Invalid.*API.*key\|API.*key.*invalid" app/lib app/middleware --include="*.ts" 2>/dev/null | grep -q "invalid\|Invalid"; then
  check_ok "API key error handling found"
else
  issue_warn "No API key error handling detected" \
    "Handle: invalid format, expired keys, revoked keys"
fi

# Check for rate limiting
if grep -r "rateLimit.*api.*key\|apiKey.*rateLimit" app/lib app/middleware --include="*.ts" 2>/dev/null | grep -q "rateLimit"; then
  check_ok "API key rate limiting found"
else
  issue_warn "No rate limiting for API keys" \
    "Implement per-key rate limiting to prevent abuse"
fi

# ============================================
# 4. Logging & Audit Trail
# ============================================
print_header "4. Logging & Audit Trail"

echo "Checking for proper API key logging..."

# Check for API key logging (should NOT log full keys)
if grep -rE "console\.log.*apiKey|logger.*apiKey" app/ --include="*.ts" 2>/dev/null | grep -v "keyId\|hint" | grep -q "apiKey"; then
  issue_critical "Full API keys may be logged!" \
    "NEVER log full API keys. Log keyId or hint only."
fi

# Check for audit logging
if grep -r "audit.*log.*api.*key\|logApiKeyUsage" app/lib --include="*.ts" 2>/dev/null | grep -q "audit\|log"; then
  check_ok "API key audit logging found"
else
  issue_warn "No audit logging for API key usage" \
    "Log: key generation, validation attempts, revocation"
fi

# Check for IP logging compliance
if grep -r "hashIpAddress\|hash.*ip" app/lib --include="*.ts" 2>/dev/null | grep -q "hash"; then
  check_ok "IP address hashing found (GDPR-compliant)"
else
  issue_warn "No IP address hashing detected" \
    "Hash IP addresses for GDPR compliance: crypto.createHmac('sha256', salt).update(ip)"
fi

# ============================================
# 5. Database Storage
# ============================================
print_header "5. Database Storage Security"

echo "Checking database schema for API key storage..."

# Check Prisma schema for proper hashing
if [[ -f prisma/schema.prisma ]]; then
  if grep -E "keyHash|key_hash|apiKeyHash" prisma/schema.prisma | grep -q "String"; then
    check_ok "API keys stored as hashes in schema"
  else
    issue_critical "API keys may be stored in plaintext!" \
      "Store only bcrypt hashes: keyHash String"
  fi
  
  # Check for expiration field
  if grep -E "expiresAt|expires_at" prisma/schema.prisma | grep -q "DateTime"; then
    check_ok "Key expiration field found in schema"
  else
    issue_warn "No expiration field in schema" \
      "Add: expiresAt DateTime? for automatic key expiration"
  fi
  
  # Check for revocation field
  if grep -E "revokedAt|revoked_at|isActive|is_active" prisma/schema.prisma | grep -q "Boolean\|DateTime"; then
    check_ok "Key revocation field found in schema"
  else
    issue_warn "No revocation field in schema" \
      "Add: revokedAt DateTime? or isActive Boolean"
  fi
else
  issue_warn "No Prisma schema found" \
    "Cannot validate database schema for API keys"
fi

# ============================================
# 6. API Key Rotation
# ============================================
print_header "6. API Key Rotation & Lifecycle"

echo "Checking for key rotation capabilities..."

# Check for rotation implementation
if grep -r "rotateApiKey\|regenerateApiKey" app/lib --include="*.ts" 2>/dev/null | grep -q "rotate\|regenerate"; then
  check_ok "API key rotation implementation found"
else
  issue_warn "No key rotation implementation" \
    "Implement: rotateApiKey() with grace period support"
fi

# Check for expiration handling
if grep -r "checkExpiration\|isExpired.*apiKey" app/lib --include="*.ts" 2>/dev/null | grep -q "expir"; then
  check_ok "Key expiration checking found"
else
  issue_warn "No expiration checking" \
    "Check key expiration before validation"
fi

# Check for usage tracking
if grep -r "lastUsedAt\|last_used_at\|usageCount" prisma/schema.prisma app/lib --include="*.ts" 2>/dev/null | grep -q "lastUsed\|usageCount"; then
  check_ok "API key usage tracking found"
else
  issue_warn "No usage tracking" \
    "Track: lastUsedAt, usageCount for monitoring"
fi

# ============================================
# 7. Documentation & Developer Experience
# ============================================
print_header "7. Documentation & Developer Experience"

echo "Checking API key documentation..."

# Check for README documentation
if grep -iE "api.*key|API.*KEY" README.md 2>/dev/null | grep -q "API"; then
  check_ok "API keys documented in README"
else
  issue_warn "API keys not in README" \
    "Document: how to generate, use, and rotate API keys"
fi

# Check for SDK/client examples
if ls packages/sdk-*/README.md 2>/dev/null | xargs grep -l "apiKey\|API_KEY" 2>/dev/null; then
  check_ok "SDK documentation includes API key usage"
else
  issue_info "No SDK documentation for API keys" \
    "Consider creating SDK with API key examples"
fi

# Check for error message clarity
if grep -rE "Invalid.*API.*key.*format|API.*key.*expired|API.*key.*revoked" app/lib app/api --include="*.ts" 2>/dev/null | grep -q "Invalid\|expired\|revoked"; then
  check_ok "Clear API key error messages found"
else
  issue_warn "Generic error messages" \
    "Provide specific errors: invalid format, expired, revoked, etc."
fi

# ============================================
# 8. Testing Coverage
# ============================================
print_header "8. Testing Coverage"

echo "Checking for API key tests..."

# Check for test files
if ls app/__tests__/*api-key*.test.ts 2>/dev/null | grep -q "api-key"; then
  check_ok "API key test files found"
  
  # Count tests
  test_count=$(grep -r "test\|it(" app/__tests__/*api-key*.test.ts 2>/dev/null | wc -l | tr -d ' ')
  if [[ $test_count -gt 15 ]]; then
    check_ok "Good test coverage ($test_count tests)"
  else
    issue_warn "Limited test coverage ($test_count tests)" \
      "Recommended: 20+ tests covering all scenarios"
  fi
else
  issue_warn "No API key tests found" \
    "Create comprehensive tests for generation, validation, rotation"
fi

# ============================================
# 9. Production Readiness
# ============================================
print_header "9. Production Readiness"

echo "Checking production deployment readiness..."

# Check for environment-specific configs
if grep -rE "NODE_ENV.*production" app/lib --include="*.ts" 2>/dev/null | grep -q "production"; then
  check_ok "Environment-aware code found"
else
  issue_warn "No environment-specific behavior" \
    "Consider different rate limits, expiration for production vs dev"
fi

# Check for monitoring/alerting
if grep -rE "monitor.*apiKey|alert.*apiKey.*fail" app/lib --include="*.ts" 2>/dev/null | grep -q "monitor\|alert"; then
  check_ok "Monitoring/alerting code found"
else
  issue_warn "No monitoring for API key usage" \
    "Monitor: failed validation attempts, usage spikes, expired keys"
fi

# Check for documentation of limits
if grep -iE "rate.*limit.*api|api.*rate.*limit" README.md docs/ 2>/dev/null | grep -q "rate.*limit"; then
  check_ok "Rate limits documented"
else
  issue_warn "Rate limits not documented" \
    "Document API key rate limits for users"
fi

# ============================================
# 10. Quick Fixes (if --fix enabled)
# ============================================
if [[ $FIX == true ]] && [[ $ISSUES_FOUND -gt 0 ]]; then
  print_header "Suggested Fixes"
  
  echo ""
  echo "🔧 Recommended immediate actions:"
  echo ""
  echo "1. Add .env to .gitignore:"
  echo "   echo '.env' >> .gitignore"
  echo ""
  echo "2. Create .env.example with placeholders:"
  echo "   cp .env .env.example"
  echo "   # Then replace real values with placeholders"
  echo ""
  echo "3. Scan git history for leaked keys:"
  echo "   git log --all --full-history -S 'sk-' --source --pretty=format:'%H'"
  echo ""
  echo "4. If keys are compromised, rotate immediately:"
  echo "   # Generate new keys"
  echo "   # Update all services"
  echo "   # Revoke old keys"
  echo ""
fi

# ============================================
# Summary
# ============================================
print_header "Audit Summary"

echo ""
if [[ $ISSUES_FOUND -eq 0 ]]; then
  echo -e "${GREEN}✅ No critical issues found!${NC}"
  echo ""
  echo "Your API key implementation looks secure."
  exit 0
elif [[ $ISSUES_FOUND -le 2 ]]; then
  echo -e "${YELLOW}⚠️  $ISSUES_FOUND issue(s) found${NC}"
  echo ""
  echo "Review warnings above and fix critical issues."
  exit 0
else
  echo -e "${RED}🚨 $ISSUES_FOUND critical issue(s) found!${NC}"
  echo ""
  echo "Fix these issues before deploying to production."
  echo ""
  echo "Run with --fix flag for suggested remediation steps:"
  echo "  ./audit-api-key-usage.sh --fix"
  exit 1
fi





















