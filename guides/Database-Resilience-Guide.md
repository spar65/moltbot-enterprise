# VibeCoder Database Resilience Guide

## Overview

This guide documents best practices for implementing database resilience patterns in VibeCoder to ensure robust, fault-tolerant database operations. These patterns help maintain system stability during temporary database failures, network issues, or high-load scenarios.

## Connection Management

### Connection Pooling

Proper connection pool configuration prevents exhausting database connections and improves performance:

```typescript
// lib/prisma.ts
import { PrismaClient } from "@prisma/client";

// Parse connection URL to add connection pool config
function getDatabaseUrl() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    throw new Error("DATABASE_URL environment variable is not set");
  }

  // Add connection pool configuration if not present
  if (!url.includes("connection_limit")) {
    const separator = url.includes("?") ? "&" : "?";

    // Production settings - adjust based on your needs
    if (process.env.NODE_ENV === "production") {
      return `${url}${separator}connection_limit=20&pool_timeout=30`;
    }

    // Development settings
    return `${url}${separator}connection_limit=5&pool_timeout=10`;
  }

  return url;
}

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: getDatabaseUrl(),
    },
  },
  log:
    process.env.NODE_ENV === "development"
      ? ["query", "info", "warn", "error"]
      : ["error"],
});

export { prisma };
```

### Connection Health Checking

Implement proactive connection health monitoring:

```typescript
// utils/db-health.ts
import { prisma } from "../lib/prisma";

export async function checkDatabaseHealth(): Promise<{
  status: "healthy" | "unhealthy";
  error?: string;
  latency?: number;
}> {
  const start = Date.now();

  try {
    // Simple query to test connectivity
    await prisma.$queryRaw`SELECT 1`;
    const latency = Date.now() - start;

    return {
      status: "healthy",
      latency,
    };
  } catch (error) {
    console.error("Database health check failed:", error);
    return {
      status: "unhealthy",
      error: error instanceof Error ? error.message : String(error),
      latency: Date.now() - start,
    };
  }
}

// Regular health check implementation
export function startHealthCheckInterval(intervalMs = 60000): () => void {
  const interval = setInterval(async () => {
    const health = await checkDatabaseHealth();

    if (health.status === "unhealthy") {
      console.error(`Database health check failed: ${health.error}`);
      // Could trigger alerts here
    } else if (health.latency && health.latency > 500) {
      console.warn(`Database latency high: ${health.latency}ms`);
    }
  }, intervalMs);

  // Return cleanup function
  return () => clearInterval(interval);
}
```

### Connection Recycling

To prevent connection staleness:

```typescript
// lib/db-recycler.ts
import { prisma } from "./prisma";

export function startConnectionRecycling(intervalMs = 3600000): () => void {
  const interval = setInterval(async () => {
    try {
      // Disconnect and reconnect to refresh connections
      await prisma.$disconnect();
      await prisma.$connect();
      console.log("Database connections recycled successfully");
    } catch (error) {
      console.error("Error recycling database connections:", error);
    }
  }, intervalMs);

  // Return cleanup function
  return () => clearInterval(interval);
}

// Usage in app startup
if (process.env.NODE_ENV === "production") {
  // Recycle connections every hour
  startConnectionRecycling();
}
```

## Retry Patterns

### Basic Retry Logic

Implement retry logic for database operations that might fail transiently:

```typescript
// utils/retry.ts
type RetryOptions = {
  maxRetries: number;
  delay: number; // milliseconds
  backoff?: boolean; // exponential backoff
  retryableErrors?: Array<string | RegExp>;
};

const defaultOptions: RetryOptions = {
  maxRetries: 3,
  delay: 100,
  backoff: true,
  retryableErrors: [
    // Connection errors
    "Connection refused",
    "Connection terminated",
    "Connection timeout",
    // Deadlock errors
    "deadlock detected",
    // Rate limit errors
    "too many connections",
    // Transient errors
    "connect ETIMEDOUT",
    "Connection terminated unexpectedly",
  ],
};

export async function withRetry<T>(
  operation: () => Promise<T>,
  options: Partial<RetryOptions> = {}
): Promise<T> {
  const opts = { ...defaultOptions, ...options };
  let lastError: Error | undefined;

  for (let attempt = 0; attempt < opts.maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));

      // Check if this error is retryable
      const errorMsg = lastError.message;
      const isRetryable =
        !opts.retryableErrors ||
        opts.retryableErrors.some((pattern) =>
          typeof pattern === "string"
            ? errorMsg.includes(pattern)
            : pattern.test(errorMsg)
        );

      if (!isRetryable) {
        throw lastError; // Not retryable, rethrow immediately
      }

      // Last attempt failed, rethrow
      if (attempt === opts.maxRetries - 1) {
        throw lastError;
      }

      // Calculate delay for next retry
      const retryDelay = opts.backoff
        ? opts.delay * Math.pow(2, attempt)
        : opts.delay;

      console.warn(
        `Database operation failed (attempt ${attempt + 1}/${
          opts.maxRetries
        }), retrying in ${retryDelay}ms:`,
        errorMsg
      );

      // Wait before next attempt
      await new Promise((resolve) => setTimeout(resolve, retryDelay));
    }
  }

  // This shouldn't happen due to the throw in the loop, but TypeScript needs it
  throw lastError;
}
```

### Repository Integration

Integrate retry logic into repository methods:

```typescript
// repositories/UserRepository.ts
import { PrismaClient, User } from "@prisma/client";
import { withRetry } from "../utils/retry";
import { DatabaseError } from "../errors/DatabaseError";

export class UserRepository {
  constructor(private prisma: PrismaClient) {}

  async findById(id: string, organizationId: string): Promise<User | null> {
    try {
      // Use retry pattern for read operations
      return await withRetry(() =>
        this.prisma.user.findFirst({
          where: {
            id,
            organizationId,
          },
        })
      );
    } catch (error) {
      throw new DatabaseError("Failed to find user by ID", error);
    }
  }

  async create(data: Prisma.UserCreateInput): Promise<User> {
    try {
      // Use retry pattern with custom options for write operations
      return await withRetry(() => this.prisma.user.create({ data }), {
        maxRetries: 5,
        delay: 200,
      });
    } catch (error) {
      throw new DatabaseError("Failed to create user", error);
    }
  }
}
```

## Circuit Breaker Pattern

Implement circuit breakers to prevent cascading failures during database outages:

```typescript
// utils/circuit-breaker.ts
export enum CircuitState {
  CLOSED = "CLOSED", // Normal operation
  OPEN = "OPEN", // Failing, no requests allowed
  HALF_OPEN = "HALF_OPEN", // Testing if system has recovered
}

type CircuitBreakerOptions = {
  failureThreshold: number; // Number of failures before opening
  resetTimeout: number; // Milliseconds until trying half-open state
  halfOpenSuccessThreshold: number; // Successes needed to close circuit
  maxSampleSize: number; // Maximum failure tracking window
};

export class CircuitBreaker {
  private state: CircuitState = CircuitState.CLOSED;
  private failureCount: number = 0;
  private successCount: number = 0;
  private lastFailureTime: number = 0;
  private readonly options: CircuitBreakerOptions;

  constructor(options: Partial<CircuitBreakerOptions> = {}) {
    this.options = {
      failureThreshold: 5,
      resetTimeout: 30000, // 30 seconds
      halfOpenSuccessThreshold: 2,
      maxSampleSize: 100,
      ...options,
    };
  }

  async execute<T>(operation: () => Promise<T>): Promise<T> {
    if (this.state === CircuitState.OPEN) {
      if (Date.now() - this.lastFailureTime >= this.options.resetTimeout) {
        this.toHalfOpen();
      } else {
        throw new Error(
          "Circuit breaker is open - database operations suspended"
        );
      }
    }

    try {
      const result = await operation();
      this.recordSuccess();
      return result;
    } catch (error) {
      this.recordFailure();
      throw error;
    }
  }

  private recordSuccess(): void {
    if (this.state === CircuitState.HALF_OPEN) {
      this.successCount++;
      if (this.successCount >= this.options.halfOpenSuccessThreshold) {
        this.toClose();
      }
    } else if (this.state === CircuitState.CLOSED) {
      // Reset failure count on success
      this.failureCount = Math.max(0, this.failureCount - 1);
    }
  }

  private recordFailure(): void {
    this.lastFailureTime = Date.now();

    if (this.state === CircuitState.HALF_OPEN) {
      this.toOpen();
    } else if (this.state === CircuitState.CLOSED) {
      this.failureCount++;
      if (this.failureCount > this.options.maxSampleSize) {
        this.failureCount = this.options.maxSampleSize;
      }

      if (this.failureCount >= this.options.failureThreshold) {
        this.toOpen();
      }
    }
  }

  private toClose(): void {
    this.state = CircuitState.CLOSED;
    this.failureCount = 0;
    this.successCount = 0;
    console.log("Circuit breaker closed - normal operations resumed");
  }

  private toOpen(): void {
    this.state = CircuitState.OPEN;
    this.successCount = 0;
    console.warn("Circuit breaker opened - database operations suspended");
  }

  private toHalfOpen(): void {
    this.state = CircuitState.HALF_OPEN;
    this.successCount = 0;
    console.log("Circuit breaker half-open - testing database connectivity");
  }

  getState(): CircuitState {
    return this.state;
  }
}
```

