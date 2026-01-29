# SPEC-ISSUES 3.0: Form & Input Validation

**Document ID**: SPEC-ISSUES-3.0  
**Category**: Form & Input Validation  
**Priority**: P1 (Important)  
**Date Created**: 2026-01-28  
**Status**: Open  
**Related Solutions**: SPEC-SOLUTION-3.0 (to be created)

---

## Executive Summary

This document catalogs input validation issues across the Moltbot codebase. While validation and sanitization utilities exist in 307 files, there are gaps in consistent application and coverage.

---

## Issue Registry

### 3.1 Inconsistent Input Validation Patterns

**Severity**: MEDIUM  
**Files with Validation Logic**: 307 files

#### Description

The codebase contains validation logic across 307 files with terms like `sanitize`, `escape`, `validate`, and `encode`. However, the patterns are inconsistent:

| Pattern | File Count | Notes |
|---------|------------|-------|
| Validation utilities | ~50 | Centralized helpers |
| Inline validation | ~200 | Ad-hoc validation in handlers |
| Schema validation (Zod) | ~30 | Type-safe validation |
| Missing validation | Unknown | Needs audit |

#### Key Validation Files

| File | Purpose | Quality |
|------|---------|---------|
| `src/config/validation.ts` | Config validation | Good |
| `src/config/zod-schema.*.ts` | Zod schemas | Good |
| `src/plugins/schema-validator.ts` | Plugin validation | Good |
| `src/agents/apply-patch.ts` | Patch validation | Medium |

---

### 3.2 CLI Input Validation Gaps

**Severity**: MEDIUM  
**Files Affected**: `src/cli/`, `src/commands/`

#### Description

CLI commands accept various inputs that flow into system operations. Validation is present but inconsistent.

#### Audit Areas

1. **File Path Inputs**:
   - Path traversal prevention
   - Symlink resolution
   - Permission checks

2. **Configuration Values**:
   - Token format validation
   - URL validation
   - Numeric bounds checking

3. **User-Provided Identifiers**:
   - Channel IDs
   - Agent IDs
   - Session keys

#### Example Gap

```typescript
// Some CLI handlers may accept paths without validation
const configPath = args.config; // Potentially untrusted
await fs.readFile(configPath); // Path traversal risk
```

---

### 3.3 Webhook Payload Validation

**Severity**: HIGH  
**Files Affected**: Hook handlers in `src/hooks/`

#### Description

Webhooks receive external payloads that require strict validation before processing.

#### Current State

| Hook Type | Validation | Notes |
|-----------|------------|-------|
| Gmail | Partial | Pub/Sub message validation |
| Generic Webhook | Minimal | JSON parsing only |
| Cron | Good | Config-based validation |

#### Recommended Improvements

```typescript
// Proposed: Strict webhook payload schema
import { z } from 'zod';

const WebhookPayloadSchema = z.object({
  event: z.string().max(100),
  timestamp: z.string().datetime(),
  data: z.record(z.unknown()).refine(
    (data) => JSON.stringify(data).length < 1_000_000,
    "Payload too large"
  ),
  signature: z.string().optional(),
});

export function validateWebhookPayload(payload: unknown) {
  return WebhookPayloadSchema.safeParse(payload);
}
```

---

### 3.4 Message Content Validation

**Severity**: MEDIUM  
**Files Affected**: Channel handlers

#### Description

Messages from external sources (WhatsApp, Telegram, etc.) need validation before processing.

#### Validation Considerations

| Field | Current | Recommended |
|-------|---------|-------------|
| Message length | Partial | Strict max (e.g., 50KB) |
| Media size | Config-based | Enforce limits |
| URL content | Minimal | URL validation |
| Phone numbers | Format check | E.164 validation |
| Email addresses | Minimal | RFC 5322 validation |

---

### 3.5 Configuration Schema Validation

**Severity**: LOW-MEDIUM  
**Current Implementation**: Zod schemas in `src/config/`

#### Strengths

- `src/config/zod-schema.*.ts` provides type-safe validation
- Configuration loading validates against schemas
- Error messages are descriptive

#### Gaps

1. **Runtime Re-validation**: Config may change after initial load
2. **Hot Reload Validation**: Need validation on config reload
3. **Environment-Specific Rules**: Some rules vary by environment

---

### 3.6 API Response Validation

**Severity**: MEDIUM  
**Context**: External API responses

#### Description

The codebase makes calls to external APIs (OpenAI, Anthropic, Stripe, etc.). Response validation varies.

#### Audit Areas

| API | Response Validation |
|-----|---------------------|
| LLM Providers | Type assertions, minimal schema |
| Telegram API | grammY handles some validation |
| Discord API | discord.js provides types |
| Slack API | Bolt provides types |

#### Recommendation

Add runtime response validation for critical API responses using Zod schemas.

---

## Validation Pattern Recommendations

### 3.7 Standardized Validation Layer

```typescript
// Proposed: Centralized validation utilities

// src/validation/index.ts
import { z } from 'zod';

// Common schemas
export const schemas = {
  // Identifiers
  uuid: z.string().uuid(),
  agentId: z.string().min(1).max(64).regex(/^[a-z0-9-]+$/),
  sessionKey: z.string().min(1).max(256),
  
  // Paths
  safePath: z.string()
    .max(4096)
    .refine((p) => !p.includes('..'), 'Path traversal not allowed')
    .refine((p) => !p.startsWith('/etc'), 'System paths not allowed'),
  
  // Content
  messageContent: z.string().max(50_000),
  commandInput: z.string().max(10_000),
  
  // URLs
  safeUrl: z.string().url().refine(
    (url) => ['http:', 'https:'].includes(new URL(url).protocol),
    'Only HTTP(S) URLs allowed'
  ),
  
  // Communication
  phoneNumber: z.string().regex(/^\+[1-9]\d{1,14}$/, 'E.164 format required'),
  email: z.string().email(),
};

// Validation helper
export function validate<T>(
  schema: z.ZodType<T>,
  data: unknown,
  context?: string
): T {
  const result = schema.safeParse(data);
  if (!result.success) {
    const message = `Validation failed${context ? ` (${context})` : ''}: ${result.error.message}`;
    throw new ValidationError(message, result.error);
  }
  return result.data;
}
```

---

## Appendix: Files with Validation Logic

<details>
<summary>Key validation files by category</summary>

**Schema Validation**:
- `src/config/zod-schema.providers-core.ts`
- `src/config/zod-schema.agent-runtime.ts`
- `src/plugins/schema-validator.ts`

**Content Sanitization**:
- `src/agents/pi-embedded-helpers.ts` (sanitize*)
- `src/gateway/chat-sanitize.test.ts`
- `src/auto-reply/templating.ts`

**Input Validation**:
- `src/config/validation.ts`
- `src/routing/session-key.ts`
- `src/channels/sender-identity.ts`

</details>

---

**Document Maintainer**: Development Team  
**Last Updated**: 2026-01-28
