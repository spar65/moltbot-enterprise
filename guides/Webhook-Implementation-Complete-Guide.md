

<example>
```typescript
// ✅ CORRECT - Recipient validates webhook signature before processing
export async function POST(request: Request) {
  const payload = await request.json();
  const signature = request.headers.get('X-Webhook-Signature');
  const timestamp = request.headers.get('X-Webhook-Timestamp');
  
  // 1. Validate timestamp (reject old webhooks - replay attack prevention)
  const webhookAge = Date.now() - new Date(timestamp).getTime();
  if (webhookAge > 5 * 60 * 1000) { // 5 minutes
    return new Response('Webhook too old', { status: 400 });
  }
  
  // 2. Verify HMAC signature
  if (!verifyWebhookSignature(payload, signature, WEBHOOK_SECRET)) {
    return new Response('Invalid signature', { status: 401 });
  }
  
  // 3. Check idempotency (prevent duplicate processing)
  const existing = await db.processedWebhooks.findUnique({
    where: { idempotencyKey: payload.idempotencyKey }
  });
  
  if (existing) {
    console.log('Duplicate webhook, already processed');
    return new Response('OK', { status: 200 });
  }
  
  // 4. Process webhook
  await processEvent(payload);
  
  // 5. Record processing
  await db.processedWebhooks.create({
    data: {
      idempotencyKey: payload.idempotencyKey,
      processedAt: new Date(),
    },
  });
  
  return new Response('OK', { status: 200 });
}
```
</example>

---

## Step 7: Testing Your Webhook System

### Unit Tests

Test each component in isolation:

```typescript
// __tests__/webhooks.test.ts
import { describe, it, expect } from '@jest/globals';
import {
  generateHmacSignature,
  verifyWebhookSignature,
  validateWebhookUrl,
} from '@/lib/webhooks';

describe('Webhook HMAC Signatures', () => {
  const testPayload = {
    event: 'test.event',
    idempotencyKey: 'test-123',
    timestamp: '2024-11-25T12:00:00Z',
    data: { message: 'Hello' },
  };
  const secret = 'test-secret';

  it('should generate consistent signatures', () => {
    const sig1 = generateHmacSignature(testPayload, secret);
    const sig2 = generateHmacSignature(testPayload, secret);
    
    expect(sig1).toBe(sig2);
    expect(sig1).toHaveLength(64); // SHA256 = 64 hex chars
  });

  it('should verify valid signatures', () => {
    const signature = generateHmacSignature(testPayload, secret);
    const isValid = verifyWebhookSignature(testPayload, signature, secret);
    
    expect(isValid).toBe(true);
  });

  it('should reject invalid signatures', () => {
    const isValid = verifyWebhookSignature(testPayload, 'wrong-signature', secret);
    
    expect(isValid).toBe(false);
  });

  it('should reject tampered payloads', () => {
    const signature = generateHmacSignature(testPayload, secret);
    const tamperedPayload = { ...testPayload, data: { message: 'Tampered!' } };
    const isValid = verifyWebhookSignature(tamperedPayload, signature, secret);
    
    expect(isValid).toBe(false);
  });
});

describe('Webhook URL Validation', () => {
  it('should accept valid HTTPS URLs', () => {
    const result = validateWebhookUrl('https://api.example.com/webhook');
    expect(result.valid).toBe(true);
  });

  it('should reject HTTP URLs in production', () => {
    process.env.NODE_ENV = 'production';
    const result = validateWebhookUrl('http://api.example.com/webhook');
    expect(result.valid).toBe(false);
    expect(result.error).toContain('HTTPS');
  });

  it('should reject localhost URLs (SSRF protection)', () => {
    const result = validateWebhookUrl('https://localhost:3000/webhook');
    expect(result.valid).toBe(false);
    expect(result.error).toContain('localhost');
  });

  it('should reject private IP addresses (SSRF protection)', () => {
    const urls = [
      'https://192.168.1.1/webhook',
      'https://10.0.0.1/webhook',
      'https://172.16.0.1/webhook',
    ];
    
    urls.forEach(url => {
      const result = validateWebhookUrl(url);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('private IP');
    });
  });
});
```

