# Cryptographic Verification - Complete Implementation Guide

**Version**: 1.0  
**Last Updated**: 2024-11-25  
**Related Rule**: @227-cryptographic-verification-standards.mdc  
**Difficulty**: Intermediate  
**Time to Implement**: 4-6 hours

---

## Table of Contents

1. [Overview](#overview)
2. [When to Use Cryptographic Verification](#when-to-use)
3. [Core Concepts](#core-concepts)
4. [Step-by-Step Implementation](#step-by-step-implementation)
5. [Testing & Validation](#testing--validation)
6. [Common Issues & Troubleshooting](#common-issues--troubleshooting)
7. [Production Deployment](#production-deployment)
8. [Advanced Patterns](#advanced-patterns)

---

## Overview

Cryptographic verification provides **mathematical proof** that data hasn't been tampered with. Unlike traditional security measures that rely on "trust us," cryptographic hashing creates verifiable proof that anyone can check.

### What You'll Build

By the end of this guide, you'll have:

✅ Deterministic hash generation using canonical JSON  
✅ Immutable hash storage in database  
✅ Public verification endpoint (no authentication)  
✅ Client-side verification UI  
✅ Audit logging for all verification attempts  
✅ Comprehensive test coverage  

### Real-World Example: GiDanc Health Check

GiDanc's ethical assessment system uses cryptographic verification to:
- Prove assessment results haven't been manipulated
- Allow public verification without API access
- Build trust with users (transparent, verifiable)
- Meet compliance requirements for data integrity

**Result**: Users can cryptographically verify their ethical assessment scores, proving the system hasn't been tampered with.

---

## When to Use

### ✅ Good Use Cases

**Trust-Critical Systems:**
- Assessment/test results
- Financial transactions
- Audit logs and compliance records
- Billing and invoicing
- Legal documents

**Public Accountability:**
- Open data initiatives
- Research findings
- Government transparency
- Certification systems

**Regulatory Compliance:**
- Healthcare records (HIPAA)
- Financial audits (SOX)
- Data privacy (GDPR Article 32 - integrity)

### ❌ Not Suitable For

- Password storage (use `bcrypt`, not SHA-256)
- Real-time encryption (use AES, not hashing)
- User authentication tokens (use JWT or sessions)
- Frequently changing data (hash becomes obsolete)

---

## Core Concepts

### 1. Hash Functions

**What is a Hash?**
- One-way mathematical function
- Input → Fixed-length output (digest)
- Same input always produces same output (deterministic)
- Impossible to reverse (one-way)

**Example:**
```typescript
hash("Hello, World!") → "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f"
hash("Hello, World!") → "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f" // Same!
hash("Hello, World?") → "c0535e4be2b79ffd93291305436bf889314e4a3faec05ecffcbb7df31ad9e51a" // Different!
```

**Key Properties:**
- **Deterministic**: Same input → Same output
- **Avalanche Effect**: Tiny change → Completely different hash
- **Collision Resistant**: Nearly impossible to find two inputs with same hash
- **One-Way**: Cannot reverse hash back to input

### 2. Canonical JSON

**The Problem:**
```javascript
// Standard JSON has inconsistent key ordering
const obj = { name: "Alice", age: 30 };

JSON.stringify(obj);  // Might be: {"name":"Alice","age":30}
JSON.stringify(obj);  // Might be: {"age":30,"name":"Alice"}  ← DIFFERENT!

// Different strings = different hashes!
hash('{"name":"Alice","age":30}')  → "abc123..."
hash('{"age":30,"name":"Alice"}')  → "def456..."  ← DIFFERENT HASH!
```

**The Solution:**
```javascript
import stringify from 'fast-json-stable-stringify';

// Canonical JSON always has consistent key ordering
stringify(obj);  // ALWAYS: {"age":30,"name":"Alice"}
stringify(obj);  // ALWAYS: {"age":30,"name":"Alice"}  ← SAME!

// Same string = same hash (deterministic!)
hash(stringify(obj));  // ALWAYS: "xyz789..."
hash(stringify(obj));  // ALWAYS: "xyz789..."  ← SAME HASH!
```

### 3. Hash Verification Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. CREATE & STORE                                            │
├─────────────────────────────────────────────────────────────┤
│ Data → Canonical JSON → SHA-256 → Hash                       │
│ Store: { data, hash }                                        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 2. VERIFY (Later)                                            │
├─────────────────────────────────────────────────────────────┤
│ Data → Canonical JSON → SHA-256 → Computed Hash              │
│ Compare: Computed Hash === Stored Hash?                      │
│   ✅ Match    → Data unchanged (verified!)                   │
│   ❌ Mismatch → Data tampered (alert!)                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Step-by-Step Implementation

### Step 1: Install Dependencies

```bash
npm install fast-json-stable-stringify
npm install --save-dev @types/node  # For crypto types
```

### Step 2: Create Hash Utility

Create `lib/verification/hash.ts`:

```typescript
import crypto from 'crypto';
import stringify from 'fast-json-stable-stringify';

/**
 * Compute deterministic hash of data
 * 
 * Uses canonical JSON to ensure same data always produces same hash
 * 
 * @param data - Object to hash
 * @returns SHA-256 hash (hex string, 64 characters)
 */
export function computeHash(data: Record<string, unknown>): string {
  // Step 1: Canonical JSON (consistent key ordering)
  const canonicalJson = stringify(data);
  
  // Step 2: SHA-256 hash
  const hash = crypto
    .createHash('sha256')
    .update(canonicalJson, 'utf8')
    .digest('hex');
  
  return hash;
}

/**
 * Verify hash matches expected value
 * 
 * Uses timing-safe comparison to prevent timing attacks
 */
export function verifyHash(
  data: Record<string, unknown>,
  expectedHash: string
): boolean {
  const computedHash = computeHash(data);
  
  // Timing-safe comparison (prevents timing attacks)
  if (computedHash.length !== expectedHash.length) {
    return false;
  }
  
  return crypto.timingSafeEqual(
    Buffer.from(computedHash),
    Buffer.from(expectedHash)
  );
}
```

### Step 3: Define Hash Payload Structure

Create `lib/verification/types.ts`:

```typescript
/**
 * Generic hash payload structure
 * 
 * Include:
 * - Unique identifier (prevents replay)
 * - Data to verify
 * - Timestamp (prevents time manipulation)
 */
export interface HashPayload {
  id: string;           // Unique identifier
  data: unknown;        // Data to verify
  timestamp: string;    // ISO 8601 timestamp
}

/**
 * Example: Assessment result payload
 */
export interface AssessmentHashPayload {
  runId: string;
  scores: {
    lying: number;
    cheating: number;
    stealing: number;
    harm: number;
  };
  timestamp: string;
}

/**
 * Example: Transaction payload
 */
export interface TransactionHashPayload {
  transactionId: string;
  amount: number;
  currency: string;
  from: string;
  to: string;
  timestamp: string;
}
```

### Step 4: Create Hash Generation Functions

Create `lib/verification/generate.ts`:

```typescript
import { computeHash } from './hash';
import type { AssessmentHashPayload } from './types';

/**
 * Generate hash for assessment result
 */
export function hashAssessmentResult(
  runId: string,
  scores: Record<string, number>,
  calculatedAt?: Date
): string {
  const timestamp = calculatedAt?.toISOString() || new Date().toISOString();
  
  const payload: AssessmentHashPayload = {
    runId,
    scores,
    timestamp,
  };
  
  return computeHash(payload);
}

/**
 * Generate hash for financial transaction
 */
export function hashTransaction(
  transactionId: string,
  amount: number,
  currency: string,
  from: string,
  to: string
): string {
  const payload = {
    transactionId,
    amount,
    currency,
    from,
    to,
    timestamp: new Date().toISOString(),
  };
  
  return computeHash(payload);
}

/**
 * Create standardized hash payload
 * 
 * Helper function to ensure consistent payload structure
 */
export function createHashPayload(
  id: string,
  data: unknown
): Record<string, unknown> {
  return {
    id,
    data,
    timestamp: new Date().toISOString(),
  };
}
```

### Step 5: Database Schema

Add verification hash column to your table:

```sql
-- Add verification hash to existing table
ALTER TABLE assessment_results
ADD COLUMN verification_hash VARCHAR(64) NOT NULL;

-- Create index for fast lookups
CREATE INDEX idx_assessment_results_hash 
ON assessment_results(verification_hash);

-- Optional: Prevent hash updates (immutability)
ALTER TABLE assessment_results
ADD CONSTRAINT immutable_verification_hash 
CHECK (verification_hash IS NOT NULL);
```

**Or with Prisma:**

```prisma
model AssessmentResult {
  id               String   @id @default(cuid())
  runId            String   @unique
  scores           Json
  calculatedAt     DateTime
  verificationHash String   @db.VarChar(64)  // SHA-256 = 64 hex chars
  createdAt        DateTime @default(now())
  
  @@index([verificationHash])
}
```

### Step 6: Store Results with Hash

Create `lib/verification/store.ts`:

```typescript
import { prisma } from '@/lib/db';
import { hashAssessmentResult } from './generate';

/**
 * Store assessment result with verification hash
 */
export async function storeVerifiedResult(
  runId: string,
  scores: Record<string, number>
): Promise<{ hash: string }> {
  
  const calculatedAt = new Date();
  
  // Compute hash
  const hash = hashAssessmentResult(runId, scores, calculatedAt);
  
  // Store immutably
  await prisma.assessmentResult.create({
    data: {
      runId,
      scores,
      calculatedAt,
      verificationHash: hash,
    },
  });
  
  return { hash };
}

/**
 * Get result with hash for verification
 */
export async function getVerifiedResult(runId: string) {
  const result = await prisma.assessmentResult.findUnique({
    where: { runId },
    select: {
      runId: true,
      scores: true,
      calculatedAt: true,
      verificationHash: true,
    },
  });
  
  if (!result) {
    throw new Error('Result not found');
  }
  
  return {
    runId: result.runId,
    scores: result.scores as Record<string, number>,
    timestamp: result.calculatedAt.toISOString(),
    hash: result.verificationHash,
  };
}
```

### Step 7: Public Verification Endpoint

Create `app/api/verify/route.ts`:

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { computeHash } from '@/lib/verification/hash';
import { prisma } from '@/lib/db';

/**
 * Public verification endpoint
 * 
 * POST /api/verify
 * Body: { runId, scores, timestamp, hash }
 * 
 * Anyone can verify result authenticity without authentication
 */
export async function POST(request: NextRequest) {
  try {
    const { runId, scores, timestamp, hash: providedHash } = await request.json();
    
    // Validate input
    if (!runId || !scores || !timestamp || !providedHash) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }
    
    // Recompute hash from provided data
    const payload = { runId, scores, timestamp };
    const computedHash = computeHash(payload);
    
    // Verify against stored hash
    const storedResult = await prisma.assessmentResult.findUnique({
      where: { runId },
      select: { verificationHash: true },
    });
    
    if (!storedResult) {
      return NextResponse.json(
        { error: 'Result not found' },
        { status: 404 }
      );
    }
    
    const matchesComputed = providedHash === computedHash;
    const matchesStored = storedResult.verificationHash === computedHash;
    const verified = matchesComputed && matchesStored;
    
    // Log verification attempt (audit trail)
    await prisma.verificationLog.create({
      data: {
        runId,
        providedHash,
        computedHash,
        verified,
        ipAddress: request.headers.get('x-forwarded-for') || 'unknown',
        userAgent: request.headers.get('user-agent') || 'unknown',
      },
    });
    
    return NextResponse.json({
      verified,
      hash: computedHash,
      matchesStored,
      message: verified
        ? 'Result verified successfully - data has not been tampered with'
        : 'Verification failed - data may have been modified',
    });
    
  } catch (error) {
    console.error('Verification error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```

### Step 8: Client-Side Verification UI

Create `components/VerifyIntegrityButton.tsx`:

```typescript
'use client';

import { useState } from 'react';

interface VerifyIntegrityButtonProps {
  runId: string;
  scores: Record<string, number>;
  timestamp: string;
  hash: string;
}

export function VerifyIntegrityButton({
  runId,
  scores,
  timestamp,
  hash,
}: VerifyIntegrityButtonProps) {
  const [status, setStatus] = useState<'idle' | 'verifying' | 'verified' | 'failed'>('idle');
  const [message, setMessage] = useState('');
  
  const handleVerify = async () => {
    setStatus('verifying');
    setMessage('');
    
    try {
      const response = await fetch('/api/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ runId, scores, timestamp, hash }),
      });
      
      const data = await response.json();
      
      if (data.verified) {
        setStatus('verified');
        setMessage(data.message);
      } else {
        setStatus('failed');
        setMessage(data.message || 'Verification failed');
      }
      
    } catch (error) {
      setStatus('failed');
      setMessage('Network error - could not verify');
    }
  };
  
  return (
    <div className="verification-widget">
      <button
        onClick={handleVerify}
        disabled={status === 'verifying'}
        className={`verify-button ${status}`}
      >
        {status === 'idle' && '🔒 Verify Integrity'}
        {status === 'verifying' && '⏳ Verifying...'}
        {status === 'verified' && '✅ Verified'}
        {status === 'failed' && '❌ Failed'}
      </button>
      
      {message && (
        <div className={`message ${status === 'verified' ? 'success' : 'error'}`}>
          {message}
        </div>
      )}
      
      {status === 'verified' && (
        <details className="verification-details">
          <summary>View Verification Details</summary>
          <div className="details-content">
            <div><strong>Run ID:</strong> {runId}</div>
            <div><strong>Timestamp:</strong> {timestamp}</div>
            <div><strong>Hash:</strong> <code>{hash}</code></div>
            <div className="hash-explanation">
              This cryptographic hash proves the data hasn't been tampered with.
              Anyone can verify this independently.
            </div>
          </div>
        </details>
      )}
    </div>
  );
}
```

**CSS** (`styles/verification.css`):

```css
.verification-widget {
  margin: 1rem 0;
  padding: 1rem;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  background: #f9f9f9;
}

.verify-button {
  padding: 0.75rem 1.5rem;
  font-size: 1rem;
  font-weight: 600;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s;
}

.verify-button.idle {
  background: #4CAF50;
  color: white;
}

.verify-button.idle:hover {
  background: #45a049;
}

.verify-button.verifying {
  background: #FFC107;
  color: #000;
  cursor: wait;
}

.verify-button.verified {
  background: #2196F3;
  color: white;
}

.verify-button.failed {
  background: #F44336;
  color: white;
}

.message {
  margin-top: 0.75rem;
  padding: 0.75rem;
  border-radius: 4px;
}

.message.success {
  background: #d4edda;
  color: #155724;
  border: 1px solid #c3e6cb;
}

.message.error {
  background: #f8d7da;
  color: #721c24;
  border: 1px solid #f5c6cb;
}

.verification-details {
  margin-top: 1rem;
  padding: 0.75rem;
  background: white;
  border-radius: 4px;
}

.details-content {
  margin-top: 0.5rem;
  font-size: 0.9rem;
}

.details-content code {
  display: block;
  margin-top: 0.25rem;
  padding: 0.5rem;
  background: #f5f5f5;
  border-radius: 3px;
  font-family: monospace;
  font-size: 0.85rem;
  word-break: break-all;
}

.hash-explanation {
  margin-top: 0.75rem;
  padding: 0.5rem;
  background: #e3f2fd;
  border-left: 3px solid #2196F3;
  font-size: 0.85rem;
  font-style: italic;
}
```

---

## Testing & Validation

### Unit Tests

Create `__tests__/verification/hash.test.ts`:

```typescript
import { describe, it, expect } from '@jest/globals';
import { computeHash, verifyHash } from '@/lib/verification/hash';

describe('Hash Computation', () => {
  it('should produce deterministic hashes', () => {
    const data = { id: 'test-123', value: 42, timestamp: '2024-11-25T12:00:00Z' };
    
    const hash1 = computeHash(data);
    const hash2 = computeHash(data);
    
    expect(hash1).toBe(hash2);
    expect(hash1).toHaveLength(64);  // SHA-256 = 64 hex chars
  });
  
  it('should handle key ordering consistently', () => {
    // Same data, different key order
    const data1 = { name: 'Alice', age: 30, city: 'NYC' };
    const data2 = { age: 30, city: 'NYC', name: 'Alice' };
    
    const hash1 = computeHash(data1);
    const hash2 = computeHash(data2);
    
    expect(hash1).toBe(hash2);  // Should be same due to canonical JSON
  });
  
  it('should produce different hashes for different data', () => {
    const data1 = { value: 42 };
    const data2 = { value: 43 };
    
    const hash1 = computeHash(data1);
    const hash2 = computeHash(data2);
    
    expect(hash1).not.toBe(hash2);
  });
  
  it('should detect tampering (avalanche effect)', () => {
    const original = { message: 'Hello, World!' };
    const tampered = { message: 'Hello, World?' };  // One character different
    
    const hash1 = computeHash(original);
    const hash2 = computeHash(tampered);
    
    expect(hash1).not.toBe(hash2);
    // Hashes should be completely different (not just one bit)
    expect(hash1.substring(0, 10)).not.toBe(hash2.substring(0, 10));
  });
});

describe('Hash Verification', () => {
  it('should verify matching hashes', () => {
    const data = { id: 'test-123', value: 42 };
    const hash = computeHash(data);
    
    const isValid = verifyHash(data, hash);
    
    expect(isValid).toBe(true);
  });
  
  it('should reject mismatched hashes', () => {
    const data = { id: 'test-123', value: 42 };
    const wrongHash = 'abc123def456...';
    
    const isValid = verifyHash(data, wrongHash);
    
    expect(isValid).toBe(false);
  });
  
  it('should detect tampered data', () => {
    const original = { id: 'test-123', value: 42 };
    const hash = computeHash(original);
    
    const tampered = { id: 'test-123', value: 43 };  // Changed value
    const isValid = verifyHash(tampered, hash);
    
    expect(isValid).toBe(false);
  });
});
```

### Integration Tests

Create `__tests__/api/verify.test.ts`:

```typescript
import { describe, it, expect } from '@jest/globals';
import { POST } from '@/app/api/verify/route';
import { computeHash } from '@/lib/verification/hash';
import { prisma } from '@/lib/db';

describe('Verification Endpoint', () => {
  const runId = 'test-run-123';
  const scores = { lying: 7, cheating: 6, stealing: 5, harm: 8 };
  const timestamp = '2024-11-25T12:00:00Z';
  const hash = computeHash({ runId, scores, timestamp });
  
  beforeEach(async () => {
    // Create test result
    await prisma.assessmentResult.create({
      data: {
        runId,
        scores,
        calculatedAt: new Date(timestamp),
        verificationHash: hash,
      },
    });
  });
  
  afterEach(async () => {
    // Cleanup
    await prisma.assessmentResult.deleteMany({ where: { runId } });
    await prisma.verificationLog.deleteMany({ where: { runId } });
  });
  
  it('should verify valid result', async () => {
    const request = new Request('http://localhost/api/verify', {
      method: 'POST',
      body: JSON.stringify({ runId, scores, timestamp, hash }),
    });
    
    const response = await POST(request as any);
    const data = await response.json();
    
    expect(response.status).toBe(200);
    expect(data.verified).toBe(true);
    expect(data.hash).toBe(hash);
  });
  
  it('should reject tampered data', async () => {
    const tamperedScores = { ...scores, lying: 10 };  // Changed score
    
    const request = new Request('http://localhost/api/verify', {
      method: 'POST',
      body: JSON.stringify({ runId, scores: tamperedScores, timestamp, hash }),
    });
    
    const response = await POST(request as any);
    const data = await response.json();
    
    expect(data.verified).toBe(false);
  });
  
  it('should log verification attempt', async () => {
    const request = new Request('http://localhost/api/verify', {
      method: 'POST',
      body: JSON.stringify({ runId, scores, timestamp, hash }),
    });
    
    await POST(request as any);
    
    const log = await prisma.verificationLog.findFirst({
      where: { runId },
    });
    
    expect(log).toBeDefined();
    expect(log?.verified).toBe(true);
  });
});
```

---

## Common Issues & Troubleshooting

### Issue 1: Hashes Don't Match (Key Ordering)

**Symptoms:**
- Same data produces different hashes
- Verification fails even with correct data

**Cause:**
```typescript
// ❌ Using standard JSON (inconsistent key ordering)
const hash1 = crypto.createHash('sha256').update(JSON.stringify({a:1, b:2})).digest('hex');
const hash2 = crypto.createHash('sha256').update(JSON.stringify({b:2, a:1})).digest('hex');
// hash1 !== hash2  ← Different hashes for same data!
```

**Solution:**
```typescript
// ✅ Use canonical JSON
import stringify from 'fast-json-stable-stringify';

const hash1 = crypto.createHash('sha256').update(stringify({a:1, b:2})).digest('hex');
const hash2 = crypto.createHash('sha256').update(stringify({b:2, a:1})).digest('hex');
// hash1 === hash2  ← Same hash regardless of key order!
```

---

### Issue 2: Timestamp Mismatch

**Symptoms:**
- Hashes don't match even with canonical JSON
- Verification fails sporadically

**Cause:**
```typescript
// ❌ Different timestamp formats
const hash1 = computeHash({ id: '123', timestamp: new Date() });  // Different milliseconds
const hash2 = computeHash({ id: '123', timestamp: new Date() });  // Different milliseconds
```

**Solution:**
```typescript
// ✅ Use ISO 8601 strings, store timestamp
const timestamp = new Date().toISOString();
const hash1 = computeHash({ id: '123', timestamp });
const hash2 = computeHash({ id: '123', timestamp });  // Same timestamp = same hash
```

---

### Issue 3: Floating Point Precision

**Symptoms:**
- Hashes different for "same" numeric values
- Verification fails with scores like 7.333333...

**Cause:**
```typescript
// ❌ Floating point precision differences
const hash1 = computeHash({ score: 7.333333333333333 });
const hash2 = computeHash({ score: 7.333333333333334 });  // Tiny difference
```

**Solution:**
```typescript
// ✅ Round to fixed precision before hashing
const roundScore = (score: number) => Math.round(score * 100) / 100;  // 2 decimal places

const hash1 = computeHash({ score: roundScore(7.333333333333333) });  // 7.33
const hash2 = computeHash({ score: roundScore(7.333333333333334) });  // 7.33
// Same hash!
```

---

## Production Deployment

### Pre-Deployment Checklist

- [ ] Canonical JSON library installed (`fast-json-stable-stringify`)
- [ ] Hash computation uses SHA-256 minimum
- [ ] Database schema includes `verification_hash` column
- [ ] Verification endpoint is public (no authentication)
- [ ] Client-side verification UI implemented
- [ ] Audit logging for verification attempts
- [ ] Tests cover tampering detection
- [ ] Documentation for users on how to verify
- [ ] Monitor verification success rate

### Performance Considerations

**Hash Computation:**
- SHA-256 is fast (~50-100 MB/s)
- Typical payload: <1KB → <1ms to hash
- No performance impact for most use cases

**Database:**
- Index `verification_hash` column for fast lookups
- Store hash as VARCHAR(64) (SHA-256 = 64 hex chars)
- Consider partitioning for large tables

**Caching:**
- Cache frequently verified results
- TTL: 5-15 minutes (balance freshness vs performance)
- Invalidate cache on data updates

---

## Advanced Patterns

### 1. Hash Chains (Blockchain-like)

Link results together for immutable audit trail:

```typescript
export function hashWithPrevious(
  currentData: Record<string, unknown>,
  previousHash: string
): string {
  const payload = {
    ...currentData,
    previousHash,  // Link to previous result
  };
  
  return computeHash(payload);
}

// Usage: Each result links to previous
const hash1 = computeHash({ id: '1', data: 'A' });
const hash2 = hashWithPrevious({ id: '2', data: 'B' }, hash1);
const hash3 = hashWithPrevious({ id: '3', data: 'C' }, hash2);

// Tampering with any result breaks the chain!
```

### 2. Merkle Trees (Efficient Batch Verification)

Verify multiple results efficiently:

```typescript
export function buildMerkleTree(hashes: string[]): string {
  if (hashes.length === 1) return hashes[0];
  
  const tree: string[] = [];
  
  for (let i = 0; i < hashes.length; i += 2) {
    const left = hashes[i];
    const right = hashes[i + 1] || left;  // Duplicate last if odd
    
    const combined = computeHash({ left, right });
    tree.push(combined);
  }
  
  return buildMerkleTree(tree);  // Recursive
}

// Verify 1000 results with single root hash!
```

### 3. Digital Signatures (Non-Repudiation)

Add public/private key signatures for stronger proof:

```typescript
import { sign, verify } from 'crypto';

export function signHash(hash: string, privateKey: string): string {
  const signature = sign('sha256', Buffer.from(hash), {
    key: privateKey,
    padding: crypto.constants.RSA_PKCS1_PSS_PADDING,
  });
  
  return signature.toString('base64');
}

export function verifySignature(
  hash: string,
  signature: string,
  publicKey: string
): boolean {
  return verify(
    'sha256',
    Buffer.from(hash),
    {
      key: publicKey,
      padding: crypto.constants.RSA_PKCS1_PSS_PADDING,
    },
    Buffer.from(signature, 'base64')
  );
}
```

---

**Guide Version**: 1.0  
**Last Updated**: 2024-11-25  
**Maintainer**: Development Team  
**Related Rule**: @227-cryptographic-verification-standards.mdc


