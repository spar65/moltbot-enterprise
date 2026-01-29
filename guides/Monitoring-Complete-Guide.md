# Monitoring Complete Guide

**The definitive guide to application and infrastructure monitoring for production systems.**

## Table of Contents

1. [Overview](#overview)
2. [Application Monitoring](#application-monitoring)
3. [Infrastructure Monitoring](#infrastructure-monitoring)
4. [Metrics & Alerting](#metrics--alerting)
5. [Log Management](#log-management)
6. [Distributed Tracing](#distributed-tracing)
7. [Synthetic Monitoring](#synthetic-monitoring)
8. [Dashboard Design](#dashboard-design)
9. [Alert Management](#alert-management)
10. [On-Call Workflows](#on-call-workflows)

---

## Overview

### Why Monitoring Matters

> **"You can't improve what you can't measure."** - Peter Drucker

Comprehensive monitoring enables:
- **Proactive Issue Detection**: Find problems before users do
- **Rapid Troubleshooting**: Reduce MTTR with rich context
- **Performance Optimization**: Identify bottlenecks and inefficiencies
- **Capacity Planning**: Forecast resource needs accurately
- **Business Insights**: Understand user behavior and system health

### The Four Golden Signals

Google's Site Reliability Engineering defines four key metrics:

1. **Latency**: How long does it take to serve a request?
2. **Traffic**: How much demand is placed on your system?
3. **Errors**: What is the rate of failed requests?
4. **Saturation**: How "full" is your system?

### Monitoring Hierarchy

```
┌─────────────────────────────────────────┐
│         Business Metrics                │  ← What matters to users
│  (User signups, purchases, sessions)    │
├─────────────────────────────────────────┤
│       Application Metrics               │  ← How your code performs
│  (API latency, error rates, throughput) │
├─────────────────────────────────────────┤
│      Infrastructure Metrics             │  ← How resources perform
│  (CPU, memory, disk, network)           │
├─────────────────────────────────────────┤
│          System Logs                    │  ← Detailed event records
│  (Access logs, error logs, audit logs)  │
└─────────────────────────────────────────┘
```

---

## Application Monitoring

### Essential Application Metrics

#### Request Metrics
```typescript
// Track all API requests
interface RequestMetrics {
  // Basic info
  endpoint: string;
  method: string;
  statusCode: number;
  
  // Performance
  duration: number;        // Milliseconds
  databaseTime: number;
  externalAPITime: number;
  
  // Context
  userId?: string;
  organizationId: string;
  userAgent: string;
  
  // Errors
  error?: {
    type: string;
    message: string;
    stack: string;
  };
}

// Middleware to track requests
export async function trackRequest(
  req: Request,
  handler: () => Promise<Response>
): Promise<Response> {
  const startTime = Date.now();
  let statusCode = 200;
  let error: Error | undefined;
  
  try {
    const response = await handler();
    statusCode = response.status;
    return response;
    
  } catch (err) {
    error = err as Error;
    statusCode = 500;
    throw err;
    
  } finally {
    const duration = Date.now() - startTime;
    
    // Send metrics
    await sendMetric({
      name: 'api_request',
      value: duration,
      tags: {
        endpoint: req.url,
        method: req.method,
        status: statusCode.toString(),
        hasError: error ? 'true' : 'false'
      }
    });
    
    // Log slow requests
    if (duration > 1000) {
      console.warn(`⚠️ Slow request: ${req.method} ${req.url} (${duration}ms)`);
    }
  }
}
```

#### Business Metrics
```typescript
// Track business-critical events
async function trackBusinessEvent(
  event: string,
  metadata: Record<string, any>
): Promise<void> {
  await sendMetric({
    name: `business.${event}`,
    value: 1,
    tags: {
      ...metadata,
      timestamp: new Date().toISOString()
    }
  });
}

// Examples
await trackBusinessEvent('user_signup', {
  organizationId,
  plan: 'enterprise',
  source: 'website'
});

await trackBusinessEvent('assessment_completed', {
  organizationId,
  assessmentType: '4d',
  duration: completionTimeMs
});

await trackBusinessEvent('payment_successful', {
  organizationId,
  amount: 99.99,
  currency: 'USD'
});
```

### Error Tracking

#### Structured Error Logging
```typescript
// Comprehensive error capture
interface ErrorContext {
  error: Error;
  severity: 'low' | 'medium' | 'high' | 'critical';
  
  // Request context
  request?: {
    method: string;
    url: string;
    headers: Record<string, string>;
    body?: any;
  };
  
  // User context
  user?: {
    id: string;
    email: string;
    organizationId: string;
  };
  
  // Additional context
  metadata?: Record<string, any>;
}

async function logError(context: ErrorContext): Promise<void> {
  const errorLog = {
    timestamp: new Date().toISOString(),
    severity: context.severity,
    
    // Error details
    errorType: context.error.name,
    errorMessage: context.error.message,
    errorStack: context.error.stack,
    
    // Context
    ...context.request,
    ...context.user,
    ...context.metadata,
    
    // Environment
    environment: process.env.NODE_ENV,
    region: process.env.VERCEL_REGION,
    commit: process.env.VERCEL_GIT_COMMIT_SHA
  };
  
  // Send to error tracking service
  console.error(JSON.stringify(errorLog));
  
  // Send metric
  await sendMetric({
    name: 'application_error',
    value: 1,
    tags: {
      errorType: context.error.name,
      severity: context.severity
    }
  });
  
  // Alert on critical errors
  if (context.severity === 'critical') {
    await sendAlert({
      severity: 'critical',
      message: `Critical error: ${context.error.message}`,
      error: errorLog
    });
  }
}
```

#### Error Rate Monitoring
```typescript
// Track error rates over time
async function monitorErrorRates(): Promise<void> {
  const errorRate = await getErrorRate('5m');  // Last 5 minutes
  const baselineRate = await getBaselineErrorRate('1h');  // 1 hour baseline
  
  // Alert if error rate spikes
  if (errorRate > baselineRate * 3) {
    await sendAlert({
      severity: 'warning',
      message: `Error rate spike: ${errorRate.toFixed(2)}% (baseline: ${
        baselineRate.toFixed(2)
      }%)`,
      metric: 'error_rate',
      value: errorRate
    });
  }
}
```

### Performance Monitoring

#### P95/P99 Latency Tracking
```typescript
// Track latency percentiles
interface LatencyMetrics {
  endpoint: string;
  
  percentiles: {
    p50: number;   // Median
    p75: number;
    p90: number;
    p95: number;   // 95% of requests faster than this
    p99: number;   // 99% of requests faster than this
    p999: number;  // 99.9% of requests faster than this
  };
  
  count: number;
  avg: number;
  max: number;
}

// Monitor latency SLOs
async function monitorLatencySLOs(): Promise<void> {
  const endpoints = await getCriticalEndpoints();
  
  for (const endpoint of endpoints) {
    const latency = await getLatencyMetrics(endpoint, '5m');
    
    // P95 latency SLO: < 500ms
    if (latency.percentiles.p95 > 500) {
      await sendAlert({
        severity: 'warning',
        message: `${endpoint} P95 latency: ${latency.percentiles.p95}ms`,
        metric: 'latency_slo_violation',
        endpoint
      });
    }
    
    // P99 latency SLO: < 1000ms
    if (latency.percentiles.p99 > 1000) {
      await sendAlert({
        severity: 'warning',
        message: `${endpoint} P99 latency: ${latency.percentiles.p99}ms`,
        metric: 'latency_slo_violation',
        endpoint
      });
    }
  }
}
```

---

## Infrastructure Monitoring

### Server/Container Metrics

#### CPU & Memory
```typescript
// Collect system metrics
interface SystemMetrics {
  cpu: {
    usage: number;         // Percentage (0-100)
    loadAverage: number[]; // [1min, 5min, 15min]
    throttling: number;    // % of time throttled
  };
  
  memory: {
    used: number;          // Bytes
    available: number;
    percentage: number;    // 0-100
    swapUsed: number;
  };
  
  disk: {
    used: number;
    available: number;
    percentage: number;
    iops: number;
  };
}

// Monitor resource utilization
async function monitorResources(): Promise<void> {
  const metrics = await getSystemMetrics();
  
  // Alert on high CPU
  if (metrics.cpu.usage > 80) {
    await sendAlert({
      severity: 'warning',
      message: `High CPU usage: ${metrics.cpu.usage}%`,
      metric: 'cpu_usage',
      value: metrics.cpu.usage
    });
  }
  
  // Alert on high memory
  if (metrics.memory.percentage > 90) {
    await sendAlert({
      severity: 'critical',
      message: `High memory usage: ${metrics.memory.percentage}%`,
      metric: 'memory_usage',
      value: metrics.memory.percentage
    });
  }
  
  // Alert on disk space
  if (metrics.disk.percentage > 80) {
    await sendAlert({
      severity: 'warning',
      message: `Low disk space: ${metrics.disk.percentage}% used`,
      metric: 'disk_usage',
      value: metrics.disk.percentage
    });
  }
}
```

### Database Monitoring

#### Connection Pool
```typescript
// Monitor database connection pool
interface ConnectionPoolMetrics {
  active: number;
  idle: number;
  waiting: number;
  total: number;
  maxPoolSize: number;
}

async function monitorConnectionPool(): Promise<void> {
  const pool = await getConnectionPoolMetrics();
  
  // Alert on pool exhaustion
  if (pool.waiting > 10) {
    await sendAlert({
      severity: 'critical',
      message: `Connection pool exhausted: ${pool.waiting} queries waiting`,
      metric: 'db_connection_pool',
      poolStats: pool
    });
  }
  
  // Warn on high utilization
  const utilization = pool.active / pool.maxPoolSize;
  if (utilization > 0.8) {
    await sendAlert({
      severity: 'warning',
      message: `High connection pool utilization: ${
        (utilization * 100).toFixed(1)
      }%`,
      metric: 'db_pool_utilization',
      value: utilization
    });
  }
}
```

#### Query Performance
```typescript
// Monitor slow queries
interface QueryMetrics {
  query: string;
  avgDuration: number;
  p95Duration: number;
  count: number;
  slowCount: number;  // > 1 second
}

async function monitorSlowQueries(): Promise<void> {
  const queries = await getSlowQueries('5m');
  
  for (const query of queries) {
    if (query.slowCount > 10) {
      await sendAlert({
        severity: 'warning',
        message: `Slow query detected: ${query.slowCount} queries > 1s`,
        metric: 'slow_queries',
        query: query.query.substring(0, 100),  // First 100 chars
        avgDuration: query.avgDuration
      });
    }
  }
}
```

---

## Metrics & Alerting

### Alert Definitions

#### Severity Levels
- **Critical (P1)**: Service down, data loss imminent, immediate action required
- **Warning (P2)**: Degraded performance, trending toward critical, action needed soon
- **Info (P3)**: Notable event, no immediate action, for awareness

#### Alert Routing
```typescript
interface AlertRouting {
  // Critical: page on-call immediately
  critical: {
    channels: ['pagerduty', 'slack-critical', 'sms'];
    escalation: {
      initial: ['on-call-primary'],
      after5min: ['on-call-secondary'],
      after15min: ['engineering-lead']
    };
  };
  
  // Warning: notify team, no page
  warning: {
    channels: ['slack-warnings', 'email'];
    recipients: ['on-call-primary', 'team-channel'];
  };
  
  // Info: log only
  info: {
    channels: ['slack-info'];
    recipients: ['team-channel'];
  };
}
```

### Alert Best Practices

#### 1. Actionable Alerts
```typescript
// ❌ BAD: Vague alert
await sendAlert({
  message: 'Something is wrong'
});

// ✅ GOOD: Actionable alert
await sendAlert({
  severity: 'critical',
  message: 'API error rate: 15% (baseline: 0.1%)',
  metric: 'api_error_rate',
  value: 15,
  runbook: 'https://docs.company.com/runbooks/high-error-rate',
  possibleActions: [
    'Check recent deployments',
    'Review error logs for patterns',
    'Check database connection pool',
    'Verify external API dependencies'
  ]
});
```

#### 2. Alert Aggregation
```typescript
// Prevent alert storms
interface AlertAggregation {
  // Group similar alerts
  groupBy: ['service', 'metric'];
  groupInterval: '5m';
  
  // Limit alert frequency
  rateLimit: {
    maxAlertsPerHour: 10;
    cooldownPeriod: '15m';
  };
}
```

#### 3. Alert Silencing
```typescript
// Silence alerts during maintenance
async function scheduleMaintenance(
  startTime: Date,
  duration: number
): Promise<void> {
  await silenceAlerts({
    start: startTime,
    end: new Date(startTime.getTime() + duration),
    reason: 'Scheduled maintenance',
    affectedServices: ['api', 'database']
  });
}
```

---

## Log Management

### Log Levels

```typescript
// Structured logging with levels
enum LogLevel {
  DEBUG = 'debug',    // Detailed debugging info
  INFO = 'info',      // General information
  WARN = 'warn',      // Warning, but not an error
  ERROR = 'error',    // Error that should be investigated
  CRITICAL = 'critical' // Critical error requiring immediate action
}

interface StructuredLog {
  timestamp: Date;
  level: LogLevel;
  message: string;
  context: Record<string, any>;
}

function log(level: LogLevel, message: string, context: Record<string, any>): void {
  const logEntry: StructuredLog = {
    timestamp: new Date(),
    level,
    message,
    context: {
      ...context,
      environment: process.env.NODE_ENV,
      region: process.env.VERCEL_REGION,
      commit: process.env.VERCEL_GIT_COMMIT_SHA
    }
  };
  
  console.log(JSON.stringify(logEntry));
}
```

### Log Retention

```typescript
// Log retention policies
interface LogRetentionPolicy {
  critical: 365;    // Days
  error: 180;
  warn: 90;
  info: 30;
  debug: 7;
  
  // Special categories
  security: 365;
  audit: 2555;      // 7 years
  access: 90;
}
```

---

## Distributed Tracing

### Trace Context Propagation

```typescript
// Create trace context
interface TraceContext {
  traceId: string;
  spanId: string;
  parentSpanId?: string;
}

function createTrace(): TraceContext {
  return {
    traceId: generateTraceId(),
    spanId: generateSpanId()
  };
}

// Propagate trace through calls
async function handleRequest(req: Request): Promise<Response> {
  const trace = getOrCreateTrace(req);
  
  // Database call
  const dbSpan = startSpan(trace, 'database-query');
  const data = await db.query('SELECT * FROM users');
  endSpan(dbSpan);
  
  // External API call
  const apiSpan = startSpan(trace, 'external-api');
  const externalData = await fetch('https://api.example.com', {
    headers: {
      'X-Trace-Id': trace.traceId,
      'X-Span-Id': apiSpan.spanId
    }
  });
  endSpan(apiSpan);
  
  return Response.json({ data, externalData });
}
```

---

## Synthetic Monitoring

### Critical Path Testing

```typescript
// Define critical user journeys
const syntheticTests = [
  {
    name: 'User Login Flow',
    frequency: '5m',
    steps: [
      { action: 'navigate', target: '/login' },
      { action: 'type', target: '#email', value: 'test@example.com' },
      { action: 'type', target: '#password', value: 'test-password' },
      { action: 'click', target: '#submit' },
      { action: 'assert', target: '#dashboard', condition: 'visible' }
    ],
    assertions: {
      maxDuration: 3000,  // 3 seconds
      expectedContent: 'Welcome back'
    }
  },
  
  {
    name: 'API Health Check',
    frequency: '1m',
    steps: [
      { action: 'api-call', target: '/api/health', method: 'GET' }
    ],
    assertions: {
      maxDuration: 500,
      expectedStatus: 200
    }
  }
];
```

---

## Dashboard Design

### Dashboard Hierarchy

1. **Executive Dashboard**: High-level business metrics
2. **Operations Dashboard**: System health and performance
3. **Debug Dashboard**: Detailed metrics for troubleshooting

### Essential Dashboards

#### Operations Dashboard
```
┌─────────────────────────────────────────┐
│           System Health                 │
│  🟢 API: 99.95% uptime                  │
│  🟢 Database: 12ms avg latency          │
│  🟡 Error Rate: 0.3% (baseline: 0.1%)   │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         Performance                     │
│  P95 Latency: 245ms                     │
│  P99 Latency: 890ms                     │
│  Requests/sec: 1,250                    │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│      Resource Utilization               │
│  CPU: ██████░░░░ 60%                    │
│  Memory: ███████░░░ 70%                 │
│  Disk: ████░░░░░░ 40%                   │
└─────────────────────────────────────────┘
```

---

## Related Resources

### Rules
- @221-application-monitoring.mdc - Application monitoring standards
- @225-infrastructure-monitoring.mdc - Infrastructure monitoring
- @222-metrics-alerting.mdc - Metrics and alerting

### Tools
- `.cursor/tools/check-infrastructure.sh` - Verify infrastructure health
- `.cursor/tools/analyze-logs.sh` - Log analysis
- `.cursor/tools/run-synthetic-tests.sh` - Run synthetic monitoring

### Guides
- `guides/Incident-Response-Complete-Guide.md` - Handling incidents
- `guides/Observability-Best-Practices.md` - Observability patterns

---

## Quick Start Checklist

- [ ] Implement application metrics tracking
- [ ] Set up error tracking and alerting
- [ ] Configure infrastructure monitoring
- [ ] Create operational dashboards
- [ ] Define alert thresholds and routing
- [ ] Implement distributed tracing
- [ ] Set up synthetic monitoring for critical paths
- [ ] Document on-call procedures
- [ ] Schedule regular dashboard reviews
- [ ] Establish metrics review cadence

---

**Time Investment**: 2-4 hours setup, ongoing maintenance
**ROI**: Reduced MTTR by 70%, proactive issue detection, improved system reliability

