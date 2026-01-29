# Cursor Development Tools

This directory contains automation scripts and utilities to support development workflows, testing, and code quality.

## 📁 Directory Structure

```
.cursor/tools/
├── README.md                      # This file
│
├── Schema & Database Tools
├── check-schema-changes.sh        # Detect Prisma schema changes
├── inspect-model.sh               # Quick Prisma model inspection
├── check-backups.sh               # Verify database backups
│
├── Security Tools
├── check-env-vars.sh              # Validate environment variables
├── check-auth-config.sh           # Validate Auth0 configuration
├── scan-secrets.sh                # Detect hardcoded secrets
├── audit-dependencies.sh          # Security vulnerability scanning
├── validate-api-keys.sh           # Validate API key implementation
├── audit-api-key-usage.sh         # Audit API key usage & security
├── validate-webhooks.sh           # Validate webhook implementation ⭐ NEW
├── test-rate-limits.sh            # Test rate limiting system ⭐ NEW
├── verify-hash-integrity.sh       # Verify cryptographic hash integrity ⭐ NEW
│
├── Email Marketing Tools
├── check-email-compliance.sh      # Email compliance checker (GDPR, CAN-SPAM, Gmail/Yahoo 2024)
├── check-dns-records.sh           # DNS authentication records validator
│
├── Deployment Tools
├── pre-deployment-check.sh        # Pre-deployment safety validation
├── validate-deployment.sh         # Post-deployment health check
│
├── Infrastructure Tools
├── check-infrastructure.sh        # Verify infrastructure health
├── test-recovery.sh               # Test disaster recovery
├── analyze-costs.sh               # Cost analysis
│
├── Performance Tools
├── run-lighthouse.sh              # Lighthouse performance audit
├── check-bundle-size.sh           # Bundle size analysis
└── analyze-performance.sh         # Comprehensive performance analysis
```

---

## 🛠️ Available Tools

### 1. **check-schema-changes.sh**
**Purpose:** Detect uncommitted Prisma schema changes and alert developers

**Usage:**
```bash
# Run from project root
./.cursor/tools/check-schema-changes.sh

# Or from anywhere
bash .cursor/tools/check-schema-changes.sh
```

**Features:**
- ✅ Detects uncommitted schema changes
- ✅ Shows field changes with color-coded output
- ✅ Provides actionable remediation steps
- ✅ Exit codes for CI/CD integration (0 = OK, 1 = Changes detected)

**Use Cases:**
- Pre-commit validation
- CI/CD pipeline checks
- Manual verification before writing tests

**Related Rules:**
- Rule 375: API Test First Time Right
- Rule 376: Database Test Isolation
- Rule 002: Source of Truth Hierarchy

---

### 2. **validate-test-setup.sh** *(Coming Soon)*
**Purpose:** Verify test environment is properly configured

**Will Check:**
- [ ] Jest configurations exist (unit, integration, api)
- [ ] Test setup files configured
- [ ] Mock directories exist
- [ ] Database test helpers available
- [ ] Prisma client generated
- [ ] All test dependencies installed

**Usage:**
```bash
./.cursor/tools/validate-test-setup.sh
```

---

### 3. **inspect-model.sh** *(Coming Soon)*
**Purpose:** Quick inspection of Prisma models with field details

**Usage:**
```bash
# Inspect specific model
./.cursor/tools/inspect-model.sh HealthCheckApiKey

# List all models
./.cursor/tools/inspect-model.sh --list

# Show relationships
./.cursor/tools/inspect-model.sh HealthCheckApiKey --relations
```

**Output Example:**
```
Model: HealthCheckApiKey
Fields:
  - id: String (UUID, Primary Key)
  - label: String ✅ (NOT "name"!)
  - keyHash: String
  - environment: String
  - organizationId: String (UUID, Foreign Key)
  - createdBy: String (UUID)
  - active: Boolean
  - lastFourChars: String

Relations:
  - organization: Organization
  - creator: User

Indexes:
  - keyHash (unique)
  - organizationId
```

---

### 4. **pre-deployment-check.sh** ⭐ **NEW**
**Purpose:** Comprehensive pre-deployment safety validation

