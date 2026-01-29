# Database Error Classification & Recovery Guide

This guide provides a comprehensive taxonomy of database errors and standardized approaches for handling and recovering from each error type.

## Overview

Database errors can be broadly classified into several categories, each requiring different handling strategies:

1. **Connection Errors**: Issues establishing or maintaining a connection to the database
2. **Query Errors**: Syntax errors, constraint violations, or type mismatches
3. **Transaction Errors**: Deadlocks, timeouts, or serialization failures
4. **Resource Errors**: Out of memory, disk space, or connection pool exhaustion
5. **Operational Errors**: Database server down, maintenance mode, or backup in progress

Understanding the specific type of error is crucial for implementing the appropriate recovery strategy and providing meaningful feedback to users and developers.

## Error Classification Taxonomy

### Connection Errors

| Error Pattern                        | Description                                  | Retryable? | Recovery Strategy               |
| ------------------------------------ | -------------------------------------------- | ---------- | ------------------------------- |
| `ECONNREFUSED`                       | Database server is not accepting connections | Yes        | Exponential backoff retry       |
| `ETIMEDOUT`                          | Connection attempt timed out                 | Yes        | Exponential backoff retry       |
| `ECONNRESET`                         | Connection was forcibly closed by the server | Yes        | Immediate retry with backoff    |
| `Connection terminated unexpectedly` | Connection dropped during operation          | Yes        | Retry with new connection       |
| `Too many connections`               | Connection pool exhausted                    | Yes        | Wait and retry with backoff     |
| `SSL/TLS error`                      | Secure connection failed                     | No         | Check certificate configuration |

### Query Errors

| Error Pattern                                           | Description               | Retryable? | Recovery Strategy                 |
| ------------------------------------------------------- | ------------------------- | ---------- | --------------------------------- |
| `syntax error at or near`                               | SQL syntax error          | No         | Fix query syntax                  |
| `column "X" does not exist`                             | Schema mismatch           | No         | Fix query or update schema        |
| `duplicate key value violates unique constraint`        | Uniqueness violation      | No         | Handle as business logic error    |
| `null value in column "X" violates not-null constraint` | Null constraint violation | No         | Validate data before query        |
| `value too long for type`                               | Data exceeds column size  | No         | Validate data length before query |
| `invalid input syntax for type`                         | Type conversion error     | No         | Validate data types before query  |

### Transaction Errors

| Error Pattern                                  | Description                                     | Retryable? | Recovery Strategy                  |
| ---------------------------------------------- | ----------------------------------------------- | ---------- | ---------------------------------- |
| `deadlock detected`                            | Concurrent transactions deadlock                | Yes        | Retry transaction with backoff     |
| `canceling statement due to statement timeout` | Transaction timeout                             | Yes        | Optimize query or increase timeout |
| `could not serialize access`                   | Serialization failure in transactions           | Yes        | Retry with exponential backoff     |
| `transaction is aborted`                       | Transaction already failed                      | No         | Begin new transaction              |
| `current transaction is aborted`               | Commands ignored until end of transaction block | No         | Rollback and begin new transaction |

### Resource Errors

| Error Pattern                             | Description                      | Retryable? | Recovery Strategy                |
| ----------------------------------------- | -------------------------------- | ---------- | -------------------------------- |
| `out of memory`                           | Database server out of memory    | Yes        | Retry with backoff, alert ops    |
| `out of shared memory`                    | Shared memory segments exhausted | Yes        | Retry with backoff, alert ops    |
| `out of disk space`                       | No disk space left on server     | No         | Alert ops, emergency cleanup     |
| `too many connections already`            | Connection limit reached         | Yes        | Retry with backoff, monitor pool |
| `remaining connection slots are reserved` | Reserved connections only        | Yes        | Retry with backoff               |

### Operational Errors

| Error Pattern                                 | Description                    | Retryable? | Recovery Strategy                   |
| --------------------------------------------- | ------------------------------ | ---------- | ----------------------------------- |
| `database system is shutting down`            | Planned shutdown in progress   | Yes        | Retry with increasing backoff       |
| `cannot execute X in a read-only transaction` | Database in read-only mode     | No         | Queue write for later or alert user |
| `the database system is in recovery mode`     | Database recovering from crash | Yes        | Retry with long backoff             |
| `PG::AdminShutdown`                           | Administrator command shutdown | Yes        | Retry with long backoff             |
| `database "X" does not exist`                 | Database not found             | No         | Check configuration                 |

