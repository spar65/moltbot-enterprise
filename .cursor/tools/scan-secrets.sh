#!/usr/bin/env bash
#
# Secrets Scanner
# 
# Purpose: Deep scan for hardcoded secrets and sensitive data
# Usage: ./.cursor/tools/scan-secrets.sh [path]
#
# Exit codes:
#   0 - No secrets found
#   1 - Secrets detected
#

set -euo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SECRETS_FOUND=0
SCAN_PATH="${1:-.}"

echo -e "${BLUE}🔍 Secrets Scanner${NC}"
echo -e "${BLUE}Scanning: $SCAN_PATH${NC}"
echo ""

# Secret patterns to detect
declare -A SECRET_PATTERNS=(
  # Stripe
  ["Stripe Secret Key"]="sk_(test|live)_[a-zA-Z0-9]{24,}"
  ["Stripe Publishable Key"]="pk_(test|live)_[a-zA-Z0-9]{24,}"
  ["Stripe Restricted Key"]="rk_(test|live)_[a-zA-Z0-9]{24,}"
  
  # Generic API Keys
  ["API Key (quoted)"]="['\"]?api[_-]?key['\"]?\s*[:=]\s*['\"][a-zA-Z0-9]{20,}['\"]"
  ["Bearer Token"]="Bearer\s+[a-zA-Z0-9_\-]{20,}"
  
  # AWS
  ["AWS Access Key"]="AKIA[0-9A-Z]{16}"
  ["AWS Secret Key"]="aws[_-]?secret[_-]?access[_-]?key.*['\"][a-zA-Z0-9/+=]{40}['\"]"
  
  # Database
  ["Database URL with Password"]="(postgres|mysql|mongodb)://[^:]+:[^@]+@"
  
  # Generic Secrets
  ["Secret/Password Assignment"]="(secret|password|passwd|pwd)['\"]?\s*[:=]\s*['\"][^'\"]{8,}['\"]"
  
  # Private Keys
  ["Private Key"]="-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"
  
  # Auth0
  ["Auth0 Secret"]="['\"]?auth0[_-]?(client[_-])?secret['\"]?\s*[:=]\s*['\"][a-zA-Z0-9_-]{32,}['\"]"
  
  # GitHub/GitLab
  ["GitHub Token"]="gh[pousr]_[a-zA-Z0-9]{36,}"
  ["GitLab Token"]="glpat-[a-zA-Z0-9_-]{20,}"
  
  # JWT
  ["JWT Token"]="eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}"
)

# Files to exclude
EXCLUDE_PATTERNS=(
  "node_modules"
  ".next"
  "dist"
  "build"
  ".git"
  "*.log"
  "*.lock"
  "*.min.js"
  "*.map"
  ".cursor/tools/scan-secrets.sh"  # Don't scan ourselves
)

# Build exclude options for grep
EXCLUDE_OPTS=""
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
  EXCLUDE_OPTS="$EXCLUDE_OPTS --exclude-dir=$pattern"
done

# Scan for each pattern
for secret_name in "${!SECRET_PATTERNS[@]}"; do
  pattern="${SECRET_PATTERNS[$secret_name]}"
  
  echo -e "${BLUE}📋 Scanning for: $secret_name${NC}"
  
  # Use grep to find matches
  if grep -r -E -n $EXCLUDE_OPTS "$pattern" "$SCAN_PATH" 2>/dev/null > /tmp/secrets_scan.txt; then
    if [ -s /tmp/secrets_scan.txt ]; then
      # Filter out .env.example (expected to have placeholders)
      if grep -v ".env.example" /tmp/secrets_scan.txt > /tmp/secrets_filtered.txt; then
        if [ -s /tmp/secrets_filtered.txt ]; then
          echo -e "${RED}❌ FOUND: $secret_name${NC}"
          echo ""
          
          # Show first 10 matches
          head -10 /tmp/secrets_filtered.txt | while IFS= read -r line; do
            echo -e "${YELLOW}   $line${NC}"
          done
          
          # Count total matches
          total=$(wc -l < /tmp/secrets_filtered.txt)
          if [ "$total" -gt 10 ]; then
            echo -e "${YELLOW}   ... and $((total - 10)) more${NC}"
          fi
          echo ""
          
          ((SECRETS_FOUND++))
        else
          echo -e "${GREEN}✓ None found (only in .env.example)${NC}"
        fi
      else
        echo -e "${GREEN}✓ None found (only in .env.example)${NC}"
      fi
    else
      echo -e "${GREEN}✓ None found${NC}"
    fi
  else
    echo -e "${GREEN}✓ None found${NC}"
  fi
  echo ""
