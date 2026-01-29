# SPEC-ISSUES 1.0: Security Vulnerabilities

**Document ID**: SPEC-ISSUES-1.0  
**Category**: Security  
**Priority**: P0 (Critical)  
**Date Created**: 2026-01-28  
**Status**: Open  
**Related Solutions**: SPEC-SOLUTION-1.0 (to be created)

---

## Executive Summary

This document catalogs security vulnerabilities identified in the Moltbot codebase through static analysis. The issues range from command injection risks to insufficient input validation and credential handling concerns.

---

## Issue Registry

### 1.1 Command Execution Attack Surface

**Severity**: HIGH  
**Files Affected**: 84 files (see Appendix A)

#### Description

The codebase contains extensive use of `child_process` functions (`exec`, `spawn`, `execSync`, `spawnSync`) across 84 files. While some files implement proper security controls, the attack surface is significant.

#### Key Locations

| File | Risk Level | Notes |
|------|------------|-------|
| `src/agents/bash-tools.exec.ts` | HIGH | Primary shell execution tool for AI agents |
| `src/process/exec.ts` | MEDIUM | General command execution utilities |
| `src/infra/ssh-tunnel.ts` | HIGH | SSH command execution |
| `src/browser/chrome.ts` | MEDIUM | Browser process spawning |
| `src/daemon/launchd.ts` | HIGH | System daemon management |
| `src/daemon/systemd.ts` | HIGH | System service management |

#### Evidence

From `src/process/exec.ts`:
```typescript
const child = spawn(argv[0], argv.slice(1), {
  stdio,
  cwd,
  env: resolvedEnv,
  windowsVerbatimArguments,
});
```

The `argv` array originates from various sources, some of which may include user-controlled input.

#### Risk Assessment

- **Attack Vector**: Malicious input passed through messaging channels could potentially reach command execution
- **Impact**: Remote code execution, system compromise
- **Exploitability**: Requires bypassing existing security controls (allowlists, sandboxing)

#### Current Mitigations (Partial)

- `src/infra/exec-approvals.ts` implements allowlist-based execution approval
- `src/agents/bash-tools.exec.ts` has `ExecSecurity` configuration
- Sandbox configurations exist in `src/agents/sandbox/`

---

### 1.2 Missing CORS Configuration

**Severity**: MEDIUM  
**Files Affected**: Gateway HTTP endpoints

#### Description

No CORS (Cross-Origin Resource Sharing) headers were found in the codebase. While the gateway primarily serves localhost, this could become an issue for:

- Remote gateway access via Tailscale
- WebSocket connections from external origins
- Control UI served from different origins

#### Evidence

Search for `Access-Control-Allow` returned no results in `/src`.

#### Risk Assessment

- **Attack Vector**: Cross-site request forgery from malicious websites
- **Impact**: Unauthorized API calls if gateway is exposed
- **Exploitability**: Low if gateway is localhost-only; increases with remote access

---

### 1.3 Sensitive Data in Logs

**Severity**: MEDIUM  
**Files Affected**: 784 files with password/secret/token/apikey references

#### Description

While `src/logging/redact.ts` implements sensitive data redaction, the coverage may be incomplete. The codebase has 7,675 references to sensitive keywords across 784 files.

#### Current Redaction Patterns

From `src/logging/redact.ts`:
```typescript
const DEFAULT_REDACT_PATTERNS: string[] = [
  String.raw`\b[A-Z0-9_]*(?:KEY|TOKEN|SECRET|PASSWORD|PASSWD)\b\s*[=:]\s*(["']?)([^\s"'\\]+)\1`,
  String.raw`\b(sk-[A-Za-z0-9_-]{8,})\b`,  // OpenAI
  String.raw`\b(ghp_[A-Za-z0-9]{20,})\b`,  // GitHub PAT
  // ... more patterns
];
```

#### Gaps Identified

1. Redaction is opt-in (`mode: "tools"`) not opt-out
2. Custom token formats may not be covered
3. No enforcement that `redactSensitiveText()` is called before logging

---

### 1.4 innerHTML Usage

**Severity**: MEDIUM  
**Files Affected**: 2 files

| File | Usage Context |
|------|---------------|
| `src/browser/cdp.ts` | Browser automation (controlled context) |
| `src/canvas-host/server.ts` | Canvas rendering |

#### Risk Assessment

While limited in scope, innerHTML usage with untrusted content can lead to XSS. Need to verify content sources.

---

### 1.5 Environment Variable Exposure

**Severity**: MEDIUM-HIGH  
**Files Affected**: 252 files with 1,728 `process.env` references

#### Description

Extensive direct access to `process.env` across the codebase. While `src/config/` provides centralized configuration, many files access environment variables directly.

#### Concerns

1. No centralized validation for all env vars at startup
2. Potential for env var typos (compile-time safety gap)
3. Inconsistent usage patterns across modules

#### Recommendation

Implement centralized type-safe config following `.cursor/rules/011-env-var-security.mdc` pattern with Zod validation.

---

### 1.6 Rate Limiting Gaps

**Severity**: MEDIUM  
**Files Affected**: Primarily Telegram integration (54 files)

#### Description

Rate limiting implementation is primarily focused on Telegram (via grammY throttler). Other channels and gateway endpoints may lack rate limiting.

#### Evidence

Rate limiting found in:
- Telegram: `src/telegram/bot.ts` uses `@grammyjs/transformer-throttler`
- Discord: Some rate limit handling in `src/discord/send.*.ts`
- Memory/embedding: `src/memory/manager.ts`

#### Gaps

- Gateway WebSocket connections
- HTTP API endpoints
- Slack webhook processing
- Signal message handling

---

## Appendix A: Command Execution Files

<details>
<summary>84 files with child_process usage</summary>

```
src/process/exec.ts
src/process/spawn-utils.ts
src/process/child-process-bridge.ts
src/agents/bash-tools.exec.ts
src/agents/bash-process-registry.ts
src/agents/shell-utils.ts
src/infra/ssh-tunnel.ts
src/infra/tailscale.ts
src/infra/restart.ts
src/browser/chrome.ts
src/daemon/launchd.ts
src/daemon/systemd.ts
src/daemon/schtasks.ts
... (71 more files)
```

</details>

---

## Appendix B: Security Controls Already in Place

1. **Exec Approvals System**: `src/infra/exec-approvals.ts`
2. **External Content Wrapping**: `src/security/external-content.ts`
3. **Sensitive Data Redaction**: `src/logging/redact.ts`
4. **Sandbox Configuration**: `src/agents/sandbox/`
5. **Pairing/Allowlist System**: `src/pairing/`
6. **DM Policy Controls**: Channel-specific DM policies

---

## Next Steps

1. Create SPEC-SOLUTION-1.0 with remediation plan
2. Prioritize fixes by severity and exploitability
3. Add security-focused tests for command execution paths
4. Implement comprehensive rate limiting
5. Add CORS headers for remote gateway access

---

**Document Maintainer**: Security Review Team  
**Last Updated**: 2026-01-28
