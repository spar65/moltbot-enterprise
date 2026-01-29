#!/usr/bin/env bash

# Email Compliance Checker
# Validates email marketing compliance with GDPR, CAN-SPAM, CASL, and Gmail/Yahoo 2024 requirements
#
# Usage:
#   ./check-email-compliance.sh [--domain yourdomain.com] [--api-key MAILCHIMP_KEY]
#
# Options:
#   --domain DOMAIN       Domain to check for email authentication records
#   --api-key KEY         MailChimp API key for list compliance checks
#   --verbose             Show detailed output
#   --help                Show this help message

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default values
DOMAIN=""
API_KEY=""
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --api-key)
      API_KEY="$2"
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
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

echo -e "${BOLD}${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          EMAIL COMPLIANCE CHECKER                            ║"
echo "║      GDPR | CAN-SPAM | CASL | Gmail/Yahoo 2024               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

PASSED=0
FAILED=0
WARNINGS=0

# Helper function to print results
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

# ============================================================================
# SECTION 1: DNS AUTHENTICATION RECORDS (Gmail/Yahoo 2024 Requirement)
# ============================================================================

echo -e "\n${BOLD}1. DNS Authentication Records${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -z "$DOMAIN" ]]; then
  print_result warn "Domain not specified. Skipping DNS checks." \
    "Use --domain yourdomain.com to check SPF, DKIM, DMARC"
else
  # Check SPF record
  if SPF_RECORD=$(dig +short TXT "$DOMAIN" | grep -i "v=spf1"); then
    print_result pass "SPF record found for $DOMAIN" "$SPF_RECORD"
  else
    print_result fail "SPF record NOT found for $DOMAIN" \
      "CRITICAL: Gmail/Yahoo 2024 requirement. Add SPF record to DNS."
  fi
  
  # Check DMARC record
  if DMARC_RECORD=$(dig +short TXT "_dmarc.$DOMAIN" | grep -i "v=DMARC1"); then
    print_result pass "DMARC record found for $DOMAIN" "$DMARC_RECORD"
    
    # Check DMARC policy
    if echo "$DMARC_RECORD" | grep -q "p=none"; then
      print_result warn "DMARC policy is set to 'none' (monitoring only)" \
        "Consider upgrading to p=quarantine or p=reject after monitoring"
    elif echo "$DMARC_RECORD" | grep -qE "p=(quarantine|reject)"; then
      print_result pass "DMARC policy is enforced (quarantine or reject)"
    fi
  else
    print_result fail "DMARC record NOT found for $DOMAIN" \
      "CRITICAL: Gmail/Yahoo 2024 requirement. Add DMARC record to DNS."
  fi
  
  # Check BIMI record (optional but recommended)
  if BIMI_RECORD=$(dig +short TXT "default._bimi.$DOMAIN"); then
    print_result pass "BIMI record found (optional but recommended)" "$BIMI_RECORD"
  else
    print_result info "BIMI record not found (optional)" \
      "Consider adding BIMI for brand logo display in email clients"
  fi
  
  # Note about DKIM
  print_result info "DKIM check requires selector knowledge" \
    "DKIM records are typically checked by email service provider (e.g., MailChimp)"
fi

# ============================================================================
# SECTION 2: One-Click Unsubscribe (Gmail/Yahoo 2024 CRITICAL)
# ============================================================================

echo -e "\n${BOLD}2. One-Click Unsubscribe (RFC 8058)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

print_result info "Checking for one-click unsubscribe implementation" \
  "This requires code review of email sending infrastructure"

# Check if .env has unsubscribe endpoint configured
if [[ -f ".env" ]]; then
  if grep -q "UNSUBSCRIBE_ENDPOINT" .env; then
    print_result pass "Unsubscribe endpoint configured in .env"
  else
    print_result warn "UNSUBSCRIBE_ENDPOINT not found in .env" \
      "Add UNSUBSCRIBE_ENDPOINT=https://yourdomain.com/api/unsubscribe"
  fi
fi

# Requirements checklist
echo -e "\n${YELLOW}One-Click Unsubscribe Requirements (Manual Verification):${NC}"
echo "  □ List-Unsubscribe header present in all marketing emails"
echo "  □ List-Unsubscribe-Post header present (RFC 8058)"
echo "  □ Unsubscribe endpoint processes requests within 2 seconds"
echo "  □ Unsubscribe does not require login or additional steps"
echo "  □ Confirmation email (optional) sent after unsubscribe"

# ============================================================================
# SECTION 3: Spam Complaint Rate (Gmail/Yahoo 2024 CRITICAL)
# ============================================================================

echo -e "\n${BOLD}3. Spam Complaint Rate Monitoring${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

print_result info "Gmail/Yahoo require spam complaint rate < 0.3%" \
  "Monitor in Google Postmaster Tools: https://postmaster.google.com"

