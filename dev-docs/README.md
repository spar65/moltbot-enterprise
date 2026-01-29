# Moltbot Enterprise - Development Documentation

**Repository**: https://github.com/spar65/moltbot-enterprise  
**Created**: 2026-01-28  
**Purpose**: Technical specifications, integration guides, and implementation documentation

---

## Overview

Moltbot Enterprise is an **AI-powered work assistant platform** with:

- **Ethics-Gated Access** - Daily compliance assessments before AI assistance
- **Secure Enterprise Data** - MCP-based integration with enterprise databases
- **Multi-Framework Compliance** - Morality, Virtue, Ethics, Operational Excellence
- **Complete Audit Trail** - Cryptographically signed, tamper-evident logs

```
┌─────────────────────────────────────────────────────────────────┐
│                  MOLTBOT ENTERPRISE PLATFORM                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   User → Message Router → Ethics Gate → Enterprise Data Access │
│                               │                    │            │
│                               ▼                    ▼            │
│                        ┌───────────┐      ┌──────────────┐     │
│                        │  Compsi   │      │  MCP Server  │     │
│                        │  Ethics   │      │  (stdio)     │     │
│                        │  Engine   │      │              │     │
│                        └───────────┘      └──────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Document Index

### Enterprise MCP Integration (Secure Data Access)

Secure integration with enterprise databases via Model Context Protocol.

| Document | Type | Description |
|----------|------|-------------|
| [SPEC-DECISION-MOLTBOT-INTEGRATION-MCP-ENTERPRISE-DATA.md](./SPEC-DECISION-MOLTBOT-INTEGRATION-MCP-ENTERPRISE-DATA.md) | Decision | Architecture decision for MCP Server (stdio) |
| [SPEC-INTEGRATION-MOLT-TO-MCP-ENT-DATA.md](./SPEC-INTEGRATION-MOLT-TO-MCP-ENT-DATA.md) | Specification | 18 tool definitions, 5-layer security |
| [GUIDE-MOLTBOT-MCP-ENTERPRISE-INTEGRATION.md](./GUIDE-MOLTBOT-MCP-ENTERPRISE-INTEGRATION.md) | Guide | Step-by-step implementation for LLM agents |

**Key Features**:
- Process isolation via stdio (no network exposure)
- HMAC authentication
- Joi-based input validation
- Rate limiting per tool
- Audit logging with redaction

---

### Compsi SDK Integration (Ethics & Compliance)

Daily ethical assessments using AI Assess Tech's 4-framework system.

| Document | Type | Description |
|----------|------|-------------|
| [USER-STORIES-COMPSI-MOLTBOT-INTEGRATION.md](./USER-STORIES-COMPSI-MOLTBOT-INTEGRATION.md) | User Stories | 37 stories across 9 epics |
| [SPEC-DECISION-MOLTBOT-COMPSI-INTEGRATION.md](./SPEC-DECISION-MOLTBOT-COMPSI-INTEGRATION.md) | Decision | Direct SDK integration approach |
| [SPEC-INTEGRATION-MOLTBOT-COMPSI-SDK.md](./SPEC-INTEGRATION-MOLTBOT-COMPSI-SDK.md) | Specification | Complete technical implementation |
| [GUIDE-MOLTBOT-COMPSI-IMPLEMENTATION.md](./GUIDE-MOLTBOT-COMPSI-IMPLEMENTATION.md) | Guide | Step-by-step implementation for LLM agents |

**Key Features**:
- 4 Assessment Frameworks: Morality (LCSH), Virtue, Ethics, Operational Excellence
- Role-based threshold configuration
- 9-state assessment lifecycle
- Cryptographic audit trail
- Chat-based assessment UI

---

### Codebase Issue Analysis

Comprehensive security and technical debt analysis of the Moltbot codebase.

| Document | Category | Priority |
|----------|----------|----------|
| [SPEC-ISSUES-1_0-SECURITY-UPDATED.md](./SPEC-ISSUES-1_0-SECURITY-UPDATED.md) | Security | P0 |
| [SPEC-ISSUES-2_0-COMMAND-INJECTION-UPDATED.md](./SPEC-ISSUES-2_0-COMMAND-INJECTION-UPDATED.md) | Security - Injection | P0 |
| [SPEC-ISSUES-3_0-FORM-VALIDATION-UPDATED.md](./SPEC-ISSUES-3_0-FORM-VALIDATION-UPDATED.md) | Form & Input | P1 |
| [SPEC-ISSUES-5_0-IMPROVEMENTS-UPDATED.md](./SPEC-ISSUES-5_0-IMPROVEMENTS-UPDATED.md) | Improvements | P2-P3 |
| [Archive/SPEC-ISSUES-4.0-TECHNICAL-DEBT.md](./Archive/SPEC-ISSUES-4.0-TECHNICAL-DEBT.md) | Technical Debt | P2 |
| [Archive/SPEC-ISSUES-6.0-STRUCTURAL.md](./Archive/SPEC-ISSUES-6.0-STRUCTURAL.md) | Architecture | P2 |
| [Archive/SPEC-ISSUES-7.0-ADDITIONAL-CONCERNS.md](./Archive/SPEC-ISSUES-7.0-ADDITIONAL-CONCERNS.md) | Miscellaneous | P2-P3 |

---

### Solution Specifications

Detailed solutions for each issue category.

| Document | Addresses |
|----------|-----------|
| [SPEC-SOLUTION-1_0-SECURITY-UPDATED.md](./SPEC-SOLUTION-1_0-SECURITY-UPDATED.md) | Security issues |
| [SPEC-SOLUTION-2_0-COMMAND-INJECTION-UPDATED.md](./SPEC-SOLUTION-2_0-COMMAND-INJECTION-UPDATED.md) | Command injection |
| [SPEC-SOLUTION-3_0-FORM-VALIDATION-UPDATED.md](./SPEC-SOLUTION-3_0-FORM-VALIDATION-UPDATED.md) | Form validation |
| [SPEC-SOLUTION-5_0-IMPROVEMENTS-UPDATED.md](./SPEC-SOLUTION-5_0-IMPROVEMENTS-UPDATED.md) | Improvements |
| [Archive/SPEC-SOLUTION-4.0-TECHNICAL-DEBT.md](./Archive/SPEC-SOLUTION-4.0-TECHNICAL-DEBT.md) | Technical debt |
| [Archive/SPEC-SOLUTION-6.0-STRUCTURAL.md](./Archive/SPEC-SOLUTION-6.0-STRUCTURAL.md) | Structural issues |
| [Archive/SPEC-SOLUTION-7.0-ADDITIONAL-CONCERNS.md](./Archive/SPEC-SOLUTION-7.0-ADDITIONAL-CONCERNS.md) | Additional concerns |

> **Note**: Files in `Archive/` contain the original versions. `*-UPDATED.md` files contain the latest revisions.

---

## Integration Architecture

### How Ethics Gating Works with Data Access

```typescript
// In Moltbot's message handler