**Usage:**
```bash
# Run all pre-deployment checks
./.cursor/tools/pre-deployment-check.sh
```

**Features:**
- ✅ Git & branch validation
- ✅ Build script safety (SKIP_* variables, vercel.json)
- ✅ Security checks (env vars, Auth0, secrets)
- ✅ Dependency audit
- ✅ Test validation
- ✅ Database safety (backups, migrations)
- ✅ Infrastructure readiness

**Checks:**
1. Git repository state and branch sync
2. Build scripts for dangerous patterns (@204-vercel-build-environment-variables.mdc)
3. Environment variable security (@011-env-var-security.mdc)
4. Auth0 configuration (@013-auth0-deployment-validation.mdc)
5. Hardcoded secrets detection
6. Dependency vulnerabilities
7. Local build success
8. Test suite passing
9. Database backups verified
10. Prisma schema committed

**Exit Codes:**
- 0: Ready for deployment
- 1: Critical issues found (do not deploy)

**Related Rules:**
- @203-production-deployment-safety.mdc
- @202-vercel-production-gotchas.mdc
- @204-vercel-build-environment-variables.mdc

**Related Guides:**
- guides/Deployment-Workflow-Complete-Guide.md

---

### 5. **validate-deployment.sh** ⭐ **NEW**
**Purpose:** Post-deployment health and stability validation

**Usage:**
```bash
# Validate production deployment
./.cursor/tools/validate-deployment.sh https://yourdomain.com

# Validate staging deployment
./.cursor/tools/validate-deployment.sh https://staging-url.vercel.app
```

**Features:**
- ✅ Site availability check
- ✅ Response time validation
- ✅ HTTPS and security headers
- ✅ Critical API endpoint testing
- ✅ Database connectivity check
- ✅ Rollback decision tree
- ✅ Monitoring recommendations

**Validation Phases:**
1. **Immediate (0-5 min)**: Critical checks
   - Site accessibility (HTTP 200)
   - Response time (< 2s)
   - Security headers
   - API health endpoints
   - Database connectivity

2. **Functional (5-15 min)**: User flows
   - Manual testing checklist
   - Critical user flows

3. **Monitoring (30+ min)**: Stability
   - Error rate monitoring
   - Performance tracking
   - Resource usage

**Rollback Triggers:**
- 🚨 Immediate: HTTP 5xx, auth broken, DB failures
- ⚠️  Consider: Error rate > 5%, response time > 5s

**Exit Codes:**
- 0: Deployment validated
- 1: Critical issues (consider rollback)

**Related Rules:**
- @203-production-deployment-safety.mdc
- @202-rollback-procedures.mdc
- @221-application-monitoring.mdc

---

### 6. **check-email-compliance.sh** ⭐ **NEW**
**Purpose:** Validate email marketing compliance with GDPR, CAN-SPAM, CASL, and Gmail/Yahoo 2024 requirements

**Usage:**
```bash
# Basic check (without domain)
./.cursor/tools/check-email-compliance.sh

# With domain (checks DNS records)
./.cursor/tools/check-email-compliance.sh --domain yourdomain.com

# Verbose output
./.cursor/tools/check-email-compliance.sh --domain yourdomain.com --verbose
```

**What It Checks:**
1. **DNS Authentication** (Gmail/Yahoo 2024 CRITICAL):
   - SPF record configured
   - DKIM signing enabled
   - DMARC policy set (minimum p=none)
   - BIMI record (optional)

2. **One-Click Unsubscribe** (RFC 8058):
   - List-Unsubscribe header requirements
   - List-Unsubscribe-Post header requirements
   - Processing time < 2 seconds requirement

3. **Spam Complaint Rate**:
   - Must be < 0.3% (Gmail/Yahoo requirement)
   - Google Postmaster Tools setup
   - Alert configuration recommendations

4. **Compliance Checklists**:
   - GDPR requirements (EU users)
   - CAN-SPAM requirements (US users)
   - CASL requirements (Canadian users)
   - List hygiene best practices
   - Accessibility standards

