# Prisma Neon Connection Guide

## Overview

This guide documents the diagnosis and resolution of Prisma connection issues with Neon PostgreSQL databases, specifically the TLS certificate parsing errors that can occur with Prisma's native query engine.

## The Problem

### Symptoms

When running integration tests or any code that connects to a Neon database, you may encounter:

```
PrismaClientInitializationError: Error opening a TLS connection: bad certificate format
```

This error is particularly frustrating because:
- Direct `psql` connections work perfectly fine
- The connection string is valid
- SSL/TLS settings appear correct (`sslmode=require`)
- The database is accessible and responsive

### Root Cause

Prisma's native query engine (written in Rust) has a different TLS implementation than standard PostgreSQL clients. In some cases, particularly with Neon's serverless PostgreSQL offering, Prisma's TLS certificate parsing can fail even when the certificate is valid.

This is a known issue that can occur when:
- Using Neon's connection pooler endpoints
- Certificate chain formatting differs from what Prisma expects
- Specific TLS library version mismatches

## Diagnosis Steps

### Step 1: Verify Raw Database Connection

First, confirm the database itself is accessible:

```bash
# Test with psql directly
psql "postgresql://user:password@host.neon.tech/database?sslmode=require" -c "SELECT NOW()"
```

If this succeeds but Prisma fails, the issue is Prisma-specific.

### Step 2: Check Error Message

Examine the full error message:

| Error Message | Likely Cause |
|--------------|--------------|
| `bad certificate format` | Prisma TLS parsing issue → Use pg adapter |
| `connection refused` | Network/firewall issue → Check network access |
| `authentication failed` | Wrong credentials → Verify .env files |
| `connection timed out` | DNS/routing issue → Check hostname |
| `database does not exist` | Wrong database name → Verify connection string |

### Step 3: Verify Environment Configuration

```bash
# Check which .env file is being used
cat .env.test | grep DATABASE_URL

# Ensure sslmode is set
# Should include: ?sslmode=require
```

## Solution: Prisma Driver Adapters

The recommended solution is to use Prisma's Driver Adapters feature, which allows Prisma to use the standard `pg` library for database connections instead of its native engine.

### Why This Works

- The `pg` library uses Node.js's native TLS implementation
- Node.js TLS is more compatible with various certificate formats
- Same TLS stack that `psql` uses (via OpenSSL/LibreSSL)
- Maintains full Prisma ORM functionality

### Implementation

#### 1. Install Required Packages

```bash
npm install @prisma/adapter-pg pg @types/pg
```

#### 2. Update Prisma Schema

Add the `driverAdapters` preview feature to your `prisma/schema.prisma`:

```prisma
generator client {
  provider        = "prisma-client-js"
  previewFeatures = ["driverAdapters"]
}

datasource db {
  provider  = "postgresql"
  url       = env("POSTGRES_URL")
  directUrl = env("POSTGRES_URL_NON_POOLING")
}
```

> **Note**: In Prisma 6.x+, `driverAdapters` is deprecated as a preview feature but still required to be specified. The functionality works without specifying it in newer versions.

#### 3. Regenerate Prisma Client

```bash
# Use the correct environment file
npx dotenv-cli -e .env.test -- npx prisma generate
```

#### 4. Create Prisma Client with Adapter

```typescript
// __tests__/helpers/database-helpers.ts
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

// Singleton pattern for test database connection
let pool: Pool | null = null;
let testPrisma: PrismaClient | null = null;

export function getTestPrismaClient(): PrismaClient {
  if (!testPrisma) {
    const connectionString = process.env.DATABASE_URL || process.env.POSTGRES_URL;
    
    if (!connectionString) {
      throw new Error('DATABASE_URL or POSTGRES_URL must be set in environment');
    }
    
    // Create pg Pool
    pool = new Pool({ connectionString });
    
    // Create Prisma adapter
    const adapter = new PrismaPg(pool);
    
    // Create Prisma client with adapter
    testPrisma = new PrismaClient({ adapter });
  }
  return testPrisma;
}

export async function disconnectTestDatabase(): Promise<void> {
  if (testPrisma) {
    await testPrisma.$disconnect();
    testPrisma = null;
  }
  if (pool) {
    await pool.end();
    pool = null;
  }
}
```

#### 5. Update Jest Configuration

Add `forceExit` to handle connection pool cleanup:

```javascript
// jest.integration.config.js
module.exports = {
  // ... other config
  testEnvironment: 'node',
  testTimeout: 30000,
  forceExit: true, // Force exit to handle pg pool cleanup
};
```

## Test Helper Pattern

Here's a complete example of a test helper file with proper connection management:

```typescript
// __tests__/helpers/database-helpers.ts
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

let pool: Pool | null = null;
let testPrisma: PrismaClient | null = null;

function getTestPrismaClient(): PrismaClient {
  if (!testPrisma) {
    const connectionString = process.env.DATABASE_URL || process.env.POSTGRES_URL;
    
    if (!connectionString) {
      throw new Error('DATABASE_URL or POSTGRES_URL must be set');
    }
    
    pool = new Pool({ connectionString });
    const adapter = new PrismaPg(pool);
    testPrisma = new PrismaClient({ adapter });
  }
  return testPrisma;
}

export const DatabaseTestHelpers = {
  getPrisma: () => getTestPrismaClient(),

  checkConnection: async (retries = 3): Promise<boolean> => {
    const client = getTestPrismaClient();
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        await client.$queryRaw`SELECT 1`;
        return true;
      } catch (error) {
        console.warn(`⚠️ Connection attempt ${attempt}/${retries} failed`);
        if (attempt < retries) {
          await new Promise(r => setTimeout(r, 1000 * attempt));
        }
      }
    }
    return false;
  },

  disconnect: async (): Promise<void> => {
    if (testPrisma) await testPrisma.$disconnect();
    if (pool) await pool.end();
    testPrisma = null;
    pool = null;
  },
};
```

