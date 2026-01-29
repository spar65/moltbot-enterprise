# Security Workflows - AI-Assisted Development Patterns

**Last Updated:** 2024-11-19  
**Status:** ✅ Production-Ready  
**Success Rate:** Target 95%+ first-run success  

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Environment Variable Security Workflow](#environment-variable-security-workflow)
3. [Auth0 Integration Workflow](#auth0-integration-workflow)
4. [Payment Security Workflow](#payment-security-workflow)
5. [Dependency Management Workflow](#dependency-management-workflow)
6. [Secret Management Workflow](#secret-management-workflow)
7. [Pre-Deployment Security Checklist](#pre-deployment-security-checklist)

---

## Quick Reference

### 🔥 Before ANY Security-Related Work

```bash
# 1. Scan for existing secrets
./.cursor/tools/scan-secrets.sh

# 2. Check environment variables
./.cursor/tools/check-env-vars.sh

# 3. Audit dependencies
./.cursor/tools/audit-dependencies.sh

# 4. Check auth configuration
./.cursor/tools/check-auth-config.sh
```

### 📚 Related Rules
- **Rule 010:** security-compliance.mdc
- **Rule 011:** env-var-security.mdc
- **Rule 012:** api-security.mdc
- **Rule 014:** third-party-auth.mdc
- **Rule 019:** auth0-integration.mdc
- **Rule 020:** payment-security.mdc

---

## Environment Variable Security Workflow

### When to Use
- Adding new API integrations
- Handling sensitive configuration
- Client vs server code separation

### Step-by-Step Process

**Step 1: Plan Environment Variables**
```bash
# Determine visibility
- Client-side → NEXT_PUBLIC_* prefix
- Server-side → No prefix
- Never both!

# Example:
✅ NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY  # Client-safe
✅ STRIPE_SECRET_KEY                    # Server-only
❌ STRIPE_KEY                           # Ambiguous!
```

**Step 2: Add to .env.example**
```bash
# .env.example - Placeholder values only!
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_your_key_here
STRIPE_SECRET_KEY=sk_test_your_secret_here
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
```

**Step 3: Add Real Values to .env.local**
```bash
# app/.env.local - NEVER commit this file!
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_51K...
STRIPE_SECRET_KEY=sk_test_51K...
DATABASE_URL=postgresql://...
```

**Step 4: Verify Security**
```bash
# Run security checks
./.cursor/tools/check-env-vars.sh

# Should verify:
✅ No secrets in .env.example
✅ All env vars documented
✅ Client/server separation correct
✅ .env files in .gitignore
```

**Step 5: Use in Code**

**Server-side (API routes, server components):**
```typescript
// ✅ CORRECT - Server-only
export async function POST(request: Request) {
  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
  // Safe - never sent to client
}
```

**Client-side (React components):**
```typescript
// ✅ CORRECT - Client-safe
export default function CheckoutButton() {
  const publishableKey = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY;
  // Safe - designed for client
}
```

**❌ NEVER DO THIS:**
```typescript
// ❌ WRONG - Server secret in client code!
export default function PaymentForm() {
  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
  // DANGER: Secret exposed to browser!
}
```

### Success Metrics
- ✅ Zero secrets in .env.example
- ✅ Zero secrets in client bundles
- ✅ All secrets documented
- ✅ Proper NEXT_PUBLIC_ usage

---

## Auth0 Integration Workflow

### When to Use
- Implementing authentication
- Adding user management
- Session handling

### Step-by-Step Process

**Step 1: Install Auth0 SDK**
```bash
cd app
npm install @auth0/nextjs-auth0
```

**Step 2: Configure Environment Variables**
```bash
# Generate strong secret
openssl rand -hex 32

# Add to app/.env.local
AUTH0_SECRET='<generated-secret-from-above>'
AUTH0_BASE_URL='http://localhost:3000'  # Dev
AUTH0_ISSUER_BASE_URL='https://YOUR_DOMAIN.auth0.com'
AUTH0_CLIENT_ID='<your-client-id>'
AUTH0_CLIENT_SECRET='<your-client-secret>'
```

**Step 3: Add to .env.example**
```bash
# app/.env.example
AUTH0_SECRET=your-auth0-secret-here-min-32-chars
AUTH0_BASE_URL=http://localhost:3000
AUTH0_ISSUER_BASE_URL=https://YOUR_DOMAIN.auth0.com
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-client-secret
```

**Step 4: Create Auth Configuration**
```typescript
// app/lib/auth0.ts
import { initAuth0 } from '@auth0/nextjs-auth0';

export default initAuth0({
  secret: process.env.AUTH0_SECRET,
  issuerBaseURL: process.env.AUTH0_ISSUER_BASE_URL,
  baseURL: process.env.AUTH0_BASE_URL,
  clientID: process.env.AUTH0_CLIENT_ID,
  clientSecret: process.env.AUTH0_CLIENT_SECRET,
  
  // Security best practices
  session: {
    cookie: {
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      httpOnly: true,
    },
    absoluteDuration: 60 * 60 * 24 * 7, // 7 days
    rolling: true,
    rollingDuration: 60 * 60 * 24, // 1 day
  },
});
```

**Step 5: Verify Configuration**
```bash
# Run auth config check
./.cursor/tools/check-auth-config.sh

# Should verify:
✅ All Auth0 env vars present
✅ AUTH0_SECRET strong enough (32+ chars)
✅ No secrets in client code
✅ Secure cookies configured
```

**Step 6: Implement Auth Routes**
```typescript
// app/api/auth/[auth0]/route.ts
import { handleAuth } from '@auth0/nextjs-auth0';

export const GET = handleAuth();
```

**Step 7: Use in Application**

**Server Component:**
```typescript
// app/dashboard/page.tsx
import { getSession } from '@auth0/nextjs-auth0';

export default async function Dashboard() {
  const session = await getSession();
  
  if (!session) {
    redirect('/api/auth/login');
  }
  
  return <div>Welcome {session.user.name}</div>;
}
```

**Client Component:**
```typescript
// app/components/LoginButton.tsx
'use client';
import { useUser } from '@auth0/nextjs-auth0/client';

export default function LoginButton() {
  const { user, isLoading } = useUser();
  
  if (isLoading) return <div>Loading...</div>;
  
  return user ? (
    <a href="/api/auth/logout">Logout</a>
  ) : (
    <a href="/api/auth/login">Login</a>
  );
}
```

### Success Metrics
- ✅ Auth0 configured correctly
- ✅ Sessions secure (HTTPS, httpOnly)
- ✅ No secrets exposed to client
- ✅ Proper session timeout

---

## Payment Security Workflow

### When to Use
- Stripe integration
- Payment processing
- Subscription management

### Step-by-Step Process

**Step 1: Never Handle Card Data Directly**
```typescript
// ❌ NEVER DO THIS
const cardNumber = request.body.cardNumber;  // PCI violation!

// ✅ ALWAYS USE STRIPE ELEMENTS
// Client-side tokenization only
```

**Step 2: Configure Stripe Keys**
```bash
# app/.env.local
STRIPE_SECRET_KEY=sk_test_...           # Server-only!
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...  # Client-safe
STRIPE_WEBHOOK_SECRET=whsec_...         # Server-only!
```

**Step 3: Server-Side Payment Intent**
```typescript
// app/api/create-payment-intent/route.ts
import Stripe from 'stripe';
import { getSession } from '@auth0/nextjs-auth0';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export async function POST(request: Request) {
  // 1. Verify authentication
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }
  
  // 2. Validate amount server-side (NEVER trust client)
  const { amount } = await request.json();
  const validatedAmount = validateAmount(amount);
  
  // 3. Create payment intent
  const paymentIntent = await stripe.paymentIntents.create({
    amount: validatedAmount,
    currency: 'usd',
    metadata: {
      userId: session.user.sub,
      organizationId: session.user.organizationId,
    },
  });
  
  // 4. Return client secret (safe to send to client)
  return NextResponse.json({
    clientSecret: paymentIntent.client_secret,
  });
}
```

**Step 4: Client-Side Payment Form**
```typescript
// app/components/PaymentForm.tsx
'use client';
import { Elements, PaymentElement } from '@stripe/react-stripe-js';
import { loadStripe } from '@stripe/stripe-js';

const stripePromise = loadStripe(
  process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!
);

export default function PaymentForm() {
  return (
    <Elements stripe={stripePromise}>
      <PaymentElement />
      {/* Stripe handles card data securely */}
    </Elements>
  );
}
```

**Step 5: Webhook Security**
```typescript
// app/api/webhooks/stripe/route.ts
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!;

export async function POST(request: Request) {
  const body = await request.text();
  const signature = request.headers.get('stripe-signature')!;
  
  try {
    // Verify webhook signature
    const event = stripe.webhooks.constructEvent(
      body,
      signature,
      webhookSecret
    );
    
    // Process event
    switch (event.type) {
      case 'payment_intent.succeeded':
        // Handle successful payment
        break;
      // ... other events
    }
    
    return NextResponse.json({ received: true });
  } catch (err) {
    return NextResponse.json(
      { error: 'Webhook signature verification failed' },
      { status: 400 }
    );
  }
}
```

### Success Metrics
- ✅ Never handle raw card data
- ✅ Server-side amount validation
- ✅ Webhook signature verification
- ✅ Proper error handling

---

## Dependency Management Workflow

### When to Use
- Adding new packages
- Before deployments
- Weekly security audits

### Step-by-Step Process

**Step 1: Before Adding New Package**
```bash
# Check package security
npm info <package-name>

# Look for:
- Last publish date (avoid stale packages)
- Weekly downloads (popularity indicator)
- License (compatibility with your project)
- Known vulnerabilities
```

**Step 2: Add Package**
```bash
cd app
npm install <package-name>
```

**Step 3: Audit Immediately**
```bash
# Run security audit
./.cursor/tools/audit-dependencies.sh

# Should check:
✅ No critical vulnerabilities
✅ No high-severity issues
✅ Compatible licenses
✅ Packages up to date
```

**Step 4: Address Issues**
```bash
# If vulnerabilities found:
npm audit fix

# If audit fix doesn't work:
npm audit fix --force  # May have breaking changes

# If still not fixed:
# Find alternative package or mitigate risk
```

**Step 5: Regular Audits**
```bash
# Weekly security check
npm audit

# Check for outdated packages
npm outdated

# Update non-breaking
npm update

# Update breaking (carefully!)
npm install <package>@latest
```

### Success Metrics
- ✅ Zero critical vulnerabilities
- ✅ Zero high-severity issues
- ✅ Compatible licenses
- ✅ Regular audit schedule

---

## Secret Management Workflow

### When to Use
- New API integrations
- Before commits
- Security reviews

### Step-by-Step Process

**Step 1: Scan for Secrets**
```bash
# Full repository scan
./.cursor/tools/scan-secrets.sh

# Scan specific directory
./.cursor/tools/scan-secrets.sh app/lib
```

**Step 2: If Secrets Found - Immediate Action**
```bash
# 1. Remove from code
# 2. Move to environment variables
# 3. Add to .gitignore

# 4. If already committed:
#    a. Rotate the secret immediately!
#    b. Update in production
#    c. Consider git history cleanup
```

**Step 3: Rotate Exposed Secrets**
```bash
# Stripe
stripe.com/dashboard → Developers → API keys → Roll keys

# Auth0
Auth0 Dashboard → Applications → Your App → Rotate secret

# Database
# Update password, update connection strings
```

**Step 4: Prevent Future Exposure**
```bash
# Add pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
./.cursor/tools/scan-secrets.sh
if [ $? -ne 0 ]; then
  echo "❌ Secrets detected! Commit blocked."
  exit 1
fi
EOF

chmod +x .git/hooks/pre-commit
```

### Success Metrics
- ✅ No hardcoded secrets
- ✅ All secrets in environment variables
- ✅ Pre-commit hooks active
- ✅ Regular scans scheduled

---

## Pre-Deployment Security Checklist

### Before EVERY Production Deploy

```bash
# 1. Scan for secrets
echo "🔍 Scanning for secrets..."
./.cursor/tools/scan-secrets.sh || exit 1

# 2. Check environment variables
echo "🔐 Checking environment variables..."
./.cursor/tools/check-env-vars.sh || exit 1

# 3. Audit dependencies
echo "📦 Auditing dependencies..."
./.cursor/tools/audit-dependencies.sh || exit 1

# 4. Check auth configuration
echo "🔑 Checking auth configuration..."
./.cursor/tools/check-auth-config.sh || exit 1

# 5. Run tests
echo "🧪 Running tests..."
npm run test || exit 1

echo "✅ All security checks passed! Safe to deploy."
```

### Manual Checklist

- [ ] All environment variables set in Vercel/production
- [ ] HTTPS enabled
- [ ] Secure cookies configured
- [ ] CORS properly configured
- [ ] Rate limiting enabled
- [ ] Error messages don't expose sensitive data
- [ ] Audit logs enabled
- [ ] Backup strategy in place
- [ ] Incident response plan documented

---

## Success Stories

### Environment Variable Migration
**Before:** Hardcoded API keys in 12 files  
**After:** All keys in environment variables  
**Time:** 45 minutes using check-env-vars.sh  
**Result:** Zero secrets in codebase

### Dependency Audit
**Before:** 5 critical, 12 high vulnerabilities  
**After:** 0 critical, 0 high vulnerabilities  
**Time:** 30 minutes using audit-dependencies.sh  
**Result:** Production-safe dependencies

### Auth0 Setup
**Before:** Manual configuration, missed secure cookies  
**After:** Automated validation, all security flags set  
**Time:** 1 hour using check-auth-config.sh  
**Result:** Enterprise-grade authentication

---

## Tools Quick Reference

```bash
# Environment variables
./.cursor/tools/check-env-vars.sh

# Dependencies
./.cursor/tools/audit-dependencies.sh

# Authentication
./.cursor/tools/check-auth-config.sh

# Secrets
./.cursor/tools/scan-secrets.sh

# All checks
./.cursor/tools/check-env-vars.sh && \
./.cursor/tools/audit-dependencies.sh && \
./.cursor/tools/check-auth-config.sh && \
./.cursor/tools/scan-secrets.sh
```

---

## See Also

- **`.cursor/docs/rules-guide.md`** - Complete rule system
- **`.cursor/docs/tools-guide.md`** - All automation tools
- **`.cursor/docs/ai-workflows.md`** - General development patterns
- **`.cursor/docs/security-checklist.md`** - Pre-deployment checklist

**Related Rules:**
- Rule 010: security-compliance.mdc
- Rule 011: env-var-security.mdc
- Rule 012: api-security.mdc
- Rule 020: payment-security.mdc

