# SPEC-SOLUTION 1.0: Security Vulnerability Remediation

**Document ID**: SPEC-SOLUTION-1.0  
**Addresses**: SPEC-ISSUES-1.0  
**Category**: Security  
**Priority**: P0 (Critical)  
**Date Created**: 2026-01-28  
**Status**: Draft

---

## Executive Summary

This document provides solutions for the security vulnerabilities identified in SPEC-ISSUES-1.0. Solutions are organized by priority and include implementation details, code examples, and testing requirements.

---

## Solution Registry

### Solution 1.1: Command Execution Security Hardening

**Addresses**: Issue 1.1 - Command Execution Attack Surface  
**Priority**: P0  
**Effort**: High (2-3 sprints)

#### Objective

Reduce command execution attack surface from 84 files to a centralized, audited execution layer.

#### Implementation Plan

##### Phase 1: Audit and Categorize (Sprint 1)

1. **Create execution inventory**
   ```typescript
   // scripts/audit-exec.ts
   // Generate report of all child_process usage
   interface ExecUsage {
     file: string;
     line: number;
     method: 'exec' | 'execFile' | 'spawn' | 'spawnSync' | 'execSync';
     commandSource: 'static' | 'config' | 'user-input' | 'unknown';
     riskLevel: 'low' | 'medium' | 'high' | 'critical';
   }
   ```

2. **Risk categorization criteria**
   | Risk Level | Criteria |
   |------------|----------|
   | Critical | User input reaches command string |
   | High | Dynamic command construction |
   | Medium | Config-driven commands |
   | Low | Static, hardcoded commands |

##### Phase 2: Centralized Execution Layer (Sprint 1-2)

```typescript
// src/process/secure-exec.ts

import { spawn, SpawnOptions } from 'child_process';
import { z } from 'zod';

// Strict command schema
const CommandSchema = z.object({
  binary: z.string().regex(/^[a-zA-Z0-9_\-./]+$/),
  args: z.array(z.string()),
  cwd: z.string().optional(),
  timeout: z.number().max(300_000).default(30_000),
  allowNetwork: z.boolean().default(false),
});

type SecureCommand = z.infer<typeof CommandSchema>;

// Allowlist of permitted binaries
const ALLOWED_BINARIES = new Set([
  // Core system
  'node', 'npm', 'npx', 'pnpm', 'bun',
  // Git operations
  'git',
  // File operations
  'ls', 'cat', 'head', 'tail', 'grep', 'find',
  // Network (when explicitly allowed)
  'curl', 'wget',
  // Custom tools
  'moltbot', 'moltbot-mac',
]);

// Blocked argument patterns
const BLOCKED_PATTERNS = [
  /\|\s*(ba)?sh\b/,       // Pipe to shell
  /;\s*rm\s+-rf/,         // Destructive chains
  /`.*`/,                  // Command substitution
  /\$\(.*\)/,             // Command substitution
  />\s*\/etc\//,          // Write to system dirs
  />\s*\/usr\//,
];

export async function secureExec(
  command: SecureCommand,
  context: ExecutionContext
): Promise<ExecResult> {
  // 1. Validate schema
  const validated = CommandSchema.parse(command);
  
  // 2. Check binary allowlist
  const binaryName = path.basename(validated.binary);
  if (!ALLOWED_BINARIES.has(binaryName)) {
    throw new SecurityError(`Binary not allowed: ${binaryName}`);
  }
  
  // 3. Check argument patterns
  const fullCommand = [validated.binary, ...validated.args].join(' ');
  for (const pattern of BLOCKED_PATTERNS) {
    if (pattern.test(fullCommand)) {
      throw new SecurityError(`Blocked pattern detected: ${pattern.source}`);
    }
  }
  
  // 4. Audit log
  await auditLog({
    action: 'exec',
    command: validated.binary,
    args: validated.args,
    actor: context.actor,
    timestamp: new Date().toISOString(),
  });
  
  // 5. Execute with constraints
  return executeWithSandbox(validated, context);
}

async function executeWithSandbox(
  command: SecureCommand,
  context: ExecutionContext
): Promise<ExecResult> {
  const child = spawn(command.binary, command.args, {
    cwd: command.cwd,
    timeout: command.timeout,
    env: sanitizeEnv(process.env),
    // Prevent shell interpretation
    shell: false,
    // Resource limits
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  
  // ... handle output, timeout, etc.
}

function sanitizeEnv(env: NodeJS.ProcessEnv): NodeJS.ProcessEnv {
  // Remove sensitive variables from child process environment
  const sanitized = { ...env };
  const sensitiveKeys = [
    'ANTHROPIC_API_KEY',
    'OPENAI_API_KEY',
    'AWS_SECRET_ACCESS_KEY',
    // ... other sensitive keys
  ];
  for (const key of sensitiveKeys) {
    delete sanitized[key];
  }
  return sanitized;
}
```

