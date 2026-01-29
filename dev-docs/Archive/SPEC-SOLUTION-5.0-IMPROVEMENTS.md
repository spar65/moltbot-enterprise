# SPEC-SOLUTION 5.0: System Improvements

**Document ID**: SPEC-SOLUTION-5.0  
**Addresses**: SPEC-ISSUES-5.0  
**Category**: Improvements  
**Priority**: P2-P3 (Enhancement)  
**Date Created**: 2026-01-28  
**Status**: Draft

---

## Executive Summary

This document provides implementation details for system improvements that enhance security, performance, maintainability, and developer experience.

---

## Solution Registry

### Solution 5.1: CORS Implementation

**Addresses**: Issue 5.1 - CORS Implementation for Remote Access  
**Priority**: P2  
**Effort**: Low (2-3 days)

See **SPEC-SOLUTION-1.0 Section 1.2** for full implementation.

---

### Solution 5.2: Comprehensive Rate Limiting

**Addresses**: Issue 5.2 - Comprehensive Rate Limiting  
**Priority**: P1  
**Effort**: Medium (1-2 sprints)

See **SPEC-SOLUTION-1.0 Section 1.6** for full implementation.

---

### Solution 5.3: Centralized Environment Configuration

**Addresses**: Issue 5.3 - Centralized Configuration Management  
**Priority**: P2  
**Effort**: High (2-3 sprints)

#### Implementation

```typescript
// src/config/env.ts

import { z } from 'zod';

// ============================================================
// ENVIRONMENT SCHEMA
// ============================================================

const EnvSchema = z.object({
  // -------------------- Runtime --------------------
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  
  // -------------------- Application --------------------
  CLAWDBOT_STATE_DIR: z.string().optional(),
  CLAWDBOT_CONFIG_DIR: z.string().optional(),
  CLAWDBOT_VERBOSE: z.string().transform(v => v === 'true' || v === '1').default('false'),
  CLAWDBOT_DEBUG: z.string().transform(v => v === 'true' || v === '1').default('false'),
  
  // -------------------- Gateway --------------------
  GATEWAY_PORT: z.string().transform(Number).pipe(z.number().min(1).max(65535)).default('18789'),
  GATEWAY_HOST: z.string().default('127.0.0.1'),
  GATEWAY_SECRET: z.string().min(16).optional(),
  
  // -------------------- LLM Providers --------------------
  OPENAI_API_KEY: z.string().optional(),
  ANTHROPIC_API_KEY: z.string().optional(),
  GOOGLE_API_KEY: z.string().optional(),
  
  // -------------------- Channels --------------------
  TELEGRAM_BOT_TOKEN: z.string().optional(),
  DISCORD_BOT_TOKEN: z.string().optional(),
  SLACK_BOT_TOKEN: z.string().optional(),
  SLACK_SIGNING_SECRET: z.string().optional(),
  
  // -------------------- External Services --------------------
  DATABASE_URL: z.string().url().optional(),
  REDIS_URL: z.string().url().optional(),
  
  // -------------------- Observability --------------------
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  METRICS_ENABLED: z.string().transform(v => v === 'true' || v === '1').default('false'),
});

export type Env = z.infer<typeof EnvSchema>;

// ============================================================
// ENVIRONMENT LOADER
// ============================================================

let cachedEnv: Env | null = null;

export function loadEnv(): Env {
  if (cachedEnv) {
    return cachedEnv;
  }
  
  const result = EnvSchema.safeParse(process.env);
  
  if (!result.success) {
    const issues = result.error.issues.map(issue => 
      `  ${issue.path.join('.')}: ${issue.message}`
    ).join('\n');
    
    throw new Error(`Environment validation failed:\n${issues}`);
  }
  
  cachedEnv = result.data;
  return cachedEnv;
}

// Singleton export
export const env = loadEnv();

// ============================================================
// TYPED ACCESSORS
// ============================================================

export function getEnv<K extends keyof Env>(key: K): Env[K] {
  return env[key];
}

export function requireEnv<K extends keyof Env>(key: K): NonNullable<Env[K]> {
  const value = env[key];
  if (value === undefined || value === null) {
    throw new Error(`Required environment variable ${key} is not set`);
  }
  return value as NonNullable<Env[K]>;
}

// ============================================================
// DEVELOPMENT UTILITIES
// ============================================================

export function dumpEnv(redact = true): Record<string, string> {
  const dump: Record<string, string> = {};
  const sensitiveKeys = ['KEY', 'TOKEN', 'SECRET', 'PASSWORD', 'CREDENTIAL'];
  
  for (const [key, value] of Object.entries(env)) {
    if (redact && sensitiveKeys.some(s => key.includes(s))) {
      dump[key] = value ? '[REDACTED]' : '[NOT SET]';
    } else {
      dump[key] = String(value ?? '[NOT SET]');
    }
  }
  
  return dump;
}
```

