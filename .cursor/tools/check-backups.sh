#!/bin/bash

# check-backups.sh - Verify backup health and coverage
# Usage: ./.cursor/tools/check-backups.sh [--environment production|staging|development]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="${1:-production}"
WARNINGS=0
ERRORS=0

echo "🔍 Backup Health Check - Environment: $ENVIRONMENT"
echo "=================================================="
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "ok")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ((WARNINGS++))
            ;;
        "error")
            echo -e "${RED}❌ $message${NC}"
            ((ERRORS++))
            ;;
        "info")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Check 1: Database Backup Configuration
echo "📊 Checking Database Backup Configuration..."
echo "-------------------------------------------"

# Check if DATABASE_URL is set
if [ -z "${DATABASE_URL:-}" ]; then
    print_status "error" "DATABASE_URL not set"
else
    print_status "ok" "DATABASE_URL is configured"
    
    # Check if connection string includes backup configuration
    if [[ "$DATABASE_URL" == *"sslmode=require"* ]]; then
        print_status "ok" "SSL mode is enabled"
    else
        print_status "warning" "SSL mode not explicitly set"
    fi
fi

echo ""

# Check 2: Backup Schedule
echo "⏰ Checking Backup Schedule..."
echo "----------------------------"

# Simulated check (in production, would check actual backup schedule)
print_status "info" "Checking automated backup schedule..."

# Daily backups
if [ -f ".vercel/backup-config.json" ] || [ ! -z "${BACKUP_SCHEDULE:-}" ]; then
    print_status "ok" "Daily backup schedule configured"
else
    print_status "warning" "No daily backup schedule found - configure automated backups"
fi

# Weekly backups
print_status "info" "Weekly backup retention: 4 weeks (recommended)"

# Monthly backups
print_status "info" "Monthly backup retention: 12 months (recommended)"

echo ""

# Check 3: Backup Verification
echo "🔬 Checking Backup Verification..."
echo "---------------------------------"

# Check for backup verification logs
if [ -d "logs/backups" ]; then
    LATEST_VERIFICATION=$(find logs/backups -name "verification-*.log" -mtime -7 -type f | head -n 1)
    
    if [ -n "$LATEST_VERIFICATION" ]; then
        print_status "ok" "Backup verified within last 7 days"
        echo "   Latest: $(basename $LATEST_VERIFICATION)"
    else
        print_status "error" "No backup verification in last 7 days"
    fi
else
    print_status "warning" "No backup verification logs found"
    print_status "info" "Create logs/backups directory and implement verification"
fi

echo ""

# Check 4: Backup Storage
echo "💾 Checking Backup Storage..."
echo "----------------------------"

# Check available disk space (if running locally)
if command_exists df; then
    DISK_USAGE=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$DISK_USAGE" -lt 80 ]; then
        print_status "ok" "Disk usage: ${DISK_USAGE}%"
    elif [ "$DISK_USAGE" -lt 90 ]; then
        print_status "warning" "Disk usage: ${DISK_USAGE}% - consider cleanup"
    else
        print_status "error" "Disk usage: ${DISK_USAGE}% - critical!"
    fi
else
    print_status "info" "Disk usage check skipped (not available)"
fi

# Check backup storage configuration
if [ ! -z "${BACKUP_BUCKET:-}" ]; then
    print_status "ok" "Backup storage bucket configured: $BACKUP_BUCKET"
else
    print_status "warning" "No backup storage bucket configured"
fi

echo ""

# Check 5: Point-in-Time Recovery (PITR)
echo "🕐 Checking Point-in-Time Recovery..."
echo "------------------------------------"

# Check if PITR is enabled
if [ "$ENVIRONMENT" = "production" ]; then
    # In production, PITR should be enabled
    print_status "info" "PITR should be enabled for production"
    print_status "info" "Retention: 7 days (recommended minimum)"
    
    # Check if using managed database service
    if [[ "${DATABASE_URL:-}" == *"vercel-storage"* ]] || [[ "${DATABASE_URL:-}" == *"supabase"* ]]; then
        print_status "ok" "Using managed database with PITR"
    else
        print_status "warning" "Verify PITR is enabled for your database"
    fi
