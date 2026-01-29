#!/usr/bin/env bash
#
# verify-infrastructure-reality.sh
# 
# Purpose: Verify actual infrastructure configuration matches documentation
# Usage: ./.cursor/tools/verify-infrastructure-reality.sh [--detailed]
#
# Exit codes:
#   0 - Infrastructure matches documentation (or gaps documented)
#   1 - Critical gaps found that need immediate attention
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DETAILED=false
if [[ "${1:-}" == "--detailed" ]]; then
  DETAILED=true
fi

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0
GAPS_FOUND=0

# Functions
print_header() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  🔍 INFRASTRUCTURE REALITY VERIFICATION${NC}"
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
  GAPS_FOUND=$((GAPS_FOUND + 1))
  echo -e "  ${RED}✗${NC} $1"
}

check_warning() {
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  WARNING_CHECKS=$((WARNING_CHECKS + 1))
  echo -e "  ${YELLOW}⚠${NC} $1"
}

print_summary() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  VERIFICATION SUMMARY${NC}"
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
  
  if [ $GAPS_FOUND -gt 0 ]; then
    echo -e "  ${RED}⚠️  $GAPS_FOUND gap(s) found between documentation and reality${NC}"
    echo -e "  ${YELLOW}Action: Review gaps and either fix infrastructure or update documentation${NC}"
    echo ""
    echo -e "  See: docs/DEPLOYMENT-INFRASTRUCTURE-GAPS.md"
    echo -e "  See: guides/Infrastructure-Verification-Guide.md"
    echo ""
  else
    echo -e "  ${GREEN}✅ No gaps found - infrastructure matches documentation!${NC}"
  fi
}

# Start
print_header
echo "Verifying actual infrastructure configuration matches documentation..."
echo "Related Rule: @207-infrastructure-verification.mdc"
echo ""

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. CI/CD PIPELINE VERIFICATION
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "1. CI/CD Pipeline Verification"

# Check if CI/CD workflow exists
if [ -f ".github/workflows/ci-cd.yml" ]; then
  check_pass "CI/CD workflow exists (.github/workflows/ci-cd.yml)"
else
  # Check if it's documented
  if grep -q "ci-cd.yml\|CI/CD pipeline" guides/Deployment-Workflow-Complete-Guide.md 2>/dev/null || \
     grep -q "ci-cd.yml\|CI/CD pipeline" .cursor/rules/203-ci-cd-pipeline-standards.mdc 2>/dev/null; then
    check_fail "CI/CD pipeline documented but NOT implemented"
    echo "    Documentation references CI/CD, but .github/workflows/ci-cd.yml doesn't exist"
    echo "    Action: Create CI/CD pipeline or document that deployments are manual"
  else
    check_warning "CI/CD pipeline not documented (may be intentional)"
  fi
fi

# Check schema validation workflow (should exist)
if [ -f ".github/workflows/schema-validation.yml" ]; then
  check_pass "Schema validation workflow exists"
else
  check_warning "Schema validation workflow missing"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. ENVIRONMENT VARIABLES VERIFICATION
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "2. Environment Variables Verification"

# Check if Vercel CLI is available
if command -v vercel &> /dev/null; then
  # Try to list environment variables
  if vercel env ls &> /dev/null; then
    check_pass "Vercel CLI configured (can check env vars)"
    echo "    Run 'vercel env ls' to verify all required variables are set"
    echo "    Required vars: DATABASE_URL, AUTH_SECRET, AUTH_URL, ANTHROPIC_API_KEY"
  else
    check_warning "Vercel CLI not authenticated (run 'vercel login')"
  fi
else
  check_warning "Vercel CLI not installed (cannot verify env vars)"
  echo "    Install: npm i -g vercel"
  echo "    Then run: vercel env ls"
fi

# Check for .env.example or documentation
if [ -f "env.example" ] || [ -f ".env.example" ]; then
  check_pass "Environment variable template exists"
else
  check_warning "No .env.example file found"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. DEPLOYMENT TOOLS VERIFICATION
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "3. Deployment Tools Verification"

# Check pre-deployment tool
if [ -f ".cursor/tools/pre-deployment-check.sh" ]; then
  if bash ./.cursor/tools/pre-deployment-check.sh &> /dev/null; then
    check_pass "pre-deployment-check.sh exists and runs"
  else
    check_warning "pre-deployment-check.sh exists but has issues (run manually to see errors)"
  fi
else
  check_fail "pre-deployment-check.sh missing (documented but not found)"
fi

# Check validate-deployment tool
if [ -f ".cursor/tools/validate-deployment.sh" ]; then
  check_pass "validate-deployment.sh exists"
else
  check_fail "validate-deployment.sh missing (documented but not found)"
fi

# Check infrastructure check tool
if [ -f ".cursor/tools/check-infrastructure.sh" ]; then
  check_pass "check-infrastructure.sh exists"
else
  check_warning "check-infrastructure.sh missing"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. MONITORING VERIFICATION
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "4. Monitoring Configuration Verification"

# Check if monitoring is documented
if grep -q "monitoring\|analytics\|error tracking" guides/Deployment-Workflow-Complete-Guide.md 2>/dev/null || \
   grep -q "monitoring\|analytics" .cursor/rules/221-application-monitoring.mdc 2>/dev/null; then
  check_warning "Monitoring is documented - verify it's actually configured in Vercel Dashboard"
  echo "    Check: Vercel Dashboard → Analytics → Is it enabled?"
  echo "    Check: Error tracking (Sentry, etc.) → Is it configured?"
else
  check_warning "Monitoring not documented (may be intentional)"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5. SECURITY CONFIGURATION VERIFICATION
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "5. Security Configuration Verification"