done

# Check for accidentally committed .env files
echo -e "${BLUE}📋 Checking for committed .env files...${NC}"
if git ls-files 2>/dev/null | grep -E "^\.env$|^\.env\.local$|^app/\.env$" > /tmp/env_files.txt; then
  if [ -s /tmp/env_files.txt ]; then
    echo -e "${RED}❌ CRITICAL: .env files committed to git!${NC}"
    echo ""
    cat /tmp/env_files.txt
    echo ""
    ((SECRETS_FOUND++))
  else
    echo -e "${GREEN}✓ No .env files committed${NC}"
  fi
else
  echo -e "${GREEN}✓ No .env files committed${NC}"
fi
echo ""

# Check git history for secrets (quick check of recent commits)
echo -e "${BLUE}📋 Checking recent git history for secrets...${NC}"
if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
  # Check last 10 commits
  if git log --all -p -10 2>/dev/null | grep -E "(api[_-]?key|secret|password|token)" | grep -v "process.env" > /tmp/git_secrets.txt 2>&1; then
    if [ -s /tmp/git_secrets.txt ]; then
      echo -e "${YELLOW}⚠️  WARNING: Found secret-like patterns in git history${NC}"
      echo -e "${BLUE}💡 Run: git log --all -p | grep -i secret${NC}"
      echo ""
    else
      echo -e "${GREEN}✓ No obvious secrets in recent commits${NC}"
    fi
  else
    echo -e "${GREEN}✓ No obvious secrets in recent commits${NC}"
  fi
else
  echo -e "${YELLOW}⚠️  Skipping git history check (not a git repo)${NC}"
fi
echo ""

# Cleanup temp files
rm -f /tmp/secrets_scan.txt /tmp/secrets_filtered.txt /tmp/env_files.txt /tmp/git_secrets.txt

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  SECRETS SCAN SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

if [ $SECRETS_FOUND -eq 0 ]; then
  echo -e "${GREEN}✅ No secrets detected!${NC}"
  echo ""
  echo -e "${BLUE}💡 Best Practices:${NC}"
  echo "  - Always use environment variables for secrets"
  echo "  - Never commit .env files"
  echo "  - Use .env.example with placeholder values"
  echo "  - Rotate secrets if accidentally exposed"
  echo "  - Run this scan before commits"
  echo ""
  exit 0
else
  echo -e "${RED}❌ $SECRETS_FOUND secret type(s) detected!${NC}"
  echo ""
  echo -e "${YELLOW}🚨 IMMEDIATE ACTIONS REQUIRED:${NC}"
  echo ""
  echo "  1. Remove hardcoded secrets from code"
  echo "  2. Move secrets to environment variables"
  echo "  3. Add secrets to .gitignore"
  echo "  4. If secrets were committed:"
  echo "     a. Rotate the secrets immediately"
  echo "     b. Consider using git-filter-branch or BFG Repo-Cleaner"
  echo "  5. Update .env.example with placeholder values only"
  echo ""
  echo -e "${BLUE}📚 See Also:${NC}"
  echo "  - Rule 010: security-compliance.mdc"
  echo "  - Rule 011: env-var-security.mdc"
  echo "  - Rule 020: payment-security.mdc"
  echo "  - .cursor/docs/security-workflows.md"
  echo ""
  exit 1
fi