### Integration Tests

Test webhook delivery with real HTTP calls:

```typescript
// __tests__/integration/webhook-delivery.test.ts
import { describe, it, expect, beforeAll, afterAll } from '@jest/globals';
import { sendWebhook } from '@/lib/webhooks';
import { createServer, Server } from 'http';

describe('Webhook Delivery Integration', () => {
  let testServer: Server;
  let receivedWebhooks: any[] = [];
  const port = 9876;
  const webhookUrl = `http://localhost:${port}/webhook`;

  beforeAll((done) => {
    // Start test webhook receiver
    testServer = createServer((req, res) => {
      let body = '';
      req.on('data', chunk => { body += chunk; });
      req.on('end', () => {
        receivedWebhooks.push({
          headers: req.headers,
          body: JSON.parse(body),
        });
        res.writeHead(200);
        res.end('OK');
      });
    });
    testServer.listen(port, done);
  });

  afterAll((done) => {
    testServer.close(done);
  });

  beforeEach(() => {
    receivedWebhooks = [];
  });

  it('should deliver webhook successfully', async () => {
    const payload = {
      event: 'test.event',
      idempotencyKey: 'test-123',
      timestamp: new Date().toISOString(),
      data: { message: 'Hello' },
    };

    const result = await sendWebhook(webhookUrl, payload, 'test-secret');

    expect(result.success).toBe(true);
    expect(result.attempts).toBe(1);
    expect(receivedWebhooks).toHaveLength(1);
    expect(receivedWebhooks[0].body).toEqual(payload);
    expect(receivedWebhooks[0].headers['x-webhook-signature']).toBeDefined();
  });

  it('should include correct headers', async () => {
    const payload = {
      event: 'order.created',
      idempotencyKey: 'order-456',
      timestamp: new Date().toISOString(),
      data: { orderId: '456' },
    };

    await sendWebhook(webhookUrl, payload, 'test-secret');

    const received = receivedWebhooks[0];
    expect(received.headers['content-type']).toBe('application/json');
    expect(received.headers['x-webhook-event']).toBe('order.created');
    expect(received.headers['x-webhook-timestamp']).toBe(payload.timestamp);
    expect(received.headers['x-webhook-signature']).toHaveLength(64);
  });
});

describe('Webhook Retry Logic', () => {
  let testServer: Server;
  let attemptCount = 0;
  const port = 9877;
  const webhookUrl = `http://localhost:${port}/webhook`;

  beforeAll((done) => {
    testServer = createServer((req, res) => {
      attemptCount++;
      
      // Fail first 2 attempts, succeed on 3rd
      if (attemptCount < 3) {
        res.writeHead(500);
        res.end('Server Error');
      } else {
        res.writeHead(200);
        res.end('OK');
      }
    });
    testServer.listen(port, done);
  });

  afterAll((done) => {
    testServer.close(done);
  });

  beforeEach(() => {
    attemptCount = 0;
  });

  it('should retry on server errors and eventually succeed', async () => {
    const payload = {
      event: 'test.event',
      idempotencyKey: 'retry-test',
      timestamp: new Date().toISOString(),
      data: {},
    };

    const result = await sendWebhook(webhookUrl, payload, 'test-secret');

    expect(result.success).toBe(true);
    expect(result.attempts).toBe(3);
    expect(attemptCount).toBe(3);
  });
});
```

### End-to-End Tests

Test complete webhook flow with database:

```typescript
// __tests__/e2e/webhook-flow.test.ts
import { describe, it, expect } from '@jest/globals';
import { sendWebhookNotification } from '@/lib/webhooks';
import { prisma } from '@/lib/db';