#### Migration Script

```typescript
// scripts/migrate-env-access.ts

/**
 * Finds all direct process.env accesses and generates migration report
 */

import * as ts from 'typescript';
import * as fs from 'fs';
import * as path from 'path';
import { glob } from 'glob';

interface EnvAccess {
  file: string;
  line: number;
  column: number;
  code: string;
  envVar: string;
}

async function findEnvAccesses(): Promise<EnvAccess[]> {
  const files = await glob('src/**/*.ts', { ignore: ['**/node_modules/**'] });
  const accesses: EnvAccess[] = [];
  
  for (const file of files) {
    const content = fs.readFileSync(file, 'utf-8');
    const sourceFile = ts.createSourceFile(
      file,
      content,
      ts.ScriptTarget.Latest,
      true
    );
    
    function visit(node: ts.Node) {
      if (
        ts.isPropertyAccessExpression(node) &&
        ts.isPropertyAccessExpression(node.expression) &&
        node.expression.expression.getText() === 'process' &&
        node.expression.name.getText() === 'env'
      ) {
        const { line, character } = sourceFile.getLineAndCharacterOfPosition(
          node.getStart()
        );
        
        accesses.push({
          file,
          line: line + 1,
          column: character + 1,
          code: node.getText(),
          envVar: node.name.getText(),
        });
      }
      
      ts.forEachChild(node, visit);
    }
    
    visit(sourceFile);
  }
  
  return accesses;
}

async function generateMigrationReport(): Promise<void> {
  const accesses = await findEnvAccesses();
  
  console.log(`Found ${accesses.length} direct process.env accesses\n`);
  
  // Group by env var
  const byVar = new Map<string, EnvAccess[]>();
  for (const access of accesses) {
    const list = byVar.get(access.envVar) ?? [];
    list.push(access);
    byVar.set(access.envVar, list);
  }
  
  console.log('Environment variables to migrate:');
  for (const [envVar, usages] of byVar) {
    console.log(`\n${envVar} (${usages.length} usages):`);
    for (const usage of usages.slice(0, 5)) {
      console.log(`  ${usage.file}:${usage.line}`);
    }
    if (usages.length > 5) {
      console.log(`  ... and ${usages.length - 5} more`);
    }
  }
}

generateMigrationReport();
```

#### ESLint Rule

```javascript
// eslint-rules/no-direct-env.js

module.exports = {
  meta: {
    type: 'problem',
    docs: {
      description: 'Disallow direct process.env access',
    },
    messages: {
      noDirectEnv: 'Use env from src/config/env.ts instead of process.env.{{name}}',
    },
  },
  create(context) {
    return {
      MemberExpression(node) {
        if (
          node.object.type === 'MemberExpression' &&
          node.object.object.name === 'process' &&
          node.object.property.name === 'env'
        ) {
          context.report({
            node,
            messageId: 'noDirectEnv',
            data: { name: node.property.name },
          });
        }
      },
    };
  },
};
```

---

### Solution 5.4: Enhanced Logging Infrastructure

**Addresses**: Issue 5.4 - Enhanced Logging Infrastructure  
**Priority**: P2  
**Effort**: Medium (1-2 sprints)