### Circuit Breaker Implementation

```typescript
// lib/database-circuit.ts
import { CircuitBreaker } from "../utils/circuit-breaker";
import { checkDatabaseHealth } from "../utils/db-health";

// Create singleton circuit breaker for database
const databaseCircuit = new CircuitBreaker({
  failureThreshold: 5,
  resetTimeout: 30000, // 30 seconds
  halfOpenSuccessThreshold: 2,
});

// Function to execute database operations with circuit breaker
export async function withCircuitBreaker<T>(
  operation: () => Promise<T>
): Promise<T> {
  return databaseCircuit.execute(operation);
}

// Regularly check health to update circuit state
export function startCircuitHealthCheck(intervalMs = 10000): () => void {
  const interval = setInterval(async () => {
    try {
      await databaseCircuit.execute(checkDatabaseHealth);
    } catch (error) {
      // Circuit will handle failures
      console.error("Health check failed through circuit breaker");
    }
  }, intervalMs);

  return () => clearInterval(interval);
}

// Repository integration
export class DatabaseClient {
  private circuit = databaseCircuit;

  async executeQuery<T>(queryFn: () => Promise<T>): Promise<T> {
    return this.circuit.execute(queryFn);
  }
}
```

## Timeouts and Deadlines

Implement timeouts to prevent hanging connections:

```typescript
// utils/timeout.ts
export class TimeoutError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "TimeoutError";
  }
}

export async function withTimeout<T>(
  operation: () => Promise<T>,
  timeoutMs: number
): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timeoutId = setTimeout(() => {
      reject(new TimeoutError(`Operation timed out after ${timeoutMs}ms`));
    }, timeoutMs);

    operation()
      .then((result) => {
        clearTimeout(timeoutId);
        resolve(result);
      })
      .catch((error) => {
        clearTimeout(timeoutId);
        reject(error);
      });
  });
}

// Usage with database operations
export async function executeWithTimeout<T>(
  operation: () => Promise<T>,
  timeoutMs: number = 5000
): Promise<T> {
  try {
    return await withTimeout(operation, timeoutMs);
  } catch (error) {
    if (error instanceof TimeoutError) {
      console.error(`Database operation timed out after ${timeoutMs}ms`);
      // You might want to add metrics or logging here
    }
    throw error;
  }
}
```

## Bulkhead Pattern

Isolate database operations to prevent cascading failures:

```typescript
// utils/bulkhead.ts
export class BulkheadRejectedError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "BulkheadRejectedError";
  }
}

export class Bulkhead {
  private concurrentExecutions: number = 0;
  private readonly maxConcurrent: number;
  private readonly maxWaiting: number;
  private readonly waitingQueue: Array<{
    resolve: (value: void) => void;
    reject: (reason: Error) => void;
  }> = [];

  constructor(maxConcurrent: number, maxWaiting: number = 0) {
    this.maxConcurrent = maxConcurrent;
    this.maxWaiting = maxWaiting;
  }

  async execute<T>(operation: () => Promise<T>): Promise<T> {
    // Try to acquire permission to execute
    await this.acquirePermission();

    try {
      return await operation();
    } finally {
      this.releasePermission();
    }
  }

  private async acquirePermission(): Promise<void> {
    if (this.concurrentExecutions < this.maxConcurrent) {
      // Can execute immediately
      this.concurrentExecutions++;
      return;
    }

    // Need to wait - check if queue has space
    if (this.waitingQueue.length >= this.maxWaiting) {
      throw new BulkheadRejectedError(
        `Bulkhead capacity exceeded: ${this.concurrentExecutions} executing, ${this.waitingQueue.length} waiting`
      );
    }

    // Add to waiting queue
    return new Promise<void>((resolve, reject) => {
      this.waitingQueue.push({ resolve, reject });
    });
  }

  private releasePermission(): void {
    if (this.waitingQueue.length > 0) {
      // Someone is waiting - let them proceed
      const next = this.waitingQueue.shift();
      next?.resolve();
    } else {
      // No one waiting - just decrement count
      this.concurrentExecutions--;
    }
  }

  getMetrics(): { executing: number; waiting: number } {
    return {
      executing: this.concurrentExecutions,
      waiting: this.waitingQueue.length,
    };
  }
}

// Different bulkheads for different types of operations
export const bulkheads = {
  read: new Bulkhead(50, 100), // More capacity for reads
  write: new Bulkhead(20, 50), // Less capacity for writes
  reporting: new Bulkhead(5, 10), // Very limited for heavy queries
};

// Usage
export async function executeRead<T>(operation: () => Promise<T>): Promise<T> {
  return bulkheads.read.execute(operation);
}

export async function executeWrite<T>(operation: () => Promise<T>): Promise<T> {
  return bulkheads.write.execute(operation);
}

export async function executeReport<T>(
  operation: () => Promise<T>
): Promise<T> {
  return bulkheads.reporting.execute(operation);
}
```

## Cache Strategies

Implement caching to reduce database load and improve resilience:

```typescript
// utils/cache.ts
import NodeCache from "node-cache";

export class CacheManager {
  private cache: NodeCache;

  constructor(ttlSeconds: number = 60) {
    this.cache = new NodeCache({
      stdTTL: ttlSeconds,
      checkperiod: ttlSeconds * 0.2,
    });
  }

  async getOrSet<T>(
    key: string,
    fetchFn: () => Promise<T>,
    ttl?: number
  ): Promise<T> {
    const cachedValue = this.cache.get<T>(key);
    if (cachedValue !== undefined) {
      return cachedValue;
    }

    const fetchedValue = await fetchFn();
    this.cache.set(key, fetchedValue, ttl);
    return fetchedValue;
  }

  invalidate(key: string): void {
    this.cache.del(key);
  }

  invalidateByPrefix(prefix: string): void {
    const keys = this.cache.keys().filter((k) => k.startsWith(prefix));
    keys.forEach((k) => this.cache.del(k));
  }

  stats(): { keys: number; hits: number; misses: number } {
    return {
      keys: this.cache.keys().length,
      hits: this.cache.getStats().hits,
      misses: this.cache.getStats().misses,
    };
  }
}

// Create caches with different TTLs
export const caches = {
  shortTerm: new CacheManager(60), // 1 minute
  mediumTerm: new CacheManager(300), // 5 minutes
  longTerm: new CacheManager(3600), // 1 hour
  userProfile: new CacheManager(1800), // 30 minutes
  projectData: new CacheManager(900), // 15 minutes
  subscriptionStatus: new CacheManager(120), // 2 minutes
};

// Repository with cache integration
export class CachedUserRepository {
  constructor(
    private repository: UserRepository,
    private cache: CacheManager = caches.userProfile
  ) {}

  async findById(id: string, organizationId: string): Promise<User | null> {
    const cacheKey = `user:${id}:${organizationId}`;

    return this.cache.getOrSet(cacheKey, () =>
      this.repository.findById(id, organizationId)
    );
  }

  async update(
    id: string,
    organizationId: string,
    data: Prisma.UserUpdateInput
  ): Promise<User> {
    const result = await this.repository.update(id, organizationId, data);

    // Invalidate cache
    this.cache.invalidate(`user:${id}:${organizationId}`);

    return result;
  }
}
```

