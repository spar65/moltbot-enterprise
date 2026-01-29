# 🚨 CRITICAL Production Safety & Deployment Guide

**THIS GUIDE CONTAINS CRITICAL PRODUCTION GOTCHAS THAT CAN BREAK YOUR ENTIRE APPLICATION**

Use this guide to prevent catastrophic production failures and ensure safe deployments.

## 🔥 CRITICAL VERCEL GOTCHAS

### ⚠️ NEVER Use `NEXT_PHASE === 'phase-production-build'` for Database Skipping

**ISSUE**: Vercel sets `NEXT_PHASE=phase-production-build` during **PRODUCTION RUNTIME**, not just builds!

**IMPACT**:

- ❌ ALL database operations silently fail in production
- ❌ Database connections return empty mock functions
- ❌ Data saves fail with no error messages
- ❌ Works perfectly in test/development but fails in production

**BAD CODE** (Will break production):

```typescript
// ❌ NEVER DO THIS - Breaks production database!
const shouldSkipDatabase = process.env.NEXT_PHASE === "phase-production-build";
```

**GOOD CODE** (Production safe):

```typescript
// ✅ SAFE - Only skip during actual CI builds without database
const shouldSkipDatabase =
  process.env.SKIP_AUTH0_CHECK === "true" ||
  (process.env.CI === "true" && !process.env.DATABASE_URL);
```

**FILES TO CHECK:**

- `src/lib/database.ts`
- `src/lib/neonDatabase.ts`
- `src/lib/prisma.ts`
- Any file with database skip logic

### ⚠️ NEVER Set Environment Variables in Build Commands OR vercel.json

**ISSUE**: Environment variables set in `package.json` build commands OR `vercel.json` persist into production runtime!

**ROOT CAUSES DISCOVERED**: 
1. **Package.json build commands:** `"build:vercel": "SKIP_AUTH0_CHECK=true next build"`
2. **⚠️ CRITICAL: vercel.json global env vars:** `{ "env": { "SKIP_AUTH0_CHECK": "true" } }`

Both set `SKIP_AUTH0_CHECK=true` that persists into production runtime!
- Result: Database operations fail in production

**IMPACT**:
- ❌ Database is skipped in production runtime
- ❌ All data saves silently fail
- ❌ Works in test/dev but breaks in production
- ❌ `shouldSkipDatabase` evaluates to `true` in production

**BAD CODE** (Will break production):
```json
// package.json
{
  "scripts": {
    "build:vercel": "SKIP_AUTH0_CHECK=true next build"
  }
}
```

```json
// vercel.json - EVEN WORSE!
{
  "env": {
    "SKIP_AUTH0_CHECK": "true"
  }
}
```

**GOOD CODE** (Production safe):
```json
// package.json - Use build-specific flags
{
  "scripts": {
    "build:vercel": "VERCEL_BUILD=true npm run auth0:check && next build"
  }
}
```

```bash
# NO vercel.json file needed! Let Next.js handle configuration.
# Vercel will use package.json scripts and next.config.js automatically.
```

**DETECTION**: Check `/api/debug/env-check` for unexpected environment variables in production.

**FILES TO CHECK:**
- `package.json` (all build scripts)
- **`vercel.json` (DELETE if it sets env vars!)**
- Any script that sets environment variables
- Vercel deployment settings

### ⚠️ Database Environment Variable Gotchas

**ISSUE**: Vercel prefixes some database environment variables

**CHECK FOR**:

- `PRODUCTION_POSTGRES_URL_DATABASE_URL` (Vercel's prefix)
- `POSTGRES_URL` (backup variable)
- `DATABASE_URL` (primary variable)

**SAFE FALLBACK**:

```typescript
// ✅ Handle all possible Vercel database URL variations
let databaseUrl =
  process.env.DATABASE_URL ||
  process.env.PRODUCTION_POSTGRES_URL_DATABASE_URL ||
  process.env.POSTGRES_URL;
```

## 🔒 MANDATORY Pre-Deployment Checks

### 1. Database Skip Logic Audit

```bash
# Check for dangerous NEXT_PHASE usage
grep -r "NEXT_PHASE.*phase-production-build" src/
# Should return NO results or only safe implementations
```

### 2. Environment Variable Validation

```bash
# Verify all required environment variables are set
node scripts/validate-environment.js
```

### 3. Production Database Connection Test

```bash
# Test database connection with production URL
SKIP_AUTH0_CHECK=false DATABASE_URL="your-prod-url" npm run test:db-connection
```

### 4. Claude AI Token Limits Check

```bash
# Verify max_tokens are within limits (32,000 max for Claude)
grep -r "max_tokens.*[0-9]" src/lib/
```

## 🛡️ CRITICAL Security Checks

### WAF & Rate Limiting

- [ ] Vercel Advanced Protection enabled
- [ ] Rate limiting configured for all API endpoints
- [ ] Bot protection enabled
- [ ] Security headers properly configured

### Environment Variables Security

- [ ] No sensitive data in client-side variables (`NEXT_PUBLIC_*`)
- [ ] All production secrets are properly set
- [ ] Test environment variables removed from production

### Database Security

- [ ] Production database uses SSL
- [ ] Database user has minimal required permissions
- [ ] Connection pooling properly configured

## 🚀 Deployment Safety Protocol

### Phase 1: Pre-Deployment Validation

```bash
# 1. Run full test suite
npm test

# 2. Lint all code
npm run lint

# 3. Security audit
npm audit --audit-level=high

# 4. Build test
npm run build

# 5. Critical checks
./scripts/pre-deployment-safety-check.sh
```

### Phase 2: Staging Deployment

- [ ] Deploy to staging environment first
- [ ] Test ALL critical user flows
- [ ] Verify database operations work
- [ ] Test AI generation and data persistence
- [ ] Load test critical endpoints

### Phase 3: Production Deployment

- [ ] Database backup completed
- [ ] Rollback plan documented
- [ ] Monitoring alerts configured
- [ ] Deploy during low-traffic window
- [ ] Immediate post-deployment verification

### Phase 4: Post-Deployment Verification

```bash
# Critical functionality tests
curl https://your-domain.us/api/health
curl https://your-domain.us/api/debug/database-connection-test
```

- [ ] Database operations working
- [ ] Authentication flow working
- [ ] AI generation working
- [ ] Data persistence working
- [ ] All critical user flows working

## 🚨 Emergency Rollback Procedures

### Immediate Rollback Triggers

- Database operations failing
- Authentication not working
- 500 errors on critical endpoints
- AI generation completely failing
- Data loss detected

### Rollback Steps

1. **Immediate**: Revert to previous Vercel deployment
2. **Database**: Restore from backup if schema changes were made
3. **Monitoring**: Monitor error rates and user reports
4. **Communication**: Notify team and users if necessary

## 📋 Production Safety Checklist

### Code Safety

- [ ] No `NEXT_PHASE === 'phase-production-build'` in database logic
- [ ] Database fallback URLs configured
- [ ] Error handling for all database operations
- [ ] Timeout configurations for AI API calls
- [ ] Rate limiting implemented

### Environment Safety

- [ ] All production environment variables set
- [ ] No test/development variables in production
- [ ] Database URL points to production database
- [ ] AI API keys are production keys
- [ ] Authentication configured for production domain

### Third-Party Services

- [ ] Auth0 configured for production domain
- [ ] Stripe using live keys (not test keys)
- [ ] Webhook endpoints updated
- [ ] Email services configured for production
- [ ] Analytics tracking configured

### Monitoring & Alerts

- [ ] Error monitoring configured
- [ ] Performance monitoring enabled
- [ ] Database monitoring active
- [ ] Alert notifications configured
- [ ] Log aggregation working

## 🛠️ Production Safety Scripts

Create these scripts in your `scripts/` directory:

### `scripts/pre-deployment-safety-check.sh`

```bash
#!/bin/bash
echo "🔍 Running Critical Production Safety Checks..."

# Check for dangerous database skip patterns
echo "Checking for dangerous NEXT_PHASE usage..."
if grep -r "NEXT_PHASE.*phase-production-build" src/; then
    echo "❌ DANGEROUS: Found NEXT_PHASE database skip logic!"
    echo "This will break production database operations!"
    exit 1
fi

# Verify environment variables
echo "Validating environment variables..."
node scripts/validate-environment.js || exit 1

# Check Claude token limits
echo "Checking Claude API token limits..."
if grep -r "max_tokens.*[0-9]" src/lib/ | grep -E "max_tokens.*[0-9]{5,}"; then
    echo "❌ WARNING: Found max_tokens values that may be too high"
    echo "Claude max is 32,000 tokens"
fi

echo "✅ All critical safety checks passed!"
```

### `scripts/validate-environment.js`

```javascript
#!/usr/bin/env node

const requiredVars = [
  "DATABASE_URL",
  "AUTH0_SECRET",
  "AUTH0_CLIENT_ID",
  "AUTH0_CLIENT_SECRET",
  "ENCRYPTION_KEY",
  "CLAUDE_API_KEY",
];

const warnings = [];
const errors = [];

// Check required variables
requiredVars.forEach((varName) => {
  if (!process.env[varName]) {
    errors.push(`Missing required environment variable: ${varName}`);
  }
});

// Check for test variables in production
const testVars = Object.keys(process.env).filter(
  (key) => key.includes("TEST_") || key.includes("_TEST")
);

if (testVars.length > 0) {
  warnings.push(`Found test environment variables: ${testVars.join(", ")}`);
}

// Check Claude token limits
const claudeFiles = [
  "src/lib/claude-retry.ts",
  "src/lib/prd-generator-progressive.ts",
];
// Add validation logic here

// Report results
if (warnings.length > 0) {
  console.log("⚠️  WARNINGS:");
  warnings.forEach((warning) => console.log(`   ${warning}`));
}

if (errors.length > 0) {
  console.log("❌ ERRORS:");
  errors.forEach((error) => console.log(`   ${error}`));
  process.exit(1);
}

console.log("✅ Environment validation passed!");
```

## 📚 Related Documentation

- [Vercel Deployment Guide](./Vercel-Deployment-Guide.md)
- [Vercel Deployment Checklist](./Vercel-Deployment-Checklist.md)
- [Security Configuration Guide](./Security-Configuration-Guide.md)

---

## 🎯 Remember: Safety First!

**The goal is to prevent production disasters, not just deploy quickly.**

- When in doubt, test in staging first
- Never skip safety checks to meet deadlines
- Document any workarounds or exceptions
- Always have a rollback plan ready

**This guide was created after a critical production incident where `NEXT_PHASE` logic caused complete database failure in production while working perfectly in development.**