describe('Complete Webhook Flow', () => {
  const organizationId = 'org-test-123';

  beforeEach(async () => {
    // Set up test organization with webhook URL
    await prisma.webhookSettings.upsert({
      where: { organizationId },
      create: {
        organizationId,
        webhookUrl: 'https://webhook.site/unique-url',
        webhookSecret: 'test-secret',
      },
      update: {},
    });
  });

  it('should create delivery record and send webhook', async () => {
    await sendWebhookNotification(
      organizationId,
      'test.completed',
      'test-run-123',
      { result: 'passed' }
    );

    // Verify delivery record created
    const delivery = await prisma.webhookDelivery.findFirst({
      where: {
        organizationId,
        idempotencyKey: 'test-run-123',
      },
    });

    expect(delivery).toBeDefined();
    expect(delivery?.event).toBe('test.completed');
    expect(delivery?.attempts).toBeGreaterThan(0);
    expect(['delivered', 'failed']).toContain(delivery?.status);
  });

  it('should prevent duplicate webhook sends using idempotency', async () => {
    const eventId = 'test-run-duplicate';

    // Send same webhook twice
    await sendWebhookNotification(organizationId, 'test.event', eventId, {});
    await sendWebhookNotification(organizationId, 'test.event', eventId, {});

    // Should only have one delivery record
    const deliveries = await prisma.webhookDelivery.findMany({
      where: {
        organizationId,
        idempotencyKey: eventId,
      },
    });

    expect(deliveries).toHaveLength(1);
  });
});
```

---

## Step 8: Monitoring & Observability

### Metrics to Track

**Delivery Metrics:**
- Success rate (percentage of successful deliveries)
- Average delivery time (latency)
- Retry rate (percentage requiring retries)
- Failure rate (percentage failing after all retries)

**System Health:**
- Pending webhooks (backlog)
- Failed webhooks (last 24 hours)
- Average attempts per delivery
- Circuit breaker trips (if implemented)

### Dashboard Implementation

```typescript
// API endpoint: GET /api/webhooks/metrics
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const organizationId = searchParams.get('organizationId');
  
  if (!organizationId) {
    return Response.json({ error: 'Missing organizationId' }, { status: 400 });
  }

  // Calculate metrics for last 7 days
  const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

  const deliveries = await prisma.webhookDelivery.findMany({
    where: {
      organizationId,
      createdAt: { gte: since },
    },
    select: {
      status: true,
      attempts: true,
      createdAt: true,
      deliveredAt: true,
    },
  });

  const total = deliveries.length;
  const successful = deliveries.filter(d => d.status === 'delivered').length;
  const failed = deliveries.filter(d => d.status === 'failed').length;
  const successRate = total > 0 ? (successful / total) * 100 : 0;

  // Average delivery time (for successful deliveries)
  const deliveryTimes = deliveries
    .filter(d => d.deliveredAt)
    .map(d => d.deliveredAt!.getTime() - d.createdAt.getTime());
  const avgDeliveryTime = deliveryTimes.length > 0
    ? deliveryTimes.reduce((sum, t) => sum + t, 0) / deliveryTimes.length
    : 0;

  // Retry rate
  const retriedCount = deliveries.filter(d => d.attempts > 1).length;
  const retryRate = total > 0 ? (retriedCount / total) * 100 : 0;

  return Response.json({
    period: '7 days',
    total,
    successful,
    failed,
    successRate: Math.round(successRate * 100) / 100,
    avgDeliveryTimeMs: Math.round(avgDeliveryTime),
    retryRate: Math.round(retryRate * 100) / 100,
  });
}
```

### Alerting

Set up alerts for webhook health:

```typescript
/**
 * Check webhook health and send alerts if needed
 */
export async function checkWebhookHealth(): Promise<void> {
  const organizations = await prisma.organization.findMany({
    where: { webhookEnabled: true },
    select: { id: true },
  });

  for (const org of organizations) {
    // Check failures in last hour
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    
    const recentDeliveries = await prisma.webhookDelivery.findMany({
      where: {
        organizationId: org.id,
        createdAt: { gte: oneHourAgo },
      },
      select: { status: true },
    });

    if (recentDeliveries.length === 0) continue;

    const failureRate = recentDeliveries.filter(d => d.status === 'failed').length / recentDeliveries.length;

    // Alert if >50% failure rate
    if (failureRate > 0.5) {
      await sendAlert({
        severity: 'high',
        message: `Webhook failure rate for ${org.id}: ${Math.round(failureRate * 100)}%`,
        organizationId: org.id,
        actionRequired: 'Check webhook URL and endpoint health',
      });
    }
  }
}

