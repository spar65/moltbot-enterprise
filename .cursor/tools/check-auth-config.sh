#!/usr/bin/env bash
#
# Authentication Configuration Checker
# 
# Purpose: Validate Auth0 and authentication setup
# Usage: ./.cursor/tools/check-auth-config.sh
#
# Exit codes:
#   0 - Configuration valid
#   1 - Configuration issues found
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

echo -e "${BLUE}🔐 Authentication Configuration Check${NC}"
echo ""

# Check 1: Required Auth0 environment variables
echo -e "${BLUE}📋 Check 1: Checking Auth0 environment variables...${NC}"

REQUIRED_AUTH_VARS=(
  "AUTH0_SECRET"
  "AUTH0_BASE_URL"
  "AUTH0_ISSUER_BASE_URL"
  "AUTH0_CLIENT_ID"
  "AUTH0_CLIENT_SECRET"
)

missing_vars=()
for var in "${REQUIRED_AUTH_VARS[@]}"; do
  if [ -f "app/.env.local" ]; then
    if ! grep -q "^$var=" app/.env.local 2>/dev/null; then
      missing_vars+=("$var")
    fi
  elif [ -f "app/.env" ]; then
    if ! grep -q "^$var=" app/.env 2>/dev/null; then
      missing_vars+=("$var")
    fi
  fi
done

