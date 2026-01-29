# Deployment Workflow Complete Guide

**Last Updated**: November 20, 2025  
**Status**: Production-Ready  
**Purpose**: Step-by-step guide for safe, reliable deployments to Vercel

---

## 🎯 Quick Reference

### Pre-Deployment Checklist
```bash
# Run all safety checks
./.cursor/tools/check-env-vars.sh
./.cursor/tools/check-auth-config.sh
./.cursor/tools/check-infrastructure.sh
./.cursor/tools/check-backups.sh

# Run tests
npm run test
npm run test:integration

# Build locally
npm run build
```

### Emergency Contacts
- **On-Call Engineer**: [Your contact info]
- **Database Admin**: [Your contact info]
- **Vercel Dashboard**: https://vercel.com/[your-org]

### Rollback Command
```bash
# See: @202-rollback-procedures.mdc
vercel rollback [deployment-url]
```

---

## 📋 Table of Contents

1. [Deployment Phases](#deployment-phases)
2. [Phase 1: Pre-Deployment](#phase-1-pre-deployment)
3. [Phase 2: Staging Deployment](#phase-2-staging-deployment)
4. [Phase 3: Production Deployment](#phase-3-production-deployment)
5. [Phase 4: Post-Deployment](#phase-4-post-deployment)
6. [Emergency Procedures](#emergency-procedures)
7. [Common Issues](#common-issues)
8. [Best Practices](#best-practices)

---

## Deployment Phases

### Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Pre-Deployment │ --> │    Staging      │ --> │   Production    │ --> │ Post-Deployment │
│   Validation    │     │   Deployment    │     │   Deployment    │     │   Monitoring    │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
      30 min                   15 min                   5 min                  30 min
```

**Total Time**: ~80 minutes for normal deployment  
**Emergency Hotfix**: ~20 minutes (see @804-hotfix-procedures.mdc)

---

## Phase 1: Pre-Deployment

**Duration**: ~30 minutes  
**Goal**: Ensure code is ready and safe for production

### 1.1 Code Review ✅

**Requirements**:
- [ ] All code reviewed and approved (see @101-code-review-standards.mdc)
- [ ] No unresolved review comments
- [ ] PR approved by at least 1 senior engineer
- [ ] All CI checks passing

**Tools**:
```bash
# Check PR status
gh pr view --json state,reviews,statusCheckRollup

# Verify branch is up to date
git fetch origin
git status
```

---

### 1.2 Test Validation ✅

**Requirements**:
- [ ] All unit tests passing
- [ ] All integration tests passing
- [ ] Manual testing completed for new features
- [ ] No test failures or skipped tests

**Commands**:
```bash
# Run all tests
npm run test

# Run integration tests
npm run test:integration

# Check test coverage (optional)
npm run test:coverage
```

**Related Rules**:
- @300-testing-standards.mdc
- @380-comprehensive-testing-standards.mdc
- @331-high-risk-feature-testing.mdc

---

### 1.3 Security Audit ✅

**Requirements**:
- [ ] Environment variables validated
- [ ] No hardcoded secrets
- [ ] Auth0 configuration valid
- [ ] No SKIP_* variables in build scripts
- [ ] Dependencies audited

**Commands**:
```bash
# Run all security checks
./.cursor/tools/check-env-vars.sh
./.cursor/tools/check-auth-config.sh
./.cursor/tools/scan-secrets.sh
./.cursor/tools/audit-dependencies.sh
```

**Critical Checks**:
```bash
# 1. Check for dangerous build script patterns
grep -r "SKIP_.*=" package.json
grep -r "DATABASE_SKIP" package.json

# 2. Check for vercel.json with env vars (should be deleted!)
cat vercel.json 2>/dev/null | grep -A 10 '"env"'

# 3. Verify no secrets in code
git diff origin/main | grep -i "password\|secret\|api_key\|token"
```

**Related Rules**:
- @011-env-var-security.mdc
- @204-vercel-build-environment-variables.mdc
- @224-secrets-management.mdc

---

### 1.4 Database Safety ✅

**Requirements**:
- [ ] Database backup verified
- [ ] Migration scripts reviewed
- [ ] Rollback plan documented
- [ ] No destructive schema changes without approval

**Commands**:
```bash
# Check backups
./.cursor/tools/check-backups.sh

# Review migrations (if any)
ls -la prisma/migrations/

# Test migration locally
npx prisma migrate dev
```

**⚠️ High-Risk Changes**:
- Schema changes (add/remove/rename columns)
- Data migrations
- Index changes
- Foreign key changes

**For High-Risk Changes**:
1. Deploy migration separately from code changes
2. Test migration in staging first
3. Have rollback SQL ready
4. Monitor database performance after deployment

**Related Rules**:
- @208-database-operations.mdc
- @212-backup-recovery-standards.mdc

---

### 1.5 Infrastructure Validation ✅

**Requirements**:
- [ ] All external services healthy (Auth0, Stripe, etc.)
- [ ] Rate limits configured
- [ ] Monitoring alerts configured
- [ ] Infrastructure ready for deployment

**Commands**:
```bash
# Check infrastructure
./.cursor/tools/check-infrastructure.sh

# Verify Vercel project settings
vercel env ls

# Check rate limits (if configured)
# Check monitoring dashboards
```

**Related Rules**:
- @200-deployment-infrastructure.mdc
- @221-application-monitoring.mdc
- @225-infrastructure-monitoring.mdc

---

### 1.6 Build Validation ✅

**Requirements**:
- [ ] Build succeeds locally
- [ ] No build warnings (critical)
- [ ] Bundle size acceptable
- [ ] Type checking passes

**Commands**:
```bash
# Clean build
rm -rf .next
npm run build

# Check bundle size
./.cursor/tools/check-bundle-size.sh

# Type check
npm run type-check

# Lint check
npm run lint
```

**Bundle Size Limits**:
- First Load JS: < 150 KB (warning at 100 KB)
- Total bundle: < 1 MB
- Individual pages: < 50 KB

**Related Rules**:
- @061-code-splitting.mdc
- @062-core-web-vitals.mdc
- @105-typescript-linter-standards.mdc

---

## Phase 2: Staging Deployment

**Duration**: ~15 minutes  
**Goal**: Validate changes in production-like environment

### 2.1 Deploy to Staging 🚀

**Requirements**:
- [ ] Staging environment mirrors production
- [ ] Uses production-like database
- [ ] All environment variables configured

**Commands**:
```bash
# Deploy to staging (preview deployment)
git checkout your-branch
vercel --env preview

# Or use GitHub PR preview
# Vercel automatically deploys PR previews
```

**Staging Environment**:
- **URL**: https://your-app-[hash].vercel.app
- **Database**: Staging database (separate from production)
- **Auth0**: Staging tenant
- **Stripe**: Test mode

---

### 2.2 Smoke Tests ☁️

**Requirements**:
- [ ] Authentication flow works
- [ ] Critical user flows tested
- [ ] Database operations verified
- [ ] Third-party integrations tested

**Manual Tests**:
1. **Authentication**:
   - [ ] Login works
   - [ ] Logout works
   - [ ] Session persistence
   - [ ] Role-based access

2. **Critical Flows**:
   - [ ] User creation
   - [ ] Data creation/read/update/delete
   - [ ] Payment processing (test mode)
   - [ ] AI generation (if applicable)

3. **Database**:
   - [ ] Data persists correctly
   - [ ] Queries return expected results
   - [ ] No console errors

**Test Endpoints**:
```bash
# Test health check
curl https://your-staging-url.vercel.app/api/health

# Test auth
curl https://your-staging-url.vercel.app/api/auth/session

# Test environment (internal only)
curl https://your-staging-url.vercel.app/api/debug/env-check
```

**Related Rules**:
- @330-third-party-integration-testing.mdc
- @331-high-risk-feature-testing.mdc

---

### 2.3 Performance Testing ⚡

**Requirements**:
- [ ] Core Web Vitals acceptable
- [ ] API response times < 1s
- [ ] No memory leaks
- [ ] Bundle size within limits

**Commands**:
```bash
# Run Lighthouse
./.cursor/tools/run-lighthouse.sh https://your-staging-url.vercel.app

# Check performance
./.cursor/tools/analyze-performance.sh
```

**Performance Thresholds**:
- **LCP** (Largest Contentful Paint): < 2.5s
- **INP** (Interaction to Next Paint): < 200ms
- **CLS** (Cumulative Layout Shift): < 0.1
- **TTFB** (Time to First Byte): < 600ms

**Related Rules**:
- @062-core-web-vitals.mdc
- @067-runtime-optimization.mdc

---

### 2.4 Security Scanning 🔒

**Requirements**:
- [ ] No security vulnerabilities detected
- [ ] No exposed secrets
- [ ] HTTPS enforced
- [ ] Security headers configured

**Commands**:
```bash
# Check security headers
curl -I https://your-staging-url.vercel.app

# Verify HTTPS redirect
curl -I http://your-staging-url.vercel.app

# Check for exposed secrets (manual review)
# Open browser dev tools > Network > Check responses
```

**Expected Security Headers**:
- `Strict-Transport-Security`
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Content-Security-Policy`

**Related Rules**:
- @010-security-compliance.mdc
- @220-security-monitoring.mdc

---

## Phase 3: Production Deployment

**Duration**: ~5 minutes  
**Goal**: Deploy to production safely

### 3.1 Final Pre-Production Checks ✅

**Requirements**:
- [ ] All staging tests passed
- [ ] Team notified of deployment
- [ ] Rollback plan documented
- [ ] Monitoring dashboards open

**Pre-Deployment Notification**:
```
🚀 PRODUCTION DEPLOYMENT STARTING

Branch: [branch-name]
Changes: [brief description]
Staging URL: [staging-url]
Risk Level: [Low/Medium/High]
Rollback Plan: [link to plan]
ETA: 5 minutes
```

---

### 3.2 Production Database Backup 💾

**CRITICAL**: Always backup before schema changes!

**Requirements**:
- [ ] Production backup completed
- [ ] Backup verified and accessible
- [ ] Backup timestamp recorded

**Commands**:
```bash
# Verify latest backup
./.cursor/tools/check-backups.sh

# For manual backup (if needed)
# See: guides/Database-Operations-Complete-Guide.md
```

**Related Rules**:
- @208-database-operations.mdc
- @212-backup-recovery-standards.mdc

---

### 3.3 Deploy to Production 🚀

**Requirements**:
- [ ] Deploy during low-traffic window (if possible)
- [ ] Monitor error rates during deployment
- [ ] Keep rollback command ready

**Commands**:
```bash
# Option 1: Merge to main (automatic deployment)
git checkout main
git pull origin main
git merge your-branch
git push origin main

# Option 2: Manual deployment
vercel --prod

# Option 3: Vercel CLI with alias
vercel alias set [deployment-url] production.yourdomain.com
```

**Deployment URL**:
- Vercel automatically deploys on push to `main`
- Deployment URL: https://[deployment-hash].vercel.app
- Production alias: https://yourdomain.com

**Monitor Deployment**:
```bash
# Watch deployment logs
vercel logs [deployment-url] --follow

# Check deployment status
vercel ls
```

---

### 3.4 Immediate Validation ✅

**Duration**: 0-5 minutes  
**Requirements**: ALL must pass or ROLLBACK immediately

**Critical Checks**:
- [ ] Site loads without errors
- [ ] Authentication works
- [ ] Database connectivity verified
- [ ] No 5xx errors in logs

**Commands**:
```bash
# 1. Test production URL
curl -I https://yourdomain.com

# 2. Test authentication
curl https://yourdomain.com/api/auth/session

# 3. Test database (internal endpoint)
curl https://yourdomain.com/api/health

# 4. Check logs for errors
vercel logs --follow
```

**🚨 ROLLBACK TRIGGERS** (0-5 min):
- Site doesn't load (5xx errors)
- Authentication broken
- Database connection failures
- Error rate > 10%

**Rollback Command**:
```bash
# Immediate rollback
vercel rollback [previous-deployment-url]

# Or via Vercel dashboard
# Go to: Deployments > Select previous > "Promote to Production"
```

**Related Rules**:
- @202-rollback-procedures.mdc
- @202-vercel-production-gotchas.mdc

---

## Phase 4: Post-Deployment

**Duration**: ~30 minutes  
**Goal**: Ensure deployment is stable and healthy

### 4.1 Short-Term Monitoring 📊

**Duration**: 5-30 minutes  
**Requirements**: Monitor for issues

**Metrics to Watch**:
1. **Error Rate**: < 1% (rollback if > 5%)
2. **Response Time**: < 2s average (rollback if > 5s)
3. **Database Queries**: No slow queries (> 1s)
4. **Memory Usage**: Stable (not climbing)

**Commands**:
```bash
# Watch logs
vercel logs --follow

# Monitor error rate
# Check: Vercel Dashboard > Analytics > Errors

# Check database performance
# See: @208-database-operations.mdc
```

**🚨 ROLLBACK TRIGGERS** (5-30 min):
- Error rate > 5%
- Response time > 5s average
- Memory leak detected
- Database connection errors

**Related Rules**:
- @221-application-monitoring.mdc
- @222-metrics-alerting.mdc

---

### 4.2 User Flow Validation 🧪

**Duration**: 10-15 minutes  
**Requirements**: Test all critical user flows

**Critical Flows**:
1. **Authentication**:
   - [ ] Login with real account
   - [ ] Logout
   - [ ] Session persistence

2. **Core Features**:
   - [ ] Create new data
   - [ ] Read existing data
   - [ ] Update data
   - [ ] Delete data

3. **Integrations**:
   - [ ] Payment processing (small test transaction)
   - [ ] AI generation (if applicable)
   - [ ] Email notifications

**Test Accounts**:
- Use dedicated test accounts in production
- Document test account credentials securely
- Clean up test data after validation

---

### 4.3 Extended Monitoring 📈

**Duration**: 30 min - 2 hours  
**Requirements**: Monitor for subtle issues

**Extended Metrics**:
1. **User Behavior**: Are users completing flows?
2. **Performance**: Any degradation over time?
3. **Errors**: Any new error patterns?
4. **Third-Party Services**: Any integration issues?

**Monitoring Dashboards**:
- Vercel Analytics
- Error tracking (Sentry, if configured)
- Database monitoring
- Custom metrics (if configured)

**Related Rules**:
- @221-application-monitoring.mdc
- @225-infrastructure-monitoring.mdc

---

### 4.4 Deployment Retrospective 📝

**Duration**: 10 minutes  
**Requirements**: Document lessons learned

**Questions to Answer**:
1. Did deployment go smoothly?
2. Any unexpected issues?
3. What could be improved?
4. Any new risks identified?

**Documentation**:
```markdown
## Deployment Retrospective - [Date]

**Branch**: [branch-name]
**Deployment Time**: [time]
**Downtime**: [none/X minutes]
**Issues Encountered**: [list issues]
**Lessons Learned**: [list lessons]
**Action Items**: [list action items]
```

**Share With Team**:
- Post in team channel
- Update deployment documentation
- Create tickets for improvements

---

## Emergency Procedures

### 🚨 Emergency Rollback

**When to Rollback**:
- Error rate > 5% for core functionality
- Site unavailable (5xx errors)
- Authentication failures
- Database connection failures
- Payment processing failures
- Security breach detected

**Rollback Steps**:
```bash
# 1. Immediately rollback to previous deployment
vercel rollback [previous-deployment-url]

# 2. Verify rollback succeeded
curl -I https://yourdomain.com
vercel logs --follow

# 3. Notify team
# Post in team channel: "🚨 ROLLED BACK - [reason]"

# 4. Monitor recovery
# Watch error rates return to normal

# 5. Document incident
# See: guides/Incident-Response-Complete-Guide.md
```

**Recovery Time**:
- Rollback: 1-2 minutes
- Verification: 2-3 minutes
- **Total**: 3-5 minutes

**Related Rules**:
- @202-rollback-procedures.mdc
- @804-hotfix-procedures.mdc

---

### 🔥 Emergency Hotfix

**When to Hotfix**:
- Critical bug in production
- Security vulnerability
- Data integrity issue
- Cannot rollback (previous version also broken)

**Hotfix Steps**:
```bash
# 1. Create hotfix branch
git checkout main
git pull origin main
git checkout -b hotfix/critical-fix

# 2. Make minimal fix
# Edit only what's necessary

# 3. Test locally
npm run test
npm run build

# 4. Deploy immediately
git add .
git commit -m "hotfix: [description]"
git push origin hotfix/critical-fix

# 5. Create PR and merge
gh pr create --title "HOTFIX: [description]" --body "Emergency fix for [issue]"

# Merge immediately (skip normal review for emergency)
gh pr merge --auto --squash

# 6. Verify fix
curl -I https://yourdomain.com
vercel logs --follow

# 7. Create follow-up ticket for proper fix
```

**Related Rules**:
- @804-hotfix-procedures.mdc

---

### 🔍 Debug Production Issues

**Common Debug Steps**:

1. **Check Logs**:
   ```bash
   vercel logs --follow
   vercel logs [deployment-url] --since 1h
   ```

2. **Check Environment Variables**:
   ```bash
   # Internal endpoint only!
   curl https://yourdomain.com/api/debug/env-check
   ```

3. **Check Database**:
   ```bash
   # Test database connection
   curl https://yourdomain.com/api/health
   ```

4. **Check External Services**:
   - Auth0: https://manage.auth0.com/dashboard
   - Stripe: https://dashboard.stripe.com/logs
   - Database: [Your database dashboard]

5. **Check Vercel Dashboard**:
   - Analytics > Errors
   - Functions > Logs
   - Settings > Environment Variables

**Related Rules**:
- @140-troubleshooting-standards.mdc
- @202-vercel-production-gotchas.mdc

---

## Common Issues

### Issue 1: NEXT_PHASE Breaking Production

**Symptoms**:
- Database operations fail in production
- `shouldSkipDatabase = true` in production
- Works in dev/test, fails in production

**Cause**:
- Using `process.env.NEXT_PHASE === 'phase-production-build'` for skipping
- Vercel sets NEXT_PHASE during production RUNTIME

**Fix**:
```javascript
// ❌ WRONG
const shouldSkip = process.env.NEXT_PHASE === 'phase-production-build';

// ✅ CORRECT
const shouldSkip = process.env.SKIP_AUTH0_CHECK === 'true' || 
                   (process.env.CI === 'true' && !process.env.DATABASE_URL);
```

**Related Rule**: @202-vercel-production-gotchas.mdc

---

### Issue 2: Environment Variables Not Set

**Symptoms**:
- `process.env.VARIABLE_NAME` is undefined
- Environment-specific features broken

**Cause**:
- Variable not set in Vercel dashboard
- Variable name mismatch
- Build vs runtime variable confusion

**Fix**:
```bash
# 1. Check what's set in Vercel
vercel env ls

# 2. Add missing variable
vercel env add VARIABLE_NAME

# 3. Redeploy
vercel --prod
```

**Related Rules**:
- @011-env-var-security.mdc
- @204-vercel-build-environment-variables.mdc

---

### Issue 3: Build Script Environment Variables Persist

**Symptoms**:
- Variables set in package.json build scripts persist to runtime
- SKIP_* variables active in production
- Database operations skipped

**Cause**:
- Setting environment variables in build scripts
- Using vercel.json to set global env vars

**Fix**:
```json
// ❌ WRONG (package.json)
{
  "scripts": {
    "build:vercel": "SKIP_AUTH0_CHECK=true next build"
  }
}

// ✅ CORRECT (package.json)
{
  "scripts": {
    "build:vercel": "VERCEL_BUILD=true npm run auth0:check && next build"
  }
}
```

**Delete** any `vercel.json` that sets env vars!

**Related Rule**: @204-vercel-build-environment-variables.mdc

---

### Issue 4: Database Connection Failures

**Symptoms**:
- "Connection pool exhausted"
- "Too many connections"
- Slow queries in production

**Cause**:
- Not using Prisma singleton pattern
- Connection pooling misconfigured
- Too many concurrent requests

**Fix**:
```typescript
// Use singleton pattern
// See: app/lib/db.ts

import { PrismaClient } from '@prisma/client';

const globalForPrisma = global as unknown as { prisma: PrismaClient };

export const prisma = globalForPrisma.prisma || new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
});

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
```

**Related Rules**:
- @208-database-operations.mdc
- @002-rule-application.mdc (Source of Truth Hierarchy)

---

### Issue 5: Authentication Failures

**Symptoms**:
- Users can't log in
- Session not persisting
- Redirect loops

**Cause**:
- Auth0 callback URL not configured
- AUTH0_SECRET not set or incorrect
- Cookie settings incorrect

**Fix**:
```bash
# 1. Validate Auth0 configuration
./.cursor/tools/check-auth-config.sh

# 2. Check Auth0 dashboard
# Application > Settings > Allowed Callback URLs
# Should include: https://yourdomain.com/api/auth/callback

# 3. Verify environment variables
vercel env ls | grep AUTH0

# 4. Check cookie settings
# Should have: sameSite: 'lax', secure: true
```

**Related Rules**:
- @019-auth0-integration.mdc
- @013-auth0-deployment-validation.mdc

---

## Best Practices

### 1. Deploy During Low-Traffic Windows

**Recommended Times**:
- Weekdays: After business hours (7pm-10pm)
- Weekends: Saturday morning (9am-12pm)
- **Avoid**: Friday afternoon, Monday morning, during campaigns

**Why**:
- Less user impact if issues occur
- Easier to monitor and respond
- Team available for issues

---

### 2. Use Feature Flags for Risky Changes

**When to Use**:
- Major UI changes
- New critical features
- Experimental features
- High-risk database changes

**Implementation**:
```typescript
// Environment variable feature flag
const isNewFeatureEnabled = process.env.ENABLE_NEW_FEATURE === 'true';

if (isNewFeatureEnabled) {
  return <NewFeature />;
} else {
  return <OldFeature />;
}
```

**Benefits**:
- Deploy code without activating feature
- Test in production with small user group
- Instant rollback without redeployment

---

### 3. Always Test in Staging First

**Never Deploy Directly to Production**:
- Always deploy to staging preview first
- Test all critical flows
- Verify performance
- Check security

**Staging Checklist**:
- [ ] Deploy to staging (automatic PR preview)
- [ ] Run smoke tests
- [ ] Test critical user flows
- [ ] Verify performance
- [ ] Check security headers
- [ ] Monitor for 10+ minutes
- [ ] Get team approval

---

### 4. Monitor Actively During Deployment

**What to Monitor**:
- Error rates (< 1%)
- Response times (< 2s)
- Database performance
- Memory usage
- User sessions

**Tools**:
- Vercel Dashboard > Analytics
- Vercel Logs (real-time)
- Database monitoring
- Custom metrics (if configured)

**Duration**:
- First 5 minutes: Critical (rollback window)
- 5-30 minutes: Important (catch early issues)
- 30+ minutes: Extended (catch subtle issues)

---

### 5. Document Everything

**What to Document**:
- Deployment time and duration
- Changes deployed
- Issues encountered
- Rollback procedures used
- Lessons learned
- Action items for improvement

**Where to Document**:
- Team wiki/docs
- Git commit messages
- PR descriptions
- Incident reports (if issues)
- Deployment log

---

### 6. Keep Rollback Ready

**Always Have**:
- Previous deployment URL
- Rollback command ready
- Rollback plan documented
- Team notification prepared

**Rollback Decision Tree**:
```
Error rate > 5%? ──YES──> ROLLBACK IMMEDIATELY
       │
       NO
       │
Response time > 5s? ──YES──> ROLLBACK IMMEDIATELY
       │
       NO
       │
Critical bug? ──YES──> HOTFIX (if small) or ROLLBACK
       │
       NO
       │
Monitor for 30 more minutes
```

---

## Related Resources

### Rules
- @200-deployment-infrastructure.mdc - Deployment infrastructure
- @201-vercel-deployment-standards.mdc - Vercel deployment standards
- @202-vercel-production-gotchas.mdc - Vercel production gotchas
- @203-production-deployment-safety.mdc - Production safety standards
- @204-vercel-build-environment-variables.mdc - Build env var safety
- @202-rollback-procedures.mdc - Emergency rollback procedures
- @804-hotfix-procedures.mdc - Emergency hotfix procedures

### Guides
- guides/Incident-Response-Complete-Guide.md - Emergency response
- guides/Database-Operations-Complete-Guide.md - Database operations
- guides/Monitoring-Complete-Guide.md - Monitoring and alerting
- guides/Secrets-Management-Complete-Guide.md - Environment variables

### Tools
- .cursor/tools/check-env-vars.sh - Validate environment variables
- .cursor/tools/check-auth-config.sh - Validate Auth0 configuration
- .cursor/tools/check-infrastructure.sh - Verify infrastructure health
- .cursor/tools/check-backups.sh - Verify backup health
- .cursor/tools/run-lighthouse.sh - Performance testing
- .cursor/tools/analyze-performance.sh - Performance analysis

---

## Summary

### Deployment Timeline

| Phase | Duration | Critical Actions |
|-------|----------|-----------------|
| **Pre-Deployment** | 30 min | Tests, security, backups |
| **Staging** | 15 min | Deploy, test, validate |
| **Production** | 5 min | Deploy, immediate checks |
| **Post-Deployment** | 30 min | Monitor, validate, document |
| **Total** | ~80 min | Normal deployment |
| **Emergency** | ~20 min | Hotfix deployment |

### Success Criteria

✅ **Successful Deployment**:
- All tests passed
- Staging validated
- Production deployment successful
- Error rate < 1%
- Response time < 2s
- No critical bugs
- Team notified
- Documentation updated

🚨 **Rollback Required**:
- Error rate > 5%
- Response time > 5s
- Database failures
- Authentication failures
- Critical bugs discovered
- Security issues detected

---

**Remember**: When in doubt, ROLLBACK. It's always safer to rollback and fix properly than to try patching in production!

🚀 **Happy Deploying!**