**Exit Codes:**
- 0: All checks passed (warnings OK)
- 1: Critical failures detected

**Related Rules:**
- @075-email-marketing-standards.mdc
- @078-email-deliverability-standards.mdc
- @080-email-effectiveness-tracking.mdc

**Related Guides:**
- `guides/Email-Deliverability-Complete-Guide.md`
- `guides/Email-Compliance-Guide.md`

---

### 7. **check-dns-records.sh** ⭐ **NEW**
**Purpose:** Validate DNS records for email authentication (SPF, DKIM, DMARC, BIMI, MX)

**Usage:**
```bash
# Check all DNS records
./.cursor/tools/check-dns-records.sh yourdomain.com

# Specify DKIM selector
./.cursor/tools/check-dns-records.sh yourdomain.com --dkim-selector k1

# Verbose output
./.cursor/tools/check-dns-records.sh yourdomain.com --verbose
```

**What It Checks:**
1. **SPF Record**:
   - Record exists
   - Policy type (~all, -all, +all)
   - DNS lookup count (max 10)
   - Common misconfigurations

2. **DMARC Record**:
   - Record exists
   - Policy level (none, quarantine, reject)
   - Aggregate report email (rua)
   - Forensic report email (ruf)

3. **DKIM Record**:
   - Record exists for specified selector
   - Key type (RSA recommended)
   - Key length (2048-bit recommended)

4. **BIMI Record** (optional):
   - Record exists
   - Logo URL configured
   - VMC (Verified Mark Certificate) configured

5. **MX Records**:
   - Records exist
   - Multiple records for redundancy

**Exit Codes:**
- 0: All checks passed (warnings OK)
- 1: Critical DNS failures detected

**Common DKIM Selectors to Try:**
- k1, k2 (common)
- default
- google
- s1, s2
- Check your email service provider documentation

**Related Tools:**
- `check-email-compliance.sh` - Comprehensive compliance check

---

### 8. **validate-api-keys.sh** ⭐ **NEW**
**Purpose:** Validate API key implementation for security, format, and best practices

**Usage:**
```bash
# Run all validation checks
./.cursor/tools/validate-api-keys.sh

# Verbose output with detailed explanations
./.cursor/tools/validate-api-keys.sh --verbose
```

**What It Checks:**

1. **API Key Format:**
   - Uses crypto.randomBytes() for generation
   - Environment-specific prefixes (live, test, dev)
   - Key format validation

2. **Security:**
   - bcrypt hashing (12+ rounds)
   - No plaintext key storage
   - Environment isolation

3. **Audit Logging:**
   - Audit log table exists
   - IP address hashing (GDPR-compliant)
   - Comprehensive event logging

4. **Rate Limiting:**
   - Rate limit implementation
   - Per-key configurations

5. **Key Lifecycle:**
   - Expiration handling
   - Rotation capabilities
   - Grace period support

6. **Testing:**
   - Test file coverage
   - Security test scenarios

7. **Documentation:**
   - README coverage
   - API key usage docs

8. **Environment Security:**
   - .env.example exists
   - No default/placeholder salts

**Exit Codes:**
- 0: All checks passed or minor warnings
- 1: Critical security issues found

**Example Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. API Key Format Validation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ Uses crypto.randomBytes() for key generation
  ✓ Implements environment-specific key prefixes
  ✓ Key format validation found

Total Checks:    24
Passed:          20
Warnings:        3
Failed:          1

🎉 Excellent! Your API key implementation is solid (83% passed)
```

**Related Rules:**
- @373-api-key-system-design.mdc
- @372-api-key-testing-standards.mdc
- @012-api-security.mdc
- @224-secrets-management.mdc

**Related Guides:**
- `guides/API-Key-Management-Complete-Guide.md`

---

### 9. **audit-api-key-usage.sh** ⭐ **NEW**
**Purpose:** Audit API key usage patterns, detect security issues, and identify hardcoded keys

**Usage:**
```bash
# Run security audit
./.cursor/tools/audit-api-key-usage.sh

# Verbose output with details
./.cursor/tools/audit-api-key-usage.sh --verbose

