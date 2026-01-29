#!/bin/bash

# Pre-Deployment Safety Check Script
# Purpose: Comprehensive safety validation before production deployment
# Usage: ./.cursor/tools/pre-deployment-check.sh
# Related Rules: @203-production-deployment-safety.mdc, @202-vercel-production-gotchas.mdc

set -e

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
    echo -e "${BLUE}  DEPLOYMENT READINESS SUMMARY${NC}"
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
print_header "🚀 PRE-DEPLOYMENT SAFETY CHECK"
echo "Starting comprehensive deployment validation..."
echo "Related Rules: @203-production-deployment-safety.mdc"
echo ""

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. GIT & BRANCH VALIDATION
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "1. Git & Branch Validation"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    check_fail "Not in a git repository"
else
    check_pass "Git repository detected"
fi

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "  Current branch: $CURRENT_BRANCH"

# Check if branch is up to date
git fetch origin > /dev/null 2>&1
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "")
BASE=$(git merge-base @ @{u} 2>/dev/null || echo "")

if [ -z "$REMOTE" ]; then
    check_warning "No upstream branch configured"
elif [ "$LOCAL" = "$REMOTE" ]; then
    check_pass "Branch is up to date with remote"
elif [ "$LOCAL" = "$BASE" ]; then
    check_fail "Branch is behind remote (need to pull)"
elif [ "$REMOTE" = "$BASE" ]; then
    check_warning "Branch has unpushed commits"
else
    check_fail "Branch has diverged from remote"
fi

# Check for uncommitted changes
if git diff-index --quiet HEAD --; then
    check_pass "No uncommitted changes"
else
    check_fail "Uncommitted changes detected"
    echo "    Run: git status"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. BUILD SCRIPT VALIDATION
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "2. Build Script Validation (@204-vercel-build-environment-variables.mdc)"

# Check for dangerous SKIP_* variables in package.json
if grep -q "SKIP_.*=" package.json 2>/dev/null; then
    check_fail "SKIP_* variables found in package.json build scripts"
    echo "    ❌ CRITICAL: Remove SKIP_* variables from package.json"
    echo "    Found:"
    grep "SKIP_.*=" package.json | sed 's/^/      /'
else
    check_pass "No SKIP_* variables in package.json"
fi

if grep -q "DATABASE_SKIP" package.json 2>/dev/null; then
    check_fail "DATABASE_SKIP found in package.json"
    echo "    ❌ CRITICAL: Remove DATABASE_SKIP from package.json"
else
    check_pass "No DATABASE_SKIP in package.json"
fi

# Check for vercel.json with env vars
if [ -f "vercel.json" ]; then
    if grep -q '"env"' vercel.json 2>/dev/null; then
        check_fail "vercel.json sets environment variables"
        echo "    ❌ CRITICAL: Delete vercel.json or remove env section"
        echo "    See: @204-vercel-build-environment-variables.mdc"
    else
        check_pass "vercel.json exists but doesn't set env vars"
    fi
else
    check_pass "No vercel.json file (recommended)"
fi

# Check for NEXT_PHASE usage (dangerous!)
if grep -r "NEXT_PHASE.*phase-production-build" src/ app/ 2>/dev/null; then
    check_fail "NEXT_PHASE used for production logic"
    echo "    ❌ CRITICAL: NEXT_PHASE breaks production!"
    echo "    See: @202-vercel-production-gotchas.mdc"
    echo "    Found in:"
    grep -r "NEXT_PHASE.*phase-production-build" src/ app/ | sed 's/^/      /'
else
    check_pass "No dangerous NEXT_PHASE usage"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. SECURITY CHECKS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "3. Security Checks"

# Run environment variable check
if [ -f "./.cursor/tools/check-env-vars.sh" ]; then
    echo "  Running environment variable security check..."
    if ./.cursor/tools/check-env-vars.sh > /dev/null 2>&1; then
        check_pass "Environment variable security check passed"
    else
        check_fail "Environment variable security check failed"
        echo "    Run: ./.cursor/tools/check-env-vars.sh"
    fi