## Error Recovery Strategies

### 1. Retry Mechanism

The core retry mechanism should follow these principles:

```typescript
type RetryOptions = {
  maxRetries: number;
  initialDelay: number;
  maxDelay: number;
  backoffFactor: number;
  retryableErrors: Array<string | RegExp>;
};

const defaultRetryOptions: RetryOptions = {
  maxRetries: 3,
  initialDelay: 100,
  maxDelay: 5000,
  backoffFactor: 2,
  retryableErrors: [
    // Connection errors
    /ECONNREFUSED/,
    /ETIMEDOUT/,
    /ECONNRESET/,
    /Connection terminated unexpectedly/,
    /Too many connections/,
    // Transaction errors
    /deadlock detected/,
    /statement timeout/,
    /could not serialize access/,
  ],
};

async function withRetry<T>(
  operation: () => Promise<T>,
  options: Partial<RetryOptions> = {}
): Promise<T> {
  const opts = { ...defaultRetryOptions, ...options };
  let lastError: Error | undefined;
  let delay = opts.initialDelay;

  for (let attempt = 0; attempt < opts.maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      const errorMessage = lastError.message;

      // Check if error is retryable
      const isRetryable = opts.retryableErrors.some((pattern) =>
        typeof pattern === "string"
          ? errorMessage.includes(pattern)
          : pattern.test(errorMessage)
      );

      if (!isRetryable || attempt === opts.maxRetries - 1) {
        throw lastError;
      }

      // Calculate backoff delay
      delay = Math.min(delay * opts.backoffFactor, opts.maxDelay);

      console.warn(
        `Database operation failed (attempt ${attempt + 1}/${
          opts.maxRetries
        }), retrying in ${delay}ms:`,
        errorMessage
      );

      // Wait before next attempt
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }

  // This should never happen due to the throw above
  throw lastError;
}
```

### 2. Circuit Breaker Pattern

For handling scenarios where the database is experiencing prolonged issues:

```typescript
class DatabaseCircuitBreaker {
  private failureCount: number = 0;
  private lastFailureTime: number = 0;
  private state: "CLOSED" | "OPEN" | "HALF_OPEN" = "CLOSED";

  constructor(
    private failureThreshold: number = 5,
    private resetTimeout: number = 30000
  ) {}

  public async execute<T>(operation: () => Promise<T>): Promise<T> {
    if (this.state === "OPEN") {
      // Check if circuit should move to half-open
      const now = Date.now();
      if (now - this.lastFailureTime >= this.resetTimeout) {
        this.state = "HALF_OPEN";
      } else {
        throw new Error("Circuit breaker is open");
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
    this.failureCount = 0;
    this.state = "CLOSED";
  }

  private recordFailure(): void {
    this.failureCount++;
    this.lastFailureTime = Date.now();

    if (
      this.state === "HALF_OPEN" ||
      this.failureCount >= this.failureThreshold
    ) {
      this.state = "OPEN";
    }
  }
}
```

### 3. Fallback Strategies

#### Cache Fallback

When the database is unavailable, consider using cache:

```typescript
async function getUserWithCacheFallback(id: string): Promise<User | null> {
  try {
    // Try to get from database
    const user = await userRepository.findById(id);

    // Update cache with fresh data
    if (user) {
      await cache.set(`user:${id}`, user, { ttl: 3600 });
    }

    return user;
  } catch (error) {
    console.warn(`Database error, falling back to cache: ${error.message}`);

    // Fallback to cache on database error
    try {
      return await cache.get(`user:${id}`);
    } catch (cacheError) {
      console.error(`Cache fallback also failed: ${cacheError.message}`);
      throw error; // Rethrow original error
    }
  }
}
```

#### Degraded Service Mode

For critical services, implement degraded operation modes:

```typescript
class UserService {
  private inDegradedMode = false;

  async getUser(id: string): Promise<User | null> {
    try {
      if (this.inDegradedMode) {
        // In degraded mode, try cache first
        const cachedUser = await cache.get(`user:${id}`);
        if (cachedUser) return cachedUser;
      }

      // Normal operation or cache miss in degraded mode
      const user = await userRepository.findById(id);
      return user;
    } catch (error) {
      // Check if error indicates we should enter degraded mode
      if (isDatabaseUnavailableError(error)) {
        this.enterDegradedMode();
      }
      throw error;
    }
  }

  private enterDegradedMode(): void {
    if (!this.inDegradedMode) {
      this.inDegradedMode = true;
      console.warn("Entering degraded service mode due to database issues");

      // Schedule periodic check to see if database is back
      this.scheduleDatabaseCheck();

      // Notify monitoring systems
      monitoring.reportIncident(
        "database_unavailable",
        "Entered degraded mode"
      );
    }
  }

  private async scheduleDatabaseCheck(): Promise<void> {
    setTimeout(async () => {
      try {
        // Perform a simple query to check database health
        await userRepository.count();

        // If successful, exit degraded mode
        this.inDegradedMode = false;
        console.info("Exiting degraded service mode, database is back");
        monitoring.resolveIncident("database_unavailable");
      } catch (error) {
        // Still having issues, reschedule check
        this.scheduleDatabaseCheck();
      }
    }, 30000); // Check every 30 seconds
  }
}
```

## Error Handling Best Practices

### 1. Consistent Error Wrapping

Always wrap database errors in application-specific errors to provide context:

```typescript
class DatabaseError extends Error {
  constructor(
    message: string,
    public originalError: Error,
    public operation: string,
    public retryable: boolean
  ) {
    super(`${message} (${operation}): ${originalError.message}`);
    this.name = "DatabaseError";
  }
}

// Usage
try {
  await prisma.user.findUnique({ where: { id } });
} catch (error) {
  throw new DatabaseError(
    "Failed to retrieve user",
    error,
    "userRepository.findById",
    isRetryableError(error)
  );
}
```

### 2. Error Instrumentation

Add instrumentation to track database errors:

```typescript
class DatabaseErrorTracker {
  static async trackError(error: DatabaseError): Promise<void> {
    await metrics.increment("database.errors", 1, {
      operation: error.operation,
      retryable: String(error.retryable),
    });

    await logger.error("Database error", {
      operation: error.operation,
      message: error.message,
      retryable: error.retryable,
      stack: error.stack,
    });

    // For critical errors, alert on-call team
    if (isCriticalOperation(error.operation)) {
      await alerting.sendAlert("Database error in critical operation", {
        operation: error.operation,
        message: error.message,
        time: new Date().toISOString(),
      });
    }
  }
}
```

### 3. Error Classification Helper

Create a helper to classify errors:

```typescript
function classifyDatabaseError(error: Error): DatabaseErrorType {
  const message = error.message.toLowerCase();

  // Connection errors
  if (
    message.includes("econnrefused") ||
    message.includes("etimedout") ||
    message.includes("econnreset") ||
    message.includes("connection terminated")
  ) {
    return "CONNECTION";
  }

  // Transaction errors
  if (
    message.includes("deadlock detected") ||
    message.includes("statement timeout") ||
    message.includes("serialize")
  ) {
    return "TRANSACTION";
  }

  // Query errors
  if (
    message.includes("syntax error") ||
    message.includes("does not exist") ||
    message.includes("violates") ||
    message.includes("invalid input")
  ) {
    return "QUERY";
  }

  // Resource errors
  if (
    message.includes("out of memory") ||
    message.includes("disk space") ||
    message.includes("too many connections")
  ) {
    return "RESOURCE";
  }

  // Operational errors
  if (
    message.includes("shutting down") ||
    message.includes("read-only") ||
    message.includes("recovery mode")
  ) {
    return "OPERATIONAL";
  }

  return "UNKNOWN";
}

// Helper to determine if error is retryable
function isRetryableError(error: Error): boolean {
  const errorType = classifyDatabaseError(error);

  // Most connection errors are retryable
  if (errorType === "CONNECTION") return true;

  // Many transaction errors are retryable
  if (errorType === "TRANSACTION") return true;

  // Some resource errors are retryable
  if (errorType === "RESOURCE" && !error.message.includes("disk space"))
    return true;

  // Some operational errors are retryable
  if (
    errorType === "OPERATIONAL" &&
    (error.message.includes("shutting down") ||
      error.message.includes("recovery mode"))
  ) {
    return true;
  }

  return false;
}
```

## Integration with Repository Pattern

Integrate error handling with the repository pattern:

```typescript
class BaseRepository<T> {
  constructor(
    protected model: any,
    protected entityName: string,
    protected circuitBreaker = new DatabaseCircuitBreaker()
  ) {}

  async findById(id: string): Promise<T | null> {
    try {
      return await this.circuitBreaker.execute(() =>
        withRetry(() => this.model.findUnique({ where: { id } }))
      );
    } catch (error) {
      const dbError = new DatabaseError(
        `Failed to find ${this.entityName}`,
        error,
        `${this.entityName}Repository.findById`,
        isRetryableError(error)
      );

      await DatabaseErrorTracker.trackError(dbError);
      throw dbError;
    }
  }

  async create(data: Partial<T>): Promise<T> {
    try {
      return await this.circuitBreaker.execute(() =>
        withRetry(() => this.model.create({ data }))
      );
    } catch (error) {
      const dbError = new DatabaseError(
        `Failed to create ${this.entityName}`,
        error,
        `${this.entityName}Repository.create`,
        isRetryableError(error)
      );

      await DatabaseErrorTracker.trackError(dbError);
      throw dbError;
    }
  }

  // Similar implementation for other methods
}

// Usage
class UserRepository extends BaseRepository<User> {
  constructor() {
    super(prisma.user, "User");
  }

  // Add user-specific methods here
}
```

## Error Handling for API Responses

Map database errors to appropriate HTTP responses:

```typescript
function mapDatabaseErrorToHttpResponse(
  error: DatabaseError,
  res: Response
): void {
  const errorType = classifyDatabaseError(error.originalError);

  switch (errorType) {
    case "CONNECTION":
    case "RESOURCE":
    case "OPERATIONAL":
      // Service unavailable for connection/resource/operational issues
      res.status(503).json({
        error: "Database service temporarily unavailable",
        retryAfter: 30, // Suggest retry after 30 seconds
        message: "Please try again later",
      });
      break;

    case "QUERY":
      if (error.originalError.message.includes("does not exist")) {
        // Not found for queries that fail because entity doesn't exist
        res.status(404).json({
          error: "Resource not found",
          message: `The requested ${
            error.operation.split(".")[0]
          } could not be found`,
        });
      } else if (
        error.originalError.message.includes("violates unique constraint")
      ) {
        // Conflict for uniqueness violations
        res.status(409).json({
          error: "Conflict",
          message: "A resource with the same unique identifier already exists",
        });
      } else {
        // Bad request for other query errors
        res.status(400).json({
          error: "Invalid request",
          message: "The request could not be processed",
        });
      }
      break;

    case "TRANSACTION":
      // Conflict for transaction errors (often due to concurrent updates)
      res.status(409).json({
        error: "Conflict",
        message:
          "The resource was modified by another request, please try again",
      });
      break;

    default:
      // Internal server error for unknown issues
      res.status(500).json({
        error: "Internal server error",
        message: "An unexpected error occurred",
      });
  }
}
```

## Monitoring and Alerting

Implement comprehensive monitoring for database errors:

```typescript
class DatabaseMonitor {
  static setupMonitoring(): void {
    // Set up error rate alerting
    metrics.alertWhenThresholdExceeds("database.errors", 10, "5m", {
      title: "High database error rate",
      message: "Database error rate exceeds 10 errors in 5 minutes",
      severity: "warning",
    });

    // Set up circuit breaker state alerting
    metrics.alertOnValue("database.circuit_breaker.state", "OPEN", {
      title: "Database circuit breaker open",
      message: "Database circuit breaker has tripped to OPEN state",
      severity: "critical",
    });

    // Set up slow query alerting
    metrics.alertWhenThresholdExceeds("database.slow_queries", 5, "5m", {
      title: "High number of slow database queries",
      message: "More than 5 slow queries detected in 5 minutes",
      severity: "warning",
    });

    // Set up connection pool utilization alerting
    metrics.alertWhenThresholdExceeds(
      "database.connection_pool.utilization",
      0.8,
      "1m",
      {
        title: "High database connection pool utilization",
        message: "Connection pool utilization above 80%",
        severity: "warning",
      }
    );
  }
}
```

## Conclusion

This guide provides a comprehensive approach to database error classification and recovery, ensuring that your application can gracefully handle database issues while providing appropriate feedback to users and operations teams.

By implementing these patterns, you can:

1. Accurately classify and respond to different types of database errors
2. Automatically retry operations when appropriate
3. Implement circuit breakers to prevent cascading failures
4. Provide fallback mechanisms for critical operations
5. Properly instrument and monitor database errors
6. Map database errors to appropriate API responses

These strategies will significantly improve the resilience and user experience of your application when database issues occur.
