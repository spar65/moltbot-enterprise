# SPEC-ISSUES 7.0: Additional Concerns

**Document ID**: SPEC-ISSUES-7.0  
**Category**: Miscellaneous  
**Priority**: P2-P3 (Various)  
**Date Created**: 2026-01-28  
**Status**: Open  
**Related Solutions**: SPEC-SOLUTION-7.0 (to be created)

---

## Executive Summary

This document catalogs additional concerns identified during the codebase review that don't fit neatly into other categories. These include operational concerns, compliance considerations, and edge cases.

---

## Issue Registry

### 7.1 Multi-Agent Safety

**Category**: Operational Safety  
**Priority**: P1  
**Source**: CLAUDE.md guidelines

#### Description

Per CLAUDE.md, multi-agent workflows require careful coordination:

- Do not create/apply/drop git stash entries
- Do not switch branches without explicit request
- Do not modify git worktrees
- Scope commits to own changes only

#### Concern

These guidelines are documented but enforcement is manual. Automated guardrails would prevent accidental violations.

#### Recommendation

```typescript
// Proposed: Git operation guardrails
export function isGitOperationAllowed(
  operation: string,
  context: AgentContext
): boolean {
  const dangerousOperations = [
    'stash',
    'checkout',
    'switch',
    'worktree',
    'push --force',
    'reset --hard',
  ];
  
  if (dangerousOperations.some(op => operation.includes(op))) {
    if (!context.explicitlyRequested) {
      logWarn(`Blocked dangerous git operation: ${operation}`);
      return false;
    }
  }
  return true;
}
```

---

### 7.2 Credential Storage Security

**Category**: Security  
**Priority**: P1  
**Location**: `~/.clawdbot/credentials/`

#### Description

Credentials are stored locally at `~/.clawdbot/credentials/`. Security considerations:

1. File permissions must be restrictive (0600)
2. Credentials should be encrypted at rest
3. Audit logging for credential access
4. Secure deletion on logout

#### Current State

- `src/security/audit.ts` exists
- `src/security/fix.ts` handles permission fixes
- File-based storage (not encrypted)

#### Recommendation

1. Implement credential encryption at rest
2. Use OS keychain where available (macOS Keychain, Windows Credential Manager)
3. Add credential access logging

---

### 7.3 Session State Management

**Category**: Reliability  
**Priority**: P2  
**Location**: `~/.clawdbot/sessions/`

#### Description

Session state is stored in filesystem. Concerns:

1. **Concurrent access**: Multiple processes may access same sessions
2. **Corruption recovery**: Session files may become corrupted
3. **Cleanup**: Old sessions may accumulate

#### Current Mitigations

- `src/agents/session-write-lock.ts` handles locking
- `src/config/sessions/store.ts` manages session storage
- Transcript repair utilities exist

#### Additional Recommendations

1. Implement session integrity checks
2. Add automatic cleanup for stale sessions
3. Consider SQLite for session storage

---

### 7.4 Memory/Vector Database Resilience

**Category**: Reliability  
**Priority**: P2  
**Location**: `src/memory/`

#### Description

The memory system uses sqlite-vec for vector storage. Concerns:

1. Database corruption handling
2. Backup and recovery
3. Performance under load
4. Index maintenance

#### Current Implementation

- `src/memory/manager.ts` handles memory operations
- Batch embedding support
- Async search capabilities

#### Recommendations

1. Implement automatic backups
2. Add corruption detection
3. Monitor query performance

---

### 7.5 Plugin Security Boundary

**Category**: Security  
**Priority**: P2  
**Location**: `extensions/`

#### Description

Plugins run with significant access to the system. Security boundaries:

1. Plugin code execution context
2. Access to credentials
3. Network access
4. Filesystem access

#### Current Controls

- Plugin install runs `npm install --omit=dev`
- Runtime dependencies must be in `dependencies`
- SDK provides controlled interface

#### Recommendations

1. Document plugin security model
2. Consider plugin sandboxing
3. Implement plugin permission system

---