##### Phase 3: Migration (Sprint 2-3)

1. **Create migration guide** for each usage category
2. **Deprecate direct child_process imports**
3. **Add ESLint rule to prevent new direct usage**

```javascript
// .eslintrc.js addition
{
  rules: {
    'no-restricted-imports': ['error', {
      paths: [{
        name: 'child_process',
        message: 'Use src/process/secure-exec.ts instead'
      }]
    }]
  }
}
```

#### Testing Requirements

```typescript
// src/process/secure-exec.test.ts

describe('secureExec', () => {
  describe('binary allowlist', () => {
    it('allows permitted binaries', async () => {
      await expect(secureExec({ binary: 'ls', args: ['-la'] }, ctx))
        .resolves.toBeDefined();
    });
    
    it('blocks non-allowed binaries', async () => {
      await expect(secureExec({ binary: 'evil', args: [] }, ctx))
        .rejects.toThrow('Binary not allowed');
    });
  });
  
  describe('argument filtering', () => {
    it('blocks shell pipes', async () => {
      await expect(secureExec({ binary: 'cat', args: ['file', '|', 'sh'] }, ctx))
        .rejects.toThrow('Blocked pattern');
    });
    
    it('blocks command substitution', async () => {
      await expect(secureExec({ binary: 'echo', args: ['$(rm -rf /)'] }, ctx))
        .rejects.toThrow('Blocked pattern');
    });
  });
  
  describe('audit logging', () => {
    it('logs all execution attempts', async () => {
      await secureExec({ binary: 'ls', args: [] }, ctx);
      expect(auditLog).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'exec', command: 'ls' })
      );
    });
  });
});
```

#### Success Criteria

- [ ] All 84 files migrated to secure-exec
- [ ] 100% test coverage on security-critical paths
- [ ] Zero direct child_process imports outside secure-exec
- [ ] Audit logging for all command executions
- [ ] ESLint rule preventing new direct usage

---

### Solution 1.2: CORS Implementation

**Addresses**: Issue 1.2 - Missing CORS Configuration  
**Priority**: P2  
**Effort**: Low (1-2 days)

#### Implementation

```typescript
// src/gateway/middleware/cors.ts

import { Context, Next } from 'hono';
import { MoltbotConfig } from '../../config/types';

interface CorsConfig {
  enabled: boolean;
  allowedOrigins: string[];
  allowCredentials: boolean;
  maxAge: number;
}

const DEFAULT_CORS_CONFIG: CorsConfig = {
  enabled: false,
  allowedOrigins: [],
  allowCredentials: true,
  maxAge: 86400,
};

export function corsMiddleware(config: MoltbotConfig) {
  const corsConfig: CorsConfig = {
    ...DEFAULT_CORS_CONFIG,
    ...config.gateway?.cors,
  };
  
  return async (c: Context, next: Next) => {
    const origin = c.req.header('Origin');
    
    // No CORS headers needed for same-origin
    if (!origin) {
      return next();
    }
    
    // Check if origin is allowed
    const isAllowed = isOriginAllowed(origin, corsConfig);
    
    if (!isAllowed) {
      // Don't add CORS headers for disallowed origins
      return next();
    }
    
    // Handle preflight
    if (c.req.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: getCorsHeaders(origin, corsConfig),
      });
    }
    
    // Add CORS headers to response
    const response = await next();
    const headers = getCorsHeaders(origin, corsConfig);
    for (const [key, value] of Object.entries(headers)) {
      c.header(key, value);
    }
    
    return response;
  };
}

function isOriginAllowed(origin: string, config: CorsConfig): boolean {
  // Always allow Tailscale origins for remote access
  if (origin.endsWith('.ts.net')) {
    return true;
  }
  
  // Check explicit allowlist
  return config.allowedOrigins.some(allowed => {
    if (allowed === '*') return true;
    if (allowed.startsWith('*.')) {
      const domain = allowed.slice(2);
      return origin.endsWith(domain);
    }
    return origin === allowed;
  });
}

function getCorsHeaders(origin: string, config: CorsConfig): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With',
    'Access-Control-Allow-Credentials': config.allowCredentials ? 'true' : 'false',
    'Access-Control-Max-Age': String(config.maxAge),
    'Access-Control-Expose-Headers': 'X-RateLimit-Remaining, X-RateLimit-Reset',
  };
}
```

