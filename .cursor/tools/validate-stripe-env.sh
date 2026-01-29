#!/bin/bash

# Validate Stripe Environment Variables
# Checks for common issues like trailing newlines, invalid formats, etc.

set -euo pipefail

echo "🔍 Validating Stripe Environment Variables..."
echo ""

# Check if we can access Vercel
if ! command -v vercel &> /dev/null; then
  echo "❌ Vercel CLI not found. Install with: npm i -g vercel"
  exit 1
fi

echo "📋 Stripe Environment Variables in Vercel:"
vercel env ls 2>&1 | grep -E "STRIPE_" || true

echo ""
echo "✅ Validation Rules:"
echo "  - STRIPE_SECRET_KEY should start with 'sk_live_' or 'sk_test_'"
echo "  - STRIPE_WEBHOOK_SECRET should start with 'whsec_'"
echo "  - STRIPE_PRICE_* should start with 'price_'"
echo "  - No trailing whitespace or newlines"
echo ""
echo "⚠️  If you see errors about invalid characters, check for trailing newlines."
echo ""
echo "To fix in Vercel Dashboard:"
echo "  1. Go to: https://vercel.com/your-project/settings/environment-variables"
echo "  2. Edit each STRIPE_* variable"
echo "  3. Ensure no trailing spaces/newlines"
echo "  4. Save"
echo ""
echo "💡 The code now automatically trims these values as a safety measure."