# Get suggested fixes for issues
./.cursor/tools/audit-api-key-usage.sh --fix
```

**What It Checks:**

1. **Hardcoded Keys:**
   - Scans for hardcoded API keys in source code
   - Checks git history for leaked keys
   - Detects common key patterns (hck_, vibe_, sk-, etc.)

2. **Environment Variables:**
   - .env in .gitignore
   - .env.example with placeholders
   - No client-side exposure (NEXT_PUBLIC_)

3. **Validation Patterns:**
   - Proper validation functions
   - Error handling
   - Rate limiting

4. **Logging:**
   - No full keys logged
   - Audit trail implementation
   - GDPR-compliant IP hashing

5. **Database Storage:**
   - Keys stored as hashes only
   - Expiration fields
   - Revocation support

6. **Key Rotation:**
   - Rotation implementation
   - Expiration checking
   - Usage tracking

7. **Documentation:**
   - README coverage
   - SDK examples
   - Clear error messages

8. **Testing:**
   - Test file coverage
   - Test count adequacy

9. **Production Readiness:**
   - Environment-aware code
   - Monitoring/alerting
   - Rate limit documentation

**Exit Codes:**
- 0: No critical issues
- 1: Critical security issues found

**Example Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Scanning for Hardcoded API Keys
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ No hardcoded API keys detected in source code
  ✓ No API keys found in recent git history

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. Environment Variable Security
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ .env is in .gitignore
  ✓ .env.example exists
  ⚠️  WARNING: Real API keys in .env.example
    → Use placeholders: API_KEY=your_key_here

✅ No critical issues found!
```

**With --fix flag:**
```
🔧 Suggested fixes:

1. Add .env to .gitignore:
   echo '.env' >> .gitignore

2. Create .env.example with placeholders:
   cp .env .env.example
   # Then replace real values with placeholders

3. Scan git history for leaked keys:
   git log --all --full-history -S 'sk-' --source

4. If keys are compromised, rotate immediately:
   # Generate new keys
   # Update all services
   # Revoke old keys
```

**Related Rules:**
- @373-api-key-system-design.mdc
- @372-api-key-testing-standards.mdc
- @011-env-var-security.mdc
- @224-secrets-management.mdc

**Related Guides:**
- `guides/API-Key-Management-Complete-Guide.md`
- `guides/Secrets-Management-Complete-Guide.md`

---

### 10. **validate-webhooks.sh** ⭐ **NEW**
**Purpose:** Validate webhook implementation for security, reliability, and best practices

**Usage:**
```bash
# Run all webhook validation checks
./.cursor/tools/validate-webhooks.sh

# Verbose output with detailed explanations
./.cursor/tools/validate-webhooks.sh --verbose
```

**What It Checks:**

1. **HMAC Signature Security:**
   - HMAC-SHA256 implementation
   - Timing-safe signature comparison
   - Secret management (no hardcoded secrets)
   - Signature verification functions

2. **Retry Logic:**
   - Exponential backoff implementation
   - Maximum retry attempts (3+)
   - Proper error handling
   - Retry timeout configuration

3. **Webhook Payload:**
   - Standardized payload structure
   - Event type definitions
   - Timestamp inclusion
   - Idempotency keys

4. **Database & Storage:**
   - Webhook delivery tracking
   - Failure logging
   - Webhook settings storage
   - Audit trail

5. **Configuration:**
   - Webhook URL validation
   - Environment-based secrets
   - Per-organization settings
   - Rate limiting on webhooks

6. **Testing:**
   - Webhook test coverage
   - Signature validation tests
   - Retry logic tests
   - Delivery failure tests

7. **Documentation:**
   - Webhook setup guide
   - Signature verification examples
   - Payload format documentation
   - Error handling guide

**Exit Codes:**
- 0: All checks passed or minor warnings
- 1: Critical webhook issues found

**Example Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. HMAC Signature Security
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ Uses HMAC-SHA256 for webhook signatures
  ✓ Implements timing-safe comparison (crypto.timingSafeEqual)
  ✓ No hardcoded webhook secrets detected