#### Configuration Schema Addition

```typescript
// Add to src/config/zod-schema.gateway.ts

const CorsSchema = z.object({
  enabled: z.boolean().default(false),
  allowedOrigins: z.array(z.string()).default([]),
  allowCredentials: z.boolean().default(true),
  maxAge: z.number().default(86400),
}).optional();

// In gateway config
gateway: z.object({
  // ... existing fields
  cors: CorsSchema,
})
```

#### Success Criteria

- [ ] CORS middleware implemented and tested
- [ ] Configuration schema updated
- [ ] Documentation added
- [ ] Tailscale origins automatically allowed

---

### Solution 1.3: Enhanced Sensitive Data Redaction

**Addresses**: Issue 1.3 - Sensitive Data in Logs  
**Priority**: P1  
**Effort**: Medium (1 sprint)

#### Implementation

##### 1. Make redaction opt-out instead of opt-in

```typescript
// src/logging/redact.ts - Enhanced

export interface RedactConfig {
  mode: 'strict' | 'normal' | 'disabled';
  additionalPatterns?: RegExp[];
  excludeFields?: string[];
}

// Default to strict mode
const DEFAULT_REDACT_CONFIG: RedactConfig = {
  mode: 'strict',
};

// Enhance logging to always redact by default
export function createLogger(name: string, config?: Partial<RedactConfig>) {
  const redactConfig = { ...DEFAULT_REDACT_CONFIG, ...config };
  
  return new Logger({
    name,
    // Redact all output unless explicitly disabled
    maskAny: redactConfig.mode !== 'disabled',
    maskValuesOfKeys: SENSITIVE_KEYS,
    // ... other config
  });
}
```

##### 2. Add comprehensive pattern coverage

```typescript
// Additional patterns for src/logging/redact.ts

const ADDITIONAL_REDACT_PATTERNS = [
  // Webhook secrets
  String.raw`webhook[_-]?secret\s*[=:]\s*["']?([^"'\s]+)["']?`,
  
  // Database connection strings
  String.raw`(postgres|mysql|mongodb):\/\/[^:]+:([^@]+)@`,
  
  // SSH private keys (full block)
  String.raw`-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]+?-----END [A-Z ]*PRIVATE KEY-----`,
  
  // JWT tokens
  String.raw`eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+`,
  
  // Session tokens
  String.raw`session[_-]?token\s*[=:]\s*["']?([A-Za-z0-9_-]{20,})["']?`,
  
  // Slack tokens
  String.raw`xox[baprs]-[A-Za-z0-9-]+`,
  
  // Telegram tokens
  String.raw`\d{8,10}:[A-Za-z0-9_-]{35}`,
  
  // Discord tokens
  String.raw`[MN][A-Za-z\d]{23,}\.[\w-]{6}\.[\w-]{27}`,
];
```

##### 3. Enforce redaction at logging boundaries

```typescript
// src/logging/enforced-logger.ts

import { redactSensitiveText } from './redact';

type LogMethod = (...args: unknown[]) => void;