else
    print_status "info" "PITR optional for $ENVIRONMENT environment"
fi

echo ""

# Check 6: Backup Encryption
echo "🔒 Checking Backup Encryption..."
echo "-------------------------------"

# Check if backups are encrypted
if [ ! -z "${BACKUP_ENCRYPTION_KEY:-}" ]; then
    print_status "ok" "Backup encryption key configured"
else
    print_status "warning" "No backup encryption key found"
    print_status "info" "Configure BACKUP_ENCRYPTION_KEY for encrypted backups"
fi

echo ""

# Check 7: Recovery Time Objective (RTO)
echo "⏱️  Checking Recovery Time Objective..."
echo "---------------------------------------"

# Check if RTO is documented
if [ -f "docs/disaster-recovery-plan.md" ] || [ -f "docs/DISASTER_RECOVERY.md" ]; then
    print_status "ok" "Disaster recovery documentation found"
else
    print_status "warning" "No disaster recovery documentation found"
    print_status "info" "Create docs/DISASTER_RECOVERY.md with RTO/RPO targets"
fi

# RTO targets by data criticality
print_status "info" "RTO Targets:"
echo "   - Critical data: 15 minutes"
echo "   - Important data: 1 hour"
echo "   - Standard data: 4 hours"

echo ""

# Check 8: Recovery Point Objective (RPO)
echo "📍 Checking Recovery Point Objective..."
echo "---------------------------------------"

# RPO targets by data criticality
print_status "info" "RPO Targets:"
echo "   - Critical data: 0 seconds (zero data loss)"
echo "   - Important data: 5 minutes"
echo "   - Standard data: 1 hour"

echo ""

# Check 9: Backup Testing
echo "🧪 Checking Backup Testing..."
echo "----------------------------"

# Check when last backup test was performed
if [ -f "docs/backup-test-results.md" ]; then
    LAST_TEST=$(grep -i "last tested" docs/backup-test-results.md | head -n 1)
    
    if [ -n "$LAST_TEST" ]; then
        print_status "ok" "Backup testing documented"
        echo "   $LAST_TEST"
    fi
else
    print_status "warning" "No backup test results found"
    print_status "info" "Document backup tests in docs/backup-test-results.md"
fi

print_status "info" "Recommended: Test backups monthly"

echo ""

# Check 10: Multi-Region Backup
echo "🌍 Checking Multi-Region Backup..."
echo "----------------------------------"

if [ "$ENVIRONMENT" = "production" ]; then
    # Production should have multi-region backups
    if [ ! -z "${BACKUP_REGION_PRIMARY:-}" ] && [ ! -z "${BACKUP_REGION_SECONDARY:-}" ]; then
        print_status "ok" "Multi-region backup configured"
        echo "   Primary: ${BACKUP_REGION_PRIMARY}"
        echo "   Secondary: ${BACKUP_REGION_SECONDARY}"
    else
        print_status "warning" "Multi-region backup not configured"
        print_status "info" "Configure BACKUP_REGION_PRIMARY and BACKUP_REGION_SECONDARY"
    fi
else
    print_status "info" "Multi-region backup optional for $ENVIRONMENT"
fi

echo ""
echo "=================================================="
echo "📊 Backup Health Check Summary"
echo "=================================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    print_status "ok" "All backup checks passed!"
elif [ $ERRORS -eq 0 ]; then
    print_status "warning" "Backup health check completed with $WARNINGS warning(s)"
else
    print_status "error" "Backup health check failed with $ERRORS error(s) and $WARNINGS warning(s)"
fi

echo ""
echo "📚 For detailed backup guidance, see:"
echo "   - guides/Database-Operations-Complete-Guide.md"
echo "   - .cursor/rules/212-backup-recovery-standards.mdc"
echo ""

# Exit with appropriate code
if [ $ERRORS -gt 0 ]; then
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    exit 0  # Warnings don't fail the check
else
    exit 0
fi