Total Checks:    28
Passed:          25
Warnings:        2
Failed:          1

⚠️  Good foundation, but address warnings before production
```

**Related Rules:**
- @385-webhook-implementation-standards.mdc
- @012-api-security.mdc
- @224-secrets-management.mdc
- @355-rate-limiting-implementation.mdc

**Related Guides:**
- `guides/Webhook-Implementation-Complete-Guide.md`

---

### 11. **test-rate-limits.sh** ⭐ **NEW**
**Purpose:** Test rate limiting implementation with realistic load scenarios

**Usage:**
```bash
# Test rate limiting on local API
./.cursor/tools/test-rate-limits.sh

# Test specific endpoint
./.cursor/tools/test-rate-limits.sh --endpoint /api/health-check/test

# Verbose output with timing details
./.cursor/tools/test-rate-limits.sh --verbose

# Custom rate limit (requests per window)
./.cursor/tools/test-rate-limits.sh --limit 10 --window 60
```

**What It Tests:**

1. **Basic Rate Limiting:**
   - Requests are counted correctly
   - Limit enforcement works
   - HTTP 429 returned when exceeded
   - Rate limit headers present

2. **Sliding Window:**
   - Window slides correctly over time
   - Old requests expire properly
   - Accurate remaining count
   - Reset time calculation

3. **Headers:**
   - X-RateLimit-Limit header
   - X-RateLimit-Remaining header
   - X-RateLimit-Reset header
   - Retry-After header (on 429)

4. **Per-Organization Limits:**
   - Different orgs have independent limits
   - Organization identification works
   - Custom limits per org respected

5. **Error Handling:**
   - Graceful degradation if rate limit system fails
   - Clear error messages
   - Proper HTTP status codes

6. **Performance:**
   - Rate limit check latency < 50ms
   - Database query optimization
   - Caching effectiveness

**Example Output:**
```
Testing Rate Limiting Implementation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Test 1: Basic Rate Limiting
  ✓ Request 1/10: 200 OK (remaining: 9)
  ✓ Request 2/10: 200 OK (remaining: 8)
  ...
  ✓ Request 10/10: 200 OK (remaining: 0)
  ✓ Request 11/10: 429 Too Many Requests
  ✓ Retry-After header present: 3600 seconds

Test 2: Sliding Window
  ✓ Window slides correctly
  ✓ Old requests expire after window duration
  ✓ Reset time accurate

Test 3: Rate Limit Headers
  ✓ X-RateLimit-Limit: 10
  ✓ X-RateLimit-Remaining: 9
  ✓ X-RateLimit-Reset: 1735171200

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Results: 15/15 tests passed ✅
Average latency: 23ms
```

**Related Rules:**
- @355-rate-limiting-implementation.mdc
- @012-api-security.mdc
- @220-security-monitoring.mdc

**Related Guides:**
- `guides/Rate-Limiting-Implementation-Complete-Guide.md`
- `guides/Rate-Limiting-Production-Success-Story.md`

---

### 12. **verify-hash-integrity.sh** ⭐ **NEW**
**Purpose:** Verify cryptographic hash integrity implementation for tamper-proof data

**Usage:**
```bash
# Run all hash integrity checks
./.cursor/tools/verify-hash-integrity.sh

# Verbose output with implementation details
./.cursor/tools/verify-hash-integrity.sh --verbose

