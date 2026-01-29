# SPEC-SOLUTION 3.0: Form & Input Validation Framework

**Document ID**: SPEC-SOLUTION-3.0  
**Addresses**: SPEC-ISSUES-3.0  
**Category**: Form & Input Validation  
**Priority**: P1 (Important)  
**Date Created**: 2026-01-28  
**Status**: Draft

---

## Executive Summary

This document provides solutions for standardizing input validation across the Moltbot codebase using Zod schemas and centralized validation utilities.

---

## Solution Registry

### Solution 3.1: Centralized Validation Library

**Addresses**: Issue 3.1 - Inconsistent Input Validation Patterns  
**Priority**: P1  
**Effort**: Medium (1-2 sprints)

#### Implementation

```typescript
// src/validation/index.ts

import { z, ZodError, ZodType } from 'zod';

// ============================================================
// COMMON SCHEMAS
// ============================================================

export const schemas = {
  // -------------------- Identifiers --------------------
  uuid: z.string().uuid(),
  
  agentId: z.string()
    .min(1, 'Agent ID required')
    .max(64, 'Agent ID too long')
    .regex(/^[a-z0-9][a-z0-9-]*[a-z0-9]$/, 'Invalid agent ID format'),
  
  sessionKey: z.string()
    .min(1, 'Session key required')
    .max(256, 'Session key too long'),
  
  channelId: z.string()
    .min(1)
    .max(128)
    .regex(/^[a-zA-Z0-9_-]+$/),
  
  // -------------------- Paths --------------------
  safePath: z.string()
    .max(4096, 'Path too long')
    .refine(
      (p) => !p.includes('..'),
      'Path traversal not allowed'
    )
    .refine(
      (p) => !p.match(/^\/(?:etc|usr|var|sys|proc|dev)\//),
      'System paths not allowed'
    )
    .refine(
      (p) => !p.includes('\0'),
      'Null bytes not allowed in paths'
    ),
  
  relativePath: z.string()
    .max(1024)
    .refine(
      (p) => !p.startsWith('/') && !p.startsWith('~'),
      'Must be relative path'
    )
    .refine(
      (p) => !p.includes('..'),
      'Path traversal not allowed'
    ),
  
  // -------------------- Content --------------------
  messageContent: z.string()
    .max(50_000, 'Message too long'),
  
  commandInput: z.string()
    .max(10_000, 'Command input too long'),
  
  jsonContent: z.string()
    .max(1_000_000)
    .refine(
      (s) => {
        try { JSON.parse(s); return true; }
        catch { return false; }
      },
      'Invalid JSON'
    ),
  
  // -------------------- URLs --------------------
  safeUrl: z.string()
    .url('Invalid URL')
    .max(2048, 'URL too long')
    .refine(
      (url) => {
        try {
          const { protocol } = new URL(url);
          return ['http:', 'https:'].includes(protocol);
        } catch { return false; }
      },
      'Only HTTP(S) URLs allowed'
    ),
  
  internalUrl: z.string()
    .url()
    .refine(
      (url) => {
        try {
          const { hostname } = new URL(url);
          return hostname === 'localhost' || 
                 hostname === '127.0.0.1' ||
                 hostname.endsWith('.local') ||
                 hostname.endsWith('.ts.net');
        } catch { return false; }
      },
      'Only internal URLs allowed'
    ),
  
  // -------------------- Communication --------------------
  phoneNumber: z.string()
    .regex(/^\+[1-9]\d{1,14}$/, 'Must be E.164 format (e.g., +14155551234)'),
  
  email: z.string()
    .email('Invalid email address')
    .max(254, 'Email too long'),
  
  // -------------------- Numbers --------------------
  port: z.number()
    .int()
    .min(1, 'Port must be at least 1')
    .max(65535, 'Port must be at most 65535'),
  
  positiveInt: z.number()
    .int()
    .positive(),
  
  percentage: z.number()
    .min(0)
    .max(100),
  
  // -------------------- Timestamps --------------------
  isoDateTime: z.string()
    .datetime({ message: 'Must be ISO 8601 format' }),
  
  unixTimestamp: z.number()
    .int()
    .positive()
    .refine(
      (t) => t > 946684800 && t < 4102444800,
      'Timestamp must be between 2000 and 2100'
    ),
};

// ============================================================
// VALIDATION UTILITIES
// ============================================================

export class ValidationError extends Error {
  constructor(
    message: string,
    public readonly details: ZodError | null = null,
    public readonly context?: string
  ) {
    super(message);
    this.name = 'ValidationError';
  }
  
  toJSON() {
    return {
      name: this.name,
      message: this.message,
      context: this.context,
      issues: this.details?.issues,
    };
  }
}

/**
 * Validate data against a schema
 * Throws ValidationError on failure
 */
export function validate<T>(
  schema: ZodType<T>,
  data: unknown,
  context?: string
): T {
  const result = schema.safeParse(data);
  
  if (!result.success) {
    const message = context
      ? `Validation failed (${context}): ${result.error.issues[0]?.message}`
      : `Validation failed: ${result.error.issues[0]?.message}`;
    throw new ValidationError(message, result.error, context);
  }
  
  return result.data;
}

/**
 * Safe validation that returns result object instead of throwing
 */
export function safeValidate<T>(
  schema: ZodType<T>,
  data: unknown
): { success: true; data: T } | { success: false; error: ValidationError } {
  const result = schema.safeParse(data);
  
  if (result.success) {
    return { success: true, data: result.data };
  }
  
  return {
    success: false,
    error: new ValidationError(
      result.error.issues[0]?.message ?? 'Validation failed',
      result.error
    ),
  };
}

/**
 * Validate and transform, with default on failure
 */
export function validateWithDefault<T>(
  schema: ZodType<T>,
  data: unknown,
  defaultValue: T
): T {
  const result = schema.safeParse(data);
  return result.success ? result.data : defaultValue;
}

/**
 * Create a validated request handler
 */
export function withValidation<TBody, TQuery, TParams>(
  schemas: {
    body?: ZodType<TBody>;
    query?: ZodType<TQuery>;
    params?: ZodType<TParams>;
  },
  handler: (validated: { body: TBody; query: TQuery; params: TParams }) => Promise<Response>
) {
  return async (c: Context): Promise<Response> => {
    try {
      const body = schemas.body 
        ? validate(schemas.body, await c.req.json(), 'request body')
        : undefined as TBody;
      
      const query = schemas.query
        ? validate(schemas.query, c.req.query(), 'query params')
        : undefined as TQuery;
      
      const params = schemas.params
        ? validate(schemas.params, c.req.param(), 'path params')
        : undefined as TParams;
      
      return handler({ body, query, params });
    } catch (error) {
      if (error instanceof ValidationError) {
        return c.json({ error: error.message, details: error.details?.issues }, 400);
      }
      throw error;
    }
  };
}
```

