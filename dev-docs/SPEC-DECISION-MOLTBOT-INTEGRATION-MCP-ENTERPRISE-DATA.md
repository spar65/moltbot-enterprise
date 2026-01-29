# SPEC-DECISION: Moltbot Integration with Enterprise MCP Data Services

**Document ID**: SPEC-DECISION-MOLTBOT-INTEGRATION-MCP-ENTERPRISE-DATA  
**Version**: 1.0  
**Date Created**: 2026-01-28  
**Status**: Approved  
**Decision**: MCP Server Integration via stdio

---

## Executive Summary

This document records the architectural decision to integrate Moltbot with enterprise data services (specifically LoanOfficerAI-MCP-POC) using the **MCP Server (stdio) pattern**. This approach was selected over HTTP API integration and plugin/extension approaches after careful security analysis.

---

## Decision Context

### Problem Statement

Moltbot needs to integrate with enterprise data systems that provide:
- Sensitive financial data (loan information, borrower details)
- Risk assessment functions (default risk, collateral evaluation)
- Predictive analytics (market impact, maintenance forecasting)

The integration must:
1. Maintain security for sensitive enterprise data
2. Provide reliable, auditable access to 18+ MCP functions
3. Minimize attack surface
4. Support enterprise compliance requirements
5. Integrate cleanly with Moltbot's existing architecture

### Options Evaluated

| Option | Description | Security Rating |
|--------|-------------|-----------------|
| **Option 1: MCP Server (stdio)** | Spawn MCP server as child process, communicate via stdin/stdout | ⭐⭐⭐⭐ |
| **Option 2: HTTP API Integration** | Run LoanOfficer as separate HTTP service, call via REST | ⭐⭐⭐ |
| **Option 3: Plugin/Extension** | Bundle LoanOfficer code as Moltbot extension | ⭐⭐ |

---

## Decision

### Selected Approach: Option 1 - MCP Server via stdio

We will integrate the LoanOfficerAI enterprise data service as an **MCP Server** that Moltbot spawns as a child process, communicating via stdio (stdin/stdout pipes).

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         APPROVED ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   MOLTBOT PROCESS                         ENTERPRISE MCP SERVER         │
│   ┌───────────────────────┐              ┌───────────────────────┐     │
│   │                       │    spawn     │                       │     │
│   │   Moltbot Gateway     ├─────────────►│  LoanOfficer MCP      │     │
│   │                       │              │  Server Process       │     │
│   │   ┌───────────────┐   │    stdio     │                       │     │
│   │   │               │   │   (pipes)    │   ┌───────────────┐   │     │
│   │   │  MCP Client   │◄──┼──────────────┼──►│  MCP Handler  │   │     │
│   │   │               │   │              │   └───────┬───────┘   │     │
│   │   └───────────────┘   │              │           │           │     │
│   │                       │              │   ┌───────▼───────┐   │     │
│   │   ┌───────────────┐   │              │   │  18 MCP       │   │     │
│   │   │               │   │              │   │  Functions    │   │     │
│   │   │  AI Agent     │   │              │   └───────┬───────┘   │     │
│   │   │               │   │              │           │           │     │
│   │   └───────────────┘   │              │   ┌───────▼───────┐   │     │
│   │                       │              │   │  SQL Server   │   │     │
│   └───────────────────────┘              │   │  (Enterprise) │   │     │
│                                          │   └───────────────┘   │     │
│                                          └───────────────────────┘     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Rationale

### Security Justification

| Security Factor | MCP Server (stdio) | Why This Matters |
|-----------------|-------------------|------------------|
| **Network Exposure** | ✅ Zero | No localhost ports, no network stack vulnerabilities |
| **Process Isolation** | ✅ Strong | Separate process with own memory space |
| **Attack Surface** | ✅ Minimal | Only MCP JSON-RPC protocol, no HTTP/REST overhead |
| **Credential Protection** | ✅ Good | DB credentials stay in MCP server process |
| **Audit Trail** | ✅ Centralized | All access flows through single MCP interface |
| **Blast Radius** | ✅ Limited | MCP server crash doesn't affect Moltbot core |

### Comparison with Rejected Options

#### Why Not HTTP API (Option 2)?

```
REJECTED: HTTP API Integration

Risks:
- localhost:3001 port accessible by any local process
- Full HTTP stack attack surface (request smuggling, header injection, etc.)
- JWT tokens transmitted (even on localhost)
- Additional complexity for TLS on localhost

Trade-off: Better process isolation but higher network risk
Decision: Security risk outweighs isolation benefit
```

#### Why Not Plugin/Extension (Option 3)?

