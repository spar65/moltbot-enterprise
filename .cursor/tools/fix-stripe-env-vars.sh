#!/bin/bash

# Fix Stripe Environment Variables in Vercel
# Removes trailing newlines/whitespace from Stripe env vars

set -euo pipefail

PROJECT_NAME="compsi"
ENVIRONMENT="production"

echo "🔧 Fixing Stripe Environment Variables in Vercel"
echo "Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT"
echo ""

# List current Stripe env vars
echo "📋 Current Stripe environment variables:"
vercel env ls 2>&1 | grep -E "STRIPE_" || true

echo ""
echo "⚠️  IMPORTANT: This script requires you to provide the actual values."
echo "   Since env vars are encrypted, we can't read them directly."
echo ""
echo "📝 Steps to fix trailing newlines:"
echo ""
echo "Option 1: Via Vercel Dashboard (Recommended)"
echo "  1. Go to: https://vercel.com/greg-spehars-projects/compsi/settings/environment-variables"
echo "  2. For each STRIPE_* variable:"
echo "     a. Click 'Edit'"
echo "     b. Copy the entire value"
echo "     c. Paste into a text editor"
echo "     d. Remove any trailing spaces/newlines (end of line)"
echo "     e. Copy the trimmed value"
echo "     f. Paste back into Vercel and save"
echo ""
echo "Option 2: Via Vercel CLI (if you have the values)"
echo "  For each variable, run:"
echo ""
echo "  # Remove old value"
echo "  vercel env rm STRIPE_SECRET_KEY $ENVIRONMENT"
echo ""
echo "  # Add trimmed value (no trailing newline)"
echo "  echo -n 'sk_live_...' | vercel env add STRIPE_SECRET_KEY $ENVIRONMENT"
echo ""
echo "  Variables to fix:"
echo "    - STRIPE_SECRET_KEY"
echo "    - STRIPE_WEBHOOK_SECRET"
echo "    - STRIPE_PRICE_STARTER"
echo "    - STRIPE_PRICE_PROFESSIONAL"
echo "    - STRIPE_PRICE_BUSINESS"
echo "    - STRIPE_PRICE_SCALE"
echo "    - STRIPE_PRICE_ENTERPRISE"
echo ""
echo "💡 Tip: Use 'echo -n' to avoid adding trailing newlines when setting values"
echo ""
echo "✅ Note: The code now automatically trims these values as a safety measure,"
echo "   but fixing at the source prevents issues and is cleaner."
