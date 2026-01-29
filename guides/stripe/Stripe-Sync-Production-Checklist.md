# Stripe Sync Production Deployment Checklist

## Pre-Deployment Database Verification

### 1. Check Database Schema

Run these checks BEFORE deploying sync functionality:

```sql
-- Check if all required columns exist
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'subscriptions'
AND column_name IN (
  'stripe_subscription_id',
  'stripe_price_id',
  'stripe_customer_id',
  'current_period_start',
  'current_period_end',
  'amount',
  'currency',
  'interval',
  'trial_end',
  'cancel_at_period_end'
);
```

**Expected**: All 10 columns should be present

### 2. Verify Constraints

```sql
-- Check for required unique constraint
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'subscriptions'::regclass
AND contype = 'u';
```

**Required**: Must have constraint on `(user_id, stripe_subscription_id)`

### 3. Check Status Constraint

```sql
-- Get current status constraint
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'subscriptions'::regclass
AND conname LIKE '%status%';
```

**Required**: Must include: `incomplete_expired`, `trialing`, `paused`

### 4. Check for Duplicate Users

```sql
-- Find duplicate emails
SELECT email, COUNT(*) as count
FROM users
GROUP BY email
HAVING COUNT(*) > 1;
```

**Action**: Clean duplicates before sync

## Migration Steps

### Step 1: Apply Database Migration

```bash
# Run the comprehensive migration
psql $DATABASE_URL < migrations/010_stripe_sync_requirements.sql
```

### Step 2: Verify Migration Success

```bash
node scripts/check-stripe-sync.js
```

Expected output:

- ✅ All required columns present
- ✅ Unique constraint exists
- ✅ Status constraint includes all values
- ✅ No duplicate users

### Step 3: Test with Single Subscription

```bash
node scripts/test-subscription-sync.js
```

This will:

1. Fetch one subscription from Stripe
2. Attempt to sync it
3. Report any errors

## Environment Configuration

### Production Environment Variables

```bash
# Primary Stripe key (contains live key in production)
STRIPE_SECRET_KEY=sk_live_51REMktEbrdIIhAd8...

# Public key
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_51REMktEbrdIIhAd8...

# Webhook secret
STRIPE_WEBHOOK_SECRET=whsec_Uxo7pAYLZy15rlqQSXsOJYxT...

# Database URL
DATABASE_URL=postgres://user:pass@host/db?sslmode=require
```

**Important**: Do NOT create `STRIPE_SECRET_KEY_LIVE` - use `STRIPE_SECRET_KEY`

## Code Deployment

### 1. Deploy Updated Files

Ensure these files are deployed:

- `pages/api/admin/stripe/sync.ts` - with timestamp handling
- `pages/api/admin/stripe/test-sync.ts` - for testing
- All migration scripts

### 2. Verify Deployment

```bash
# Check if sync endpoint is accessible
curl -X POST https://your-domain.com/api/admin/stripe/sync \
  -H "Cookie: your-admin-session"
```

## Post-Deployment Verification

### 1. Initial Sync Test

1. Navigate to Admin > Stripe Integration
2. Click "Test Connection" to verify API keys
3. Note the customer/subscription counts
4. Click "Sync Now"

### 2. Verify Sync Results

```sql
-- Check synced data
SELECT COUNT(*) as user_count FROM users WHERE stripe_customer_id IS NOT NULL;
SELECT COUNT(*) as sub_count FROM subscriptions;
SELECT status, COUNT(*) FROM subscriptions GROUP BY status;
```

### 3. Check for Sync Errors

```sql
-- Check payment logs for errors
SELECT * FROM payment_logs
WHERE event_type = 'sync_error'
ORDER BY created_at DESC
LIMIT 10;
```

## Monitoring & Alerts

### 1. Set Up Monitoring

```typescript
// Add to monitoring service
async function checkStripeSync() {
  const lastSync = await sql`
    SELECT MAX(created_at) as last_sync 
    FROM payment_logs 
    WHERE event_type = 'sync_completed'
  `;

  if (
    !lastSync[0].last_sync ||
    Date.now() - new Date(lastSync[0].last_sync) > 24 * 60 * 60 * 1000
  ) {
    alert("Stripe sync has not run in 24 hours");
  }
}
```

### 2. Data Consistency Check

```typescript
// Run weekly
async function checkDataConsistency() {
  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
  const stripeCount = (await stripe.subscriptions.list({ limit: 1 }))
    .total_count;
  const dbCount = (await sql`SELECT COUNT(*) FROM subscriptions`)[0].count;

  if (Math.abs(stripeCount - dbCount) > 5) {
    alert(`Data mismatch: Stripe has ${stripeCount}, DB has ${dbCount}`);
  }
}
```

## Rollback Plan

If issues occur:

### 1. Stop Sync Operations

Disable sync button or endpoint temporarily

### 2. Clean Invalid Data

```sql
-- Remove subscriptions with invalid data
DELETE FROM subscriptions
WHERE stripe_subscription_id IS NULL
OR current_period_start IS NULL;
```

### 3. Fix Issues

1. Apply missing constraints
2. Fix timestamp handling
3. Update status constraints

### 4. Re-run Sync

After fixes, run sync again from admin panel

## Common Production Issues

### Issue: "No subscriptions synced"

**Check**: Unique constraint exists
**Fix**: `ALTER TABLE subscriptions ADD CONSTRAINT ...`

### Issue: "Timestamp errors"

**Check**: Stripe data for undefined timestamps
**Fix**: Deploy code with null checks

### Issue: "Status constraint violation"

**Check**: Current status constraint
**Fix**: Update constraint to include all statuses

### Issue: "Duplicate key violation"

**Check**: For duplicate emails or subscriptions
**Fix**: Clean duplicates before sync

## Success Criteria

Deployment is successful when:

- ✅ All Stripe customers synced to users table
- ✅ All Stripe subscriptions synced
- ✅ No errors in payment_logs
- ✅ Admin can view sync status
- ✅ Sync can be re-run without errors

## Support Contacts

- Database Issues: DBA Team
- Stripe API Issues: Payment Team
- Auth/Admin Issues: Security Team
- Deployment Issues: DevOps Team

## Post-Deployment Tasks

1. **Document sync frequency** - How often should sync run?
2. **Set up automated sync** - Cron job or scheduled task
3. **Create runbook** - For support team
4. **Monitor for 48 hours** - Check logs and performance
5. **Update team** - Share deployment results
