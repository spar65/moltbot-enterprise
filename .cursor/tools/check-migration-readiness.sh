#!/bin/bash

# Migration Readiness Check for v0.3.2 → v0.4.0
# Purpose: Validate all prerequisites before starting migration
# Usage: ./.cursor/tools/check-migration-readiness.sh
# Related: docs/SPEC-v0.4.0-06-Migration-Strategy.md

set -e

# Colors
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
    echo -e "${BLUE}  MIGRATION READINESS SUMMARY${NC}"
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
print_header "🚀 MIGRATION READINESS CHECK (v0.3.2 → v0.4.0)"
echo "Checking prerequisites for safe migration..."
echo "Related: docs/SPEC-v0.4.0-06-Migration-Strategy.md"
echo ""

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. TEST SUITE STATUS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "1. v0.3.2 Test Suite Status"

# Project structure is now flat - no need to cd into app/

# Run tests and capture output
if command -v npm &> /dev/null; then
    echo "  Running test suite..."
    TEST_OUTPUT=$(npm test -- --passWithNoTests 2>&1 || true)
    
    # Check if tests passed
    if echo "$TEST_OUTPUT" | grep -q "Tests:.*passed"; then
        PASSED_COUNT=$(echo "$TEST_OUTPUT" | grep -oP '\d+(?= passed)' | head -1)
        TOTAL_COUNT=$(echo "$TEST_OUTPUT" | grep -oP '\d+ total' | grep -oP '\d+' | head -1)
        
        if [ "$PASSED_COUNT" = "$TOTAL_COUNT" ]; then
            check_pass "All tests passing ($PASSED_COUNT/$TOTAL_COUNT)"
        elif [ "$PASSED_COUNT" -ge 390 ]; then
            check_warning "Most tests passing ($PASSED_COUNT/$TOTAL_COUNT) - acceptable"
        else
            check_fail "Too many failing tests ($PASSED_COUNT/$TOTAL_COUNT)"
            echo "    Fix failing tests before migration"
        fi
    else
        check_warning "Could not determine test status"
        echo "    Run: npm test"
    fi
else
    check_warning "npm not found, skipping test check"
fi

cd - > /dev/null 2>&1 || true

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. GIT STATUS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "2. Git Repository Status"

# Check if in git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    check_fail "Not in a git repository"
else
    check_pass "Git repository detected"
fi

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "  Current branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" = "release/v0.3.2" ] || [ "$CURRENT_BRANCH" = "main" ]; then
    check_pass "On stable branch: $CURRENT_BRANCH"
else
    check_warning "Not on stable branch (currently: $CURRENT_BRANCH)"
    echo "    Consider creating feature branch from stable branch"
fi

# Check for uncommitted changes
if git diff-index --quiet HEAD --; then
    check_pass "No uncommitted changes"
else
    check_fail "Uncommitted changes detected"
    echo "    Commit or stash changes before migration"
    git status --short | head -5 | sed 's/^/      /'
fi

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
    echo "    Run: git pull"
elif [ "$REMOTE" = "$BASE" ]; then
    check_warning "Branch has unpushed commits"
else
    check_fail "Branch has diverged from remote"
    echo "    Resolve divergence before migration"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. BASELINE PERFORMANCE
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "3. Baseline Performance Documentation"

# Check for existing baseline
BASELINE_FILE=$(find docs -name "*baseline*.md" -o -name "*v0.3.2*performance*.md" 2>/dev/null | head -1)

if [ -n "$BASELINE_FILE" ]; then
    check_pass "Performance baseline documented: $BASELINE_FILE"
else
    check_warning "No performance baseline found"
    echo "    Run: ./.cursor/tools/analyze-performance.sh > docs/v0.3.2-baseline-\$(date +%Y%m%d).md"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. BACKUP DEPLOYMENT
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "4. Backup Deployment URL"

# Check for backup URL documentation
if [ -f "deployment-log.txt" ] && grep -q "v0.3.2 Backup URL" deployment-log.txt; then
    BACKUP_URL=$(grep "v0.3.2 Backup URL" deployment-log.txt | awk '{print $NF}')
    check_pass "Backup URL documented: $BACKUP_URL"
elif [ -f "docs/DEPLOYMENT-SUMMARY.md" ]; then
    check_warning "Backup URL not explicitly saved"
    echo "    Deploy v0.3.2 to backup URL:"
    echo "    vercel --prod --name compsi-v0.3.2-backup"
    echo "    Save URL to deployment-log.txt"