---

### Solution 3.2: CLI Input Validation

**Addresses**: Issue 3.2 - CLI Input Validation Gaps  
**Priority**: P1  
**Effort**: Medium (1 sprint)

#### Implementation

```typescript
// src/cli/validation.ts

import { z } from 'zod';
import { schemas, validate, ValidationError } from '../validation';
import * as path from 'path';
import * as fs from 'fs';

// ============================================================
// CLI-SPECIFIC SCHEMAS
// ============================================================

export const cliSchemas = {
  // File path that must exist
  existingPath: z.string()
    .transform((p) => path.resolve(p))
    .refine(
      (p) => fs.existsSync(p),
      (p) => ({ message: `Path does not exist: ${p}` })
    ),
  
  // File path for output (parent must exist)
  outputPath: z.string()
    .transform((p) => path.resolve(p))
    .refine(
      (p) => fs.existsSync(path.dirname(p)),
      (p) => ({ message: `Parent directory does not exist: ${path.dirname(p)}` })
    ),
  
  // Config file path
  configPath: z.string()
    .transform((p) => path.resolve(p))
    .refine(
      (p) => fs.existsSync(p),
      'Config file does not exist'
    )
    .refine(
      (p) => p.endsWith('.json') || p.endsWith('.yaml') || p.endsWith('.yml'),
      'Config must be JSON or YAML'
    ),
  
  // Port number with availability check option
  portArg: schemas.port,
  
  // Timeout in seconds
  timeoutArg: z.string()
    .regex(/^\d+[smh]?$/, 'Invalid timeout format (e.g., 30, 30s, 5m, 1h)')
    .transform((t) => {
      const match = t.match(/^(\d+)([smh])?$/);
      if (!match) throw new Error('Invalid timeout');
      const [, num, unit] = match;
      const multipliers: Record<string, number> = { s: 1, m: 60, h: 3600 };
      return parseInt(num) * (multipliers[unit ?? 's'] ?? 1);
    }),
  
  // Verbosity level
  verbosity: z.enum(['quiet', 'normal', 'verbose', 'debug']).default('normal'),
  
  // Channel name
  channelName: z.enum([
    'whatsapp', 'telegram', 'discord', 'slack', 
    'signal', 'imessage', 'line', 'msteams', 'matrix'
  ]),
};

// ============================================================
// CLI ARGUMENT VALIDATORS
// ============================================================

/**
 * Validate CLI arguments with helpful error messages
 */
export function validateCliArgs<T extends z.ZodRawShape>(
  schema: z.ZodObject<T>,
  args: Record<string, unknown>,
  commandName: string
): z.infer<z.ZodObject<T>> {
  try {
    return validate(schema, args, `${commandName} arguments`);
  } catch (error) {
    if (error instanceof ValidationError) {
      // Format error for CLI output
      const issues = error.details?.issues ?? [];
      const messages = issues.map(issue => {
        const path = issue.path.join('.');
        return `  --${path}: ${issue.message}`;
      });
      
      console.error(`Error in ${commandName}:`);
      console.error(messages.join('\n'));
      process.exit(1);
    }
    throw error;
  }
}

/**
 * Path validation with security checks
 */
export function validatePath(
  inputPath: string,
  options: {
    mustExist?: boolean;
    allowAbsolute?: boolean;
    baseDir?: string;
  } = {}
): string {
  const { mustExist = false, allowAbsolute = true, baseDir } = options;
  
  // Resolve path
  let resolved: string;
  if (baseDir && !path.isAbsolute(inputPath)) {
    resolved = path.resolve(baseDir, inputPath);
  } else {
    resolved = path.resolve(inputPath);
  }
  
  // Security checks
  if (!allowAbsolute && path.isAbsolute(inputPath)) {
    throw new ValidationError('Absolute paths not allowed');
  }
  
  // Path traversal check
  if (baseDir) {
    const relative = path.relative(baseDir, resolved);
    if (relative.startsWith('..')) {
      throw new ValidationError('Path traversal not allowed');
    }
  }
  
  // Existence check
  if (mustExist && !fs.existsSync(resolved)) {
    throw new ValidationError(`Path does not exist: ${resolved}`);
  }
  
  return resolved;
}
```