### Fallback Cache for Resilience

Implement a fallback strategy when database is unavailable:

```typescript
// utils/resilient-cache.ts
import { CacheManager } from "./cache";
import { CircuitState } from "./circuit-breaker";
import { databaseCircuit } from "../lib/database-circuit";

// Extended cache that provides fallback behavior
export class ResilientCache extends CacheManager {
  constructor(
    ttlSeconds: number = 60,
    private staleIfErrorTtl: number = 3600, // 1 hour stale fallback
    private logFallback: boolean = true
  ) {
    super(ttlSeconds);
  }

  async getOrSet<T>(
    key: string,
    fetchFn: () => Promise<T>,
    ttl?: number
  ): Promise<T> {
    // Get from cache (even if expired)
    const cachedValue = this.getRaw<{
      value: T;
      timestamp: number;
      ttl: number;
    }>(key);

    // If database circuit is open (indicating issues), use stale cache if available
    if (
      databaseCircuit.getState() === CircuitState.OPEN &&
      cachedValue !== undefined
    ) {
      if (this.logFallback) {
        console.warn(
          `Using stale cache for ${key} due to database circuit open`
        );
      }
      return cachedValue.value;
    }

    try {
      // Try to fetch fresh value
      const freshValue = await fetchFn();
      this.setRaw(
        key,
        {
          value: freshValue,
          timestamp: Date.now(),
          ttl: ttl || this.defaultTtl,
        },
        ttl
      );
      return freshValue;
    } catch (error) {
      // If fetch fails but we have a cached value (even expired), use it
      if (cachedValue !== undefined) {
        if (this.logFallback) {
          console.warn(
            `Using stale cache for ${key} due to fetch error:`,
            error
          );
        }

        // Extend the TTL for stale-if-error period
        this.setRaw(
          key,
          {
            ...cachedValue,
            ttl: this.staleIfErrorTtl,
          },
          this.staleIfErrorTtl
        );

        return cachedValue.value;
      }

      // No cached value available, must propagate error
      throw error;
    }
  }

  // Raw cache access methods
  private getRaw<T>(key: string): T | undefined {
    return this.cache.get<T>(key);
  }

  private setRaw<T>(key: string, value: T, ttl?: number): void {
    this.cache.set(key, value, ttl);
  }
}

// Create resilient caches
export const resilientCaches = {
  userProfile: new ResilientCache(1800, 86400), // 30min normal, 24h stale
  subscriptionStatus: new ResilientCache(120, 3600), // 2min normal, 1h stale
  projectList: new ResilientCache(300, 7200), // 5min normal, 2h stale
};
```

## Graceful Shutdown

Implement graceful shutdown to prevent connection issues during deployment:

```typescript
// lib/graceful-shutdown.ts
import { prisma } from "./prisma";

export function setupGracefulShutdown(): void {
  // Handle process termination signals
  ["SIGINT", "SIGTERM", "SIGUSR2"].forEach((signal) => {
    process.on(signal, async () => {
      console.log(`Received ${signal}, shutting down gracefully...`);

      // Give active requests time to complete (adjust as needed)
      const shutdownDelay = 5000; // 5 seconds

      setTimeout(async () => {
        try {
          // Close database connections
          console.log("Closing database connections...");
          await prisma.$disconnect();
          console.log("Database connections closed successfully");
        } catch (error) {
          console.error("Error during database disconnection:", error);
        }

        console.log("Shutdown complete");
        process.exit(0);
      }, shutdownDelay);
    });
  });
}

// Usage in main application
if (process.env.NODE_ENV === "production") {
  setupGracefulShutdown();
}
```