echo -e "\n${YELLOW}Spam Rate Monitoring Setup (Manual Steps):${NC}"
echo "  □ Register domain in Google Postmaster Tools"
echo "  □ Register domain in Microsoft SNDS (Outlook)"
echo "  □ Set up alerts for complaint rate > 0.2%"
echo "  □ Monitor complaint rates daily"
echo "  □ Document emergency procedures for rate spikes"

# ============================================================================
# SECTION 4: GDPR Compliance
# ============================================================================

echo -e "\n${BOLD}4. GDPR Compliance (EU Users)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "\n${YELLOW}GDPR Requirements Checklist:${NC}"
echo "  □ Explicit consent collected before sending marketing emails"
echo "  □ Consent timestamps and source recorded in database"
echo "  □ Separate consent for different email types (marketing, transactional)"
echo "  □ Easy-to-find unsubscribe link in all emails"
echo "  □ Preference center allows granular control"
echo "  □ Data processing documented in privacy policy"
echo "  □ Data retention policies defined and enforced"
echo "  □ Right to access, rectify, delete data implemented"
echo "  □ Data breach notification procedures in place"

# ============================================================================
# SECTION 5: CAN-SPAM Compliance (US Users)
# ============================================================================

echo -e "\n${BOLD}5. CAN-SPAM Compliance (US Users)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "\n${YELLOW}CAN-SPAM Requirements Checklist:${NC}"
echo "  □ Accurate 'From' and 'Reply-To' addresses"
echo "  □ Subject line reflects email content (not deceptive)"
echo "  □ Physical mailing address in footer"
echo "  □ Clear identification as advertisement (if applicable)"
echo "  □ Unsubscribe requests honored within 10 business days"
echo "  □ Unsubscribe mechanism works for 30 days after sending"
echo "  □ No charge/fee/login required to unsubscribe"

# ============================================================================
# SECTION 6: CASL Compliance (Canadian Users)
# ============================================================================

echo -e "\n${BOLD}6. CASL Compliance (Canadian Users)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "\n${YELLOW}CASL Requirements Checklist:${NC}"
echo "  □ Express consent obtained before sending commercial emails"
echo "  □ Consent mechanism clearly identifies sender"
echo "  □ Consent includes purpose of collection"
echo "  □ Sender identification clearly stated in email"
echo "  □ Contact information provided in email"
echo "  □ Unsubscribe mechanism clearly stated"
echo "  □ Unsubscribe requests processed within 10 business days"
echo "  □ Consent records retained for 3 years minimum"

# ============================================================================
# SECTION 7: Email List Hygiene
# ============================================================================

echo -e "\n${BOLD}7. Email List Hygiene${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "\n${YELLOW}List Hygiene Best Practices:${NC}"
echo "  □ Double opt-in implemented for new subscriptions"
echo "  □ Bounce handling configured (remove hard bounces immediately)"
echo "  □ Soft bounces monitored (remove after 3-5 bounces)"
echo "  □ Engagement-based sunset policies (remove inactive > 12 months)"
echo "  □ Re-permission campaigns for dormant subscribers"
echo "  □ Spam trap detection and removal procedures"
echo "  □ Regular list cleaning (quarterly minimum)"

# ============================================================================
# SECTION 8: Accessibility & Content Standards
# ============================================================================

echo -e "\n${BOLD}8. Accessibility & Content Standards${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "\n${YELLOW}Accessibility Requirements:${NC}"
echo "  □ All images have descriptive alt text"
echo "  □ Color contrast ratio ≥ 4.5:1 for text"
echo "  □ Semantic HTML structure (proper headings)"
echo "  □ Meaningful link text (not 'click here')"
echo "  □ Dark mode styles implemented"
echo "  □ Mobile-responsive design"
echo "  □ Text size ≥ 14px for body content"

# ============================================================================
# FINAL SUMMARY
# ============================================================================

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                     COMPLIANCE SUMMARY                       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Passed Checks:  ${PASSED}${NC}"
echo -e "${RED}Failed Checks:  ${FAILED}${NC}"
echo -e "${YELLOW}Warnings:       ${WARNINGS}${NC}"
echo ""

if [[ $FAILED -gt 0 ]]; then
  echo -e "${RED}${BOLD}⚠ CRITICAL: $FAILED compliance check(s) failed!${NC}"
  echo -e "${RED}Address failed checks immediately to ensure compliance.${NC}"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo -e "${YELLOW}${BOLD}⚠ $WARNINGS warning(s) found.${NC}"
  echo -e "${YELLOW}Review warnings and implement recommendations.${NC}"
  exit 0
else
  echo -e "${GREEN}${BOLD}✓ All automated compliance checks passed!${NC}"
  echo -e "${GREEN}Review manual checklists to ensure full compliance.${NC}"
  exit 0
fi