# Test specific file's hash implementation
./.cursor/tools/verify-hash-integrity.sh --test-file app/lib/scoring.ts
```

**What It Checks:**

1. **Hash Function Implementation:**
   - Uses SHA-256 (industry standard)
   - HMAC-SHA256 for signatures
   - Timing-safe comparison (prevents timing attacks)
   - Canonical JSON serialization (deterministic hashing)

2. **Hash Storage:**
   - Database schema has hash/integrity fields
   - Hash fields use appropriate types (String for hex)
   - Verification functions implemented
   - Public verification endpoints

3. **Hash Determinism:**
   - Tests verify same input → same hash
   - Tampering detection tests
   - Hash format validation (64 hex chars)

4. **Verification Endpoints:**
   - Public API for hash verification
   - Rate limiting on verification endpoints
   - Clear documentation for clients

5. **Security Practices:**
   - No hardcoded secrets
   - Environment-based secret management
   - Hash length validation (64 chars)
   - Hex format validation (/^[a-f0-9]{64}$/)

6. **Hash Chain & Audit:**
   - Hash chain implementation (tamper-evident)
   - Timestamp in hash computation (prevents replay)
   - Immutable audit logs

7. **Performance:**
   - Hash caching for frequently accessed data
   - Batch hash computation
   - Streaming for large files

8. **Documentation:**
   - Hash verification examples
   - SDK includes verification
   - API docs show hash fields

**Exit Codes:**
- 0: All checks passed
- 1: Critical security issues detected

**Example Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Hash Function Implementation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ Uses SHA-256 for hash generation
  ✓ Uses HMAC-SHA256 for signatures
  ✓ Uses timing-safe comparison
  ✓ Uses canonical JSON serialization

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
5. Security Best Practices
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ Webhook/signing secrets in .env.example
  ✓ No hardcoded secrets in hash operations
  ✓ Hash length validation found
  ✓ Hex format validation found

Total Checks:    32
Passed:          28
Warnings:        3
Failed:          1

✅ Excellent! Your hash integrity implementation is solid (88% passed)
```

**Related Rules:**
- @227-cryptographic-verification-standards.mdc
- @012-api-security.mdc
- @224-secrets-management.mdc
- @385-webhook-implementation-standards.mdc

**Related Guides:**
- `guides/Cryptographic-Verification-Complete-Guide.md`

---

### 13. **sync-design-docs.sh** *(Coming Soon)*
**Purpose:** Detect mismatches between schema and design docs

**Usage:**
```bash
# Check all design docs
./.cursor/tools/sync-design-docs.sh

# Check specific doc
./.cursor/tools/sync-design-docs.sh docs/DESIGN-03-API-Keys.md
```

**Features:**
- Scan design docs for field references
- Compare against actual schema
- Report mismatches with suggestions
- Optionally auto-update docs

---

## 🚀 Quick Start Guide

### For New Developers

1. **Verify your test setup:**
   ```bash
   ./.cursor/tools/validate-test-setup.sh
   ```

2. **Before writing API tests, inspect the schema:**
   ```bash
   ./.cursor/tools/inspect-model.sh YourModel
   ```

3. **Before committing schema changes:**
   ```bash
   ./.cursor/tools/check-schema-changes.sh
   ```

### For Deployment (⭐ NEW)

1. **Before deploying to production:**
   ```bash
   # Run comprehensive pre-deployment checks
   ./.cursor/tools/pre-deployment-check.sh
   ```

2. **After deploying:**
   ```bash
   # Validate deployment health
   ./.cursor/tools/validate-deployment.sh https://yourdomain.com
   
   # Monitor logs
   vercel logs --follow
   ```

3. **If issues detected:**
   ```bash
   # Immediate rollback
   vercel rollback [previous-deployment-url]
   
   # See: @202-rollback-procedures.mdc
   ```

### For CI/CD Integration

Add to your pipeline:

```yaml
# Example GitHub Actions
- name: Validate Schema
  run: ./.cursor/tools/check-schema-changes.sh

- name: Verify Test Setup
  run: ./.cursor/tools/validate-test-setup.sh

# ⭐ NEW: Pre-deployment validation
- name: Pre-Deployment Safety Check
  run: ./.cursor/tools/pre-deployment-check.sh
  
# ⭐ NEW: Post-deployment validation
- name: Validate Deployment
  run: ./.cursor/tools/validate-deployment.sh https://staging-url.vercel.app
```

---

## 📋 Tool Development Guidelines

When creating new tools for this directory:

### 1. **File Naming**
- Use kebab-case: `check-schema-changes.sh`
- Use `.sh` extension for shell scripts
- Use descriptive names that explain the purpose

### 2. **Script Header Template**
```bash
#!/usr/bin/env bash
#
# Tool Name
# 
# Purpose: Brief description
# Usage: ./toolname.sh [options]
#
# Exit codes:
#   0 - Success
#   1 - Error or validation failed
#

set -euo pipefail
```

