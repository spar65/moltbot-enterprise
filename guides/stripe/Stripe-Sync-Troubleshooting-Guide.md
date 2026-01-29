# Stripe Sync Troubleshooting Guide

## Quick Diagnosis Checklist

When Stripe sync isn't working, check these in order:

1. **Sync returns 0 subscriptions synced?**

   - Check database constraints ✓
   - Check for missing columns ✓
   - Check timestamp handling ✓

2. **Getting database errors?**

   - Check unique constraints ✓
   - Check status constraints ✓
   - Check foreign key constraints ✓

3. **Wrong environment?**
   - Check which Stripe key is being used ✓
   - Verify database connection ✓

## Common Issues and Solutions

### Issue 1: "there is no unique or exclusion constraint matching the ON CONFLICT specification"

**Symptom**: Sync endpoint returns success but shows 0 subscriptions synced.

**Root Cause**: Missing unique constraint on (user_id, stripe_subscription_id).

**Solution**:

```sql
ALTER TABLE subscriptions
ADD CONSTRAINT subscriptions_user_id_stripe_subscription_id_unique
UNIQUE (user_id, stripe_subscription_id);
```

**Verification Script**:

```javascript
// scripts/check-subscription-constraints.js
const constraints = await sql`
  SELECT conname, pg_get_constraintdef(oid) as definition
  FROM pg_constraint
  WHERE conrelid = 'subscriptions'::regclass
  AND contype = 'u'
`;
console.log(constraints);
```

### Issue 2: "invalid input syntax for type timestamp: 0NaN-NaN-NaNTNaN:NaN:NaN.NaN+NaN:NaN"

**Symptom**: Sync fails with timestamp error when inserting subscriptions.

**Root Cause**: Stripe subscription objects have undefined `current_period_start` or `current_period_end`.

**Solution**: Add null checks for all timestamp fields:

```typescript
// Before
${new Date(subscription.current_period_start * 1000)}

// After
${subscription.current_period_start ? new Date(subscription.current_period_start * 1000) : null}
```

### Issue 3: "new row for relation \"subscriptions\" violates check constraint"

**Symptom**: Sync fails with constraint violation for subscription status.

**Root Cause**: Database constraint doesn't include all possible Stripe statuses.

**Solution**:

```sql
ALTER TABLE subscriptions
DROP CONSTRAINT IF EXISTS subscriptions_status_check;

ALTER TABLE subscriptions
ADD CONSTRAINT subscriptions_status_check
CHECK (status IN (
  'active', 'past_due', 'unpaid', 'canceled', 'cancelled',
  'incomplete', 'incomplete_expired', 'trialing', 'paused', 'inactive'
));
```

### Issue 4: Missing Required Columns

**Symptom**: Insert fails with "column does not exist" errors.

**Root Cause**: Subscriptions table missing Stripe-specific columns.

**Solution**:

```sql
ALTER TABLE subscriptions
ADD COLUMN IF NOT EXISTS stripe_subscription_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS stripe_price_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS stripe_customer_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS current_period_start TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS current_period_end TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS trial_end TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS cancel_at_period_end BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS amount INTEGER,
ADD COLUMN IF NOT EXISTS currency VARCHAR(10),
ADD COLUMN IF NOT EXISTS interval VARCHAR(20);
```

### Issue 5: Using Wrong Stripe Key

**Symptom**: Debug shows test data but you need production data.

**Root Cause**: Code using wrong environment variable or hardcoded test key.

**Solution**:

- Use `process.env.STRIPE_SECRET_KEY` (contains live key in production)
- Don't create separate `STRIPE_SECRET_KEY_LIVE` variables
- Vercel automatically manages test/live keys

**Debug Endpoint**:

```typescript
// pages/api/admin/stripe/debug.ts
export default async function handler(req, res) {
  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
  const keyType = process.env.STRIPE_SECRET_KEY?.startsWith("sk_live")
    ? "LIVE"
    : "TEST";

  const [customers, subscriptions] = await Promise.all([
    stripe.customers.list({ limit: 5 }),
    stripe.subscriptions.list({ limit: 5, status: "all" }),
  ]);

  res.json({
    environment: keyType,
    customers: customers.data.length,
    subscriptions: subscriptions.data.length,
  });
}
```

## Debugging Scripts

### 1. Complete Database Check

```javascript
// scripts/check-stripe-sync.js
async function checkDatabase() {
  const sql = neon(DATABASE_URL);

  // Check columns
  const columns = await sql`
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'subscriptions'
  `;

  // Check constraints
  const constraints = await sql`
    SELECT conname, pg_get_constraintdef(oid) 
    FROM pg_constraint 
    WHERE conrelid = 'subscriptions'::regclass
  `;

  // Check for duplicates
  const duplicates = await sql`
    SELECT user_id, stripe_subscription_id, COUNT(*) 
    FROM subscriptions 
    GROUP BY user_id, stripe_subscription_id 
    HAVING COUNT(*) > 1
  `;

  return { columns, constraints, duplicates };
}
```