#### Implementation

```typescript
// src/logging/structured-logger.ts

import { Logger } from 'tslog';
import { redactSensitiveText } from './redact';

// ============================================================
// STRUCTURED LOG ENTRY
// ============================================================

interface LogEntry {
  timestamp: string;
  level: 'debug' | 'info' | 'warn' | 'error';
  message: string;
  module: string;
  context?: Record<string, unknown>;
  error?: {
    name: string;
    message: string;
    stack?: string;
  };
  duration?: number;
  requestId?: string;
}

// ============================================================
// LOGGER FACTORY
// ============================================================

interface LoggerOptions {
  module: string;
  redact?: boolean;
  json?: boolean;
}

export function createLogger(options: LoggerOptions) {
  const { module, redact = true, json = false } = options;
  
  const baseLogger = new Logger({
    name: module,
    type: json ? 'json' : 'pretty',
    minLevel: getMinLevel(),
  });
  
  const log = (
    level: LogEntry['level'],
    message: string,
    context?: Record<string, unknown>
  ) => {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level,
      message: redact ? redactSensitiveText(message) : message,
      module,
      context: context ? (redact ? redactContext(context) : context) : undefined,
    };
    
    if (json) {
      console[level](JSON.stringify(entry));
    } else {
      baseLogger[level](entry.message, entry.context);
    }
  };
  
  return {
    debug: (message: string, context?: Record<string, unknown>) => 
      log('debug', message, context),
    info: (message: string, context?: Record<string, unknown>) => 
      log('info', message, context),
    warn: (message: string, context?: Record<string, unknown>) => 
      log('warn', message, context),
    error: (message: string, error?: Error, context?: Record<string, unknown>) => {
      const entry: LogEntry = {
        timestamp: new Date().toISOString(),
        level: 'error',
        message: redact ? redactSensitiveText(message) : message,
        module,
        context: context ? (redact ? redactContext(context) : context) : undefined,
        error: error ? {
          name: error.name,
          message: redact ? redactSensitiveText(error.message) : error.message,
          stack: error.stack,
        } : undefined,
      };
      
      if (json) {
        console.error(JSON.stringify(entry));
      } else {
        baseLogger.error(entry.message, entry.error, entry.context);
      }
    },
    
    // Performance tracking
    time: (label: string) => {
      const start = performance.now();
      return {
        end: (context?: Record<string, unknown>) => {
          const duration = performance.now() - start;
          log('debug', `${label} completed`, { ...context, duration });
          return duration;
        },
      };
    },
  };
}

function redactContext(context: Record<string, unknown>): Record<string, unknown> {
  return JSON.parse(redactSensitiveText(JSON.stringify(context)));
}

function getMinLevel(): number {
  const level = process.env.LOG_LEVEL ?? 'info';
  const levels: Record<string, number> = {
    debug: 0,
    info: 1,
    warn: 2,
    error: 3,
  };
  return levels[level] ?? 1;
}

// ============================================================
// AUDIT LOGGER
// ============================================================

interface AuditEntry {
  timestamp: string;
  action: string;
  actor: string;
  resource: string;
  result: 'success' | 'failure';
  metadata?: Record<string, unknown>;
  ip?: string;
}

export function createAuditLogger(module: string) {
  const logger = createLogger({ module: `audit:${module}`, json: true, redact: true });
  
  return {
    log: (entry: Omit<AuditEntry, 'timestamp'>) => {
      const fullEntry: AuditEntry = {
        ...entry,
        timestamp: new Date().toISOString(),
      };
      logger.info('AUDIT', fullEntry as unknown as Record<string, unknown>);
    },
  };
}

// ============================================================
// REQUEST LOGGER MIDDLEWARE
// ============================================================

export function requestLogger(module: string) {
  const logger = createLogger({ module });
  
  return async (c: Context, next: Next) => {
    const requestId = crypto.randomUUID();
    const start = performance.now();
    
    logger.info('Request started', {
      requestId,
      method: c.req.method,
      path: c.req.path,
    });
    
    try {
      await next();
      
      logger.info('Request completed', {
        requestId,
        status: c.res.status,
        duration: performance.now() - start,
      });
    } catch (error) {
      logger.error('Request failed', error as Error, {
        requestId,
        duration: performance.now() - start,
      });
      throw error;
    }
  };
}
```