### 3. **Output Standards**
- Use color codes for visual clarity:
  - 🔴 RED (`\033[0;31m`): Errors
  - 🟡 YELLOW (`\033[1;33m`): Warnings
  - 🟢 GREEN (`\033[0;32m`): Success
  - 🔵 BLUE (`\033[0;34m`): Info
  - ⚪ NC (`\033[0m`): No Color (reset)

- Use emojis for visual indicators:
  - ✅ Success
  - ❌ Error
  - ⚠️  Warning
  - 🔍 Checking/Inspecting
  - 🧹 Cleanup
  - 📋 List/Details
  - 💡 Tip/Suggestion

### 4. **Error Handling**
- Always use `set -euo pipefail` for strict error handling
- Provide clear error messages with remediation steps
- Exit with appropriate codes for CI/CD integration

### 5. **Documentation**
- Include usage examples in script comments
- Update this README when adding new tools
- Reference related rules/guides

---

## 🔗 Related Resources

### Rules
- **Rule 002:** Source of Truth Hierarchy
- **Rule 375:** API Test First Time Right
- **Rule 376:** Database Test Isolation

### Guides
- **API & Database Testing Complete Guide:** `guides/testing/API-Database-Testing-Complete-Guide.md`
- **Schema-First Workflow Diagram:** `docs/SCHEMA-FIRST-WORKFLOW-DIAGRAM.md`

### Workflows
- **GitHub Actions Schema Validation:** `.github/workflows/schema-validation.yml`

---

## 🎯 Tool Priority Roadmap

### ✅ Phase 1: Schema Validation (COMPLETE)
- [x] `check-schema-changes.sh`
- [x] `inspect-model.sh`

### ✅ Phase 2: Security Tools (COMPLETE) ⭐ **ENHANCED**
- [x] `check-env-vars.sh`
- [x] `check-auth-config.sh`
- [x] `scan-secrets.sh`
- [x] `audit-dependencies.sh`
- [x] `validate-api-keys.sh` ⭐ **NEW** - Validate API key implementation
- [x] `audit-api-key-usage.sh` ⭐ **NEW** - Audit API key security

### ✅ Phase 3: Deployment Tools (COMPLETE) ⭐ **NEW**
- [x] `pre-deployment-check.sh`
- [x] `validate-deployment.sh`

### ✅ Phase 4: Infrastructure Tools (COMPLETE)
- [x] `check-infrastructure.sh`
- [x] `check-backups.sh`
- [x] `test-recovery.sh`
- [x] `analyze-costs.sh`

### ✅ Phase 5: Performance Tools (COMPLETE)
- [x] `run-lighthouse.sh`
- [x] `check-bundle-size.sh`
- [x] `analyze-performance.sh`

### 🔄 Phase 6: Test Infrastructure (PLANNED)
- [ ] `validate-test-setup.sh`

### 🔮 Phase 7: Documentation Sync (FUTURE)
- [ ] `sync-design-docs.sh`
- [ ] `generate-api-docs.sh`

### 🔮 Phase 8: Test Helpers (FUTURE)
- [ ] `generate-test-template.sh` - Scaffold new API test
- [ ] `find-missing-tests.sh` - Detect untested endpoints
- [ ] `analyze-test-coverage.sh` - Coverage report with gaps

---

## 💡 Contributing

When adding new tools:

1. **Create the script** in `.cursor/tools/`
2. **Make it executable:** `chmod +x .cursor/tools/yourscript.sh`
3. **Test thoroughly** before committing
4. **Update this README** with documentation
5. **Update related rules** if needed
6. **Add to CI/CD** if appropriate

---

## 📞 Support

For questions about these tools:
- Review related rules in `.cursor/rules/`
- Check guides in `guides/testing/`
- Consult workflow diagrams in `docs/`

---

**Last Updated:** November 20, 2025  
**Maintainer:** Development Team  
**Status:** Active Development  
**New Tools**: Pre-deployment check, Post-deployment validation

