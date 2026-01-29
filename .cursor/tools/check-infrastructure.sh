#!/bin/bash

# check-infrastructure.sh - Verify infrastructure health and configuration
# Usage: ./.cursor/tools/check-infrastructure.sh [--environment production|staging|development]

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

echo "🏗️  Infrastructure Health Check - Environment: $ENVIRONMENT"
echo "=========================================================="
echo ""

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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check 1: Environment Variables
echo "🔐 Checking Environment Variables..."
echo "-----------------------------------"

# Required environment variables
REQUIRED_VARS=(
    "DATABASE_URL"
    "NEXTAUTH_SECRET"
    "NEXTAUTH_URL"
)

OPTIONAL_VARS=(
    "STRIPE_SECRET_KEY"
    "OPENAI_API_KEY"
    "AUTH0_CLIENT_SECRET"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        print_status "error" "$var is not set"
    else
        print_status "ok" "$var is configured"
    fi
done

for var in "${OPTIONAL_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        print_status "info" "$var is not set (optional)"
    else
        print_status "ok" "$var is configured"
    fi
done

echo ""

# Check 2: Database Connectivity
echo "🗄️  Checking Database Connectivity..."
echo "------------------------------------"

if [ ! -z "${DATABASE_URL:-}" ]; then
    # Check if we can connect to database (using psql or prisma)
    if command_exists psql; then
        if psql "$DATABASE_URL" -c "SELECT 1" > /dev/null 2>&1; then
            print_status "ok" "Database connection successful"
        else
            print_status "error" "Cannot connect to database"
        fi
    elif command_exists npx; then
        # Try using Prisma
        if npx prisma db execute --stdin <<< "SELECT 1" > /dev/null 2>&1; then
            print_status "ok" "Database connection successful (via Prisma)"
        else
            print_status "warning" "Cannot verify database connection"
            print_status "info" "Install postgresql client for better checks"
        fi
    else
        print_status "info" "Cannot verify database connection (psql not installed)"
    fi
    
    # Check connection string format
    if [[ "$DATABASE_URL" == postgresql://* ]]; then
        print_status "ok" "Database URL format is valid"
    else
        print_status "warning" "Database URL format may be invalid"
    fi
else
    print_status "error" "DATABASE_URL not configured"
fi

echo ""

# Check 3: Node.js Version
echo "📦 Checking Node.js Version..."
echo "-----------------------------"

if command_exists node; then
    NODE_VERSION=$(node --version | sed 's/v//')
    MAJOR_VERSION=$(echo $NODE_VERSION | cut -d'.' -f1)
    
    print_status "info" "Node.js version: $NODE_VERSION"
    
    if [ "$MAJOR_VERSION" -ge 18 ]; then
        print_status "ok" "Node.js version is supported (>= 18)"
    else
        print_status "error" "Node.js version is too old (< 18)"
    fi
else
    print_status "error" "Node.js is not installed"
fi

echo ""

# Check 4: Dependencies
echo "📚 Checking Dependencies..."
echo "-------------------------"

if [ -f "package.json" ]; then
    print_status "ok" "package.json found"
    
    if [ -f "package-lock.json" ]; then
        print_status "ok" "package-lock.json found"
    else
        print_status "warning" "package-lock.json missing - run npm install"
    fi
    
    if [ -d "node_modules" ]; then
        print_status "ok" "node_modules directory exists"
        
        # Check if node_modules is up to date
        if [ "package-lock.json" -nt "node_modules" ]; then
            print_status "warning" "Dependencies may be out of date - run npm install"
        fi
    else
        print_status "error" "node_modules directory missing - run npm install"
    fi
else
    print_status "error" "package.json not found"
fi

echo ""

# Check 5: Prisma Schema
echo "🔷 Checking Prisma Schema..."
echo "---------------------------"

if [ -f "prisma/schema.prisma" ]; then
    print_status "ok" "Prisma schema found"
    
    # Check if schema is valid
    if command_exists npx; then
        if npx prisma validate > /dev/null 2>&1; then
            print_status "ok" "Prisma schema is valid"
        else
            print_status "error" "Prisma schema has errors"
        fi
        
        # Check if migrations are up to date
        if [ -d "prisma/migrations" ]; then
            print_status "ok" "Migrations directory exists"
            
            MIGRATION_COUNT=$(ls -1 prisma/migrations | wc -l)
            print_status "info" "Found $MIGRATION_COUNT migration(s)"
        else
            print_status "warning" "No migrations directory found"
        fi
    else
        print_status "info" "Cannot validate schema (npx not available)"
    fi
else
    print_status "error" "Prisma schema not found"
fi

echo ""

# Check 6: Build Configuration
echo "🔧 Checking Build Configuration..."
echo "---------------------------------"

if [ -f "next.config.ts" ] || [ -f "next.config.js" ]; then
    print_status "ok" "Next.js configuration found"
else
    print_status "warning" "Next.js configuration not found"
fi

if [ -f "tsconfig.json" ]; then
    print_status "ok" "TypeScript configuration found"
else
    print_status "warning" "TypeScript configuration not found"
fi

if [ -f "tailwind.config.ts" ] || [ -f "tailwind.config.js" ]; then
    print_status "ok" "Tailwind configuration found"
else
    print_status "info" "Tailwind configuration not found (may not be using Tailwind)"
fi

echo ""

# Check 7: Git Repository
echo "📝 Checking Git Repository..."
echo "----------------------------"

if [ -d ".git" ]; then
    print_status "ok" "Git repository initialized"
    
    # Check current branch
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    print_status "info" "Current branch: $CURRENT_BRANCH"
    
    # Check for uncommitted changes
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        print_status "ok" "No uncommitted changes"
    else
        print_status "warning" "Uncommitted changes detected"
    fi
    
    # Check remote
    if git remote get-url origin > /dev/null 2>&1; then
        REMOTE=$(git remote get-url origin)
        print_status "ok" "Git remote configured"
    else
        print_status "warning" "No git remote configured"
    fi
else
    print_status "error" "Not a git repository"
fi

echo ""

# Check 8: Security
echo "🔒 Checking Security Configuration..."
echo "------------------------------------"

# Check .env files are gitignored
if [ -f ".gitignore" ]; then
    if grep -q "\.env\.local" .gitignore; then
        print_status "ok" ".env.local is gitignored"
    else
        print_status "error" ".env.local is NOT gitignored - security risk!"
    fi
    
    if grep -q "\.env" .gitignore; then
        print_status "ok" ".env is gitignored"
    else
        print_status "warning" ".env should be in .gitignore"
    fi
else
    print_status "error" ".gitignore not found"
fi

# Check for exposed secrets in git history
if [ -d ".git" ]; then
    print_status "info" "Checking for exposed secrets..."
    
    # Simple check for common secret patterns
    if git log --all --full-history --source --pickaxe-all -S "sk_live_" > /dev/null 2>&1; then
        FOUND=$(git log --all --full-history --source --pickaxe-all -S "sk_live_" | wc -l)
        if [ $FOUND -gt 0 ]; then
            print_status "error" "Possible Stripe live keys found in git history!"
        else
            print_status "ok" "No obvious secrets in git history"
        fi
    fi
fi

echo ""

# Check 9: Monitoring & Logging
echo "📊 Checking Monitoring & Logging..."
echo "----------------------------------"

# Check if monitoring is configured
if [ ! -z "${SENTRY_DSN:-}" ]; then
    print_status "ok" "Sentry monitoring configured"
else
    print_status "info" "Sentry not configured (optional)"
fi

if [ ! -z "${VERCEL_ANALYTICS_ID:-}" ]; then
    print_status "ok" "Vercel Analytics configured"
else
    print_status "info" "Vercel Analytics not configured (optional)"
fi

# Check for logging configuration
if [ -f "lib/logger.ts" ] || [ -f "lib/logging.ts" ]; then
    print_status "ok" "Logging module found"
else
    print_status "info" "No dedicated logging module found"
fi

echo ""

# Check 10: Health Check Endpoint
echo "🏥 Checking Health Check Endpoint..."
echo "-----------------------------------"

if [ -f "app/api/health/route.ts" ] || [ -f "pages/api/health.ts" ]; then
    print_status "ok" "Health check endpoint exists"
else
    print_status "warning" "No health check endpoint found"
    print_status "info" "Create app/api/health/route.ts for monitoring"
fi

echo ""

# Check 11: Rate Limiting
echo "⏱️  Checking Rate Limiting..."
echo "----------------------------"

if grep -r "rateLimit" app/ --include="*.ts" --include="*.tsx" > /dev/null 2>&1; then
    print_status "ok" "Rate limiting appears to be implemented"
else
    print_status "warning" "No rate limiting detected"
    print_status "info" "Consider implementing rate limiting for API endpoints"
fi

echo ""

# Check 12: CORS Configuration
echo "🌐 Checking CORS Configuration..."
echo "---------------------------------"

if [ -f "middleware.ts" ]; then
    if grep -q "cors\|origin" middleware.ts; then
        print_status "ok" "CORS configuration found in middleware"
    else
        print_status "info" "No CORS configuration in middleware"
    fi
else
    print_status "info" "No middleware.ts file found"
fi

echo ""

# Check 13: SSL/TLS
echo "🔐 Checking SSL/TLS Configuration..."
echo "-----------------------------------"

if [ "$ENVIRONMENT" = "production" ]; then
    # Check if NEXTAUTH_URL uses HTTPS
    if [[ "${NEXTAUTH_URL:-}" == https://* ]]; then
        print_status "ok" "NEXTAUTH_URL uses HTTPS"
    else
        print_status "error" "NEXTAUTH_URL should use HTTPS in production"
    fi
    
    # Check if DATABASE_URL uses SSL
    if [[ "${DATABASE_URL:-}" == *"sslmode=require"* ]]; then
        print_status "ok" "Database connection uses SSL"
    else
        print_status "warning" "Database connection should use SSL in production"
    fi
else
    print_status "info" "SSL checks skipped for $ENVIRONMENT environment"
fi

echo ""

# Check 14: Documentation
echo "📖 Checking Documentation..."
echo "---------------------------"

DOC_FILES=(
    "README.md"
    "docs/DEPLOYMENT.md"
    "docs/ARCHITECTURE.md"
)

for doc in "${DOC_FILES[@]}"; do
    if [ -f "$doc" ]; then
        print_status "ok" "$doc exists"
    else
        print_status "info" "$doc not found (recommended)"
    fi
done

echo ""

# Summary
echo "=========================================================="
echo "📊 Infrastructure Health Check Summary"
echo "=========================================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    print_status "ok" "All infrastructure checks passed!"
elif [ $ERRORS -eq 0 ]; then
    print_status "warning" "Infrastructure check completed with $WARNINGS warning(s)"
else
    print_status "error" "Infrastructure check found $ERRORS error(s) and $WARNINGS warning(s)"
fi

echo ""
echo "📚 For detailed infrastructure guidance, see:"
echo "   - guides/Monitoring-Complete-Guide.md"
echo "   - .cursor/rules/225-infrastructure-monitoring.mdc"
echo "   - .cursor/rules/221-application-monitoring.mdc"
echo ""

# Exit with appropriate code
if [ $ERRORS -gt 0 ]; then
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    exit 0  # Warnings don't fail the check
else
    exit 0
fi

