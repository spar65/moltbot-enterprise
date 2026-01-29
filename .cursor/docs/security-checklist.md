# Security Checklist - Pre-Deployment & Development

**Last Updated:** 2024-11-19  
**Purpose:** Comprehensive security checklist for development and deployment  
**Status:** ✅ Production-Ready

---

## Quick Start

### Automated Security Scan (30 seconds)
```bash
# Run all security tools
./.cursor/tools/scan-secrets.sh && \
./.cursor/tools/check-env-vars.sh && \
./.cursor/tools/audit-dependencies.sh && \
./.cursor/tools/check-auth-config.sh

# All passed? You're good to go! ✅
```

---

## Pre-Commit Checklist

**Run before EVERY commit:**

### ✅ Secrets & Environment Variables
```bash
□ Run: ./.cursor/tools/scan-secrets.sh
□ No hardcoded secrets in code
□ No API keys in comments
□ No passwords in config files
□ .env files in .gitignore
□ Only placeholders in .env.example
```

### ✅ Code Quality
```bash
□ Tests pass: npm run test
□ Linter clean: npm run lint
□ TypeScript compiles: npm run build
□ No console.log in production code
□ No TODO comments for critical issues
```

---

## Pre-Pull Request Checklist

**Before opening a PR:**

### ✅ Security Review
```bash
□ All automated checks passed (above)
□ No new security vulnerabilities: npm audit
□ Auth properly tested
□ API endpoints secured
□ Rate limiting in place
□ Error messages don't expose sensitive data
```

### ✅ Documentation
```bash
□ README updated if needed
□ API endpoints documented
□ Environment variables documented in .env.example
□ Security considerations noted
```

---

## Pre-Deployment Checklist

**Before EVERY production deployment:**

### 1. Environment Variables

```bash
□ Run: ./.cursor/tools/check-env-vars.sh

Manual Checks:
□ All production env vars set in Vercel/hosting platform
□ No NEXT_PUBLIC_* variables contain secrets
□ Database URLs use production credentials
□ AUTH0_BASE_URL set to production domain
□ STRIPE_SECRET_KEY is live key (not test)
□ All API keys rotated from test to production
□ Session secrets are strong (32+ characters)
```

### 2. Dependencies

```bash
□ Run: ./.cursor/tools/audit-dependencies.sh

Manual Checks:
□ Zero critical vulnerabilities
□ Zero high-severity vulnerabilities
□ Moderate vulnerabilities reviewed and accepted/fixed
□ All dependencies up to date (or pinned intentionally)
□ Licenses compatible with commercial use
□ No deprecated packages
```

### 3. Authentication & Authorization

```bash
□ Run: ./.cursor/tools/check-auth-config.sh

Manual Checks:
□ Auth0 callback URLs include production domain
□ Logout URLs configured correctly
□ Session cookies have secure flag in production
□ Session cookies are httpOnly
□ Session timeout configured (recommendation: 7 days max)
□ Rolling sessions enabled
□ CORS configured for production domain only
□ API endpoints require authentication
□ Role-based access control working
□ User permissions validated server-side
```

### 4. Secrets Management

```bash
□ Run: ./.cursor/tools/scan-secrets.sh

Manual Checks:
□ Zero hardcoded secrets in codebase
□ All secrets use environment variables
□ .env files not committed to git
□ Production secrets different from development
□ Secrets rotated regularly (90-day policy)
□ Old secrets revoked
□ Secret rotation process documented
```

### 5. API Security

```bash
Manual Checks:
□ All API routes require authentication
□ API key validation working
□ Rate limiting enabled
□ Input validation on all endpoints
□ SQL injection prevention (parameterized queries)
□ XSS prevention (input sanitization)
□ CSRF protection enabled
□ API versioning strategy in place
□ Error responses don't leak sensitive info
□ Request size limits configured
```

### 6. Payment Security (if applicable)

```bash
Manual Checks:
□ Stripe webhook signature verification working
□ Never handling raw card data
□ Using Stripe Elements for card input
□ Amount validation server-side
□ Payment intents created server-side only
□ Test mode disabled in production
□ Webhook endpoints secured
□ Idempotency keys used for payments
□ Failed payment handling
□ Refund process secure
```

### 7. Database Security

```bash
Manual Checks:
□ Database credentials not in code
□ Connection pooling configured
□ Prepared statements used (Prisma handles this)
□ Row-level security policies (if applicable)
□ Database backups automated
□ Backup restoration tested
□ Database encryption at rest
□ SSL/TLS for database connections
```

### 8. HTTPS & Transport Security

```bash
Manual Checks:
□ HTTPS enabled (Vercel handles this)
□ HTTP redirects to HTTPS
□ HSTS header configured
□ Secure cookies flag enabled
□ TLS 1.2+ only
□ Certificate auto-renewal working
```

### 9. Monitoring & Logging

```bash
Manual Checks:
□ Error tracking configured (Sentry, etc.)
□ Security events logged
□ Failed authentication attempts logged
□ API access logged
□ Logs don't contain sensitive data
□ Log retention policy configured
□ Alerts configured for:
  - Failed authentication attempts (>10/hour)
  - API rate limit hits
  - Payment failures
  - Database errors
  - Critical errors
```

### 10. Incident Response

```bash
Manual Checks:
□ Incident response plan documented
□ Security contact information published
□ Emergency rollback procedure documented
□ Secret rotation procedure documented
□ Data breach notification plan
□ Team trained on incident response
```

---

## Feature-Specific Checklists

### New API Endpoint Checklist