# Check if security is documented
if grep -q "WAF\|Advanced Protection\|rate limiting" guides/Vercel-Deployment-Guide.md 2>/dev/null; then
  check_warning "Security features documented - verify they're enabled in Vercel Dashboard"
  echo "    Check: Vercel Dashboard → Security → Advanced Protection"
  echo "    Check: Rate limiting configured?"
  echo "    Check: Bot protection enabled?"
else
  check_warning "Security configuration not documented"
fi

# Check next.config.ts for security headers
if [ -f "next.config.ts" ] || [ -f "next.config.js" ]; then
  CONFIG_FILE="next.config.ts"
  [ -f "next.config.js" ] && CONFIG_FILE="next.config.js"
  
  if grep -q "headers\|security" "$CONFIG_FILE" 2>/dev/null; then
    check_pass "Security headers configured in next.config"
  else
    check_warning "No security headers found in next.config"
  fi
else
  check_warning "next.config.ts/js not found"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 6. VERCEL STRUCTURAL COMPATIBILITY CHECK
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "6. Vercel Structural Compatibility Check"

# Check for nested Next.js structure (common Vercel issue)
if [ -d "app/app" ] || [ -d "app/pages" ]; then
  check_fail "Nested Next.js structure detected (app/app or app/pages)"
  echo "    ⚠️  This structure often causes 404 errors on Vercel"
  echo "    Action: Flatten structure (move Next.js to root) or verify Root Directory setting"
fi

# Check for multiple vercel.json files
VERCEL_JSON_COUNT=$(find . -name "vercel.json" -not -path "./node_modules/*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$VERCEL_JSON_COUNT" -gt 1 ]; then
  check_fail "$VERCEL_JSON_COUNT vercel.json file(s) found (conflicts with Root Directory)"
  echo "    ⚠️  Multiple vercel.json files can cause Vercel configuration conflicts"
  echo "    Action: Remove redundant vercel.json files or consolidate"
  if [ "$DETAILED" = true ]; then
    echo "    Files found:"
    find . -name "vercel.json" -not -path "./node_modules/*" 2>/dev/null
  fi
elif [ "$VERCEL_JSON_COUNT" -eq 1 ]; then
  check_warning "vercel.json exists - verify it doesn't conflict with Root Directory setting"
  echo "    If using Root Directory setting, consider removing vercel.json"
else
  check_pass "No vercel.json files (using Root Directory setting - recommended)"
fi

# Check if Next.js is at root (preferred structure)
if [ -f "package.json" ] && [ -d "app" ] && [ ! -d "app/app" ]; then
  check_pass "Next.js structure is flat (app/ at root - recommended)"
elif [ -f "package.json" ] && [ -d "app/app" ]; then
  check_fail "Nested Next.js structure detected (app/app/)"
  echo "    ⚠️  This structure causes routing issues on Vercel"
  echo "    Action: Flatten to app/ at root or verify Root Directory = 'app'"
else
  check_warning "Could not verify Next.js structure"
fi

# Check middleware for Edge Runtime incompatibilities
if [ -f "app/middleware.ts" ] || [ -f "middleware.ts" ]; then
  MIDDLEWARE_FILE="app/middleware.ts"
  [ -f "middleware.ts" ] && MIDDLEWARE_FILE="middleware.ts"
  
  if grep -q "import.*from.*['\"]fs['\"]\|import.*from.*['\"]path['\"]" "$MIDDLEWARE_FILE" 2>/dev/null; then
    check_fail "Middleware uses Node.js modules (fs, path) - incompatible with Edge Runtime"
    echo "    ⚠️  This will cause MIDDLEWARE_INVOCATION_FAILED on Vercel"
    echo "    Action: Remove Node.js module imports from middleware"
  else
    check_pass "Middleware appears Edge-compatible"
  fi
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 7. STRUCTURAL CONSISTENCY CHECK (Path References)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "7. Structural Consistency Check (Path References)"

# Check for old path references that might break things
OLD_PATH_REFS=$(grep -rn "cd app\|working-directory.*app\|app/package\|app/prisma" \
  --include="*.{sh,yml,yaml}" \
  .github/workflows/ \
  .cursor/tools/ \
  scripts/ \
  2>/dev/null | grep -v node_modules | grep -v ".next" | wc -l || echo "0")

if [ "$OLD_PATH_REFS" -gt 0 ]; then
  check_warning "$OLD_PATH_REFS file(s) still reference 'app/' paths"
  if [ "$DETAILED" = true ]; then
    echo "    Files with 'app/' references:"
    grep -rn "cd app\|working-directory.*app\|app/package\|app/prisma" \
      --include="*.{sh,yml,yaml}" \
      .github/workflows/ \
      .cursor/tools/ \
      scripts/ \
      2>/dev/null | grep -v node_modules | head -10
  fi
  echo "    Action: Review and update if structure was flattened"
else
  check_pass "No old path references found in critical files"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 7. DOCUMENTATION GAP CHECK
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "7. Documentation Gap Detection"

# Check if gap analysis document exists
if [ -f "docs/DEPLOYMENT-INFRASTRUCTURE-GAPS.md" ]; then
  check_pass "Gap analysis document exists"
  echo "    Review: docs/DEPLOYMENT-INFRASTRUCTURE-GAPS.md"
else
  check_warning "No gap analysis document found"
  echo "    Consider creating: docs/DEPLOYMENT-INFRASTRUCTURE-GAPS.md"
fi

# Summary
print_summary

# Exit code
if [ $FAILED_CHECKS -gt 0 ]; then
  exit 1
else
  exit 0
fi
