# Secrets Management Complete Guide

**The definitive guide to secure storage, rotation, and access control of sensitive credentials and API keys.**

## Table of Contents

1. [Overview](#overview)
2. [Secrets Classification](#secrets-classification)
3. [Storage Solutions](#storage-solutions)
4. [Access Control](#access-control)
5. [Rotation Strategies](#rotation-strategies)
6. [Development Workflow](#development-workflow)
7. [Detection & Prevention](#detection--prevention)
8. [Incident Response](#incident-response)
9. [Compliance](#compliance)
10. [Best Practices](#best-practices)

---

## Overview

### What are Secrets?

**Secrets** are sensitive credentials that grant access to systems, services, and data:

- **API Keys**: Third-party service credentials (Stripe, OpenAI, Auth0)
- **Database Credentials**: Connection strings, passwords
- **Encryption Keys**: Data encryption, signing keys
- **OAuth Tokens**: Access tokens, refresh tokens
- **Private Keys**: SSH keys, TLS certificates
- **Session Secrets**: JWT signing keys, cookie secrets

### Why Secrets Management Matters

> **"A single exposed secret can compromise your entire system."**

**Consequences of exposed secrets**:
- Unauthorized access to services ($$$)
- Data breaches (legal liability, reputation damage)
- Compliance violations (fines, audits)
- Service disruption
- Customer trust erosion

### Secrets Management Principles

1. **Never Commit Secrets**: No secrets in source control
2. **Encrypt at Rest**: Secrets stored encrypted
3. **Encrypt in Transit**: Secrets transmitted over TLS
4. **Least Privilege**: Minimum access necessary
5. **Rotate Regularly**: Change secrets periodically
6. **Audit Access**: Log who accessed what, when
7. **Detect Exposure**: Scan for leaked secrets

---

## Secrets Classification

### Sensitivity Levels

#### Critical (P0)
**Impact if exposed**: Complete system compromise

**Examples**:
- Database master credentials
- Root API keys
- Master encryption keys
- OAuth client secrets

**Storage**: Hardware Security Module (HSM) or dedicated secrets manager

**Rotation**: Monthly or after any suspected exposure

**Access**: 2-3 people maximum, with strict audit logging

---

#### High (P1)
**Impact if exposed**: Significant security or financial risk

**Examples**:
- Payment processor API keys (Stripe)
- AI service API keys (OpenAI, Anthropic)
- Production database read-write credentials
- Auth0 management API tokens

**Storage**: Secrets manager with encryption

**Rotation**: Quarterly

**Access**: Engineering team with audit logging

---

#### Medium (P2)
**Impact if exposed**: Limited security or operational risk

**Examples**:
- Staging environment credentials
- Read-only database credentials
- Analytics API keys
- Email service API keys

**Storage**: Secrets manager or encrypted environment variables

**Rotation**: Annually or as needed

**Access**: Engineering team

---

#### Low (P3)
**Impact if exposed**: Minimal risk

**Examples**:
- Public API keys (designed to be public)
- Development environment credentials
- Non-sensitive configuration values

**Storage**: Environment variables or configuration files

**Rotation**: As needed

**Access**: Entire team

---

## Storage Solutions

### Vercel Environment Variables

```typescript
// .env.local (NEVER commit this file!)
# Critical secrets
DATABASE_URL="postgresql://user:password@host:5432/db"
STRIPE_SECRET_KEY="sk_live_..."
AUTH0_CLIENT_SECRET="..."

# High-priority secrets
OPENAI_API_KEY="sk-..."
ANTHROPIC_API_KEY="sk-ant-..."

# Medium-priority secrets
SENDGRID_API_KEY="SG...."
ANALYTICS_WRITE_KEY="..."

# Low-priority (or public)
NEXT_PUBLIC_APP_URL="https://app.example.com"
```

**Vercel Dashboard**:
1. Project Settings → Environment Variables
2. Add variable with:
   - Name: `DATABASE_URL`
   - Value: `postgresql://...`
   - Environments: Production, Preview, Development

**Best practices**:
- Use different secrets for each environment
- Never mix production and development secrets
- Mark public variables with `NEXT_PUBLIC_` prefix
- Document which secrets are required

---

### AWS Secrets Manager

```typescript
// lib/secrets.ts
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

const client = new SecretsManagerClient({ region: 'us-east-1' });

export async function getSecret(secretName: string): Promise<string> {
  try {
    const response = await client.send(
      new GetSecretValueCommand({ SecretId: secretName })
    );
    
    return response.SecretString || '';
    
  } catch (error) {
    console.error(`Failed to retrieve secret: ${secretName}`, error);
    throw error;
  }
}

// Usage
const stripeKey = await getSecret('production/stripe/secret-key');
const dbPassword = await getSecret('production/database/password');
```

**Benefits**:
- Automatic encryption at rest
- Automatic rotation support
- Fine-grained access control (IAM)
- Audit logging via CloudTrail
- Version history

**Setup**:
```bash
# Create secret
aws secretsmanager create-secret \
  --name production/stripe/secret-key \
  --secret-string "sk_live_..."

# Enable automatic rotation
aws secretsmanager rotate-secret \
  --secret-id production/stripe/secret-key \
  --rotation-lambda-arn arn:aws:lambda:us-east-1:123456789012:function:SecretsManagerRotation \
  --rotation-rules AutomaticallyAfterDays=30
```

---

### HashiCorp Vault

```typescript
// lib/vault.ts
import Vault from 'node-vault';

const vault = Vault({
  apiVersion: 'v1',
  endpoint: process.env.VAULT_ADDR,
  token: process.env.VAULT_TOKEN
});

export async function getVaultSecret(path: string): Promise<any> {
  try {
    const result = await vault.read(`secret/data/${path}`);
    return result.data.data;
    
  } catch (error) {
    console.error(`Failed to read from Vault: ${path}`, error);
    throw error;
  }
}

// Usage
const secrets = await getVaultSecret('production/api-keys');
const stripeKey = secrets.stripe_secret_key;
```

**Benefits**:
- Dynamic secrets (generated on-demand)
- Secret leasing and renewal
- Comprehensive audit logging
- Multiple authentication methods
- Secret versioning

---

## Access Control

### Role-Based Access Control (RBAC)

```typescript
// Define roles and permissions
const secretPermissions = {
  // Platform admin: full access
  'platform-admin': {
    secrets: ['*'],
    actions: ['read', 'write', 'delete', 'rotate']
  },
  
  // Engineering lead: read all, write staging/dev
  'engineering-lead': {
    secrets: [
      'production/*',     // Read only
      'staging/*',        // Read/write
      'development/*'     // Read/write
    ],
    actions: ['read', 'write', 'rotate']
  },
  
  // Engineer: read staging/dev
  'engineer': {
    secrets: [
      'staging/*',
      'development/*'
    ],
    actions: ['read']
  },
  
  // CI/CD: read production (specific secrets only)
  'ci-cd': {
    secrets: [
      'production/database-url',
      'production/api-keys/*'
    ],
    actions: ['read']
  }
};

// Check access before retrieving secret
async function getSecretWithAuth(
  secretName: string,
  user: User
): Promise<string> {
  // Check if user has access
  const hasAccess = checkSecretAccess(user.role, secretName, 'read');
  
  if (!hasAccess) {
    // Log unauthorized access attempt
    await logSecurityEvent({
      type: 'unauthorized_secret_access',
      user: user.id,
      secret: secretName,
      timestamp: new Date()
    });
    
    throw new Error(`Access denied: ${secretName}`);
  }
  
  // Log authorized access
  await logSecretAccess({
    user: user.id,
    secret: secretName,
    action: 'read',
    timestamp: new Date()
  });
  
  return await getSecret(secretName);
}
```

### Multi-Factor Authentication (MFA)

```typescript
// Require MFA for accessing production secrets
async function getProductionSecret(
  secretName: string,
  user: User,
  mfaToken: string
): Promise<string> {
  // Verify MFA token
  const mfaValid = await verifyMFAToken(user.id, mfaToken);
  
  if (!mfaValid) {
    throw new Error('Invalid MFA token');
  }
  
  // Check if accessing production secret
  if (secretName.startsWith('production/')) {
    // Log MFA-protected access
    await logSecurityEvent({
      type: 'mfa_secret_access',
      user: user.id,
      secret: secretName,
      timestamp: new Date()
    });
  }
  
  return await getSecret(secretName);
}
```

---

## Rotation Strategies

### Automatic Rotation

```typescript
// Rotation schedule by secret type
const rotationSchedules = {
  // Critical secrets: monthly
  'database-master-password': {
    schedule: 'monthly',
    daysBeforeExpiry: 30
  },
  
  // High-priority secrets: quarterly
  'stripe-secret-key': {
    schedule: 'quarterly',
    daysBeforeExpiry: 90
  },
  
  // Medium-priority secrets: annually
  'analytics-api-key': {
    schedule: 'annually',
    daysBeforeExpiry: 365
  }
};

// Automatic rotation handler
async function rotateSecret(secretName: string): Promise<void> {
  console.log(`🔄 Starting rotation for: ${secretName}`);
  
  try {
    // 1. Generate new secret
    const newSecret = await generateNewSecret(secretName);
    
    // 2. Store new secret with version
    await storeSecretVersion(secretName, newSecret);
    
    // 3. Update dependent services
    await updateDependentServices(secretName, newSecret);
    
    // 4. Verify new secret works
    const verified = await verifySecretWorks(secretName, newSecret);
    
    if (!verified) {
      // Rollback to previous version
      await rollbackSecret(secretName);
      throw new Error('New secret verification failed');
    }
    
    // 5. Mark old secret for deletion (grace period)
    await scheduleOldSecretDeletion(secretName, 7);  // 7 days
    
    // 6. Notify team
    await notifyTeam({
      message: `✅ Secret rotated successfully: ${secretName}`,
      severity: 'info'
    });
    
    console.log(`✅ Rotation complete: ${secretName}`);
    
  } catch (error) {
    console.error(`❌ Rotation failed: ${secretName}`, error);
    
    await notifyTeam({
      message: `🚨 Secret rotation failed: ${secretName}`,
      severity: 'critical',
      error
    });
    
    throw error;
  }
}

// Schedule automatic rotations
cron.schedule('0 0 1 * *', async () => {
  // First day of each month
  const secretsToRotate = await getSecretsForRotation();
  
  for (const secret of secretsToRotate) {
    await rotateSecret(secret.name);
  }
});
```

### Zero-Downtime Rotation

```typescript
// Strategy: Dual-write period during rotation

// Phase 1: Start accepting both old and new secrets
async function startRotation(secretName: string): Promise<void> {
  // Generate new secret
  const newSecret = await generateNewSecret(secretName);
  
  // Store both old and new (dual-write)
  await storeSecretVersion(secretName, newSecret, 'pending');
  
  // Update application to accept both
  await updateSecretValidation(secretName, {
    mode: 'dual',
    oldSecret: await getSecret(secretName),
    newSecret: newSecret
  });
  
  console.log('✅ Phase 1 complete: Accepting both secrets');
}

// Phase 2: Update all clients to use new secret
async function migrateClients(secretName: string): Promise<void> {
  // Update environment variables across services
  await updateVercelEnvVar(secretName);
  await updateDockerSecrets(secretName);
  await updateK8sSecrets(secretName);
  
  // Wait for all instances to reload
  await waitForServiceReloads(300);  // 5 minutes
  
  console.log('✅ Phase 2 complete: All clients updated');
}

// Phase 3: Remove old secret
async function completeRotation(secretName: string): Promise<void> {
  // Verify no services using old secret
  const oldSecretUsage = await checkOldSecretUsage(secretName);
  
  if (oldSecretUsage > 0) {
    throw new Error('Old secret still in use, cannot complete rotation');
  }
  
  // Update to only accept new secret
  await updateSecretValidation(secretName, {
    mode: 'single',
    secret: await getSecret(secretName, 'pending')
  });
  
  // Promote new secret to primary
  await promoteSecretVersion(secretName, 'pending', 'primary');
  
  // Delete old secret
  await deleteOldSecretVersion(secretName);
  
  console.log('✅ Phase 3 complete: Rotation finished');
}
```

---

## Development Workflow

### Local Development

```bash
# .env.local (Git-ignored)
# Copy from .env.example and fill in real values

# Database
DATABASE_URL="postgresql://localhost:5432/dev_db"

# API Keys (use test/development keys)
STRIPE_SECRET_KEY="sk_test_..."  # Test key, not production!
OPENAI_API_KEY="sk-dev-..."      # Development key

# Auth0 (development tenant)
AUTH0_DOMAIN="dev-tenant.auth0.com"
AUTH0_CLIENT_ID="..."
AUTH0_CLIENT_SECRET="..."

# Session secret (generate unique per developer)
NEXTAUTH_SECRET="$(openssl rand -base64 32)"
```

**Setup instructions**:
```bash
# 1. Copy example environment file
cp .env.example .env.local

# 2. Generate session secret
echo "NEXTAUTH_SECRET=\"$(openssl rand -base64 32)\"" >> .env.local

# 3. Ask team lead for development API keys
# Add them to .env.local

# 4. Verify setup
npm run dev
```

### .env.example Template

```bash
# .env.example - Committed to Git
# This file documents all required environment variables

# =============================================================================
# Database
# =============================================================================
DATABASE_URL="postgresql://user:password@host:5432/database"

# =============================================================================
# Authentication
# =============================================================================
AUTH0_DOMAIN="your-tenant.auth0.com"
AUTH0_CLIENT_ID="your-client-id"
AUTH0_CLIENT_SECRET="your-client-secret"
NEXTAUTH_SECRET="generate-with-openssl-rand-base64-32"
NEXTAUTH_URL="http://localhost:3000"

# =============================================================================
# Payment Processing
# =============================================================================
STRIPE_SECRET_KEY="sk_test_... or sk_live_..."
STRIPE_WEBHOOK_SECRET="whsec_..."

# =============================================================================
# AI Services
# =============================================================================
OPENAI_API_KEY="sk-..."
ANTHROPIC_API_KEY="sk-ant-..."

# =============================================================================
# Email
# =============================================================================
SENDGRID_API_KEY="SG...."

# =============================================================================
# Monitoring
# =============================================================================
SENTRY_DSN="https://...@sentry.io/..."

# =============================================================================
# Feature Flags (optional)
# =============================================================================
NEXT_PUBLIC_ENABLE_NEW_FEATURE="false"
```

---

## Detection & Prevention

### Pre-Commit Hooks

```bash
# .husky/pre-commit
#!/bin/sh
. "$(dirname "$0")/_/husky.sh"

echo "🔍 Scanning for secrets..."

# Run secret scanning
./.cursor/tools/scan-secrets.sh

if [ $? -ne 0 ]; then
  echo "❌ Secret detected! Commit blocked."
  echo "Remove the secret and try again."
  exit 1
fi

echo "✅ No secrets detected"
```

### CI/CD Secret Scanning

```yaml
# .github/workflows/security-scan.yml
name: Security Scan

on: [push, pull_request]

jobs:
  secret-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0  # Full history for better detection
      
      - name: Scan for secrets
        run: |
          # Install truffleHog
          pip install truffleHog
          
          # Scan repository
          truffleHog --regex --entropy=True .
          
          # Fail if secrets found
          if [ $? -eq 0 ]; then
            echo "✅ No secrets detected"
          else
            echo "❌ Secrets detected!"
            exit 1
          fi
```

### Runtime Secret Detection

```typescript
// Detect secrets in logs and responses
function sanitizeLog(message: string): string {
  // Remove potential API keys
  message = message.replace(
    /sk_live_[a-zA-Z0-9]{24,}/g,
    'sk_live_[REDACTED]'
  );
  
  // Remove JWT tokens
  message = message.replace(
    /eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*/g,
    'jwt_[REDACTED]'
  );
  
  // Remove database passwords
  message = message.replace(
    /postgresql:\/\/[^:]+:([^@]+)@/g,
    'postgresql://user:[REDACTED]@'
  );
  
  return message;
}

// Sanitize all logs
const originalConsoleLog = console.log;
console.log = (...args: any[]) => {
  const sanitized = args.map(arg =>
    typeof arg === 'string' ? sanitizeLog(arg) : arg
  );
  originalConsoleLog(...sanitized);
};
```

---

## Incident Response

### Secret Exposure Response Plan

#### Phase 1: Detection (Immediate)

**How secrets get exposed**:
- Committed to Git
- Logged in application
- Exposed in client-side code
- Leaked in error messages
- Stolen from compromised system

**Detection methods**:
- GitHub secret scanning alerts
- Manual discovery
- Security researcher report
- Anomalous usage patterns

---

#### Phase 2: Assessment (< 5 minutes)

**Assess impact**:
```typescript
interface SecretExposureAssessment {
  // What was exposed?
  secretName: string;
  secretType: 'api-key' | 'database-password' | 'oauth-token' | 'encryption-key';
  sensitivity: 'critical' | 'high' | 'medium' | 'low';
  
  // Where was it exposed?
  exposureLocation: 'git-history' | 'logs' | 'client-code' | 'error-message' | 'stolen';
  exposureScope: 'public' | 'private-repo' | 'internal-only';
  
  // When was it exposed?
  exposureDate: Date;
  detectionDate: Date;
  exposureDuration: number;  // Hours
  
  // Who has access?
  potentialAccessors: string[];  // 'public' | 'team' | 'unknown'
}
```

---

#### Phase 3: Containment (< 15 minutes)

**Immediate actions**:

1. **Revoke exposed secret immediately**
   ```typescript
   await revokeSecret('stripe-secret-key');
   ```

2. **Generate and deploy new secret**
   ```typescript
   const newSecret = await generateNewSecret('stripe-secret-key');
   await deployNewSecret('stripe-secret-key', newSecret);
   ```

3. **Check for unauthorized usage**
   ```typescript
   const unauthorizedUsage = await checkSecretUsage(
     'stripe-secret-key',
     startDate: exposureDate,
     endDate: new Date()
   );
   ```

4. **If critical, enable maintenance mode**
   ```typescript
   if (assessment.sensitivity === 'critical') {
     await enableMaintenanceMode();
   }
   ```

---

#### Phase 4: Investigation (< 1 hour)

**Investigate extent of compromise**:

1. **Review access logs**
   ```bash
   # Check who accessed the secret
   grep "stripe-secret-key" /var/log/audit.log
   ```

2. **Check for unauthorized API calls**
   ```typescript
   // Review Stripe dashboard for suspicious activity
   const transactions = await stripe.charges.list({
     created: { gte: Math.floor(exposureDate.getTime() / 1000) }
   });
   
   // Flag suspicious transactions
   const suspicious = transactions.data.filter(tx => 
     tx.amount > 10000 || !isKnownCustomer(tx.customer)
   );
   ```

3. **Check for data exfiltration**
   ```bash
   # Check database access logs
   psql -c "SELECT * FROM pg_stat_activity WHERE query LIKE '%SELECT%' AND usename = 'exposed_user';"
   ```

---

#### Phase 5: Recovery (< 2 hours)

**Remediation steps**:

1. **Remove secret from Git history**
   ```bash
   # Use BFG Repo-Cleaner to remove secrets
   bfg --replace-text passwords.txt repo.git
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   git push --force
   ```

2. **Rotate all related secrets**
   ```typescript
   // Rotate all secrets that could be compromised
   await rotateSecret('database-password');
   await rotateSecret('session-secret');
   await rotateSecret('encryption-key');
   ```

3. **Notify affected parties**
   ```typescript
   await notifySecurityTeam({
     incident: 'secret-exposure',
     severity: 'high',
     details: assessment
   });
   
   // If customer data compromised, notify customers
   if (assessment.dataCompromised) {
     await notifyAffectedCustomers();
   }
   ```

---

#### Phase 6: Post-Incident (< 1 week)

**Follow-up actions**:

1. **Conduct post-mortem**
   - How did exposure occur?
   - What controls failed?
   - How can we prevent recurrence?

2. **Implement preventive measures**
   - Add pre-commit hooks
   - Enable secret scanning
   - Improve access controls
   - Additional training

3. **Update incident response plan**
   - Document lessons learned
   - Update runbooks
   - Conduct drill

---

## Compliance

### Regulatory Requirements

#### SOC 2
- Secrets stored encrypted at rest
- Access controls documented
- Secret access logged and audited
- Regular secret rotation
- Incident response procedures

#### PCI-DSS (if handling payments)
- Payment credentials never logged
- Encryption keys rotated annually
- Strong access control to secrets
- Audit trail of secret access

#### GDPR (if handling EU data)
- Encryption of personal data at rest
- Key management procedures documented
- Ability to revoke access immediately
- Data breach notification within 72 hours

---

## Best Practices

### Do's ✅

1. **Use environment variables for secrets**
   ```typescript
   const apiKey = process.env.STRIPE_SECRET_KEY;
   ```

2. **Different secrets for each environment**
   ```
   production/stripe-secret-key
   staging/stripe-secret-key
   development/stripe-secret-key
   ```

3. **Rotate secrets regularly**
   ```typescript
   cron.schedule('0 0 1 * *', rotateSecrets);
   ```

4. **Log secret access**
   ```typescript
   await logSecretAccess({
     user: userId,
     secret: secretName,
     action: 'read',
     timestamp: new Date()
   });
   ```

5. **Use secret managers**
   ```typescript
   const secret = await awsSecretsManager.getSecret('api-key');
   ```

---

### Don'ts ❌

1. **❌ Never commit secrets to Git**
   ```typescript
   // BAD!
   const apiKey = "sk_live_1234567890abcdef";
   ```

2. **❌ Never log secrets**
   ```typescript
   // BAD!
   console.log(`Using API key: ${apiKey}`);
   ```

3. **❌ Never hardcode secrets**
   ```typescript
   // BAD!
   const config = {
     dbPassword: "my-super-secret-password"
   };
   ```

4. **❌ Never expose secrets in client code**
   ```typescript
   // BAD! This is sent to the browser
   const STRIPE_SECRET_KEY = "sk_live_...";
   ```

5. **❌ Never use production secrets in development**
   ```typescript
   // BAD! Use development/test keys
   const apiKey = process.env.NODE_ENV === 'production' 
     ? prodKey 
     : prodKey;  // Should be testKey!
   ```

---

## Related Resources

### Rules
- @224-secrets-management.mdc - Secrets management standards
- @011-env-var-security.mdc - Environment variable security
- @012-api-security.mdc - API security

### Tools
- `.cursor/tools/scan-secrets.sh` - Detect hardcoded secrets
- `.cursor/tools/check-env-vars.sh` - Validate environment variables
- `.cursor/tools/rotate-secrets.sh` - Automate secret rotation

### Guides
- `guides/Security-Complete-Guide.md` - Comprehensive security guide
- `guides/Incident-Response-Complete-Guide.md` - Incident response

---

## Quick Start Checklist

- [ ] Set up `.env.local` for local development
- [ ] Create `.env.example` with all required variables
- [ ] Add `.env.local` to `.gitignore`
- [ ] Set up Vercel environment variables for all environments
- [ ] Install pre-commit hooks for secret scanning
- [ ] Enable GitHub secret scanning
- [ ] Document secret rotation schedule
- [ ] Set up secret access logging
- [ ] Create secret exposure incident response plan
- [ ] Conduct secret management training with team

---

**Time Investment**: 2-3 hours setup
**ROI**: Zero secret exposures, compliance-ready, rapid incident response