## Combined Resilience Patterns

Combine multiple resilience patterns for robust database access:

```typescript
// lib/resilient-db-client.ts
import { PrismaClient } from "@prisma/client";
import { withRetry } from "../utils/retry";
import { withTimeout, TimeoutError } from "../utils/timeout";
import { withCircuitBreaker } from "./database-circuit";
import { bulkheads } from "../utils/bulkhead";
import { resilientCaches } from "../utils/resilient-cache";

// Combines all resilience patterns
export class ResilientDatabaseClient {
  constructor(private prisma: PrismaClient) {}

  // For read operations
  async read<T>(
    operation: () => Promise<T>,
    options: {
      timeoutMs?: number;
      retries?: number;
      cacheKey?: string;
      cacheTtl?: number;
    } = {}
  ): Promise<T> {
    const timeoutMs = options.timeoutMs || 5000;
    const retries = options.retries || 3;

    // If cache key provided, use cache
    if (options.cacheKey) {
      return resilientCaches.userProfile.getOrSet(
        options.cacheKey,
        () => this.executeRead(operation, timeoutMs, retries),
        options.cacheTtl
      );
    }

    return this.executeRead(operation, timeoutMs, retries);
  }

  private async executeRead<T>(
    operation: () => Promise<T>,
    timeoutMs: number,
    retries: number
  ): Promise<T> {
    return bulkheads.read.execute(() =>
      withCircuitBreaker(() =>
        withRetry(() => withTimeout(operation, timeoutMs), {
          maxRetries: retries,
        })
      )
    );
  }

  // For write operations
  async write<T>(
    operation: () => Promise<T>,
    options: {
      timeoutMs?: number;
      retries?: number;
      invalidateCache?: string | string[];
    } = {}
  ): Promise<T> {
    const timeoutMs = options.timeoutMs || 10000;
    const retries = options.retries || 5;

    try {
      return await bulkheads.write.execute(() =>
        withCircuitBreaker(() =>
          withRetry(() => withTimeout(operation, timeoutMs), {
            maxRetries: retries,
          })
        )
      );
    } finally {
      // Invalidate cache if specified
      if (options.invalidateCache) {
        if (typeof options.invalidateCache === "string") {
          resilientCaches.userProfile.invalidate(options.invalidateCache);
        } else {
          options.invalidateCache.forEach((key) =>
            resilientCaches.userProfile.invalidate(key)
          );
        }
      }
    }
  }

  // For heavy reporting queries
  async report<T>(
    operation: () => Promise<T>,
    options: {
      timeoutMs?: number;
      cacheKey?: string;
      cacheTtl?: number;
    } = {}
  ): Promise<T> {
    const timeoutMs = options.timeoutMs || 30000;

    // Reporting queries should always use cache when possible
    if (options.cacheKey) {
      return resilientCaches.projectList.getOrSet(
        options.cacheKey,
        () => this.executeReport(operation, timeoutMs),
        options.cacheTtl
      );
    }

    return this.executeReport(operation, timeoutMs);
  }

  private async executeReport<T>(
    operation: () => Promise<T>,
    timeoutMs: number
  ): Promise<T> {
    return bulkheads.reporting.execute(() =>
      withCircuitBreaker(() => withTimeout(operation, timeoutMs))
    );
  }
}

// Create singleton instance
export const resilientDb = new ResilientDatabaseClient(prisma);

// Usage example
async function getUserProfile(
  userId: string,
  organizationId: string
): Promise<User | null> {
  return resilientDb.read(
    () =>
      prisma.user.findFirst({
        where: { id: userId, organizationId },
        include: { profile: true },
      }),
    {
      cacheKey: `user-profile:${userId}:${organizationId}`,
      cacheTtl: 1800, // 30 minutes
    }
  );
}

async function updateUserProfile(
  userId: string,
  organizationId: string,
  data: any
): Promise<User> {
  return resilientDb.write(
    () =>
      prisma.user.update({
        where: { id: userId, organizationId },
        data,
      }),
    {
      invalidateCache: `user-profile:${userId}:${organizationId}`,
    }
  );
}
```

