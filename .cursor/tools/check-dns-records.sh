#!/usr/bin/env bash

# DNS Records Checker for Email Authentication
# Validates SPF, DKIM, DMARC, BIMI, and MX records
#
# Usage:
#   ./check-dns-records.sh yourdomain.com [--dkim-selector k1]
#
# Options:
#   --dkim-selector SELECTOR    DKIM selector to check (default: k1)
#   --verbose                    Show detailed output
#   --help                       Show this help message

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

# Default values
DKIM_SELECTOR="k1"
VERBOSE=false

# Parse arguments
DOMAIN=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --dkim-selector)
      DKIM_SELECTOR="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      grep '^#' "$0" | tail -n +2 | head -n -1 | cut -c 3-
      exit 0
      ;;
    *)
      if [[ -z "$DOMAIN" ]]; then
        DOMAIN="$1"
        shift
      else
        echo -e "${RED}Unknown option: $1${NC}"
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$DOMAIN" ]]; then
  echo -e "${RED}Error: Domain required${NC}"
  echo "Usage: $0 yourdomain.com"
  exit 1
fi

echo -e "${BOLD}${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              DNS RECORDS CHECKER                             ║"
echo "║         Email Authentication Validation                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "Domain: ${BOLD}$DOMAIN${NC}"
echo ""

PASSED=0
FAILED=0
WARNINGS=0

print_result() {
  local status=$1
  local message=$2
  local details=${3:-""}
  
  case $status in
    pass)
      echo -e "${GREEN}✓${NC} $message"
      ((PASSED++))
      ;;
    fail)
      echo -e "${RED}✗${NC} $message"
      ((FAILED++))
      ;;
    warn)
      echo -e "${YELLOW}⚠${NC} $message"
      ((WARNINGS++))
      ;;
    info)
      echo -e "${BLUE}ℹ${NC} $message"
      ;;
  esac
  
  if [[ -n "$details" ]] && [[ "$VERBOSE" == "true" ]]; then
    echo -e "  ${BLUE}→${NC} $details"
  fi
}

# Check SPF Record
echo -e "${BOLD}SPF (Sender Policy Framework)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if SPF_RECORD=$(dig +short TXT "$DOMAIN" 2>/dev/null | grep -i "v=spf1"); then
  print_result pass "SPF record found"
  
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "  Record: ${BLUE}$SPF_RECORD${NC}"
  fi
  
  # Check for common issues
  if echo "$SPF_RECORD" | grep -q "\~all"; then
    print_result info "SPF uses soft fail (~all) - recommended for monitoring"
  elif echo "$SPF_RECORD" | grep -q "\-all"; then
    print_result pass "SPF uses hard fail (-all) - strict policy"
  elif echo "$SPF_RECORD" | grep -q "?all"; then
    print_result warn "SPF uses neutral (?all) - not recommended"
  elif echo "$SPF_RECORD" | grep -q "+all"; then
    print_result fail "SPF uses pass all (+all) - DANGEROUS! Anyone can spoof your domain"
  fi
  
  # Count DNS lookups
  LOOKUP_COUNT=$(echo "$SPF_RECORD" | grep -o "include:" | wc -l | tr -d ' ')
  if [[ $LOOKUP_COUNT -gt 10 ]]; then
    print_result fail "SPF has $LOOKUP_COUNT DNS lookups (max: 10)"
  elif [[ $LOOKUP_COUNT -gt 7 ]]; then
    print_result warn "SPF has $LOOKUP_COUNT DNS lookups (max: 10, recommend < 8)"
  else
    print_result pass "SPF has $LOOKUP_COUNT DNS lookups (within limits)"
  fi
else
  print_result fail "SPF record NOT found"
  echo -e "  ${YELLOW}Recommendation:${NC} Add SPF record to DNS:"
  echo -e "  ${BLUE}v=spf1 include:_spf.google.com include:mailchimp.com ~all${NC}"
fi

echo ""

# Check DMARC Record
echo -e "${BOLD}DMARC (Domain-based Message Authentication)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if DMARC_RECORD=$(dig +short TXT "_dmarc.$DOMAIN" 2>/dev/null | grep -i "v=DMARC1"); then
  print_result pass "DMARC record found"
  
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "  Record: ${BLUE}$DMARC_RECORD${NC}"
  fi
  
  # Check policy
  if echo "$DMARC_RECORD" | grep -q "p=none"; then
    print_result warn "DMARC policy: none (monitoring only)"
    echo -e "  ${YELLOW}Recommendation:${NC} After monitoring, upgrade to p=quarantine or p=reject"
  elif echo "$DMARC_RECORD" | grep -q "p=quarantine"; then
    print_result pass "DMARC policy: quarantine (recommended)"
  elif echo "$DMARC_RECORD" | grep -q "p=reject"; then
    print_result pass "DMARC policy: reject (strict enforcement)"
  fi
  
  # Check for aggregate report email
  if echo "$DMARC_RECORD" | grep -q "rua="; then
    print_result pass "Aggregate reports configured (rua)"
  else
    print_result warn "No aggregate report email (rua) configured"
  fi
  
  # Check for forensic report email
  if echo "$DMARC_RECORD" | grep -q "ruf="; then
    print_result pass "Forensic reports configured (ruf)"
  else
    print_result info "No forensic report email (ruf) configured (optional)"
  fi
