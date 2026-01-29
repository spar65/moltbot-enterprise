#!/usr/bin/env bash
#
# Environment Variables Security Checker
# 
# Purpose: Validate environment variable security practices
# Usage: ./.cursor/tools/check-env-vars.sh
#
# Exit codes:
#   0 - All checks passed
#   1 - Security issues found
#

set -euo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

ISSUES_FOUND=0
WARNINGS_FOUND=0

echo -e "${BLUE}🔐 Environment Variables Security Check${NC}"
echo ""

# Check 1: .env.example should not contain secrets
echo -e "${BLUE}📋 Check 1: Scanning .env.example for secrets...${NC}"
if [ -f ".env.example" ]; then
  # Look for patterns that suggest actual secrets
  if grep -E "(sk_|pk_|_secret|_key|_token|password)" .env.example | grep -v "your-.*-here" | grep -v "REPLACE" | grep -v "EXAMPLE" | grep -v "xxx" > /dev/null 2>&1; then
    echo -e "${RED}❌ FAIL: Potential secrets found in .env.example${NC}"
    echo -e "${YELLOW}   Secrets should use placeholder values like:${NC}"
    echo -e "${YELLOW}   API_KEY=your-api-key-here${NC}"
    echo ""
    grep -n -E "(sk_|pk_|_secret|_key|_token|password)" .env.example | grep -v "your-.*-here" | grep -v "REPLACE" | grep -v "EXAMPLE" | grep -v "xxx" || true
    echo ""
    ((ISSUES_FOUND++))
  else
    echo -e "${GREEN}✅ PASS: No secrets in .env.example${NC}"
  fi
else
  echo -e "${YELLOW}⚠️  WARNING: No .env.example file found${NC}"
  ((WARNINGS_FOUND++))
fi
echo ""

# Check 2: Scan for hardcoded secrets in code
echo -e "${BLUE}📋 Check 2: Scanning code for hardcoded secrets...${NC}"
SECRET_PATTERNS=(
  "sk_test_[a-zA-Z0-9]+"
  "sk_live_[a-zA-Z0-9]+"
  "pk_test_[a-zA-Z0-9]+"
  "pk_live_[a-zA-Z0-9]+"
  "Bearer [a-zA-Z0-9_-]{20,}"
  "api[_-]?key['\"]?\s*[:=]\s*['\"][a-zA-Z0-9]{20,}"
)

found_secrets=false
for pattern in "${SECRET_PATTERNS[@]}"; do
  if grep -r -E "$pattern" app/app app/lib --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null | grep -v "node_modules" | grep -v ".next" > /tmp/secrets.txt 2>&1; then
    if [ -s /tmp/secrets.txt ]; then
      found_secrets=true
      echo -e "${RED}❌ FAIL: Hardcoded secrets detected!${NC}"
      echo ""
      head -10 /tmp/secrets.txt
      echo ""
      ((ISSUES_FOUND++))
    fi
  fi
done

if [ "$found_secrets" = false ]; then
  echo -e "${GREEN}✅ PASS: No hardcoded secrets detected${NC}"
fi
rm -f /tmp/secrets.txt
echo ""

# Check 3: Client vs Server environment variable separation
echo -e "${BLUE}📋 Check 3: Checking client/server env var separation...${NC}"
if [ -d "app/app" ]; then
  # Check for server-only vars used in client code
  if grep -r "process\.env\." app/app --include="*.tsx" --include="*.jsx" | grep -v "NEXT_PUBLIC_" | grep -v "node_modules" > /tmp/client_env.txt 2>&1; then
    if [ -s /tmp/client_env.txt ]; then
      echo -e "${RED}❌ FAIL: Server-only env vars used in client code!${NC}"
      echo -e "${YELLOW}   Client code should only use NEXT_PUBLIC_* variables${NC}"
      echo ""
      head -10 /tmp/client_env.txt
      echo ""
      ((ISSUES_FOUND++))
    fi
  else
    echo -e "${GREEN}✅ PASS: Proper client/server env var separation${NC}"
  fi
  rm -f /tmp/client_env.txt
else
  echo -e "${YELLOW}⚠️  WARNING: Could not find app directory${NC}"
  ((WARNINGS_FOUND++))
fi
echo ""

# Check 4: .env file should be in .gitignore
echo -e "${BLUE}📋 Check 4: Checking .gitignore for .env files...${NC}"
if [ -f ".gitignore" ]; then
  if grep -q "^\.env$\|^\.env\.local$" .gitignore; then
    echo -e "${GREEN}✅ PASS: .env files in .gitignore${NC}"
  else
    echo -e "${RED}❌ FAIL: .env files not properly ignored!${NC}"
    echo -e "${YELLOW}   Add to .gitignore:${NC}"
    echo -e "${YELLOW}   .env${NC}"
    echo -e "${YELLOW}   .env.local${NC}"
    echo ""
    ((ISSUES_FOUND++))
  fi
else
  echo -e "${RED}❌ FAIL: No .gitignore file found!${NC}"
  ((ISSUES_FOUND++))
fi
echo ""

# Check 5: Check for committed .env files
echo -e "${BLUE}📋 Check 5: Checking for committed .env files...${NC}"
if git ls-files | grep -E "^\.env$|^\.env\.local$" > /dev/null 2>&1; then
  echo -e "${RED}❌ FAIL: .env files are committed to git!${NC}"
  echo -e "${YELLOW}   Run: git rm --cached .env${NC}"
  echo ""
  ((ISSUES_FOUND++))
else
  echo -e "${GREEN}✅ PASS: No .env files committed${NC}"
fi
echo ""

# Check 6: Validate environment variable documentation
echo -e "${BLUE}📋 Check 6: Checking environment variable documentation...${NC}"
if [ -f ".env.example" ] && [ -f "README.md" ]; then
  if grep -q "environment variable\|Environment Variable\|\.env" README.md; then
    echo -e "${GREEN}✅ PASS: Environment variables documented${NC}"
  else
    echo -e "${YELLOW}⚠️  WARNING: Environment variables not documented in README${NC}"
    ((WARNINGS_FOUND++))
  fi
else
  echo -e "${YELLOW}⚠️  WARNING: Missing .env.example or README.md${NC}"
  ((WARNINGS_FOUND++))
fi
echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  ENVIRONMENT VARIABLES SECURITY SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

if [ $ISSUES_FOUND -eq 0 ]; then
  echo -e "${GREEN}✅ All security checks passed!${NC}"
  echo ""
  if [ $WARNINGS_FOUND -gt 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS_FOUND warning(s) found (non-blocking)${NC}"
  fi
  exit 0
else
  echo -e "${RED}❌ $ISSUES_FOUND security issue(s) found!${NC}"
  echo ""
  echo -e "${YELLOW}📋 Remediation Steps:${NC}"
  echo ""
  echo "  1. Remove any hardcoded secrets from code"
  echo "  2. Use environment variables for all secrets"
  echo "  3. Keep .env files in .gitignore"
  echo "  4. Use NEXT_PUBLIC_* prefix for client-side variables only"
  echo "  5. Document all required environment variables"
  echo ""
  echo -e "${BLUE}📚 See Also:${NC}"
  echo "  - Rule 011: env-var-security.mdc"
  echo "  - .cursor/docs/security-workflows.md"
  echo ""
  exit 1
fi