if [ ${#missing_vars[@]} -eq 0 ]; then
  echo -e "${GREEN}✅ PASS: All required Auth0 variables present${NC}"
else
  echo -e "${RED}❌ FAIL: Missing Auth0 variables:${NC}"
  for var in "${missing_vars[@]}"; do
    echo -e "${YELLOW}   - $var${NC}"
  done
  echo ""
  ((ISSUES_FOUND++))
fi
echo ""

# Check 2: AUTH0_SECRET strength
echo -e "${BLUE}📋 Check 2: Checking AUTH0_SECRET strength...${NC}"

if [ -f "app/.env.local" ] || [ -f "app/.env" ]; then
  env_file="app/.env.local"
  [ ! -f "$env_file" ] && env_file="app/.env"
  
  if grep -q "^AUTH0_SECRET=" "$env_file"; then
    secret=$(grep "^AUTH0_SECRET=" "$env_file" | cut -d= -f2 | tr -d '"' | tr -d "'")
    secret_length=${#secret}
    
    if [ $secret_length -lt 32 ]; then
      echo -e "${RED}❌ FAIL: AUTH0_SECRET too short ($secret_length chars)${NC}"
      echo -e "${YELLOW}   Minimum: 32 characters${NC}"
      echo -e "${BLUE}💡 Generate: openssl rand -hex 32${NC}"
      echo ""
      ((ISSUES_FOUND++))
    else
      echo -e "${GREEN}✅ PASS: AUTH0_SECRET has sufficient length${NC}"
    fi
  else
    echo -e "${YELLOW}⚠️  WARNING: AUTH0_SECRET not found${NC}"
    ((WARNINGS_FOUND++))
  fi
else
  echo -e "${YELLOW}⚠️  WARNING: No .env file found${NC}"
  ((WARNINGS_FOUND++))
fi
echo ""

# Check 3: Check for Auth0 secrets in client code
echo -e "${BLUE}📋 Check 3: Scanning for Auth0 secrets in client code...${NC}"

if [ -d "app/app" ]; then
  if grep -r "AUTH0_CLIENT_SECRET\|AUTH0_SECRET" app/app --include="*.tsx" --include="*.jsx" 2>/dev/null; then
    echo -e "${RED}❌ FAIL: Auth0 secrets exposed in client code!${NC}"
    echo -e "${YELLOW}   Server-only secrets must not be in client components${NC}"
    echo ""
    ((ISSUES_FOUND++))
  else
    echo -e "${GREEN}✅ PASS: No Auth0 secrets in client code${NC}"
  fi
else
  echo -e "${YELLOW}⚠️  WARNING: Could not find app directory${NC}"
  ((WARNINGS_FOUND++))
fi
echo ""

# Check 4: Validate callback URLs configuration
echo -e "${BLUE}📋 Check 4: Checking callback URL configuration...${NC}"

if [ -f "app/.env.local" ] || [ -f "app/.env" ]; then
  env_file="app/.env.local"
  [ ! -f "$env_file" ] && env_file="app/.env"
  
  if grep -q "^AUTH0_BASE_URL=" "$env_file"; then
    base_url=$(grep "^AUTH0_BASE_URL=" "$env_file" | cut -d= -f2 | tr -d '"' | tr -d "'")
    
    if [[ "$base_url" == "http://localhost"* ]]; then
      echo -e "${YELLOW}⚠️  WARNING: Using localhost URL (development only)${NC}"
      ((WARNINGS_FOUND++))
    elif [[ "$base_url" == "https://"* ]]; then
      echo -e "${GREEN}✅ PASS: Using HTTPS for base URL${NC}"
    else
      echo -e "${RED}❌ FAIL: Invalid base URL format${NC}"
      echo -e "${YELLOW}   Should be: https://yourdomain.com${NC}"
      ((ISSUES_FOUND++))
    fi
  else
    echo -e "${YELLOW}⚠️  WARNING: AUTH0_BASE_URL not configured${NC}"
    ((WARNINGS_FOUND++))
  fi
fi
echo ""

# Check 5: Check for Auth0 SDK version
echo -e "${BLUE}📋 Check 5: Checking Auth0 SDK version...${NC}"

if [ -f "app/package.json" ]; then
  if grep -q "@auth0/nextjs-auth0" app/package.json; then
    version=$(grep "@auth0/nextjs-auth0" app/package.json | sed 's/.*: "[\^~]*//' | sed 's/".*//')
    echo -e "${GREEN}✅ Auth0 SDK installed: v$version${NC}"
    
    # Check if major version is at least 3
    major_version=$(echo "$version" | cut -d. -f1)
    if [ "$major_version" -lt 3 ]; then
      echo -e "${YELLOW}⚠️  WARNING: Auth0 SDK v$version is outdated${NC}"
      echo -e "${BLUE}💡 Consider upgrading to latest version${NC}"
      ((WARNINGS_FOUND++))
    fi
  else
    echo -e "${YELLOW}⚠️  WARNING: Auth0 SDK not found in package.json${NC}"
    ((WARNINGS_FOUND++))
  fi
else
  echo -e "${YELLOW}⚠️  WARNING: package.json not found${NC}"
  ((WARNINGS_FOUND++))
fi
echo ""

# Check 6: Session cookie configuration
echo -e "${BLUE}📋 Check 6: Checking session configuration...${NC}"

if [ -f "app/lib/auth0.ts" ] || [ -f "app/lib/auth.ts" ]; then
  auth_file=$([ -f "app/lib/auth0.ts" ] && echo "app/lib/auth0.ts" || echo "app/lib/auth.ts")
  
  if grep -q "cookie.*secure.*true" "$auth_file" 2>/dev/null; then
    echo -e "${GREEN}✅ PASS: Secure cookie flag enabled${NC}"
  else
    echo -e "${YELLOW}⚠️  WARNING: Secure cookie flag not explicitly set${NC}"
    echo -e "${BLUE}💡 Ensure cookies are secure in production${NC}"
    ((WARNINGS_FOUND++))
  fi
else
  echo -e "${YELLOW}⚠️  WARNING: Auth configuration file not found${NC}"
  ((WARNINGS_FOUND++))
fi
echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  AUTHENTICATION CONFIGURATION SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

if [ $ISSUES_FOUND -eq 0 ]; then
  echo -e "${GREEN}✅ All critical checks passed!${NC}"
  echo ""
  if [ $WARNINGS_FOUND -gt 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS_FOUND warning(s) found (non-blocking)${NC}"
    echo ""
    echo -e "${BLUE}💡 Recommendations:${NC}"
    echo "  - Review warnings above"
    echo "  - Keep Auth0 SDK updated"
    echo "  - Use HTTPS in production"
  fi
  exit 0
else
  echo -e "${RED}❌ $ISSUES_FOUND critical issue(s) found!${NC}"
  echo ""
  echo -e "${YELLOW}🚨 REQUIRED ACTIONS:${NC}"
  echo ""
  echo "  1. Add missing Auth0 environment variables"
  echo "  2. Ensure AUTH0_SECRET is at least 32 characters"
  echo "  3. Remove any Auth0 secrets from client code"
  echo "  4. Configure proper callback URLs"
  echo "  5. Test authentication flow"
  echo ""
  echo -e "${BLUE}📚 See Also:${NC}"
  echo "  - Rule 014: third-party-auth.mdc"
  echo "  - Rule 019: auth0-integration.mdc"
  echo "  - Rule 046: session-validation.mdc"
  echo "  - .cursor/docs/security-workflows.md#authentication"
  echo ""
  exit 1
fi