function wrapLogMethod(method: LogMethod): LogMethod {
  return (...args: unknown[]) => {
    const redactedArgs = args.map(arg => {
      if (typeof arg === 'string') {
        return redactSensitiveText(arg);
      }
      if (typeof arg === 'object' && arg !== null) {
        return JSON.parse(redactSensitiveText(JSON.stringify(arg)));
      }
      return arg;
    });
    return method(...redactedArgs);
  };
}

export function createEnforcedLogger(baseLogger: Logger): Logger {
  return {
    ...baseLogger,
    info: wrapLogMethod(baseLogger.info.bind(baseLogger)),
    warn: wrapLogMethod(baseLogger.warn.bind(baseLogger)),
    error: wrapLogMethod(baseLogger.error.bind(baseLogger)),
    debug: wrapLogMethod(baseLogger.debug.bind(baseLogger)),
  };
}
```

#### Testing Requirements

```typescript
describe('enhanced redaction', () => {
  it('redacts JWT tokens', () => {
    const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U';
    expect(redactSensitiveText(jwt)).not.toContain('eyJ');
  });
  
  it('redacts Slack tokens', () => {
    const token = 'xoxb-FAKE-TOKEN-FOR-TESTING-ONLY';
    expect(redactSensitiveText(token)).toMatch(/\[REDACTED.*\]/);
  });
  
  it('redacts database connection strings', () => {
    const connStr = 'postgres://user:secretpassword@host:5432/db';
    expect(redactSensitiveText(connStr)).not.toContain('secretpassword');
  });
});
```

#### Success Criteria

- [ ] Redaction is opt-out by default
- [ ] All known token formats covered
- [ ] Database connection strings redacted
- [ ] Logging wrapper enforces redaction
- [ ] Test coverage for all patterns

---

### Solution 1.4: innerHTML Security

**Addresses**: Issue 1.4 - innerHTML Usage  
**Priority**: P2  
**Effort**: Low (2-3 days)

#### Implementation

1. **Audit current usage** in `src/browser/cdp.ts` and `src/canvas-host/server.ts`
2. **Add content sanitization** for any user-controlled content

```typescript
// src/security/html-sanitize.ts

import DOMPurify from 'dompurify';
import { JSDOM } from 'jsdom';

const window = new JSDOM('').window;
const purify = DOMPurify(window);

export function sanitizeHtml(html: string): string {
  return purify.sanitize(html, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br', 'ul', 'ol', 'li', 'code', 'pre'],
    ALLOWED_ATTR: ['href', 'class'],
    ALLOW_DATA_ATTR: false,
  });
}

// For canvas content that needs more flexibility
export function sanitizeCanvasHtml(html: string): string {
  return purify.sanitize(html, {
    ALLOWED_TAGS: ['div', 'span', 'p', 'img', 'svg', 'path', 'g', 'text'],
    ALLOWED_ATTR: ['class', 'style', 'src', 'alt', 'd', 'fill', 'stroke', 'viewBox'],
    FORBID_TAGS: ['script', 'iframe', 'object', 'embed', 'form', 'input'],
    FORBID_ATTR: ['onclick', 'onerror', 'onload'],
  });
}
```

#### Success Criteria

- [ ] All innerHTML usage audited
- [ ] DOMPurify integrated for user content
- [ ] Tests for XSS prevention

---

### Solution 1.5: Centralized Environment Variable Management

**Addresses**: Issue 1.5 - Environment Variable Exposure  
**Priority**: P2  
**Effort**: High (2-3 sprints)

#### Implementation

See detailed implementation in **SPEC-SOLUTION-5.0** (Section 5.3).

#### Key Steps

1. Create centralized `src/config/env.ts` with Zod schema
2. Migrate all 1,728 `process.env` accesses
3. Add ESLint rule to prevent direct access
4. Startup validation for all required env vars

---

### Solution 1.6: Comprehensive Rate Limiting

**Addresses**: Issue 1.6 - Rate Limiting Gaps  
**Priority**: P1  
**Effort**: Medium (1-2 sprints)

#### Implementation

```typescript
// src/gateway/middleware/rate-limit.ts

import { Context, Next } from 'hono';

interface RateLimitConfig {
  windowMs: number;
  max: number;
  keyGenerator: (c: Context) => string;
  skip?: (c: Context) => boolean;
}