else
    check_warning "Environment variable check tool not found"
fi

# Run Auth0 configuration check
if [ -f "./.cursor/tools/check-auth-config.sh" ]; then
    echo "  Running Auth0 configuration check..."
    if ./.cursor/tools/check-auth-config.sh > /dev/null 2>&1; then
        check_pass "Auth0 configuration check passed"
    else
        check_fail "Auth0 configuration check failed"
        echo "    Run: ./.cursor/tools/check-auth-config.sh"
    fi
else
    check_warning "Auth0 check tool not found"
fi

# Check for hardcoded secrets
if [ -f "./.cursor/tools/scan-secrets.sh" ]; then
    echo "  Scanning for hardcoded secrets..."
    if ./.cursor/tools/scan-secrets.sh > /dev/null 2>&1; then
        check_pass "No hardcoded secrets detected"
    else
        check_fail "Hardcoded secrets detected"
        echo "    Run: ./.cursor/tools/scan-secrets.sh"
    fi
else
    check_warning "Secret scanning tool not found"
fi

# Check for exposed secrets in recent commits
echo "  Checking recent commits for secrets..."
if git log -1 --pretty=format:%B | grep -iE "password|secret|api_key|token" > /dev/null; then
    check_warning "Potential secrets in commit message"
    echo "    Review commit message for exposed secrets"
else
    check_pass "No secrets in recent commit message"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. DEPENDENCY & BUILD CHECKS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "4. Dependency & Build Checks"

# Check for lockfile
if [ -f "package-lock.json" ]; then
    check_pass "package-lock.json exists"
else
    check_warning "No package-lock.json (using yarn or pnpm?)"
fi

# Check for dependency vulnerabilities
echo "  Auditing dependencies..."
if npm audit --audit-level=high > /dev/null 2>&1; then
    check_pass "No high-severity vulnerabilities"
else
    check_warning "High-severity vulnerabilities found"
    echo "    Run: npm audit"
    echo "    Or: ./.cursor/tools/audit-dependencies.sh"
fi

# Check if node_modules is up to date
if [ -d "node_modules" ]; then
    if [ package.json -nt node_modules ]; then
        check_warning "package.json newer than node_modules"
        echo "    Run: npm install"
    else
        check_pass "Dependencies up to date"
    fi
else
    check_fail "node_modules directory not found"
    echo "    Run: npm install"
fi

# Try to build locally
echo "  Testing local build..."
if npm run build > /dev/null 2>&1; then
    check_pass "Local build successful"
else
    check_fail "Local build failed"
    echo "    Run: npm run build"
    echo "    Fix build errors before deploying"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5. TEST VALIDATION
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "5. Test Validation"

# Check if tests exist
if [ -d "__tests__" ] || [ -d "tests" ] || ls *.test.* 1> /dev/null 2>&1; then
    check_pass "Test files found"
    
    # Run tests
    echo "  Running tests..."
    if npm run test > /dev/null 2>&1; then
        check_pass "All tests passed"
    else
        check_fail "Tests failed"
        echo "    Run: npm run test"
        echo "    Fix failing tests before deploying"
    fi
else
    check_warning "No test files found"
    echo "    Consider adding tests (@300-testing-standards.mdc)"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 6. DATABASE SAFETY
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "6. Database Safety (@208-database-operations.mdc)"

# Check for backup tool
if [ -f "./.cursor/tools/check-backups.sh" ]; then
    echo "  Checking database backups..."
    if ./.cursor/tools/check-backups.sh > /dev/null 2>&1; then
        check_pass "Database backups verified"
    else
        check_warning "Database backup check failed"
        echo "    Run: ./.cursor/tools/check-backups.sh"
    fi
else
    check_warning "Backup check tool not found"
fi

