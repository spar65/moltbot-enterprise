# Development Documentation: Issue Specifications

**Created**: 2026-01-28  
**Purpose**: Comprehensive issue tracking for Moltbot codebase review  
**Workflow**: SPEC-ISSUES → SPEC-SOLUTION → Implementation (BB)

---

## Document Index

### Issue Specifications

| Document | Category | Priority | Status |
|----------|----------|----------|--------|
| [SPEC-ISSUES-1.0-SECURITY.md](./SPEC-ISSUES-1.0-SECURITY.md) | Security | P0 | Open |
| [SPEC-ISSUES-2.0-COMMAND-INJECTION.md](./SPEC-ISSUES-2.0-COMMAND-INJECTION.md) | Security - Injection | P0 | Open |
| [SPEC-ISSUES-3.0-FORM-VALIDATION.md](./SPEC-ISSUES-3.0-FORM-VALIDATION.md) | Form & Input | P1 | Open |
| [SPEC-ISSUES-4.0-TECHNICAL-DEBT.md](./SPEC-ISSUES-4.0-TECHNICAL-DEBT.md) | Technical Debt | P2 | Open |
| [SPEC-ISSUES-5.0-IMPROVEMENTS.md](./SPEC-ISSUES-5.0-IMPROVEMENTS.md) | Improvements | P2-P3 | Open |
| [SPEC-ISSUES-6.0-STRUCTURAL.md](./SPEC-ISSUES-6.0-STRUCTURAL.md) | Architecture | P2 | Open |
| [SPEC-ISSUES-7.0-ADDITIONAL-CONCERNS.md](./SPEC-ISSUES-7.0-ADDITIONAL-CONCERNS.md) | Miscellaneous | P2-P3 | Open |

### Solution Specifications

| Document | Addresses | Status |
|----------|-----------|--------|
| [SPEC-SOLUTION-1.0-SECURITY.md](./SPEC-SOLUTION-1.0-SECURITY.md) | SPEC-ISSUES-1.0 | Draft |
| [SPEC-SOLUTION-2.0-COMMAND-INJECTION.md](./SPEC-SOLUTION-2.0-COMMAND-INJECTION.md) | SPEC-ISSUES-2.0 | Draft |
| [SPEC-SOLUTION-3.0-FORM-VALIDATION.md](./SPEC-SOLUTION-3.0-FORM-VALIDATION.md) | SPEC-ISSUES-3.0 | Draft |
| [SPEC-SOLUTION-4.0-TECHNICAL-DEBT.md](./SPEC-SOLUTION-4.0-TECHNICAL-DEBT.md) | SPEC-ISSUES-4.0 | Draft |
| [SPEC-SOLUTION-5.0-IMPROVEMENTS.md](./SPEC-SOLUTION-5.0-IMPROVEMENTS.md) | SPEC-ISSUES-5.0 | Draft |
| [SPEC-SOLUTION-6.0-STRUCTURAL.md](./SPEC-SOLUTION-6.0-STRUCTURAL.md) | SPEC-ISSUES-6.0 | Draft |
| [SPEC-SOLUTION-7.0-ADDITIONAL-CONCERNS.md](./SPEC-SOLUTION-7.0-ADDITIONAL-CONCERNS.md) | SPEC-ISSUES-7.0 | Draft |

### Enterprise MCP Integration

| Document | Type | Description |
|----------|------|-------------|
| [SPEC-DECISION-MOLTBOT-INTEGRATION-MCP-ENTERPRISE-DATA.md](./SPEC-DECISION-MOLTBOT-INTEGRATION-MCP-ENTERPRISE-DATA.md) | Decision | Architecture decision for MCP Server (stdio) approach |
| [SPEC-INTEGRATION-MOLT-TO-MCP-ENT-DATA.md](./SPEC-INTEGRATION-MOLT-TO-MCP-ENT-DATA.md) | Specification | Complete integration specification with tool definitions |
| [GUIDE-MOLTBOT-MCP-ENTERPRISE-INTEGRATION.md](./GUIDE-MOLTBOT-MCP-ENTERPRISE-INTEGRATION.md) | Guide | Step-by-step implementation guide for LLM agents |

### Compsi SDK Integration (AI Ethics Assessment)

| Document | Type | Description |
|----------|------|-------------|
| [USER-STORIES-COMPSI-MOLTBOT-INTEGRATION.md](./USER-STORIES-COMPSI-MOLTBOT-INTEGRATION.md) | User Stories | 37 user stories across 9 epics for daily ethics assessments |
| [SPEC-DECISION-MOLTBOT-COMPSI-INTEGRATION.md](./SPEC-DECISION-MOLTBOT-COMPSI-INTEGRATION.md) | Decision | Architecture decision for direct SDK integration |
| [SPEC-INTEGRATION-MOLTBOT-COMPSI-SDK.md](./SPEC-INTEGRATION-MOLTBOT-COMPSI-SDK.md) | Specification | Complete technical implementation specification |
| [GUIDE-MOLTBOT-COMPSI-IMPLEMENTATION.md](./GUIDE-MOLTBOT-COMPSI-IMPLEMENTATION.md) | Guide | Step-by-step implementation guide for LLM agents |

---

## Priority Definitions