#### Example Usage in CLI Command

```typescript
// src/commands/send.ts

import { z } from 'zod';
import { validateCliArgs, cliSchemas } from '../cli/validation';
import { schemas } from '../validation';

const SendArgsSchema = z.object({
  channel: cliSchemas.channelName,
  to: schemas.phoneNumber.or(schemas.email).or(z.string().min(1)),
  message: schemas.messageContent,
  timeout: cliSchemas.timeoutArg.optional(),
});

export async function sendCommand(args: Record<string, unknown>) {
  const validated = validateCliArgs(SendArgsSchema, args, 'send');
  
  // Now validated.channel, validated.to, validated.message are type-safe
  await sendMessage({
    channel: validated.channel,
    recipient: validated.to,
    content: validated.message,
    timeout: validated.timeout,
  });
}
```

---

### Solution 3.3: Webhook Payload Validation

**Addresses**: Issue 3.3 - Webhook Payload Validation  
**Priority**: P1  
**Effort**: Low (1 week)

#### Implementation

```typescript
// src/hooks/webhook-schemas.ts

import { z } from 'zod';

// ============================================================
// BASE WEBHOOK SCHEMA
// ============================================================

export const BaseWebhookPayloadSchema = z.object({
  event: z.string()
    .min(1)
    .max(100)
    .regex(/^[a-z][a-z0-9_.]*$/i, 'Invalid event name'),
  
  timestamp: z.string()
    .datetime()
    .optional()
    .default(() => new Date().toISOString()),
  
  source: z.string()
    .max(256)
    .optional(),
  
  data: z.record(z.unknown())
    .refine(
      (data) => JSON.stringify(data).length < 1_000_000,
      'Payload data too large (max 1MB)'
    ),
});

export type BaseWebhookPayload = z.infer<typeof BaseWebhookPayloadSchema>;

// ============================================================
// SERVICE-SPECIFIC SCHEMAS
// ============================================================

// Gmail webhook payload
export const GmailWebhookSchema = z.object({
  message: z.object({
    data: z.string(), // Base64 encoded
    messageId: z.string(),
    publishTime: z.string().datetime(),
  }),
  subscription: z.string(),
});

// Stripe webhook payload
export const StripeWebhookSchema = z.object({
  id: z.string().startsWith('evt_'),
  object: z.literal('event'),
  type: z.string(),
  data: z.object({
    object: z.record(z.unknown()),
  }),
  livemode: z.boolean(),
  created: z.number(),
});

// Generic task webhook
export const TaskWebhookSchema = z.object({
  event: z.enum(['task.created', 'task.completed', 'task.failed']),
  taskId: z.string().uuid(),
  timestamp: z.string().datetime(),
  data: z.object({
    name: z.string().max(256),
    result: z.unknown().optional(),
    error: z.string().optional(),
  }),
});

// ============================================================
// WEBHOOK VALIDATOR FACTORY
// ============================================================

export function createWebhookValidator<T extends z.ZodType>(
  schema: T,
  options: {
    requireSignature?: boolean;
    signatureHeader?: string;
    signatureValidator?: (payload: string, signature: string) => boolean;
  } = {}
) {
  return async (req: Request): Promise<z.infer<T>> => {
    // Signature validation
    if (options.requireSignature && options.signatureValidator) {
      const signature = req.headers.get(options.signatureHeader ?? 'x-signature');
      const body = await req.text();
      
      if (!signature || !options.signatureValidator(body, signature)) {
        throw new ValidationError('Invalid webhook signature');
      }
      
      // Parse after signature check
      const parsed = JSON.parse(body);
      return schema.parse(parsed);
    }
    
    // Parse without signature
    const body = await req.json();
    return schema.parse(body);
  };
}

// Example usage
export const validateGmailWebhook = createWebhookValidator(GmailWebhookSchema);
export const validateStripeWebhook = createWebhookValidator(StripeWebhookSchema, {
  requireSignature: true,
  signatureHeader: 'stripe-signature',
  signatureValidator: (payload, sig) => verifyStripeSignature(payload, sig),
});
```