# Check for pending migrations
if [ -d "prisma/migrations" ]; then
    MIGRATION_COUNT=$(find prisma/migrations -type d -mindepth 1 | wc -l)
    if [ "$MIGRATION_COUNT" -gt 0 ]; then
        check_pass "Prisma migrations exist ($MIGRATION_COUNT migrations)"
        
        # Check if migrations are applied
        if npm run prisma:migrate:status > /dev/null 2>&1; then
            check_pass "All migrations applied"
        else
            check_warning "Pending migrations may exist"
            echo "    Verify: npx prisma migrate status"
        fi
    else
        check_warning "No Prisma migrations found"
    fi
else
    check_warning "No prisma/migrations directory"
fi

# Check for Prisma schema
if [ -f "prisma/schema.prisma" ]; then
    check_pass "Prisma schema found"
    
    # Check for uncommitted schema changes
    if [ -f "./.cursor/tools/check-schema-changes.sh" ]; then
        if ./.cursor/tools/check-schema-changes.sh > /dev/null 2>&1; then
            check_pass "No uncommitted schema changes"
        else
            check_fail "Uncommitted Prisma schema changes"
            echo "    ❌ CRITICAL: Commit schema changes and create migration"
            echo "    Run: ./.cursor/tools/check-schema-changes.sh"
        fi
    fi
else
    check_warning "No Prisma schema found"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 7. INFRASTRUCTURE READINESS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "7. Infrastructure Readiness"

# Check for infrastructure tool
if [ -f "./.cursor/tools/check-infrastructure.sh" ]; then
    echo "  Checking infrastructure..."
    if ./.cursor/tools/check-infrastructure.sh > /dev/null 2>&1; then
        check_pass "Infrastructure check passed"
    else
        check_warning "Infrastructure check failed"
        echo "    Run: ./.cursor/tools/check-infrastructure.sh"
    fi
else
    check_warning "Infrastructure check tool not found"
fi

# Check if Vercel CLI is available
if command -v vercel &> /dev/null; then
    check_pass "Vercel CLI available"
    
    # Check Vercel project link
    if [ -f ".vercel/project.json" ]; then
        check_pass "Vercel project linked"
    else
        check_warning "Vercel project not linked"
        echo "    Run: vercel link"
    fi
else
    check_warning "Vercel CLI not installed"
    echo "    Install: npm i -g vercel"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 8. DOCUMENTATION & PROCESS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "8. Documentation & Process"

# Check for deployment guide
if [ -f "guides/Deployment-Workflow-Complete-Guide.md" ]; then
    check_pass "Deployment guide available"
else
    check_warning "Deployment guide not found"
    echo "    See: guides/Deployment-Workflow-Complete-Guide.md"
fi

# Check for rollback procedures
if [ -f ".cursor/rules/202-rollback-procedures.mdc" ]; then
    check_pass "Rollback procedures documented"
else
    check_warning "Rollback procedures not found"
    echo "    See: @202-rollback-procedures.mdc"
fi

# Remind about staging
check_warning "Remember: Deploy to staging first!"
echo "    1. Create PR and get preview deployment"
echo "    2. Test in staging environment"
echo "    3. Get team approval"
echo "    4. Then deploy to production"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SUMMARY
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_summary

# Final decision
if [ $FAILED_CHECKS -gt 0 ]; then
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ❌ DEPLOYMENT NOT RECOMMENDED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "${RED}Fix all failed checks before deploying to production!${NC}\n"
    exit 1
elif [ $WARNING_CHECKS -gt 3 ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  ⚠️  DEPLOYMENT READY WITH WARNINGS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "${YELLOW}Review warnings carefully before deploying.${NC}\n"
    exit 0
else
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ READY FOR DEPLOYMENT${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "${GREEN}All checks passed! Safe to deploy to staging, then production.${NC}\n"
    echo -e "Next steps:"
    echo -e "  1. Deploy to staging: Create PR and test preview"
    echo -e "  2. Run smoke tests in staging"
    echo -e "  3. Get team approval"
    echo -e "  4. Deploy to production: Merge to main"
    echo -e "  5. Monitor: ./.cursor/tools/validate-deployment.sh\n"
    exit 0
fi