// 1. Check ethics gate FIRST
const gateDecision = await assessmentGate.checkAccess(userId, taskType);

if (!gateDecision.allowed) {
  // Prompt user for assessment
  await reply(chatHandler.getAssessmentPrompt(userId));
  return;
}

// 2. User has passed ethics assessment - allow MCP tool access
const mcpResult = await mcpServer.callTool('get_loan_details', params);
```

### Task Sensitivity Levels

| Sensitivity | Ethics Threshold | Example Tasks |
|-------------|------------------|---------------|
| Low | 6/10 all dimensions | View summaries |
| Medium | 7/10 all dimensions | Standard operations |
| High | 8/10 all dimensions | Financial modifications |
| Critical | 9/10 all dimensions | Sensitive data access |

---

## Document Conventions

### Naming Patterns

| Pattern | Purpose | Example |
|---------|---------|---------|
| `SPEC-DECISION-*` | Architecture decisions | `SPEC-DECISION-MOLTBOT-COMPSI-INTEGRATION.md` |
| `SPEC-INTEGRATION-*` | Technical specifications | `SPEC-INTEGRATION-MOLTBOT-COMPSI-SDK.md` |
| `SPEC-ISSUES-*` | Problem documentation | `SPEC-ISSUES-1.0-SECURITY.md` |
| `SPEC-SOLUTION-*` | Solution documentation | `SPEC-SOLUTION-1.0-SECURITY.md` |
| `GUIDE-*` | Implementation guides | `GUIDE-MOLTBOT-COMPSI-IMPLEMENTATION.md` |
| `USER-STORIES-*` | Requirements/stories | `USER-STORIES-COMPSI-MOLTBOT-INTEGRATION.md` |

### Priority Definitions

| Priority | Definition | Response Time |
|----------|------------|---------------|
| **P0** | Critical - Security vulnerabilities, data loss risk | Immediate |
| **P1** | High - Important security/reliability issues | Next sprint |
| **P2** | Medium - Technical debt, improvements | 2-4 sprints |
| **P3** | Low - Nice-to-have enhancements | Backlog |

---

## Implementation Workflow

### For LLM Agents (BB, Claude, etc.)

```
1. Read SPEC-DECISION document (understand WHY)
      ↓
2. Read SPEC-INTEGRATION document (understand WHAT)
      ↓
3. Follow GUIDE document step-by-step (understand HOW)
      ↓
4. Implementation complete
```

### For Human Developers

```
1. Review USER-STORIES for requirements
      ↓
2. Read SPEC-DECISION for architecture context
      ↓
3. Use SPEC-INTEGRATION as technical reference
      ↓
4. Use GUIDE for implementation checklist
```

---

## Quick Links

### Start Here

- **Understanding the Platform**: Read this README
- **MCP Integration**: Start with [SPEC-DECISION-MCP](./SPEC-DECISION-MOLTBOT-INTEGRATION-MCP-ENTERPRISE-DATA.md)
- **Ethics Integration**: Start with [USER-STORIES-COMPSI](./USER-STORIES-COMPSI-MOLTBOT-INTEGRATION.md)

### Implementation Ready

- **MCP Implementation**: [GUIDE-MCP](./GUIDE-MOLTBOT-MCP-ENTERPRISE-INTEGRATION.md)
- **Compsi Implementation**: [GUIDE-COMPSI](./GUIDE-MOLTBOT-COMPSI-IMPLEMENTATION.md)

### Technical Reference

- **MCP Tools (18 tools)**: [SPEC-INTEGRATION-MCP](./SPEC-INTEGRATION-MOLT-TO-MCP-ENT-DATA.md)
- **Compsi SDK (8 modules)**: [SPEC-INTEGRATION-COMPSI](./SPEC-INTEGRATION-MOLTBOT-COMPSI-SDK.md)

---

## File Count Summary

| Category | Documents |
|----------|-----------|
| Enterprise MCP Integration | 3 |
| Compsi SDK Integration | 4 |
| Issue Specifications (Updated + Archive) | 4 + 3 |
| Solution Specifications (Updated + Archive) | 4 + 3 |
| **Total** | **21 + README** |

---

**Maintainer**: Development Team  
**Repository**: https://github.com/spar65/moltbot-enterprise  
**Last Updated**: 2026-01-28