### 7.6 API Key Rotation

**Category**: Security Operations  
**Priority**: P2

#### Description

API keys (OpenAI, Anthropic, etc.) may need rotation. Current state:

1. Keys stored in config files
2. OAuth refresh for some providers
3. No automated rotation

#### Recommendations

1. Document key rotation procedures
2. Implement rotation reminders
3. Support graceful key rollover

---

### 7.7 Error Message Information Leakage

**Category**: Security  
**Priority**: P2

#### Description

Error messages may leak sensitive information:

1. Stack traces with file paths
2. Configuration values in errors
3. Internal state in error objects

#### Current Mitigations

- `src/logging/redact.ts` redacts some patterns
- Error handling varies by module

#### Recommendations

1. Sanitize all user-facing error messages
2. Log detailed errors internally only
3. Return generic errors to external clients

---

### 7.8 Webhook Signature Verification

**Category**: Security  
**Priority**: P1  
**Location**: Various webhook handlers

#### Description

Webhooks from external services should verify signatures:

| Service | Signature Verification |
|---------|----------------------|
| Telegram | Bot token validation |
| Slack | Signing secret |
| Discord | Ed25519 signature |
| LINE | Channel secret |
| Generic webhooks | Configurable |

#### Audit Required

Verify all webhook endpoints properly validate incoming requests.

---

### 7.9 Timezone Handling

**Category**: Reliability  
**Priority**: P3

#### Description

Cron jobs and scheduled tasks need consistent timezone handling:

1. Server timezone vs user timezone
2. Daylight saving time transitions
3. UTC standardization

#### Current Implementation

- `src/cron/` handles scheduling
- Croner library for cron expressions

#### Recommendations

1. Document timezone assumptions
2. Store all times in UTC
3. Handle DST transitions

---

### 7.10 Graceful Shutdown

**Category**: Reliability  
**Priority**: P2

#### Description

Ensure clean shutdown on SIGTERM/SIGINT:

1. Complete in-flight requests
2. Flush logs
3. Close database connections
4. Save session state
5. Release locks

#### Current Implementation

- `src/cli/gateway.sigterm.test.ts` tests shutdown
- Various cleanup handlers

#### Recommendations

1. Audit all shutdown paths
2. Add timeout for graceful shutdown
3. Document recovery from ungraceful shutdown

---

### 7.11 Audit Trail Requirements

**Category**: Compliance  
**Priority**: P2

#### Description

For compliance/debugging, track:

1. Authentication events
2. Command execution
3. Configuration changes
4. External API calls
5. Error events

#### Current State

- Logging exists but not structured for audit
- No centralized audit log

#### Recommendations

1. Implement structured audit logging
2. Ensure immutable audit records
3. Add retention policy

---

### 7.12 Resource Limits

**Category**: Reliability  
**Priority**: P2

#### Description

Prevent resource exhaustion:

| Resource | Limit Mechanism |
|----------|----------------|
| Memory | Node.js heap limits |
| Disk | No automatic limits |
| Network connections | Varies by library |
| Child processes | Configurable |
| File descriptors | OS limits |

#### Recommendations

1. Implement disk usage monitoring
2. Set connection pool limits
3. Monitor resource usage metrics

---

## Summary Matrix

| Issue | Category | Priority | Complexity |
|-------|----------|----------|------------|
| Multi-agent safety | Operations | P1 | Medium |
| Credential storage | Security | P1 | High |
| Session management | Reliability | P2 | Medium |
| Memory resilience | Reliability | P2 | Medium |
| Plugin security | Security | P2 | High |
| API key rotation | Security Ops | P2 | Low |
| Error leakage | Security | P2 | Medium |
| Webhook signatures | Security | P1 | Medium |
| Timezone handling | Reliability | P3 | Low |
| Graceful shutdown | Reliability | P2 | Medium |
| Audit trail | Compliance | P2 | Medium |
| Resource limits | Reliability | P2 | Medium |

---

**Document Maintainer**: Development Team  
**Last Updated**: 2026-01-28