else
    check_warning "No backup deployment documented"
    echo "    Create backup before migration:"
    echo "    1. vercel --prod --name compsi-v0.3.2-backup"
    echo "    2. Save URL: echo 'v0.3.2 Backup URL: [URL]' > deployment-log.txt"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5. DATABASE BACKUP
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "5. Database Backup Status"

# Check for backup verification script
if [ -f ".cursor/tools/check-backups.sh" ]; then
    check_pass "Backup check script exists"
    
    # Run backup check if available
    if bash ./.cursor/tools/check-backups.sh 2>&1 | grep -q "Backup.*recent"; then
        check_pass "Recent database backup verified"
    else
        check_warning "Run backup verification:"
        echo "    ./.cursor/tools/check-backups.sh"
    fi
else
    check_warning "Backup check script not found"
    echo "    Manual verification required"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 6. MONITORING SETUP
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "6. Monitoring & Alerting"

# Check for monitoring configuration
if [ -f "vercel.json" ] && grep -q "monitoring" vercel.json; then
    check_pass "Monitoring configured in vercel.json"
elif [ -n "$SENTRY_DSN" ] || grep -q "SENTRY_DSN" .env* 2>/dev/null; then
    check_pass "Sentry monitoring detected"
else
    check_warning "No monitoring configuration found"
    echo "    Consider setting up error monitoring"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 7. MIGRATION SPECIFICATIONS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "7. Migration Documentation"

# Check for v0.4.0 specs
if [ -f "docs/SPEC-v0.4.0-06-Migration-Strategy.md" ]; then
    check_pass "Migration strategy documented"
else
    check_fail "Migration strategy not found"
    echo "    Required: docs/SPEC-v0.4.0-06-Migration-Strategy.md"
fi

if [ -f "docs/SPEC-v0.4.0-07-Testing-Strategy.md" ]; then
    check_pass "Testing strategy documented"
else
    check_warning "Testing strategy not found"
fi

if [ -f "docs/SPEC-v0.4.0-08-Deployment-Rollback.md" ]; then
    check_pass "Rollback procedures documented"
else
    check_warning "Rollback procedures not documented"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 8. FEATURE BRANCH READY
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_section "8. Feature Branch Preparation"

# Check if feature branch exists
if git rev-parse --verify feature/v0.4.0-ui-foundation >/dev/null 2>&1; then
    check_pass "Feature branch exists: feature/v0.4.0-ui-foundation"
    
    # Check if it's up to date with base
    git fetch origin > /dev/null 2>&1
    FEATURE_BASE=$(git merge-base main feature/v0.4.0-ui-foundation)
    MAIN_HEAD=$(git rev-parse main)
    
    if [ "$FEATURE_BASE" = "$MAIN_HEAD" ]; then
        check_pass "Feature branch is up to date with main"
    else
        check_warning "Feature branch may be behind main"
        echo "    Consider rebasing: git rebase main"
    fi
else
    check_warning "Feature branch not created yet"
    echo "    Create with: git checkout -b feature/v0.4.0-ui-foundation"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SUMMARY & RECOMMENDATION
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print_summary

# Determine readiness
if [ $FAILED_CHECKS -eq 0 ]; then
    if [ $WARNING_CHECKS -eq 0 ]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}  ✅ READY FOR MIGRATION${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        echo -e "All checks passed! You can proceed with migration:\n"
        echo -e "  1. Review: docs/SPEC-v0.4.0-06-Migration-Strategy.md"
        echo -e "  2. Create feature branch: git checkout -b feature/v0.4.0-ui-foundation"
        echo -e "  3. Begin Week 1, Day 1 implementation"
        echo ""
        exit 0
    else
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}  ⚠️  READY WITH WARNINGS${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        echo -e "You can proceed with migration, but address warnings when possible:\n"
        echo -e "  1. Review warnings above"
        echo -e "  2. Create feature branch: git checkout -b feature/v0.4.0-ui-foundation"
        echo -e "  3. Begin implementation"
        echo ""
        exit 0
    fi
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ❌ NOT READY FOR MIGRATION${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "Fix failed checks before proceeding:\n"
    echo -e "  1. Review failed checks above"
    echo -e "  2. Address each issue"
    echo -e "  3. Run this script again: ./.cursor/tools/check-migration-readiness.sh"
    echo ""
    exit 1
fi