---

### Solution 5.5: Enhanced Health Checks

**Addresses**: Issue 5.5 - Health Check Enhancements  
**Priority**: P2  
**Effort**: Medium (1 sprint)

#### Implementation

```typescript
// src/health/health-check.ts

import { z } from 'zod';

// ============================================================
// HEALTH CHECK TYPES
// ============================================================

type HealthStatus = 'healthy' | 'degraded' | 'unhealthy';

interface ComponentHealth {
  status: HealthStatus;
  message?: string;
  latency?: number;
  lastCheck: string;
}

interface HealthCheckResponse {
  status: HealthStatus;
  timestamp: string;
  version: string;
  uptime: number;
  
  components: {
    gateway: ComponentHealth;
    channels: Record<string, ComponentHealth>;
    providers: Record<string, ComponentHealth>;
  };
  
  resources: {
    memory: {
      used: number;
      total: number;
      percentage: number;
    };
    disk?: {
      used: number;
      total: number;
      percentage: number;
    };
  };
  
  metrics?: {
    requestsPerMinute: number;
    averageLatency: number;
    errorRate: number;
  };
}

// ============================================================
// HEALTH CHECK IMPLEMENTATION
// ============================================================

class HealthChecker {
  private startTime = Date.now();
  private checks: Map<string, () => Promise<ComponentHealth>> = new Map();
  
  registerCheck(name: string, check: () => Promise<ComponentHealth>): void {
    this.checks.set(name, check);
  }
  
  async runChecks(): Promise<HealthCheckResponse> {
    const results: Record<string, ComponentHealth> = {};
    let overallStatus: HealthStatus = 'healthy';
    
    // Run all checks in parallel
    const checkPromises = Array.from(this.checks.entries()).map(
      async ([name, check]) => {
        const start = performance.now();
        try {
          const result = await Promise.race([
            check(),
            new Promise<ComponentHealth>((_, reject) => 
              setTimeout(() => reject(new Error('Timeout')), 5000)
            ),
          ]);
          results[name] = {
            ...result,
            latency: performance.now() - start,
            lastCheck: new Date().toISOString(),
          };
        } catch (error) {
          results[name] = {
            status: 'unhealthy',
            message: error instanceof Error ? error.message : 'Check failed',
            latency: performance.now() - start,
            lastCheck: new Date().toISOString(),
          };
        }
      }
    );
    
    await Promise.all(checkPromises);
    
    // Calculate overall status
    for (const result of Object.values(results)) {
      if (result.status === 'unhealthy') {
        overallStatus = 'unhealthy';
        break;
      }
      if (result.status === 'degraded') {
        overallStatus = 'degraded';
      }
    }
    
    // Get resource usage
    const memUsage = process.memoryUsage();
    
    return {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version ?? 'unknown',
      uptime: Date.now() - this.startTime,
      
      components: {
        gateway: results.gateway ?? { status: 'unhealthy', lastCheck: new Date().toISOString() },
        channels: this.filterByPrefix(results, 'channel:'),
        providers: this.filterByPrefix(results, 'provider:'),
      },
      
      resources: {
        memory: {
          used: memUsage.heapUsed,
          total: memUsage.heapTotal,
          percentage: Math.round((memUsage.heapUsed / memUsage.heapTotal) * 100),
        },
      },
    };
  }
  
  private filterByPrefix(
    results: Record<string, ComponentHealth>,
    prefix: string
  ): Record<string, ComponentHealth> {
    const filtered: Record<string, ComponentHealth> = {};
    for (const [key, value] of Object.entries(results)) {
      if (key.startsWith(prefix)) {
        filtered[key.slice(prefix.length)] = value;
      }
    }
    return filtered;
  }
}

// ============================================================
// HEALTH CHECK REGISTRY
// ============================================================

export const healthChecker = new HealthChecker();

// Register default checks
healthChecker.registerCheck('gateway', async () => {
  // Check gateway is responding
  return { status: 'healthy', lastCheck: new Date().toISOString() };
});

// Provider health check factory
export function registerProviderCheck(
  name: string,
  checkFn: () => Promise<boolean>
): void {
  healthChecker.registerCheck(`provider:${name}`, async () => {
    try {
      const isHealthy = await checkFn();
      return {
        status: isHealthy ? 'healthy' : 'degraded',
        lastCheck: new Date().toISOString(),
      };
    } catch {
      return {
        status: 'unhealthy',
        lastCheck: new Date().toISOString(),
      };
    }
  });
}

// Channel health check factory
export function registerChannelCheck(
  name: string,
  checkFn: () => Promise<boolean>
): void {
  healthChecker.registerCheck(`channel:${name}`, async () => {
    try {
      const isHealthy = await checkFn();
      return {
        status: isHealthy ? 'healthy' : 'degraded',
        lastCheck: new Date().toISOString(),
      };
    } catch {
      return {
        status: 'unhealthy',
        lastCheck: new Date().toISOString(),
      };
    }
  });
}
```

