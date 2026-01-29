#!/usr/bin/env bash
#
# Dependency Security Auditor
# 
# Purpose: Check for security vulnerabilities and outdated packages
# Usage: ./.cursor/tools/audit-dependencies.sh
#
# Exit codes:
#   0 - No critical issues
#   1 - Critical vulnerabilities found
#

set -euo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

CRITICAL_FOUND=0
HIGH_FOUND=0

echo -e "${BLUE}🔍 Dependency Security Audit${NC}"
echo ""

# Check if in app directory
if [ ! -f "app/package.json" ]; then
  echo -e "${RED}❌ ERROR: app/package.json not found!${NC}"
  echo "   Run this script from project root"
  exit 1
fi

cd app

# Check 1: npm audit
echo -e "${BLUE}📋 Check 1: Running npm audit...${NC}"
echo ""

if npm audit --json > /tmp/audit.json 2>&1; then
  echo -e "${GREEN}✅ No vulnerabilities found!${NC}"
else
  # Parse audit results
  if command -v jq &> /dev/null; then
    CRITICAL=$(jq '.metadata.vulnerabilities.critical // 0' /tmp/audit.json 2>/dev/null || echo "0")
    HIGH=$(jq '.metadata.vulnerabilities.high // 0' /tmp/audit.json 2>/dev/null || echo "0")
    MODERATE=$(jq '.metadata.vulnerabilities.moderate // 0' /tmp/audit.json 2>/dev/null || echo "0")
    LOW=$(jq '.metadata.vulnerabilities.low // 0' /tmp/audit.json 2>/dev/null || echo "0")
    
    echo -e "${YELLOW}Vulnerability Summary:${NC}"
    echo "  Critical: $CRITICAL"
    echo "  High:     $HIGH"
    echo "  Moderate: $MODERATE"
    echo "  Low:      $LOW"
    echo ""
    
    if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
      echo -e "${RED}❌ FAIL: Critical or High severity vulnerabilities found!${NC}"
      echo ""
      npm audit --audit-level=high 2>&1 | head -50
      echo ""
      CRITICAL_FOUND=1
    elif [ "$MODERATE" -gt 0 ]; then
      echo -e "${YELLOW}⚠️  WARNING: Moderate severity vulnerabilities found${NC}"
      HIGH_FOUND=1
    fi
  else
    # jq not available, use basic output
    echo -e "${YELLOW}⚠️  Vulnerabilities detected (install jq for detailed report)${NC}"
    npm audit --audit-level=moderate 2>&1 | head -30
    HIGH_FOUND=1
  fi
fi
echo ""

# Check 2: Outdated packages
echo -e "${BLUE}📋 Check 2: Checking for outdated packages...${NC}"
echo ""

if npm outdated > /tmp/outdated.txt 2>&1; then
  echo -e "${GREEN}✅ All packages up to date${NC}"
else
  if [ -s /tmp/outdated.txt ]; then
    echo -e "${YELLOW}⚠️  Outdated packages found:${NC}"
    echo ""
    head -20 /tmp/outdated.txt
    echo ""
    echo -e "${BLUE}💡 TIP: Run 'npm update' to update packages${NC}"
  fi
fi
echo ""

# Check 3: Check for known vulnerable package versions
echo -e "${BLUE}📋 Check 3: Checking for known problematic packages...${NC}"
echo ""

PROBLEMATIC_PACKAGES=(
  "event-stream:3.3.6"  # Known malicious version
  "flatmap-stream:0.1.1" # Known malicious version
)

found_problematic=false
for pkg_version in "${PROBLEMATIC_PACKAGES[@]}"; do
  pkg=$(echo "$pkg_version" | cut -d: -f1)
  version=$(echo "$pkg_version" | cut -d: -f2)
  
  if grep -q "\"$pkg\": \"$version\"" package-lock.json 2>/dev/null; then
    found_problematic=true
    echo -e "${RED}❌ CRITICAL: Found known malicious package: $pkg@$version${NC}"
    CRITICAL_FOUND=1
  fi
done

if [ "$found_problematic" = false ]; then
  echo -e "${GREEN}✅ PASS: No known malicious packages detected${NC}"
fi
echo ""

# Check 4: License compliance
echo -e "${BLUE}📋 Check 4: Checking license compliance...${NC}"
echo ""

if command -v npx &> /dev/null; then
  # Check for problematic licenses (GPL, AGPL in commercial projects)
  if npx --yes license-checker --summary 2>/dev/null | grep -iE "GPL|AGPL" > /tmp/licenses.txt; then
    if [ -s /tmp/licenses.txt ]; then
      echo -e "${YELLOW}⚠️  WARNING: Restrictive licenses detected:${NC}"
      cat /tmp/licenses.txt
      echo ""
      echo -e "${BLUE}💡 Review these licenses for compatibility${NC}"
    fi
  else
    echo -e "${GREEN}✅ PASS: No restrictive licenses detected${NC}"
  fi
else
  echo -e "${YELLOW}⚠️  Skipping license check (npx not available)${NC}"
fi
echo ""

# Cleanup
rm -f /tmp/audit.json /tmp/outdated.txt /tmp/licenses.txt
cd ..

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  DEPENDENCY SECURITY SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

if [ $CRITICAL_FOUND -eq 0 ]; then
  if [ $HIGH_FOUND -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo -e "${BLUE}💡 Recommendations:${NC}"
    echo "  - Run this audit regularly (weekly)"
    echo "  - Keep packages updated"
    echo "  - Review changelogs before updating"
    echo ""
    exit 0
  else
    echo -e "${YELLOW}⚠️  Warnings found (non-critical)${NC}"
    echo ""
    echo -e "${BLUE}📋 Recommended Actions:${NC}"
    echo "  1. Review moderate vulnerabilities"
    echo "  2. Update outdated packages"
    echo "  3. Run: npm audit fix"
    echo ""
    exit 0
  fi
else
  echo -e "${RED}❌ CRITICAL ISSUES FOUND!${NC}"
  echo ""
  echo -e "${YELLOW}🚨 IMMEDIATE ACTIONS REQUIRED:${NC}"
  echo ""
  echo "  1. Run: npm audit fix --force"
  echo "  2. Review and test the fixes"
  echo "  3. If fixes break functionality, find alternatives"
  echo "  4. DO NOT deploy until resolved"
  echo ""
  echo -e "${BLUE}📚 See Also:${NC}"
  echo "  - Rule 013: dependency-auditing.mdc"
  echo "  - .cursor/docs/security-workflows.md#dependency-management"
  echo ""
  exit 1
fi