### 2. Clean and Fix Production

```javascript
// scripts/clean-and-fix-production.js
async function cleanAndFix() {
  const sql = neon(DATABASE_URL);

  // 1. Remove duplicates
  await sql`
    DELETE FROM subscriptions 
    WHERE id NOT IN (
      SELECT DISTINCT ON (user_id, stripe_subscription_id) id
      FROM subscriptions
      ORDER BY user_id, stripe_subscription_id, updated_at DESC
    )
  `;

  // 2. Add missing columns
  await sql`ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS ...`;

  // 3. Fix constraints
  await sql`ALTER TABLE subscriptions ADD CONSTRAINT ...`;

  console.log("✅ Database ready for sync");
}
```

### 3. Test Single Subscription Sync

```javascript
// scripts/test-subscription-sync.js
async function testSingleSync() {
  const stripe = new Stripe(STRIPE_KEY);
  const sql = neon(DATABASE_URL);

  // Get one subscription
  const subs = await stripe.subscriptions.list({ limit: 1 });
  const sub = subs.data[0];

  console.log("Subscription:", {
    id: sub.id,
    current_period_start: sub.current_period_start,
    current_period_end: sub.current_period_end,
    created: sub.created,
  });

  // Try to insert
  try {
    await sql`INSERT INTO subscriptions ...`;
    console.log("✅ Insert successful");
  } catch (error) {
    console.log("❌ Error:", error.message);
    console.log("Code:", error.code);
    console.log("Detail:", error.detail);
  }
}
```

## Prevention Strategies

### 1. Database Migrations

Always include these in your migration:

```sql
-- Unique constraint for upserts
ALTER TABLE subscriptions
ADD CONSTRAINT subscriptions_user_id_stripe_subscription_id_unique
UNIQUE (user_id, stripe_subscription_id);

-- Complete status constraint
ALTER TABLE subscriptions
ADD CONSTRAINT subscriptions_status_check
CHECK (status IN (
  'active', 'past_due', 'unpaid', 'canceled', 'cancelled',
  'incomplete', 'incomplete_expired', 'trialing', 'paused', 'inactive'
));
```

### 2. Code Patterns

Always use safe timestamp handling:

```typescript
const safeTimestamp = (unixTime?: number) =>
  unixTime ? new Date(unixTime * 1000).toISOString() : null;

// Usage
current_period_start: safeTimestamp(subscription.current_period_start),
current_period_end: safeTimestamp(subscription.current_period_end),
```

### 3. Testing

Include these test scenarios:

- Subscriptions with undefined timestamps
- Subscriptions with all possible statuses
- Duplicate sync attempts (idempotency)
- Missing users (should create them)

## Emergency Recovery

If sync is completely broken:

1. **Clean the database**:

```javascript
await sql`DELETE FROM subscriptions`;
await sql`DELETE FROM users WHERE email IN (SELECT DISTINCT email FROM users GROUP BY email HAVING COUNT(*) > 1)`;
```

2. **Fix all constraints**:

```sql
-- Run all ALTER TABLE commands from above
```

3. **Test with one subscription**:

```javascript
node scripts/test-subscription-sync.js
```

4. **Run full sync**:
   Click "Sync Now" in Admin panel or call `/api/admin/stripe/sync`

## Monitoring

Add these checks to your monitoring:

1. **Sync Health Check**:

```typescript
// Check last successful sync
const lastSync = await sql`
  SELECT MAX(created_at) as last_sync
  FROM payment_logs
  WHERE event_type = 'sync_completed'
`;

if (Date.now() - lastSync > 24 * 60 * 60 * 1000) {
  alert('Stripe sync hasn't run in 24 hours');
}
```

2. **Data Consistency Check**:

```typescript
// Compare Stripe vs Database counts
const stripeCount = (await stripe.subscriptions.list({ limit: 1 })).total_count;
const dbCount = (await sql`SELECT COUNT(*) FROM subscriptions`)[0].count;

if (Math.abs(stripeCount - dbCount) > 5) {
  alert("Stripe/Database mismatch detected");
}
```

## Related Documentation

- [Stripe Sync Implementation Guide](./Stripe-Sync-Implementation-Guide.md)
- [Stripe API Error Codes](https://stripe.com/docs/error-codes)
- [PostgreSQL Error Codes](https://www.postgresql.org/docs/current/errcodes-appendix.html)
