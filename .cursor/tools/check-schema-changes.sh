#!/usr/bin/env bash
#
# Schema Change Detection Script
# 
# Purpose: Detect uncommitted Prisma schema changes and alert developers
# Usage: ./scripts/check-schema-changes.sh
# CI/CD: Run as pre-commit hook or GitHub Action
#
# Exit codes:
#   0 - No uncommitted schema changes
#   1 - Schema has uncommitted changes (requires action)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Checking for Prisma schema changes...${NC}"
echo ""

# Check if prisma/schema.prisma exists
if [ ! -f "prisma/schema.prisma" ]; then
  echo -e "${RED}❌ ERROR: prisma/schema.prisma not found!${NC}"
  echo "   Run this script from the project root directory."
  exit 1
fi

# Check if git is available
if ! command -v git &> /dev/null; then
  echo -e "${YELLOW}⚠️  WARNING: Git not found. Skipping schema change detection.${NC}"
  exit 0
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo -e "${YELLOW}⚠️  WARNING: Not a git repository. Skipping schema change detection.${NC}"
  exit 0
fi

# Check for uncommitted changes to schema
if git diff --name-only | grep -q "prisma/schema.prisma"; then
  echo -e "${YELLOW}⚠️  WARNING: Prisma schema has uncommitted changes!${NC}"
  echo ""
  echo -e "${BLUE}📋 Changed fields:${NC}"
  echo ""
  
  # Show the actual changes
  git diff prisma/schema.prisma | grep "^[+-]" | grep -v "^[+-][+-][+-]" | head -20
  
  echo ""
  echo -e "${RED}🔧 REQUIRED ACTIONS:${NC}"
  echo ""
  echo "  1. Review schema changes above"
  echo "  2. Run: ${BLUE}npx prisma generate${NC} (regenerate types)"
  echo "  3. Update tests to match new schema"
  echo "  4. Update design docs if needed"
  echo "  5. Commit schema.prisma with your changes"
  echo ""
  echo -e "${YELLOW}💡 TIP: Run this to see full diff:${NC}"
  echo "   ${BLUE}git diff prisma/schema.prisma${NC}"
  echo ""
  
  exit 1
fi

# Check for staged schema changes
if git diff --cached --name-only | grep -q "prisma/schema.prisma"; then
  echo -e "${GREEN}✅ Schema changes are staged (ready to commit)${NC}"
  echo ""
  echo -e "${BLUE}📋 Staged changes:${NC}"
  echo ""
  
  git diff --cached prisma/schema.prisma | grep "^[+-]" | grep -v "^[+-][+-][+-]" | head -20
  
  echo ""
  echo -e "${BLUE}🔍 Verification checklist:${NC}"
  echo "  [ ] Ran 'npx prisma generate'?"
  echo "  [ ] Updated tests to use new field names?"
  echo "  [ ] Updated design docs?"
  echo "  [ ] Tests passing?"
  echo ""
  
  exit 0
fi

# No uncommitted changes
echo -e "${GREEN}✅ No uncommitted schema changes detected${NC}"
echo ""

exit 0