## Monitoring Database Resilience

### Health Dashboard

Create a database health dashboard for monitoring:

```typescript
// pages/api/admin/database-health.ts
import { NextApiRequest, NextApiResponse } from "next";
import { checkDatabaseHealth } from "../../../utils/db-health";
import { withAuth, requireRole } from "../../../middleware/auth";
import { databaseCircuit } from "../../../lib/database-circuit";
import { bulkheads } from "../../../utils/bulkhead";
import { resilientCaches, caches } from "../../../utils/cache";
import { prisma } from "../../../lib/prisma";

async function handler(req: NextApiRequest, res: NextApiResponse) {
  // Only allow admin users
  requireRole(req, "ADMIN");

  // Get all health metrics
  const [dbHealth, connectionStats, cacheStats, circuitState, bulkheadStats] =
    await Promise.all([
      checkDatabaseHealth(),
      getDatabaseConnectionStats(),
      getCacheStats(),
      { state: databaseCircuit.getState() },
      {
        read: bulkheads.read.getMetrics(),
        write: bulkheads.write.getMetrics(),
        reporting: bulkheads.reporting.getMetrics(),
      },
    ]);

  res.status(200).json({
    database: dbHealth,
    connections: connectionStats,
    circuit: circuitState,
    bulkheads: bulkheadStats,
    cache: cacheStats,
    timestamp: new Date().toISOString(),
  });
}

async function getDatabaseConnectionStats() {
  try {
    const stats = await prisma.$queryRaw`
      SELECT 
        count(*) as total_connections,
        sum(CASE WHEN state = 'active' THEN 1 ELSE 0 END) as active_connections,
        sum(CASE WHEN state = 'idle' THEN 1 ELSE 0 END) as idle_connections
      FROM pg_stat_activity 
      WHERE datname = current_database()
    `;
    return stats[0];
  } catch (error) {
    console.error("Error getting connection stats:", error);
    return { error: "Failed to fetch connection stats" };
  }
}

function getCacheStats() {
  return {
    userProfile: caches.userProfile.stats(),
    projectData: caches.projectData.stats(),
    subscriptionStatus: caches.subscriptionStatus.stats(),
    resilient: {
      userProfile: resilientCaches.userProfile.stats(),
      subscriptionStatus: resilientCaches.subscriptionStatus.stats(),
      projectList: resilientCaches.projectList.stats(),
    },
  };
}

export default withAuth(handler);
```

### Resilience Metrics

Track database resilience metrics for monitoring:

```typescript
// utils/resilience-metrics.ts
import { prisma } from "../lib/prisma";

// Simple in-memory metrics storage
// In production, use a proper metrics system like Prometheus
class ResilienceMetrics {
  private retries: number = 0;
  private timeouts: number = 0;
  private circuitBreaks: number = 0;
  private cacheHits: number = 0;
  private cacheMisses: number = 0;
  private bulkheadRejections: number = 0;

  // Rolling window of recent errors
  private readonly errors: Array<{
    timestamp: number;
    error: string;
  }> = [];

  // Latency samples
  private readonly latencySamples: number[] = [];
  private readonly maxSamples = 1000;

  incrementRetries(): void {
    this.retries++;
  }

  incrementTimeouts(): void {
    this.timeouts++;
  }

  incrementCircuitBreaks(): void {
    this.circuitBreaks++;
  }

  incrementCacheHits(): void {
    this.cacheHits++;
  }

  incrementCacheMisses(): void {
    this.cacheMisses++;
  }

  incrementBulkheadRejections(): void {
    this.bulkheadRejections++;
  }

  recordError(error: Error): void {
    this.errors.push({
      timestamp: Date.now(),
      error: error.message,
    });

    // Keep only recent errors
    if (this.errors.length > 100) {
      this.errors.shift();
    }
  }

  recordLatency(latencyMs: number): void {
    this.latencySamples.push(latencyMs);

    // Keep array at reasonable size
    if (this.latencySamples.length > this.maxSamples) {
      this.latencySamples.shift();
    }
  }

  getMetrics() {
    const latencySorted = [...this.latencySamples].sort((a, b) => a - b);
    const len = latencySorted.length;

    return {
      retries: this.retries,
      timeouts: this.timeouts,
      circuitBreaks: this.circuitBreaks,
      cacheHits: this.cacheHits,
      cacheMisses: this.cacheMisses,
      bulkheadRejections: this.bulkheadRejections,
      recentErrors: this.errors.slice(-10), // Last 10 errors
      latency: {
        p50: len > 0 ? latencySorted[Math.floor(len * 0.5)] : null,
        p90: len > 0 ? latencySorted[Math.floor(len * 0.9)] : null,
        p99: len > 0 ? latencySorted[Math.floor(len * 0.99)] : null,
        min: len > 0 ? latencySorted[0] : null,
        max: len > 0 ? latencySorted[len - 1] : null,
        samples: len,
      },
    };
  }

  // Reset all metrics (e.g., after recording to persistent storage)
  reset(): void {
    this.retries = 0;
    this.timeouts = 0;
    this.circuitBreaks = 0;
    this.cacheHits = 0;
    this.cacheMisses = 0;
    this.bulkheadRejections = 0;
    this.errors.length = 0;
    this.latencySamples.length = 0;
  }
}

// Singleton instance
export const metrics = new ResilienceMetrics();

// Schedule metrics persistence
export function startMetricsPersistence(intervalMs = 60000): () => void {
  const interval = setInterval(async () => {
    const currentMetrics = metrics.getMetrics();

    try {
      // Persist metrics to database
      await prisma.databaseMetrics.create({
        data: {
          timestamp: new Date(),
          retries: currentMetrics.retries,
          timeouts: currentMetrics.timeouts,
          circuitBreaks: currentMetrics.circuitBreaks,
          cacheHits: currentMetrics.cacheHits,
          cacheMisses: currentMetrics.cacheMisses,
          bulkheadRejections: currentMetrics.bulkheadRejections,
          latencyP50: currentMetrics.latency.p50 ?? 0,
          latencyP90: currentMetrics.latency.p90 ?? 0,
          latencyP99: currentMetrics.latency.p99 ?? 0,
          errors: JSON.stringify(currentMetrics.recentErrors),
        },
      });

      // Reset in-memory metrics after persistence
      metrics.reset();
    } catch (error) {
      console.error("Failed to persist database metrics:", error);
    }
  }, intervalMs);

  return () => clearInterval(interval);
}

// In production, start persistence
if (process.env.NODE_ENV === "production") {
  startMetricsPersistence();
}
```

## Conclusion

Database resilience is critical for maintaining application reliability, especially in multi-tenant environments where database failures can affect many organizations. By implementing these patterns, you can:

1. **Prevent cascading failures** during database outages
2. **Maintain service availability** during transient issues
3. **Degrade gracefully** when full functionality is not possible
4. **Recover automatically** when database service is restored
5. **Protect database resources** from overload during recovery

These patterns should be implemented as part of a comprehensive resilience strategy that includes:

- Proper database configuration and maintenance
- Regular backups and disaster recovery testing
- Performance monitoring and alerting
- Capacity planning and scaling strategies

Remember that resilience is not just about technology, but also about processes and people. Ensure your team is trained to respond to database incidents effectively, and that you have clear escalation procedures in place.

Keep this guide updated as your database resilience needs evolve and as you learn from production incidents.