---

### Solution 3.4: Message Content Validation

**Addresses**: Issue 3.4 - Message Content Validation  
**Priority**: P2  
**Effort**: Low (1 week)

#### Implementation

```typescript
// src/channels/message-validation.ts

import { z } from 'zod';

// ============================================================
// MESSAGE SCHEMAS
// ============================================================

export const MessageContentSchema = z.object({
  text: z.string()
    .max(50_000, 'Message text too long')
    .optional(),
  
  media: z.array(z.object({
    type: z.enum(['image', 'video', 'audio', 'document']),
    url: z.string().url().optional(),
    data: z.string().max(10_000_000).optional(), // 10MB base64
    mimeType: z.string().regex(/^[a-z]+\/[a-z0-9.+-]+$/i),
    filename: z.string().max(256).optional(),
  })).max(10, 'Too many media attachments').optional(),
  
  mentions: z.array(z.object({
    type: z.enum(['user', 'channel', 'everyone']),
    id: z.string().max(128),
    offset: z.number().int().min(0),
    length: z.number().int().min(1),
  })).max(50).optional(),
  
  replyTo: z.string().max(256).optional(),
  
  metadata: z.record(z.unknown())
    .refine(
      (m) => JSON.stringify(m).length < 10_000,
      'Metadata too large'
    )
    .optional(),
});

export type MessageContent = z.infer<typeof MessageContentSchema>;

// ============================================================
// SENDER VALIDATION
// ============================================================

export const SenderIdentitySchema = z.object({
  id: z.string().min(1).max(256),
  name: z.string().max(256).optional(),
  phone: z.string().regex(/^\+[1-9]\d{1,14}$/).optional(),
  email: z.string().email().max(254).optional(),
  username: z.string().max(64).optional(),
  isBot: z.boolean().default(false),
  isVerified: z.boolean().default(false),
});

// ============================================================
// CHANNEL-SPECIFIC VALIDATORS
// ============================================================

const CHANNEL_LIMITS: Record<string, { maxLength: number; maxMedia: number }> = {
  whatsapp: { maxLength: 4096, maxMedia: 10 },
  telegram: { maxLength: 4096, maxMedia: 10 },
  discord: { maxLength: 2000, maxMedia: 10 },
  slack: { maxLength: 40000, maxMedia: 10 },
  signal: { maxLength: 2000, maxMedia: 10 },
  sms: { maxLength: 1600, maxMedia: 0 },
};

export function validateMessageForChannel(
  content: MessageContent,
  channel: string
): { valid: boolean; errors: string[] } {
  const limits = CHANNEL_LIMITS[channel] ?? { maxLength: 4096, maxMedia: 10 };
  const errors: string[] = [];
  
  if (content.text && content.text.length > limits.maxLength) {
    errors.push(`Message too long for ${channel} (max ${limits.maxLength} chars)`);
  }
  
  if (content.media && content.media.length > limits.maxMedia) {
    errors.push(`Too many attachments for ${channel} (max ${limits.maxMedia})`);
  }
  
  return { valid: errors.length === 0, errors };
}
```

---

### Solution 3.5: Configuration Schema Enhancement

**Addresses**: Issue 3.5 - Configuration Schema Validation  
**Priority**: P2  
**Effort**: Low (ongoing)