else
  print_result fail "DMARC record NOT found"
  echo -e "  ${YELLOW}Recommendation:${NC} Add DMARC record to DNS:"
  echo -e "  ${BLUE}_dmarc.$DOMAIN${NC}"
  echo -e "  ${BLUE}v=DMARC1; p=none; rua=mailto:dmarc@$DOMAIN; pct=100${NC}"
fi

echo ""

# Check DKIM Record
echo -e "${BOLD}DKIM (DomainKeys Identified Mail)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

DKIM_DOMAIN="${DKIM_SELECTOR}._domainkey.$DOMAIN"
if DKIM_RECORD=$(dig +short TXT "$DKIM_DOMAIN" 2>/dev/null | grep -i "v=DKIM1"); then
  print_result pass "DKIM record found (selector: $DKIM_SELECTOR)"
  
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "  Record: ${BLUE}${DKIM_RECORD:0:80}...${NC}"
  fi
  
  # Check key type
  if echo "$DKIM_RECORD" | grep -q "k=rsa"; then
    print_result pass "DKIM uses RSA keys"
  fi
  
  # Check key length (approximate)
  KEY_LENGTH=${#DKIM_RECORD}
  if [[ $KEY_LENGTH -gt 300 ]]; then
    print_result pass "DKIM key appears to be 2048-bit (recommended)"
  else
    print_result warn "DKIM key may be 1024-bit (recommend 2048-bit)"
  fi
else
  print_result fail "DKIM record NOT found (selector: $DKIM_SELECTOR)"
  echo -e "  ${YELLOW}Note:${NC} DKIM selector varies by email service provider"
  echo -e "  ${YELLOW}Common selectors:${NC} k1, default, google, s1, s2"
  echo -e "  ${YELLOW}Recommendation:${NC} Check your ESP for correct DKIM selector"
fi

echo ""

# Check BIMI Record (optional)
echo -e "${BOLD}BIMI (Brand Indicators for Message Identification)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if BIMI_RECORD=$(dig +short TXT "default._bimi.$DOMAIN" 2>/dev/null); then
  print_result pass "BIMI record found"
  
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "  Record: ${BLUE}$BIMI_RECORD${NC}"
  fi
  
  # Check for logo URL
  if echo "$BIMI_RECORD" | grep -q "l=https://"; then
    print_result pass "BIMI logo URL configured"
  fi
  
  # Check for VMC
  if echo "$BIMI_RECORD" | grep -q "a=https://"; then
    print_result pass "BIMI VMC (Verified Mark Certificate) configured"
  else
    print_result warn "BIMI VMC not configured (required for some email clients)"
  fi
else
  print_result info "BIMI record not found (optional)"
  echo -e "  ${BLUE}Info:${NC} BIMI displays brand logo in email clients"
  echo -e "  ${BLUE}Requires:${NC} DMARC policy=quarantine or reject + VMC"
fi

echo ""

# Check MX Records
echo -e "${BOLD}MX (Mail Exchange)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if MX_RECORDS=$(dig +short MX "$DOMAIN" 2>/dev/null | head -n 5); then
  if [[ -n "$MX_RECORDS" ]]; then
    print_result pass "MX records found"
    
    if [[ "$VERBOSE" == "true" ]]; then
      echo -e "  ${BLUE}Records:${NC}"
      while IFS= read -r line; do
        echo -e "    $line"
      done <<< "$MX_RECORDS"
    fi
    
    MX_COUNT=$(echo "$MX_RECORDS" | wc -l | tr -d ' ')
    if [[ $MX_COUNT -gt 1 ]]; then
      print_result pass "Multiple MX records ($MX_COUNT) for redundancy"
    else
      print_result warn "Only 1 MX record (recommend multiple for redundancy)"
    fi
  else
    print_result fail "MX records empty"
  fi
else
  print_result fail "MX records NOT found"
  echo -e "  ${YELLOW}Recommendation:${NC} Configure MX records for receiving email"
fi

echo ""

# Summary
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                      DNS CHECK SUMMARY                       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Passed:   ${PASSED}${NC}"
echo -e "${RED}Failed:   ${FAILED}${NC}"
echo -e "${YELLOW}Warnings: ${WARNINGS}${NC}"
echo ""

if [[ $FAILED -gt 0 ]]; then
  echo -e "${RED}${BOLD}⚠ CRITICAL: $FAILED DNS check(s) failed!${NC}"
  echo -e "${RED}Fix DNS records to ensure email deliverability.${NC}"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo -e "${YELLOW}${BOLD}⚠ $WARNINGS warning(s) found.${NC}"
  echo -e "${YELLOW}Review warnings and implement recommendations.${NC}"
  exit 0
else
  echo -e "${GREEN}${BOLD}✓ All DNS checks passed!${NC}"
  echo -e "${GREEN}Email authentication properly configured.${NC}"
  exit 0
fi