```bash
□ Authentication required
□ Authorization checked (role/permissions)
□ Input validation
□ Output sanitization
□ Rate limiting applied
□ Error handling (don't leak info)
□ Audit logging
□ Tests written (including security tests)
□ Documentation updated
```

### New Environment Variable Checklist

```bash
□ Added to .env.example (placeholder only)
□ Added to .env.local (real value)
□ Added to Vercel environment variables
□ Documented in README
□ Proper prefix (NEXT_PUBLIC_ if client-side)
□ Security scan passed
□ Team notified if rotating existing secret
```

### Third-Party Integration Checklist

```bash
□ API keys secure (environment variables)
□ Webhook signature verification
□ Rate limiting considered
□ Error handling for API failures
□ Retry logic implemented
□ Timeout handling
□ Cost monitoring (if metered API)
□ Vendor security reviewed
□ Data sharing agreement signed
□ Privacy policy updated
```

### Database Migration Checklist

```bash
□ Migration tested in development
□ Migration tested in staging
□ Rollback plan ready
□ Data backup before migration
□ Down time communicated
□ Migration idempotent
□ Performance impact assessed
□ Indexes added if needed
□ Foreign key constraints reviewed
```

---

## Weekly Security Tasks

**Every Monday:**

```bash
□ Run: ./.cursor/tools/audit-dependencies.sh
□ Check npm outdated
□ Review security alerts from GitHub
□ Review failed authentication logs
□ Check API rate limit hits
□ Review error logs
□ Rotate test API keys (if compromised)
```

---

## Monthly Security Tasks

**First Monday of month:**

```bash
□ Full security audit
□ Review access control lists
□ Review user permissions
□ Check for unused API keys
□ Review third-party integrations
□ Update dependencies
□ Review incident response plan
□ Team security training/review
```

---

## Quarterly Security Tasks

**First Monday of quarter:**

```bash
□ Penetration testing (if applicable)
□ Security policy review
□ Rotate production secrets
□ Review disaster recovery plan
□ Test backup restoration
□ Review compliance requirements
□ Update security documentation
```

---

## Emergency Procedures

### Secret Compromised

```bash
1. IMMEDIATELY rotate the secret
2. Check logs for unauthorized access
3. Assess damage
4. Notify affected users (if applicable)
5. Update secret everywhere:
   - Local .env.local
   - Vercel environment variables
   - Team members
6. Review how compromise happened
7. Implement prevention measures
8. Document incident
```

### Security Breach Detected

```bash
1. Isolate affected systems
2. Preserve logs and evidence
3. Assess scope of breach
4. Notify security team
5. Rotate ALL credentials
6. Notify affected users (legal requirement)
7. Implement fixes
8. Post-mortem analysis
9. Update security procedures
```

### Database Compromise

```bash
1. Immediately disable database access
2. Rotate ALL database credentials
3. Review database logs
4. Restore from backup if needed
5. Assess data exposure
6. Notify affected users (GDPR, etc.)
7. Implement additional security measures
8. Document and report
```

---

## Compliance Checklists

### GDPR Compliance (if applicable)

```bash
□ User consent for data collection
□ Privacy policy published
□ Data retention policy
□ User data export capability
□ User data deletion capability
□ Data processing agreement with vendors
□ Data breach notification process
□ DPO appointed (if required)
```

### PCI DSS Compliance (if handling payments)

```bash
□ Never store card data
□ Use PCI-compliant payment processor (Stripe)
□ Secure network configuration
□ Regular security testing
□ Access control measures
□ Audit logs maintained
□ Annual compliance review
```

---

## Tools Reference

### Quick Commands

```bash
# Full security scan
./.cursor/tools/scan-secrets.sh && \
./.cursor/tools/check-env-vars.sh && \
./.cursor/tools/audit-dependencies.sh && \
./.cursor/tools/check-auth-config.sh

# Individual scans
./.cursor/tools/scan-secrets.sh          # Find hardcoded secrets
./.cursor/tools/check-env-vars.sh        # Validate environment variables
./.cursor/tools/audit-dependencies.sh    # Check for vulnerabilities
./.cursor/tools/check-auth-config.sh     # Validate Auth0 setup

# Prisma schema
./.cursor/tools/inspect-model.sh Model   # Inspect database model
./.cursor/tools/check-schema-changes.sh  # Validate schema changes
```

---

## Related Documentation

- **`.cursor/docs/security-workflows.md`** - Detailed security workflows
- **`.cursor/docs/rules-guide.md`** - Complete rule system
- **`.cursor/docs/tools-guide.md`** - All automation tools
- **`.cursor/docs/ai-workflows.md`** - Development patterns

**Related Rules:**
- Rule 010: security-compliance.mdc
- Rule 011: env-var-security.mdc
- Rule 012: api-security.mdc
- Rule 013: dependency-auditing.mdc
- Rule 014: third-party-auth.mdc
- Rule 019: auth0-integration.mdc
- Rule 020: payment-security.mdc
- Rule 046: session-validation.mdc

---

## Success Metrics

**Target Goals:**
- ✅ Zero hardcoded secrets
- ✅ Zero critical vulnerabilities
- ✅ Zero high-severity issues
- ✅ 100% HTTPS coverage
- ✅ <1 second authentication response
- ✅ Zero unauthorized access attempts succeeding
- ✅ 100% test coverage on security-critical code

**Review this checklist:**
- Before every commit
- Before every PR
- Before every deployment
- Weekly for routine checks
- Monthly for comprehensive review
- Quarterly for strategic review

---

**Last reviewed:** 2024-11-19  
**Next review due:** 2024-12-19  
**Maintained by:** Development Team  
**Questions?** See `.cursor/docs/security-workflows.md`