## Integration Test Pattern

For integration tests that need database connectivity with graceful degradation:

```typescript
// __tests__/integration/example.test.ts
import { DatabaseTestHelpers } from '../helpers/database-helpers';

let dbAvailable = false;

beforeAll(async () => {
  try {
    const prisma = DatabaseTestHelpers.getPrisma();
    await prisma.$queryRaw`SELECT 1`;
    dbAvailable = true;
  } catch (error: any) {
    console.warn('⚠️ Database unavailable - tests will be skipped');
    console.warn(`Error: ${error.message}`);
  }
});

afterAll(async () => {
  await DatabaseTestHelpers.disconnect();
});

// Wrapper for database-dependent tests
const dbTest = (name: string, fn: () => Promise<void>) => {
  test(name, async () => {
    if (!dbAvailable) {
      console.log(`⏭️ [SKIPPED] ${name} - Database unavailable`);
      return;
    }
    await fn();
  });
};

describe('Database Integration Tests', () => {
  dbTest('should query the database', async () => {
    const prisma = DatabaseTestHelpers.getPrisma();
    const result = await prisma.user.findMany({ take: 1 });
    expect(result).toBeDefined();
  });
});
```

## Environment Configuration

### .env.test Example

```bash
# Test Database Configuration (Neon)
DATABASE_URL="postgresql://username:password@ep-example-123456.us-east-1.aws.neon.tech/testdb?sslmode=require"
POSTGRES_URL="postgresql://username:password@ep-example-123456.us-east-1.aws.neon.tech/testdb?sslmode=require"

# For direct connections (migrations)
POSTGRES_URL_NON_POOLING="postgresql://username:password@ep-example-123456.us-east-1.aws.neon.tech/testdb?sslmode=require"
```

### SSL Mode Options

| Mode | Description | Recommendation |
|------|-------------|----------------|
| `disable` | No SSL | Never use for Neon |
| `allow` | Try SSL, fallback to non-SSL | Not recommended |
| `prefer` | Prefer SSL, fallback to non-SSL | Not recommended |
| `require` | Require SSL, no cert verification | **Use for development/test** |
| `verify-ca` | Verify CA certificate | Use for staging |
| `verify-full` | Verify CA + hostname | Use for production |

## Troubleshooting

### Issue: Jest doesn't exit after tests

**Cause**: pg Pool connections not properly closed.

**Solution**: Add `forceExit: true` to Jest config and ensure `pool.end()` is called:

```javascript
// jest.integration.config.js
module.exports = {
  forceExit: true,
};
```

### Issue: Warning about SSL modes

You may see:
```
Warning: SECURITY WARNING: The SSL modes 'prefer', 'require', and 'verify-ca' 
are treated as aliases for 'verify-full'.
```

**Solution**: This is a deprecation warning from `pg`. For now, it's informational and doesn't affect functionality. Use `sslmode=verify-full` to silence it.

### Issue: Connection works locally but fails in CI

**Cause**: CI environment may have different network configuration.

**Solution**:
1. Ensure CI has network access to Neon
2. Use GitHub Secrets for DATABASE_URL
3. Consider Neon's IP allowlist settings

### Issue: Multiple pool instances causing resource exhaustion

**Cause**: Creating new pools in different files without sharing.

**Solution**: Use a singleton pattern or shared module for the database connection:

```typescript
// lib/test-db.ts - Single source of truth for test DB
export { getTestPrismaClient, disconnectTestDatabase } from '../__tests__/helpers/database-helpers';
```

## Production Considerations

The pg adapter solution is specifically recommended for **test environments** where Neon TLS issues occur. For production:

1. **Prefer Prisma's native engine** when it works (better performance)
2. **Use connection pooling** (PgBouncer or Neon's built-in pooler)
3. **Enable proper TLS verification** (`sslmode=verify-full`)
4. **Monitor connection pool metrics**

## Quick Reference

### Commands

```bash
# Test raw connection
psql "$DATABASE_URL" -c "SELECT 1"

# Install pg adapter
npm install @prisma/adapter-pg pg @types/pg

# Regenerate Prisma with test env
npx dotenv-cli -e .env.test -- npx prisma generate

# Run integration tests
npm run test:integration
```

### Files to Update

| File | Change |
|------|--------|
| `prisma/schema.prisma` | Add `previewFeatures = ["driverAdapters"]` |
| `__tests__/helpers/database-helpers.ts` | Use pg adapter pattern |
| `jest.integration.config.js` | Add `forceExit: true` |
| `.env.test` | Ensure `sslmode=require` in URL |

## Related Documentation

- [Prisma Driver Adapters](https://www.prisma.io/docs/concepts/database-connectors/postgresql#driver-adapters)
- [Neon Connection Guide](https://neon.tech/docs/guides/prisma)
- [pg Library Documentation](https://node-postgres.com/)
- [Cursor Rule: 377-prisma-neon-connection.mdc](../.cursor/rules/377-prisma-neon-connection.mdc)

---

**Last Updated**: 2026-01-15  
**Applies To**: Prisma 5.x+, Neon PostgreSQL, Node.js 18+