interface RateLimitStore {
  hits: Map<string, { count: number; resetTime: number }>;
}

export function rateLimitMiddleware(config: RateLimitConfig) {
  const store: RateLimitStore = { hits: new Map() };
  
  // Cleanup expired entries periodically
  setInterval(() => {
    const now = Date.now();
    for (const [key, value] of store.hits) {
      if (value.resetTime < now) {
        store.hits.delete(key);
      }
    }
  }, config.windowMs);
  
  return async (c: Context, next: Next) => {
    // Check skip condition
    if (config.skip?.(c)) {
      return next();
    }
    
    const key = config.keyGenerator(c);
    const now = Date.now();
    
    let entry = store.hits.get(key);
    
    if (!entry || entry.resetTime < now) {
      entry = { count: 0, resetTime: now + config.windowMs };
      store.hits.set(key, entry);
    }
    
    entry.count++;
    
    // Set rate limit headers
    c.header('X-RateLimit-Limit', String(config.max));
    c.header('X-RateLimit-Remaining', String(Math.max(0, config.max - entry.count)));
    c.header('X-RateLimit-Reset', String(Math.ceil(entry.resetTime / 1000)));
    
    if (entry.count > config.max) {
      c.header('Retry-After', String(Math.ceil((entry.resetTime - now) / 1000)));
      return c.json({ error: 'Too many requests' }, 429);
    }
    
    return next();
  };
}

// Endpoint-specific rate limits
export const RATE_LIMITS = {
  // Chat messages: 10 per second
  chat: { windowMs: 1000, max: 10 },
  
  // Command execution: 5 per minute
  exec: { windowMs: 60_000, max: 5 },
  
  // Model calls: 30 per minute
  models: { windowMs: 60_000, max: 30 },
  
  // WebSocket connections: 5 per minute per IP
  websocket: { windowMs: 60_000, max: 5 },
  
  // API general: 100 per minute
  api: { windowMs: 60_000, max: 100 },
};
```

#### Gateway Integration

```typescript
// src/gateway/server.ts

import { rateLimitMiddleware, RATE_LIMITS } from './middleware/rate-limit';

// Apply rate limiting to specific endpoints
app.use('/api/chat/*', rateLimitMiddleware({
  ...RATE_LIMITS.chat,
  keyGenerator: (c) => `${c.req.header('x-forwarded-for') || 'unknown'}:chat`,
}));

app.use('/api/exec/*', rateLimitMiddleware({
  ...RATE_LIMITS.exec,
  keyGenerator: (c) => `${c.req.header('x-forwarded-for') || 'unknown'}:exec`,
}));

// Global rate limit
app.use('/api/*', rateLimitMiddleware({
  ...RATE_LIMITS.api,
  keyGenerator: (c) => c.req.header('x-forwarded-for') || 'unknown',
}));
```

#### Success Criteria

- [ ] Rate limiting on all gateway endpoints
- [ ] WebSocket connection rate limiting
- [ ] Per-endpoint configurable limits
- [ ] Rate limit headers in responses
- [ ] Bypass for internal/authenticated requests

---

## Implementation Roadmap

### Sprint 1: Foundation
- [ ] Command execution audit
- [ ] Secure-exec layer design
- [ ] Rate limiting implementation

### Sprint 2: Core Security
- [ ] Secure-exec implementation
- [ ] Start migration of critical files
- [ ] CORS implementation

### Sprint 3: Hardening
- [ ] Complete secure-exec migration
- [ ] Enhanced redaction
- [ ] innerHTML sanitization
- [ ] ESLint rules

### Sprint 4: Validation
- [ ] Security testing
- [ ] Penetration testing
- [ ] Documentation updates

---

## Dependencies

| Solution | Depends On | Blocks |
|----------|------------|--------|
| 1.1 Secure-exec | - | 2.x Command Injection |
| 1.2 CORS | - | Remote access features |
| 1.3 Redaction | - | - |
| 1.6 Rate Limiting | - | Production deployment |

---

**Document Maintainer**: Security Team  
**Last Updated**: 2026-01-28