```
REJECTED: Plugin/Extension Integration

Risks:
- Plugin code runs in Moltbot process with full permissions
- No isolation - memory corruption affects entire system
- All Moltbot credentials accessible to plugin code
- Compromise of plugin = compromise of Moltbot
- Harder to audit and update independently

Trade-off: Simpler deployment but unacceptable security posture
Decision: Security risk unacceptable for enterprise data
```

---

## Technical Benefits

### 1. Native MCP Protocol Support

Moltbot already has MCP infrastructure:
- MCP client implementation exists
- Tool discovery via MCP protocol
- Standardized request/response format

### 2. Stdio Communication Security

```typescript
// Stdio pipes provide:
// - No network exposure
// - Only parent process can communicate
// - No IP-based attacks possible
// - No port scanning vulnerabilities
// - No TLS/certificate management needed
```

### 3. Process Lifecycle Management

```typescript
// Moltbot manages MCP server lifecycle:
// - Start on demand or at gateway startup
// - Health monitoring via heartbeat
// - Automatic restart on crash
// - Graceful shutdown propagation
```

### 4. Credential Isolation

```
MOLTBOT PROCESS                    MCP SERVER PROCESS
┌────────────────────┐            ┌────────────────────┐
│                    │            │                    │
│  MOLTBOT_API_KEY   │            │  DB_SERVER         │
│  ANTHROPIC_KEY     │            │  DB_USER           │
│  OPENAI_KEY        │            │  DB_PASSWORD       │
│  TELEGRAM_TOKEN    │            │  OPENAI_API_KEY    │
│                    │            │                    │
│  (Moltbot secrets  │            │  (Enterprise DB    │
│   stay here)       │            │   secrets here)    │
│                    │            │                    │
└────────────────────┘            └────────────────────┘
        ↑                                  ↑
        │                                  │
        └──── SEPARATE PROCESSES ──────────┘
```

---

## Implementation Implications

### What This Decision Requires

1. **MCP Server Wrapper for LoanOfficerAI**
   - New `mcp-server.js` entry point using stdio transport
   - JSON-RPC message parsing
   - Function routing to existing MCP functions

2. **Moltbot MCP Client Configuration**
   - Server definition in MCP config
   - Environment variable passing
   - Health monitoring setup

3. **Security Enhancements**
   - Request authentication (optional but recommended)
   - Input validation at MCP boundary
   - Comprehensive audit logging
   - Rate limiting per function

4. **Documentation Updates**
   - Integration guide for operators
   - Security configuration guide
   - Troubleshooting documentation

### What This Decision Avoids

1. **No network security configuration** - No TLS, no firewall rules, no port management
2. **No HTTP server maintenance** - No Express security updates, no CORS config
3. **No token management** - No JWT issuance, refresh, or revocation
4. **No API versioning** - MCP protocol handles capability negotiation

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| MCP server crash | Medium | Low | Auto-restart, graceful degradation |
| Malformed MCP messages | Low | Low | Schema validation at boundary |
| Resource exhaustion | Low | Medium | Rate limiting, timeout enforcement |
| Credential leak via logs | Medium | High | Log redaction, audit log encryption |
| Child process hang | Low | Medium | Heartbeat monitoring, timeout kill |

---

## Success Criteria

### Security

- [ ] Zero network ports exposed by integration
- [ ] All database credentials isolated to MCP server process
- [ ] 100% of MCP calls logged to audit trail
- [ ] No sensitive data in Moltbot logs

### Functionality

- [ ] All 18 LoanOfficer MCP functions accessible from Moltbot
- [ ] Response time < 500ms for simple queries
- [ ] Automatic recovery from MCP server crashes
- [ ] Graceful handling of database unavailability

### Operations

- [ ] MCP server starts automatically with Moltbot gateway
- [ ] Health status visible in `moltbot status`
- [ ] Clear error messages for configuration issues
- [ ] Documented troubleshooting procedures

---

## Approval

| Role | Name | Date | Decision |
|------|------|------|----------|
| Security Review | - | 2026-01-28 | Approved |
| Architecture Review | - | 2026-01-28 | Approved |
| Product Owner | - | 2026-01-28 | Approved |

---

## References

- **SPEC-ISSUES-1.0-SECURITY.md** - Security vulnerability analysis
- **SPEC-ISSUES-2.0-COMMAND-INJECTION.md** - Command injection prevention
- **SPEC-SOLUTION-1.0-SECURITY.md** - Security remediation patterns
- **LoanOfficerAI-MCP-POC/README.md** - Source MCP implementation
- **Moltbot CLAUDE.md** - Project guidelines and MCP infrastructure

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-28 | Architecture Team | Initial decision document |

---

**Document Status**: APPROVED  
**Next Step**: Proceed to SPEC-INTEGRATION-MOLT-TO-MCP-ENT-DATA.md