#### Implementation

```typescript
// src/config/runtime-validation.ts

import { z } from 'zod';
import { MoltbotConfigSchema } from './zod-schema';

// Runtime config validator
export class ConfigValidator {
  private config: z.infer<typeof MoltbotConfigSchema>;
  private validationErrors: string[] = [];
  
  constructor(config: unknown) {
    const result = MoltbotConfigSchema.safeParse(config);
    
    if (!result.success) {
      this.validationErrors = result.error.issues.map(issue => 
        `${issue.path.join('.')}: ${issue.message}`
      );
      throw new ConfigValidationError(this.validationErrors);
    }
    
    this.config = result.data;
  }
  
  // Re-validate after config reload
  revalidate(newConfig: unknown): boolean {
    const result = MoltbotConfigSchema.safeParse(newConfig);
    
    if (!result.success) {
      this.validationErrors = result.error.issues.map(issue =>
        `${issue.path.join('.')}: ${issue.message}`
      );
      return false;
    }
    
    this.config = result.data;
    this.validationErrors = [];
    return true;
  }
  
  // Environment-specific validation
  validateForEnvironment(env: 'development' | 'staging' | 'production'): string[] {
    const warnings: string[] = [];
    
    if (env === 'production') {
      // Production-specific checks
      if (!this.config.gateway?.tls?.enabled) {
        warnings.push('TLS not enabled for production');
      }
      
      if (this.config.logging?.level === 'debug') {
        warnings.push('Debug logging enabled in production');
      }
    }
    
    return warnings;
  }
}

class ConfigValidationError extends Error {
  constructor(public readonly errors: string[]) {
    super(`Configuration validation failed:\n${errors.join('\n')}`);
    this.name = 'ConfigValidationError';
  }
}
```

---

### Solution 3.6: API Response Validation

**Addresses**: Issue 3.6 - API Response Validation  
**Priority**: P2  
**Effort**: Medium (ongoing)

#### Implementation

```typescript
// src/providers/response-validation.ts

import { z } from 'zod';

// ============================================================
// LLM RESPONSE SCHEMAS
// ============================================================

export const LLMMessageSchema = z.object({
  role: z.enum(['user', 'assistant', 'system', 'tool']),
  content: z.string().or(z.null()),
  tool_calls: z.array(z.object({
    id: z.string(),
    type: z.literal('function'),
    function: z.object({
      name: z.string(),
      arguments: z.string(),
    }),
  })).optional(),
});

export const LLMResponseSchema = z.object({
  id: z.string(),
  object: z.string(),
  created: z.number(),
  model: z.string(),
  choices: z.array(z.object({
    index: z.number(),
    message: LLMMessageSchema,
    finish_reason: z.enum(['stop', 'length', 'tool_calls', 'content_filter']).nullable(),
  })),
  usage: z.object({
    prompt_tokens: z.number(),
    completion_tokens: z.number(),
    total_tokens: z.number(),
  }).optional(),
});

// ============================================================
// VALIDATED API CALLER
// ============================================================

export async function callWithValidation<T>(
  endpoint: string,
  options: RequestInit,
  responseSchema: z.ZodType<T>
): Promise<T> {
  const response = await fetch(endpoint, options);
  
  if (!response.ok) {
    throw new Error(`API error: ${response.status} ${response.statusText}`);
  }
  
  const data = await response.json();
  
  // Validate response
  const result = responseSchema.safeParse(data);
  
  if (!result.success) {
    console.warn('API response validation warning:', result.error.issues);
    // Still return data but log warning
    return data as T;
  }
  
  return result.data;
}
```

---

## Implementation Roadmap

### Sprint 1: Foundation
- [ ] Create `src/validation/index.ts` with core utilities
- [ ] Add common schemas
- [ ] Integrate with existing Zod schemas

### Sprint 2: CLI & Webhooks
- [ ] CLI validation utilities
- [ ] Webhook schema definitions
- [ ] Migrate existing webhooks

### Sprint 3: Messages & API
- [ ] Message validation
- [ ] Channel-specific limits
- [ ] API response validation

### Sprint 4: Documentation
- [ ] Schema documentation generation
- [ ] Developer guide
- [ ] Migration guide for existing code

---

## Success Criteria

- [ ] Centralized validation library implemented
- [ ] All CLI commands using validation
- [ ] All webhooks validated
- [ ] Message validation per channel
- [ ] Runtime config validation
- [ ] 100% test coverage on validation utilities

---

**Document Maintainer**: Development Team  
**Last Updated**: 2026-01-28