// Run this as a cron job every 15 minutes
```

---

## Step 9: User-Facing Features

### Webhook Configuration UI

Allow users to configure webhooks via UI:

```typescript
// app/settings/webhooks/page.tsx
'use client';

import { useState } from 'react';

export default function WebhookSettings() {
  const [webhookUrl, setWebhookUrl] = useState('');
  const [testResult, setTestResult] = useState<any>(null);
  const [isTestError, setIsSaving] = useState(false);

  const handleTestWebhook = async () => {
    setIsTesting(true);
    setTestResult(null);

    try {
      const response = await fetch('/api/webhooks/test', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ webhookUrl }),
      });

      const result = await response.json();
      setTestResult(result);
    } catch (error) {
      setTestResult({ error: 'Failed to send test webhook' });
    } finally {
      setIsTesting(false);
    }
  };

  const handleSave = async () => {
    setIsSaving(true);
    
    try {
      await fetch('/api/webhooks/settings', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ webhookUrl }),
      });
      
      alert('Webhook settings saved!');
    } catch (error) {
      alert('Failed to save settings');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">Webhook Settings</h1>

      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium mb-2">
            Webhook URL
          </label>
          <input
            type="url"
            value={webhookUrl}
            onChange={(e) => setWebhookUrl(e.target.value)}
            placeholder="https://api.example.com/webhook"
            className="w-full px-3 py-2 border rounded-md"
          />
          <p className="text-sm text-gray-600 mt-1">
            We'll send POST requests to this URL when events occur
          </p>
        </div>

        <div className="flex gap-3">
          <button
            onClick={handleTestWebhook}
            disabled={isTesting || !webhookUrl}
            className="px-4 py-2 bg-gray-200 rounded-md hover:bg-gray-300 disabled:opacity-50"
          >
            {isTesting ? 'Testing...' : 'Test Webhook'}
          </button>

          <button
            onClick={handleSave}
            disabled={isSaving || !webhookUrl}
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
          >
            {isSaving ? 'Saving...' : 'Save'}
          </button>
        </div>

        {testResult && (
          <div className={`p-4 rounded-md ${testResult.success ? 'bg-green-50 border border-green-200' : 'bg-red-50 border border-red-200'}`}>
            <p className="font-medium">
              {testResult.success ? '✅ Test successful!' : '❌ Test failed'}
            </p>
            <p className="text-sm mt-1">{testResult.message || testResult.error}</p>
          </div>
        )}
      </div>

      <div className="mt-8 p-4 bg-gray-50 rounded-md">
        <h2 className="font-medium mb-2">Webhook Documentation</h2>
        <p className="text-sm text-gray-700 mb-2">
          Your webhook endpoint should:
        </p>
        <ul className="text-sm text-gray-700 space-y-1 list-disc pl-5">
          <li>Accept POST requests with JSON payload</li>
          <li>Verify the X-Webhook-Signature header</li>
          <li>Return 200 OK within 30 seconds</li>
          <li>Handle idempotency (duplicate events)</li>
        </ul>
        <a href="/docs/webhooks" className="text-blue-600 text-sm hover:underline mt-2 inline-block">
          View full documentation →
        </a>
      </div>
    </div>
  );
}
```

### Webhook Delivery History

Show users their webhook delivery history:

```typescript
// app/settings/webhooks/history/page.tsx
export default async function WebhookHistory() {
  const deliveries = await prisma.webhookDelivery.findMany({
    where: { organizationId: 'current-org-id' }, // From auth
    orderBy: { createdAt: 'desc' },
    take: 50,
  });

  return (
    <div className="max-w-6xl mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">Webhook Delivery History</h1>

      <table className="w-full border-collapse">
        <thead>
          <tr className="bg-gray-100">
            <th className="text-left p-3 border">Event</th>
            <th className="text-left p-3 border">Status</th>
            <th className="text-left p-3 border">Attempts</th>
            <th className="text-left p-3 border">Created</th>
            <th className="text-left p-3 border">Delivered</th>
          </tr>
        </thead>
        <tbody>
          {deliveries.map(delivery => (
            <tr key={delivery.id} className="hover:bg-gray-50">
              <td className="p-3 border font-mono text-sm">{delivery.event}</td>
              <td className="p-3 border">
                <span className={`px-2 py-1 rounded text-xs ${
                  delivery.status === 'delivered' ? 'bg-green-100 text-green-800' : 
                  delivery.status === 'failed' ? 'bg-red-100 text-red-800' : 
                  'bg-yellow-100 text-yellow-800'
                }`}>
                  {delivery.status}
                </span>
              </td>
              <td className="p-3 border">{delivery.attempts}</td>
              <td className="p-3 border text-sm text-gray-600">
                {delivery.createdAt.toLocaleString()}
              </td>
              <td className="p-3 border text-sm text-gray-600">
                {delivery.deliveredAt?.toLocaleString() || '-'}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

---

## Step 10: Documentation for Users

### Example Webhook Receiver

Provide example code for users to implement webhook receivers:

**Node.js / Express Example:**

```javascript
// Example webhook receiver for Node.js / Express
const express = require('express');
const crypto = require('crypto');
const app = express();

app.use(express.json());

// Your webhook secret (from dashboard)
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET;

// Verify webhook signature
function verifySignature(payload, signature, secret) {
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(JSON.stringify(payload))
    .digest('hex');
  
  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature)
  );
}

// Webhook endpoint
app.post('/webhook', async (req, res) => {
  const signature = req.headers['x-webhook-signature'];
  const timestamp = req.headers['x-webhook-timestamp'];
  const payload = req.body;

  // 1. Verify timestamp (reject old webhooks)
  const webhookAge = Date.now() - new Date(timestamp).getTime();
  if (webhookAge > 5 * 60 * 1000) { // 5 minutes
    return res.status(400).send('Webhook too old');
  }

  // 2. Verify signature
  if (!verifySignature(payload, signature, WEBHOOK_SECRET)) {
    return res.status(401).send('Invalid signature');
  }

  // 3. Check for duplicate (idempotency)
  const alreadyProcessed = await checkIdempotency(payload.idempotencyKey);
  if (alreadyProcessed) {
    return res.status(200).send('Already processed');
  }

  // 4. Process webhook based on event type
  try {
    switch (payload.event) {
      case 'test.completed':
        await handleTestCompleted(payload.data);
        break;
      case 'test.failed':
        await handleTestFailed(payload.data);
        break;
      default:
        console.log(`Unknown event: ${payload.event}`);
    }

    // 5. Mark as processed
    await markAsProcessed(payload.idempotencyKey);

    // 6. Return 200 OK
    res.status(200).send('Webhook processed');

  } catch (error) {
    console.error('Error processing webhook:', error);
    res.status(500).send('Internal server error');
  }
});

app.listen(3000, () => {
  console.log('Webhook receiver listening on port 3000');
});
```

**Python / Flask Example:**

```python
# Example webhook receiver for Python / Flask
from flask import Flask, request, jsonify
import hmac
import hashlib
import json
import time
from datetime import datetime

app = Flask(__name__)

WEBHOOK_SECRET = 'your-webhook-secret'

def verify_signature(payload, signature, secret):
    """Verify HMAC signature"""
    expected_signature = hmac.new(
        secret.encode('utf-8'),
        json.dumps(payload).encode('utf-8'),
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(signature, expected_signature)

@app.route('/webhook', methods=['POST'])
def webhook():
    signature = request.headers.get('X-Webhook-Signature')
    timestamp = request.headers.get('X-Webhook-Timestamp')
    payload = request.get_json()

    # 1. Verify timestamp
    webhook_time = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
    age_seconds = (datetime.utcnow() - webhook_time).total_seconds()
    if age_seconds > 300:  # 5 minutes
        return 'Webhook too old', 400

    # 2. Verify signature
    if not verify_signature(payload, signature, WEBHOOK_SECRET):
        return 'Invalid signature', 401

    # 3. Check idempotency
    if check_idempotency(payload['idempotencyKey']):
        return 'Already processed', 200

    # 4. Process webhook
    try:
        event = payload['event']
        
        if event == 'test.completed':
            handle_test_completed(payload['data'])
        elif event == 'test.failed':
            handle_test_failed(payload['data'])
        else:
            print(f'Unknown event: {event}')

        # 5. Mark as processed
        mark_as_processed(payload['idempotencyKey'])

        return 'OK', 200

    except Exception as e:
        print(f'Error processing webhook: {e}')
        return 'Internal server error', 500

if __name__ == '__main__':
    app.run(port=3000)
```

---

## Common Issues & Troubleshooting

### Issue 1: Webhooks Not Being Received

**Symptoms:**
- No webhooks appearing in receiver logs
- Delivery status shows "pending" or "failed"

**Diagnosis:**
```bash
# Check webhook URL is accessible
curl -X POST https://your-webhook-url.com/webhook \
  -H "Content-Type: application/json" \
  -d '{"test": true}'

# Check firewall / network restrictions
# Check DNS resolution
# Check SSL certificate validity (for HTTPS)
```

**Solutions:**
- Ensure webhook URL is publicly accessible
- Check firewall rules allow incoming POST requests
- Verify SSL certificate is valid (HTTPS)
- Check URL is correct (no typos)

---

### Issue 2: Signature Verification Failing

**Symptoms:**
- Receiver rejects webhooks with "Invalid signature"
- 401 Unauthorized responses

**Diagnosis:**
```typescript
// Add logging to both sender and receiver
console.log('Payload:', JSON.stringify(payload));
console.log('Secret:', secret.substring(0, 4) + '***');
console.log('Generated signature:', signature);

// On receiver side
console.log('Received signature:', receivedSignature);
console.log('Expected signature:', expectedSignature);
```

**Common Causes:**
- Using wrong secret (sender and receiver must use same secret)
- Payload modified between signature generation and verification
- Character encoding issues (use UTF-8)
- JSON serialization inconsistency (key ordering)

**Solutions:**
- Verify both sides use same secret
- Use canonical JSON serialization
- Don't modify payload between generation and verification
- Check for whitespace / encoding issues

---

### Issue 3: Duplicate Webhook Processing

**Symptoms:**
- Same event processed multiple times
- Idempotency not working

**Diagnosis:**
```typescript
// Check idempotency key logging
console.log('Idempotency key:', payload.idempotencyKey);
console.log('Already processed?', alreadyProcessed);
```

**Solutions:**
- Ensure idempotency keys are truly unique per event
- Store processed keys in database (not in-memory cache)
- Set appropriate TTL on processed keys (7-30 days)
- Return 200 OK for duplicates (don't throw error)

---

### Issue 4: Webhooks Timing Out

**Symptoms:**
- Webhooks fail with timeout errors
- Receiver takes >30 seconds to respond

**Diagnosis:**
```typescript
// Add timing logs
const start = Date.now();
await processWebhook(payload);
console.log(`Processing took ${Date.now() - start}ms`);
```

**Solutions:**
- Return 200 OK immediately, process async
- Move heavy processing to background jobs
- Increase timeout (sender side) if necessary
- Optimize webhook processing logic

**Pattern: Async Processing**

```typescript
// Webhook receiver - acknowledge immediately, process async
export async function POST(request: Request) {
  const payload = await request.json();
  
  // Verify signature (fast)
  if (!verifyWebhookSignature(payload, ...)) {
    return new Response('Invalid signature', { status: 401 });
  }
  
  // Queue for async processing (fast)
  await queue.add('process-webhook', { payload });
  
  // Return immediately
  return new Response('OK', { status: 200 });
}

// Background job - process webhook
async function processWebhookJob(job) {
  const { payload } = job.data;
  
  // Heavy processing here (can take minutes)
  await heavyOperation(payload);
}
```

---

## Performance Optimization

### 1. Batch Webhook Delivery

If you have many webhooks to send, batch them:

```typescript
/**
 * Batch send webhooks (more efficient than individual sends)
 */
export async function batchSendWebhooks(
  events: Array<{ event: string; eventId: string; data: any }>,
  webhookUrl: string,
  secret: string
): Promise<void> {
  
  // Send all webhooks in parallel (up to 10 concurrent)
  const batchSize = 10;
  
  for (let i = 0; i < events.length; i += batchSize) {
    const batch = events.slice(i, i + batchSize);
    
    await Promise.all(
      batch.map(event =>
        sendWebhookNotification(
          event.organizationId,
          event.event,
          event.eventId,
          event.data
        )
      )
    );
  }
}
```

### 2. Circuit Breaker

Prevent wasting resources on consistently failing endpoints:

```typescript
/**
 * Circuit breaker for webhook delivery
 */
class WebhookCircuitBreaker {
  private failures = new Map<string, number>();
  private readonly threshold = 5; // Open circuit after 5 failures
  private readonly resetTime = 5 * 60 * 1000; // 5 minutes

  isOpen(organizationId: string): boolean {
    const failureCount = this.failures.get(organizationId) || 0;
    return failureCount >= this.threshold;
  }

  recordFailure(organizationId: string): void {
    const current = this.failures.get(organizationId) || 0;
    this.failures.set(organizationId, current + 1);

    // Reset after timeout
    setTimeout(() => {
      this.failures.delete(organizationId);
    }, this.resetTime);
  }

  recordSuccess(organizationId: string): void {
    this.failures.delete(organizationId);
  }
}

const circuitBreaker = new WebhookCircuitBreaker();

// Use in sendWebhook
export async function sendWebhook(...) {
  if (circuitBreaker.isOpen(organizationId)) {
    console.log('Circuit breaker OPEN, skipping webhook');
    return { success: false, error: 'Circuit breaker open' };
  }

  const result = await actualSendWebhook(...);

  if (result.success) {
    circuitBreaker.recordSuccess(organizationId);
  } else {
    circuitBreaker.recordFailure(organizationId);
  }

  return result;
}
```

---

## Security Best Practices Summary

✅ **DO:**
- Use HMAC-SHA256 signatures
- Use timing-safe comparison
- Validate webhook URLs (no localhost, private IPs)
- Enforce HTTPS in production
- Include timestamps (prevent replay)
- Rate limit webhook endpoints
- Log all webhook attempts
- Rotate secrets periodically

❌ **DON'T:**
- Send webhooks without signatures
- Use plain comparison for signature verification
- Allow HTTP in production
- Skip idempotency checks
- Hardcode secrets in code
- Retry 4xx errors
- Process webhooks synchronously if slow

---

## Production Checklist

Before going live with webhooks:

- [ ] HMAC signatures implemented and tested
- [ ] Retry logic with exponential backoff working
- [ ] Idempotency keys in all webhooks
- [ ] Delivery tracking in database
- [ ] Webhook URL validation (HTTPS, no private IPs)
- [ ] Test webhook endpoint implemented
- [ ] User documentation written
- [ ] Example webhook receivers provided
- [ ] Monitoring dashboard showing metrics
- [ ] Alerts configured for high failure rates
- [ ] Secrets stored in environment variables
- [ ] Circuit breaker implemented (optional but recommended)
- [ ] Load testing completed
- [ ] Error handling tested (network failures, timeouts, etc.)

---

## Resources & References

**Standards & Specifications:**
- [RFC 2104 - HMAC](https://tools.ietf.org/html/rfc2104)
- [OWASP - Webhook Security](https://cheatsheetseries.owasp.org/cheatsheets/Webhook_Security_Cheat_Sheet.html)

**Example Implementations:**
- [Stripe Webhooks](https://stripe.com/docs/webhooks)
- [GitHub Webhooks](https://docs.github.com/en/webhooks)
- [Twilio Webhooks](https://www.twilio.com/docs/usage/webhooks)

**Tools:**
- [webhook.site](https://webhook.site/) - Test webhook receiver
- [ngrok](https://ngrok.com/) - Tunnel for local webhook testing
- [requestbin](https://requestbin.com/) - Inspect webhook requests

---

**Guide Version**: 1.0  
**Last Updated**: 2024-11-25  
**Maintainer**: Development Team  
**Related Rule**: @385-webhook-implementation-standards.mdc