---

### Solution 5.6: Documentation Generation

**Addresses**: Issue 5.6 - Documentation Generation  
**Priority**: P3  
**Effort**: Medium (1 sprint)

#### Implementation

```typescript
// scripts/generate-docs.ts

/**
 * Generates documentation from:
 * 1. TypeScript types
 * 2. Zod schemas
 * 3. CLI command definitions
 * 4. Configuration schemas
 */

import { z } from 'zod';
import * as ts from 'typescript';

// Generate Markdown from Zod schema
function zodToMarkdown(schema: z.ZodType, name: string): string {
  let md = `## ${name}\n\n`;
  
  if (schema instanceof z.ZodObject) {
    md += '| Field | Type | Required | Description |\n';
    md += '|-------|------|----------|-------------|\n';
    
    const shape = schema.shape;
    for (const [key, value] of Object.entries(shape)) {
      const zodValue = value as z.ZodType;
      const isOptional = zodValue.isOptional();
      const description = zodValue.description ?? '';
      const type = getZodTypeName(zodValue);
      
      md += `| \`${key}\` | ${type} | ${isOptional ? 'No' : 'Yes'} | ${description} |\n`;
    }
  }
  
  return md;
}

function getZodTypeName(schema: z.ZodType): string {
  if (schema instanceof z.ZodString) return 'string';
  if (schema instanceof z.ZodNumber) return 'number';
  if (schema instanceof z.ZodBoolean) return 'boolean';
  if (schema instanceof z.ZodArray) return `${getZodTypeName(schema.element)}[]`;
  if (schema instanceof z.ZodOptional) return getZodTypeName(schema.unwrap());
  if (schema instanceof z.ZodEnum) return schema.options.map(o => `\`${o}\``).join(' | ');
  return 'unknown';
}

// Usage:
// const docs = zodToMarkdown(MoltbotConfigSchema, 'MoltbotConfig');
// fs.writeFileSync('docs/config-reference.md', docs);
```

---

### Solution 5.7: Performance Monitoring

**Addresses**: Issue 5.7 - Performance Monitoring  
**Priority**: P2  
**Effort**: Medium (1-2 sprints)

#### Implementation

```typescript
// src/metrics/performance.ts

// ============================================================
// METRICS COLLECTOR
// ============================================================

interface Metric {
  name: string;
  value: number;
  timestamp: number;
  tags: Record<string, string>;
}

class MetricsCollector {
  private metrics: Metric[] = [];
  private histograms: Map<string, number[]> = new Map();
  
  // Counter
  increment(name: string, tags: Record<string, string> = {}, value = 1): void {
    this.metrics.push({
      name,
      value,
      timestamp: Date.now(),
      tags,
    });
  }
  