| Priority | Definition | Response Time |
|----------|------------|---------------|
| **P0** | Critical - Security vulnerabilities, data loss risk | Immediate |
| **P1** | High - Important security/reliability issues | Next sprint |
| **P2** | Medium - Technical debt, improvements | 2-4 sprints |
| **P3** | Low - Nice-to-have enhancements | Backlog |

---

## Issue Summary

### Critical (P0) - Requires Immediate Attention

1. **Command Execution Attack Surface** (SPEC-ISSUES-1.1)
   - 84 files with child_process usage
   - Partial mitigations in place (exec approvals, sandboxing)
   - Need comprehensive audit of all execution paths

2. **Email-to-Command Injection** (SPEC-ISSUES-2.1)
   - Gmail hooks → Agent → Shell execution path
   - External content wrapping exists but bypasses possible
   - Need enhanced detection and blocking

3. **Webhook Command Injection** (SPEC-ISSUES-2.2)
   - Webhook payloads can reach command execution
   - Need strict payload validation

### High (P1) - Important

4. **Missing Rate Limiting** (SPEC-ISSUES-1.6)
   - Only Telegram has comprehensive rate limiting
   - Gateway and other channels need protection

5. **Credential Storage** (SPEC-ISSUES-7.2)
   - File-based storage without encryption
   - Need encryption at rest

6. **Webhook Signature Verification** (SPEC-ISSUES-7.8)
   - Audit needed for all webhook endpoints

### Medium (P2) - Technical Debt

7. **Type Safety** (SPEC-ISSUES-4.1)
   - 295 `any` usages across 142 files
   - Reduces compile-time safety

8. **CORS Configuration** (SPEC-ISSUES-5.1)
   - No CORS headers for remote access

9. **Centralized Configuration** (SPEC-ISSUES-5.3)
   - 1,728 direct `process.env` accesses

10. **Structural Complexity** (SPEC-ISSUES-6.x)
    - Large modules need splitting
    - Channel architecture inconsistency

---

## Workflow

### Phase 1: Issue Documentation (Current)
```
Codebase Analysis → SPEC-ISSUES-#.# Documents
```

### Phase 2: Solution Design (Next)
```
SPEC-ISSUES-#.# → SPEC-SOLUTION-#.# Documents
```

### Phase 3: Implementation (BB)
```
SPEC-SOLUTION-#.# → Development Tasks → Implementation
```

---

## Analysis Methodology

### Static Analysis Performed

| Analysis Type | Tool | Results |
|--------------|------|---------|
| Command execution | Grep | 84 files |
| Sensitive data | Grep | 7,675 matches |
| Type safety | Grep (`any`) | 295 matches |
| Validation | Grep | 307 files |
| File writes | Grep | 540 matches |
| Env access | Grep | 1,728 matches |

### Files Reviewed in Detail

- `src/process/exec.ts` - Command execution
- `src/agents/bash-tools.exec.ts` - Agent shell tools
- `src/security/external-content.ts` - Content wrapping
- `src/logging/redact.ts` - Sensitive data redaction
- `.cursor/rules/011-env-var-security.mdc` - Security rules

---

## Existing Security Controls

The codebase already has several security mechanisms:

| Control | Location | Coverage |
|---------|----------|----------|
| Exec Approvals | `src/infra/exec-approvals.ts` | Command execution |
| External Content Wrapping | `src/security/external-content.ts` | Email/webhook content |
| Sensitive Data Redaction | `src/logging/redact.ts` | Logging |
| Sandbox Configuration | `src/agents/sandbox/` | Agent execution |
| DM Pairing/Allowlist | `src/pairing/` | Channel access |
| Security Audit | `src/security/audit.ts` | File permissions |

---

## Next Steps

1. **Create SPEC-SOLUTION Documents**
   - SPEC-SOLUTION-1.0 for security issues
   - SPEC-SOLUTION-2.0 for command injection
   - Continue for each SPEC-ISSUES document

2. **Prioritize Based on Risk**
   - Focus on P0 issues first
   - Create timeline for P1 issues

3. **Feed into BB for Implementation**
   - Convert solutions to actionable tasks
   - Track implementation progress

---

## Document Conventions

### Issue Numbering

```
SPEC-ISSUES-{Major}.{Minor}-{Category}.md

Examples:
- SPEC-ISSUES-1.0-SECURITY.md (Security category, version 1.0)
- SPEC-ISSUES-2.0-COMMAND-INJECTION.md (Command injection, version 2.0)
```

### Solution Numbering

```
SPEC-SOLUTION-{Major}.{Minor}-{Category}.md

Maps directly to corresponding SPEC-ISSUES document.
```

### Issue ID Within Documents

```
{Document}.{Issue}

Examples:
- 1.1 = SPEC-ISSUES-1.0, Issue 1
- 2.3 = SPEC-ISSUES-2.0, Issue 3
```

---

## Contributing

When adding new issues:

1. Determine category (Security, Form, Tech Debt, etc.)
2. Find appropriate SPEC-ISSUES document
3. Add issue with unique ID
4. Include: Description, Evidence, Risk, Recommendations
5. Update this README's summary

---

**Maintainer**: Development Team  
**Last Updated**: 2026-01-28