  // Gauge
  gauge(name: string, value: number, tags: Record<string, string> = {}): void {
    this.metrics.push({
      name,
      value,
      timestamp: Date.now(),
      tags,
    });
  }
  
  // Histogram
  histogram(name: string, value: number, tags: Record<string, string> = {}): void {
    const key = `${name}:${JSON.stringify(tags)}`;
    const values = this.histograms.get(key) ?? [];
    values.push(value);
    this.histograms.set(key, values);
    
    // Also record as gauge for current value
    this.gauge(name, value, tags);
  }
  
  // Timer helper
  timer(name: string, tags: Record<string, string> = {}) {
    const start = performance.now();
    return {
      end: () => {
        const duration = performance.now() - start;
        this.histogram(name, duration, tags);
        return duration;
      },
    };
  }
  
  // Get percentiles for histogram
  getPercentiles(name: string, percentiles: number[] = [50, 90, 95, 99]): Record<string, number> {
    const values = this.histograms.get(name) ?? [];
    if (values.length === 0) return {};
    
    const sorted = [...values].sort((a, b) => a - b);
    const result: Record<string, number> = {};
    
    for (const p of percentiles) {
      const index = Math.ceil((p / 100) * sorted.length) - 1;
      result[`p${p}`] = sorted[index];
    }
    
    return result;
  }
  
  // Get summary
  getSummary(): Record<string, unknown> {
    const summary: Record<string, unknown> = {};
    
    for (const [key, values] of this.histograms) {
      summary[key] = {
        count: values.length,
        min: Math.min(...values),
        max: Math.max(...values),
        avg: values.reduce((a, b) => a + b, 0) / values.length,
        ...this.getPercentiles(key),
      };
    }
    
    return summary;
  }
}

export const metrics = new MetricsCollector();

// ============================================================
// DECORATOR FOR PERFORMANCE TRACKING
// ============================================================

export function trackPerformance(metricName: string) {
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor
  ) {
    const originalMethod = descriptor.value;
    
    descriptor.value = async function (...args: any[]) {
      const timer = metrics.timer(metricName, { method: propertyKey });
      try {
        const result = await originalMethod.apply(this, args);
        metrics.increment(`${metricName}.success`);
        return result;
      } catch (error) {
        metrics.increment(`${metricName}.error`);
        throw error;
      } finally {
        timer.end();
      }
    };
    
    return descriptor;
  };
}

// ============================================================
// SPECIFIC METRICS
// ============================================================

// LLM call tracking
export function trackLLMCall(provider: string, model: string, tokens: number, duration: number): void {
  metrics.histogram('llm.latency', duration, { provider, model });
  metrics.increment('llm.calls', { provider, model });
  metrics.increment('llm.tokens', { provider, model }, tokens);
}

// Message processing tracking
export function trackMessage(channel: string, duration: number): void {
  metrics.histogram('message.latency', duration, { channel });
  metrics.increment('message.count', { channel });
}

// Tool execution tracking
export function trackToolExecution(tool: string, duration: number, success: boolean): void {
  metrics.histogram('tool.latency', duration, { tool });
  metrics.increment('tool.count', { tool, result: success ? 'success' : 'error' });
}
```

---

## Implementation Roadmap

### Sprint 1: Core Infrastructure
- [ ] Centralized environment configuration
- [ ] Enhanced logging
- [ ] Basic metrics collection

### Sprint 2: Health & Monitoring
- [ ] Enhanced health checks
- [ ] Performance monitoring integration
- [ ] Alerting hooks

### Sprint 3: Developer Experience
- [ ] Documentation generation
- [ ] ESLint rules for env access
- [ ] Migration tooling

---

## Success Criteria

| Improvement | Metric | Target |
|-------------|--------|--------|
| Env centralization | Direct process.env usage | 0 |
| Logging | Structured log coverage | 100% |
| Health checks | Component coverage | All components |
| Performance | Tracked operations | LLM, Messages, Tools |

---

**Document Maintainer**: Development Team  
**Last Updated**: 2026-01-28
