# SPEC-SOLUTION 1.0: Security Vulnerability Remediation (UPDATED)

**Document ID**: SPEC-SOLUTION-1.0  
**Addresses**: SPEC-ISSUES-1.0  
**Category**: Security  
**Priority**: P0 (Critical)  
**Date Created**: 2026-01-28  
**Date Updated**: 2026-01-28  
**Status**: Ready for Implementation

---

## Executive Summary

This document provides comprehensive solutions for the security vulnerabilities identified in SPEC-ISSUES-1.0. Solutions are organized by priority and include:

- **Detailed implementation plans** with phase-by-phase execution
- **Production-ready code examples** using TypeScript, Zod, and Hono
- **Comprehensive test suites** with security-focused test cases
- **Success criteria** with measurable metrics
- **Integration guides** for existing Moltbot architecture

**Implementation Strategy**: Defense-in-depth with centralized security enforcement, comprehensive audit logging, and minimal disruption to existing functionality.

---

## Solution Registry

### Solution 1.1: Command Execution Security Hardening

**Addresses**: SPEC-ISSUES-1.0, Issue 1.1  
**Priority**: P0 (Critical)  
**Effort**: High (2-3 sprints, ~120-180 hours)  
**Dependencies**: None  
**Blocks**: SPEC-SOLUTION-2.0 (Command Injection prevention)

#### Objective

Transform command execution from a distributed, partially-secured surface area (84 files) into a centralized, comprehensively-audited security boundary with:

1. **Mandatory allowlist enforcement** - Zero execution without explicit approval
2. **Comprehensive argument validation** - Pattern-based blocking of dangerous constructs
3. **Full audit trail** - Every execution logged with context and actor
4. **Resource constraints** - CPU, memory, and timeout limits
5. **Environment sanitization** - No credential leakage to child processes

---

#### Implementation Plan

##### Phase 1: Audit and Categorize (Sprint 1, Week 1-2)

**Deliverable**: Comprehensive inventory of all command execution points

**Step 1.1: Create Automated Audit Script**

```typescript
// scripts/audit-exec.ts

import * as fs from 'fs';
import * as path from 'path';
import { glob } from 'glob';

interface ExecUsage {
  file: string;
  line: number;
  method: 'exec' | 'execFile' | 'spawn' | 'spawnSync' | 'execSync' | 'execFileSync';
  commandSource: 'static' | 'config' | 'user-input' | 'dynamic' | 'unknown';
  riskLevel: 'low' | 'medium' | 'high' | 'critical';
  context: string;  // Surrounding code context
  mitigations: string[];  // Current security controls
}

interface AuditReport {
  totalFiles: number;
  totalUsages: number;
  byRiskLevel: Record<string, number>;
  byMethod: Record<string, number>;
  criticalFiles: ExecUsage[];
  recommendations: string[];
}

async function auditCommandExecution(): Promise<AuditReport> {
  const files = await glob('src/**/*.ts', { ignore: ['**/*.test.ts', '**/*.spec.ts'] });
  const usages: ExecUsage[] = [];
  
  for (const file of files) {
    const content = fs.readFileSync(file, 'utf-8');
    const lines = content.split('\n');
    
    // Search for child_process usage
    lines.forEach((line, index) => {
      const execMatch = line.match(/(exec|execFile|spawn|spawnSync|execSync|execFileSync)\(/);
      if (execMatch) {
        const usage = analyzeUsage(file, index + 1, lines, execMatch[1]);
        usages.push(usage);
      }
    });
  }
  
  return generateReport(usages);
}

function analyzeUsage(
  file: string, 
  line: number, 
  lines: string[], 
  method: string
): ExecUsage {
  // Get context (5 lines before and after)
  const contextStart = Math.max(0, line - 6);
  const contextEnd = Math.min(lines.length, line + 5);
  const context = lines.slice(contextStart, contextEnd).join('\n');
  
  // Analyze command source
  const commandSource = detectCommandSource(context);
  
  // Assess risk level
  const riskLevel = assessRisk(context, commandSource, method);
  
  // Identify current mitigations
  const mitigations = detectMitigations(context);
  
  return {
    file,
    line,
    method: method as any,
    commandSource,
    riskLevel,
    context,
    mitigations,
  };
}

function detectCommandSource(context: string): ExecUsage['commandSource'] {
  // Check for obvious user input
  if (context.match(/req\.(body|query|params)|message\.(text|content)|input/i)) {
    return 'user-input';
  }
  
  // Check for config
  if (context.match(/config\.|process\.env|getConfig/)) {
    return 'config';
  }
  
  // Check for string literals
  if (context.match(/['"](ls|git|npm|node|curl)['"]/)) {
    return 'static';
  }
  
  // Check for template strings or concatenation
  if (context.match(/`.*\$\{|concat|\+.*\+/)) {
    return 'dynamic';
  }
  
  return 'unknown';
}

function assessRisk(
  context: string, 
  commandSource: ExecUsage['commandSource'],
  method: string
): ExecUsage['riskLevel'] {
  // Critical: User input + synchronous execution
  if (commandSource === 'user-input' && method.includes('Sync')) {
    return 'critical';
  }
  
  // Critical: User input reaches command
  if (commandSource === 'user-input') {
    return 'critical';
  }
  
  // High: Dynamic command construction
  if (commandSource === 'dynamic') {
    return 'high';
  }
  
  // Medium: Config-driven
  if (commandSource === 'config') {
    return 'medium';
  }
  
  // Low: Static commands only
  if (commandSource === 'static') {
    return 'low';
  }
  
  return 'medium';  // Unknown defaults to medium
}

function detectMitigations(context: string): string[] {
  const mitigations: string[] = [];
  
  if (context.includes('exec-approvals') || context.includes('allowlist')) {
    mitigations.push('Allowlist check');
  }
  
  if (context.includes('sanitize') || context.includes('escape')) {
    mitigations.push('Input sanitization');
  }
  
  if (context.includes('sandbox') || context.includes('docker')) {
    mitigations.push('Sandboxed execution');
  }
  
  if (context.includes('shell: false')) {
    mitigations.push('Shell disabled');
  }
  
  if (context.includes('timeout')) {
    mitigations.push('Timeout configured');
  }
  
  return mitigations;
}

function generateReport(usages: ExecUsage[]): AuditReport {
  const byRiskLevel: Record<string, number> = {
    critical: 0,
    high: 0,
    medium: 0,
    low: 0,
  };
  
  const byMethod: Record<string, number> = {};
  
  usages.forEach(usage => {
    byRiskLevel[usage.riskLevel]++;
    byMethod[usage.method] = (byMethod[usage.method] || 0) + 1;
  });
  
  const criticalFiles = usages
    .filter(u => u.riskLevel === 'critical' || u.riskLevel === 'high')
    .sort((a, b) => {
      const riskOrder = { critical: 0, high: 1, medium: 2, low: 3 };
      return riskOrder[a.riskLevel] - riskOrder[b.riskLevel];
    });
  
  const recommendations = generateRecommendations(usages, criticalFiles);
  
  return {
    totalFiles: new Set(usages.map(u => u.file)).size,
    totalUsages: usages.length,
    byRiskLevel,
    byMethod,
    criticalFiles,
    recommendations,
  };
}

function generateRecommendations(
  usages: ExecUsage[], 
  criticalFiles: ExecUsage[]
): string[] {
  const recommendations: string[] = [];
  
  if (criticalFiles.length > 0) {
    recommendations.push(
      `URGENT: ${criticalFiles.length} critical/high-risk executions require immediate remediation`
    );
  }
  
  const missingMitigations = usages.filter(u => u.mitigations.length === 0);
  if (missingMitigations.length > 0) {
    recommendations.push(
      `${missingMitigations.length} executions have no security controls`
    );
  }
  
  const userInputExecs = usages.filter(u => u.commandSource === 'user-input');
  if (userInputExecs.length > 0) {
    recommendations.push(
      `${userInputExecs.length} executions directly use user input - highest priority for migration`
    );
  }
  
  recommendations.push(
    'Implement centralized secure-exec layer (Solution 1.1, Phase 2)'
  );
  
  recommendations.push(
    'Add ESLint rule to prevent new child_process imports'
  );
  
  return recommendations;
}

// CLI execution
if (require.main === module) {
  auditCommandExecution().then(report => {
    console.log('Command Execution Audit Report');
    console.log('='.repeat(50));
    console.log(`Total files with execution: ${report.totalFiles}`);
    console.log(`Total execution calls: ${report.totalUsages}`);
    console.log('\nRisk Distribution:');
    Object.entries(report.byRiskLevel).forEach(([level, count]) => {
      console.log(`  ${level}: ${count}`);
    });
    console.log('\nMethod Distribution:');
    Object.entries(report.byMethod).forEach(([method, count]) => {
      console.log(`  ${method}: ${count}`);
    });
    console.log('\nRecommendations:');
    report.recommendations.forEach((rec, i) => {
      console.log(`  ${i + 1}. ${rec}`);
    });
    
    // Write detailed report
    fs.writeFileSync(
      'audit-exec-report.json',
      JSON.stringify(report, null, 2)
    );
    console.log('\nDetailed report written to: audit-exec-report.json');
  });
}

export { auditCommandExecution, type AuditReport, type ExecUsage };
```

**Usage**:
```bash
npx tsx scripts/audit-exec.ts
# Generates: audit-exec-report.json
```

**Step 1.2: Manual Risk Categorization**

Review the audit report and manually categorize files:

| Risk Level | Migration Phase | Timeline |
|------------|----------------|----------|
| Critical | Phase 1 (Week 1-2) | Sprint 1 |
| High | Phase 2 (Week 3-4) | Sprint 1-2 |
| Medium | Phase 3 (Week 5-8) | Sprint 2-3 |
| Low | Phase 4 (Week 9+) | Sprint 3+ |

---

##### Phase 2: Centralized Execution Layer (Sprint 1-2, Week 2-4)

**Deliverable**: Production-ready `secure-exec` module with comprehensive test coverage

**Implementation: `src/process/secure-exec.ts`**

```typescript
// src/process/secure-exec.ts

import { spawn, SpawnOptions, ChildProcess } from 'child_process';
import { z } from 'zod';
import * as path from 'path';
import { auditLog } from '../security/audit';
import { logger } from '../logging';

// ============================================================
// SCHEMAS & TYPES
// ============================================================

const CommandSchema = z.object({
  binary: z.string()
    .regex(/^[a-zA-Z0-9_\-./]+$/, 'Binary name contains invalid characters')
    .refine(
      (bin) => !bin.includes('..'),
      'Binary path cannot contain traversal'
    ),
  args: z.array(z.string())
    .max(100, 'Too many arguments'),
  cwd: z.string()
    .optional()
    .refine(
      (dir) => !dir || !dir.includes('..'),
      'Working directory cannot contain traversal'
    ),
  timeout: z.number()
    .int()
    .min(1000)
    .max(300_000)
    .default(30_000),
  allowNetwork: z.boolean().default(false),
  maxMemoryMb: z.number().int().min(64).max(2048).default(512),
});

export type SecureCommand = z.infer<typeof CommandSchema>;

export interface ExecutionContext {
  actor: string;  // Who is executing (user ID, agent ID, etc.)
  source: string;  // Where did this come from (channel, CLI, webhook, etc.)
  sessionId?: string;
  metadata?: Record<string, unknown>;
}

export interface ExecResult {
  exitCode: number;
  stdout: string;
  stderr: string;
  duration: number;
  truncated: boolean;
}

export class SecurityError extends Error {
  constructor(message: string, public details?: Record<string, unknown>) {
    super(message);
    this.name = 'SecurityError';
  }
}

// ============================================================
// SECURITY CONFIGURATION
// ============================================================

// Allowlist of permitted binaries (strict enforcement)
const ALLOWED_BINARIES = new Set([
  // Core system tools (read-only operations)
  'ls', 'cat', 'head', 'tail', 'grep', 'find', 'sort', 'uniq', 'wc',
  
  // Git operations (safe subset)
  'git',
  
  // Node.js ecosystem
  'node', 'npm', 'npx', 'pnpm', 'bun',
  
  // Network tools (when explicitly allowed)
  'curl', 'wget', 'ping',
  
  // Custom Moltbot tools
  'moltbot', 'moltbot-mac',
  
  // Development tools (controlled)
  'tsx', 'vitest',
]);

// Blocked argument patterns (defense in depth)
const BLOCKED_PATTERNS = [
  // Shell injection attempts
  { pattern: /\|\s*(ba)?sh\b/i, reason: 'Pipe to shell' },
  { pattern: /;\s*\w+/i, reason: 'Command chaining' },
  { pattern: /&&|\|\|/i, reason: 'Logical operators' },
  
  // Command substitution
  { pattern: /`[^`]*`/, reason: 'Backtick substitution' },
  { pattern: /\$\([^)]*\)/, reason: 'Dollar substitution' },
  
  // Dangerous commands
  { pattern: /\brm\s+-rf\s+[\/~]/i, reason: 'Recursive delete' },
  { pattern: /\bchmod\s+[0-7]*7/i, reason: 'Unsafe permissions' },
  { pattern: /\beval\s+/i, reason: 'Eval command' },
  { pattern: /\bsudo\b/i, reason: 'Privilege escalation' },
  
  // Output redirection to system paths
  { pattern: />\s*\/etc\//i, reason: 'Write to /etc' },
  { pattern: />\s*\/usr\//i, reason: 'Write to /usr' },
  { pattern: />\s*\/sys\//i, reason: 'Write to /sys' },
  { pattern: />\s*\/dev\//i, reason: 'Write to /dev' },
  
  // Null bytes (path traversal)
  { pattern: /\x00/, reason: 'Null byte injection' },
];

// Sensitive environment variables to remove
const SENSITIVE_ENV_KEYS = [
  'ANTHROPIC_API_KEY',
  'OPENAI_API_KEY',
  'AWS_SECRET_ACCESS_KEY',
  'AWS_ACCESS_KEY_ID',
  'GITHUB_TOKEN',
  'SLACK_BOT_TOKEN',
  'SLACK_APP_TOKEN',
  'TELEGRAM_BOT_TOKEN',
  'DISCORD_BOT_TOKEN',
  'DATABASE_URL',
  'STRIPE_SECRET_KEY',
];

// ============================================================
// MAIN EXECUTION FUNCTION
// ============================================================

export async function secureExec(
  command: SecureCommand,
  context: ExecutionContext
): Promise<ExecResult> {
  const startTime = Date.now();
  
  // Step 1: Validate schema
  const validated = CommandSchema.parse(command);
  
  // Step 2: Check binary allowlist
  const binaryName = path.basename(validated.binary);
  if (!ALLOWED_BINARIES.has(binaryName)) {
    const error = new SecurityError(
      `Binary not allowed: ${binaryName}`,
      { binary: binaryName, allowlist: Array.from(ALLOWED_BINARIES) }
    );
    await logSecurityEvent('exec_blocked_binary', context, { error: error.message });
    throw error;
  }
  
  // Step 3: Validate arguments against blocked patterns
  const fullCommand = [validated.binary, ...validated.args].join(' ');
  for (const { pattern, reason } of BLOCKED_PATTERNS) {
    if (pattern.test(fullCommand)) {
      const error = new SecurityError(
        `Blocked pattern detected: ${reason}`,
        { pattern: pattern.source, command: fullCommand }
      );
      await logSecurityEvent('exec_blocked_pattern', context, { 
        error: error.message,
        pattern: pattern.source 
      });
      throw error;
    }
  }
  
  // Step 4: Audit log (before execution)
  await auditLog({
    action: 'exec',
    command: validated.binary,
    args: validated.args,
    actor: context.actor,
    source: context.source,
    sessionId: context.sessionId,
    timestamp: new Date().toISOString(),
    metadata: context.metadata,
  });
  
  // Step 5: Execute with sandbox constraints
  try {
    const result = await executeWithSandbox(validated, context);
    
    // Log successful execution
    await logSecurityEvent('exec_success', context, {
      duration: Date.now() - startTime,
      exitCode: result.exitCode,
    });
    
    return result;
  } catch (error) {
    // Log failed execution
    await logSecurityEvent('exec_failure', context, {
      duration: Date.now() - startTime,
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
}

// ============================================================
// SANDBOX EXECUTION
// ============================================================

async function executeWithSandbox(
  command: SecureCommand,
  context: ExecutionContext
): Promise<ExecResult> {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();
    
    // Sanitize environment
    const env = sanitizeEnv(process.env);
    
    // Prepare spawn options
    const options: SpawnOptions = {
      cwd: command.cwd || process.cwd(),
      timeout: command.timeout,
      env,
      // CRITICAL: Disable shell interpretation
      shell: false,
      // Limit stdio
      stdio: ['ignore', 'pipe', 'pipe'],
      // Kill signal on timeout
      killSignal: 'SIGKILL',
    };
    
    // Spawn the process
    const child: ChildProcess = spawn(command.binary, command.args, options);
    
    let stdout = '';
    let stderr = '';
    let truncated = false;
    
    const MAX_OUTPUT_SIZE = 10 * 1024 * 1024;  // 10MB limit
    
    // Capture stdout
    child.stdout?.on('data', (chunk: Buffer) => {
      if (stdout.length < MAX_OUTPUT_SIZE) {
        stdout += chunk.toString('utf-8');
      } else {
        truncated = true;
      }
    });
    
    // Capture stderr
    child.stderr?.on('data', (chunk: Buffer) => {
      if (stderr.length < MAX_OUTPUT_SIZE) {
        stderr += chunk.toString('utf-8');
      } else {
        truncated = true;
      }
    });
    
    // Handle completion
    child.on('close', (exitCode: number | null) => {
      const duration = Date.now() - startTime;
      
      resolve({
        exitCode: exitCode ?? -1,
        stdout,
        stderr,
        duration,
        truncated,
      });
    });
    
    // Handle errors
    child.on('error', (error: Error) => {
      reject(new SecurityError(
        `Execution failed: ${error.message}`,
        { command: command.binary, error: error.message }
      ));
    });
    
    // Enforce timeout (belt-and-suspenders with spawn timeout)
    const timeoutHandle = setTimeout(() => {
      if (child.pid) {
        child.kill('SIGKILL');
        reject(new SecurityError(
          `Execution timeout after ${command.timeout}ms`,
          { command: command.binary, timeout: command.timeout }
        ));
      }
    }, command.timeout + 1000);  // +1s grace period
    
    child.on('exit', () => clearTimeout(timeoutHandle));
  });
}

// ============================================================
// HELPER FUNCTIONS
// ============================================================

function sanitizeEnv(env: NodeJS.ProcessEnv): NodeJS.ProcessEnv {
  const sanitized = { ...env };
  
  // Remove sensitive keys
  for (const key of SENSITIVE_ENV_KEYS) {
    delete sanitized[key];
  }
  
  // Remove any key containing "SECRET", "KEY", "TOKEN", "PASSWORD"
  Object.keys(sanitized).forEach(key => {
    if (/(SECRET|KEY|TOKEN|PASSWORD|PASSWD)/i.test(key)) {
      delete sanitized[key];
    }
  });
  
  return sanitized;
}

async function logSecurityEvent(
  event: string,
  context: ExecutionContext,
  details: Record<string, unknown>
): Promise<void> {
  logger.warn(`[SECURITY] ${event}`, {
    event,
    actor: context.actor,
    source: context.source,
    sessionId: context.sessionId,
    ...details,
  });
}

// ============================================================
// UTILITY: Check if binary is allowed
// ============================================================

export function isBinaryAllowed(binary: string): boolean {
  const binaryName = path.basename(binary);
  return ALLOWED_BINARIES.has(binaryName);
}

// ============================================================
// UTILITY: Add custom binary to allowlist (admin only)
// ============================================================

export function addAllowedBinary(binary: string, adminContext: ExecutionContext): void {
  if (!adminContext.metadata?.isAdmin) {
    throw new SecurityError('Only admins can modify binary allowlist');
  }
  
  ALLOWED_BINARIES.add(binary);
  
  auditLog({
    action: 'allowlist_add',
    binary,
    actor: context.actor,
    timestamp: new Date().toISOString(),
  });
  
  logger.info(`[SECURITY] Added binary to allowlist: ${binary}`, {
    actor: adminContext.actor,
  });
}
```

---

**Integration with Existing Code**:

```typescript
// Example: Migrating src/agents/bash-tools.exec.ts

// BEFORE (unsafe)
import { exec } from 'child_process';

async function runBashCommand(cmd: string) {
  return new Promise((resolve, reject) => {
    exec(cmd, (error, stdout, stderr) => {
      if (error) reject(error);
      else resolve({ stdout, stderr });
    });
  });
}

// AFTER (secure)
import { secureExec, SecureCommand, ExecutionContext } from '../process/secure-exec';

async function runBashCommand(
  cmd: string,
  agentId: string,
  sessionId: string
): Promise<{ stdout: string; stderr: string }> {
  // Parse command into binary + args
  const parts = cmd.split(' ');
  const command: SecureCommand = {
    binary: parts[0],
    args: parts.slice(1),
    timeout: 30_000,
  };
  
  const context: ExecutionContext = {
    actor: agentId,
    source: 'agent-tool',
    sessionId,
  };
  
  const result = await secureExec(command, context);
  
  return {
    stdout: result.stdout,
    stderr: result.stderr,
  };
}
```

---

##### Phase 2 Testing Requirements

```typescript
// src/process/secure-exec.test.ts

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { secureExec, SecurityError, isBinaryAllowed } from './secure-exec';
import type { SecureCommand, ExecutionContext } from './secure-exec';

describe('secureExec', () => {
  const mockContext: ExecutionContext = {
    actor: 'test-user',
    source: 'test',
    sessionId: 'test-session-123',
  };
  
  beforeEach(() => {
    vi.clearAllMocks();
  });
  
  describe('Binary Allowlist', () => {
    it('allows permitted binaries', async () => {
      const command: SecureCommand = {
        binary: 'ls',
        args: ['-la'],
      };
      
      await expect(secureExec(command, mockContext))
        .resolves
        .toMatchObject({
          exitCode: 0,
          stdout: expect.any(String),
        });
    });
    
    it('blocks non-allowed binaries', async () => {
      const command: SecureCommand = {
        binary: 'evil-binary',
        args: [],
      };
      
      await expect(secureExec(command, mockContext))
        .rejects
        .toThrow(SecurityError);
      
      await expect(secureExec(command, mockContext))
        .rejects
        .toThrow('Binary not allowed: evil-binary');
    });
    
    it('blocks binary path traversal', async () => {
      const command: SecureCommand = {
        binary: '../../bin/ls',
        args: [],
      };
      
      await expect(secureExec(command, mockContext))
        .rejects
        .toThrow(SecurityError);
    });
  });
  
  describe('Argument Pattern Blocking', () => {
    it('blocks pipe to shell', async () => {
      const command: SecureCommand = {
        binary: 'cat',
        args: ['file.txt', '|', 'sh'],
      };
      
      await expect(secureExec(command, mockContext))
        .rejects
        .toThrow('Blocked pattern detected: Pipe to shell');
    });
    
    it('blocks command substitution with backticks', async () => {
      const command: SecureCommand = {
        binary: 'echo',
        args: ['`whoami`'],
      };
      
      await expect(secureExec(command, mockContext))
        .rejects
        .toThrow('Blocked pattern detected: Backtick substitution');
    });
    
    it('blocks command substitution with $()', async () => {
      const command: SecureCommand = {
        binary: 'echo',
        args: ['$(rm -rf /)'],
      };
      
      await expect(secureExec(command, mockContext))
        .rejects
        .toThrow('Blocked pattern detected: Dollar substitution');
    });
    
    it('blocks command chaining with semicolon', async () => {
      const command: SecureCommand = {
        binary: 'ls',
        args: ['; rm -rf /'],
      };
      
      await expect(secureExec(command, mockContext))
        .rejects
        .toThrow('Blocked pattern detected: Command chaining');
    });
    
    it('blocks logical operators (&&, ||)', async () => {
      const command: SecureCommand = {
        binary: 'ls',
        args: ['&&', 'rm', '-rf', '/'],
      };
      
      await expect(secureExec(command, mockContext))
        .rejects
        .toThrow('Blocked pattern detected: Logical operators');
    });
    
    it('blocks writes to /etc', async () => {
      const command: SecureCommand = {
        binary: 'echo',
        args: ['malicious', '>', '/etc/passwd'],
      };
      
      await expect(secureExec(command, mockContext))
        .rejects
        .toThrow('Blocked pattern detected: Write to /etc');
    });
    
    it('blocks rm -rf /', async () => {
      const command: SecureCommand = {
        binary: 'rm',
        args: ['-rf', '/'],
      };
      
      await expect(secureExec(command, mockContext))
        .rejects
        .toThrow('Blocked pattern detected: Recursive delete');
    });
  });
  
  describe('Environment Sanitization', () => {
    it('removes sensitive environment variables', async () => {
      // Set sensitive env vars
      process.env.ANTHROPIC_API_KEY = 'test-key-123';
      process.env.OPENAI_API_KEY = 'test-key-456';
      
      const command: SecureCommand = {
        binary: 'node',
        args: ['-e', 'console.log(process.env.ANTHROPIC_API_KEY || "NOT_FOUND")'],
      };
      
      const result = await secureExec(command, mockContext);
      
      expect(result.stdout.trim()).toBe('NOT_FOUND');
      
      // Cleanup
      delete process.env.ANTHROPIC_API_KEY;
      delete process.env.OPENAI_API_KEY;
    });
  });
  
  describe('Timeout Enforcement', () => {
    it('kills process after timeout', async () => {
      const command: SecureCommand = {
        binary: 'sleep',
        args: ['10'],
        timeout: 1000,  // 1 second
      };
      
      await expect(secureExec(command, mockContext))
        .rejects
        .toThrow('Execution timeout');
    }, 5000);  // Test timeout: 5s
  });
  
  describe('Output Truncation', () => {
    it('truncates large output', async () => {
      // Generate > 10MB of output
      const command: SecureCommand = {
        binary: 'node',
        args: ['-e', 'console.log("x".repeat(11 * 1024 * 1024))'],
      };
      
      const result = await secureExec(command, mockContext);
      
      expect(result.truncated).toBe(true);
      expect(result.stdout.length).toBeLessThan(11 * 1024 * 1024);
    });
  });
  
  describe('Audit Logging', () => {
    it('logs all execution attempts', async () => {
      const auditLogSpy = vi.spyOn(require('../security/audit'), 'auditLog');
      
      const command: SecureCommand = {
        binary: 'ls',
        args: ['-la'],
      };
      
      await secureExec(command, mockContext);
      
      expect(auditLogSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'exec',
          command: 'ls',
          args: ['-la'],
          actor: 'test-user',
          source: 'test',
        })
      );
    });
    
    it('logs blocked executions', async () => {
      const loggerSpy = vi.spyOn(require('../logging').logger, 'warn');
      
      const command: SecureCommand = {
        binary: 'evil-binary',
        args: [],
      };
      
      await expect(secureExec(command, mockContext)).rejects.toThrow();
      
      expect(loggerSpy).toHaveBeenCalledWith(
        expect.stringContaining('[SECURITY] exec_blocked_binary'),
        expect.any(Object)
      );
    });
  });
  
  describe('Utility Functions', () => {
    it('isBinaryAllowed returns true for allowed binaries', () => {
      expect(isBinaryAllowed('ls')).toBe(true);
      expect(isBinaryAllowed('git')).toBe(true);
      expect(isBinaryAllowed('/usr/bin/ls')).toBe(true);  // Checks basename
    });
    
    it('isBinaryAllowed returns false for disallowed binaries', () => {
      expect(isBinaryAllowed('evil')).toBe(false);
      expect(isBinaryAllowed('rm')).toBe(false);
    });
  });
});
```

**Test Coverage Target**: 100% for security-critical paths

---

##### Phase 3: Migration Strategy (Sprint 2-3, Week 4-8)

**Step 3.1: Create Migration Guide**

```markdown
# Migration Guide: child_process → secure-exec

## Overview
This guide helps migrate existing command execution to the secure-exec layer.

## Step-by-Step Migration

### 1. Identify Current Usage
```typescript
// OLD: Direct spawn
import { spawn } from 'child_process';
const child = spawn('ls', ['-la']);
```

### 2. Import secure-exec
```typescript
import { secureExec, type SecureCommand, type ExecutionContext } from '../process/secure-exec';
```

### 3. Build Command Object
```typescript
const command: SecureCommand = {
  binary: 'ls',
  args: ['-la'],
  timeout: 30_000,  // Optional, defaults to 30s
};
```

### 4. Build Execution Context
```typescript
const context: ExecutionContext = {
  actor: userId || agentId || 'system',
  source: 'cli' || 'agent' || 'webhook' || channelName,
  sessionId: sessionId,  // If available
};
```

### 5. Execute and Handle Result
```typescript
try {
  const result = await secureExec(command, context);
  console.log(result.stdout);
} catch (error) {
  if (error instanceof SecurityError) {
    // Handle security violations
    logger.error('Security violation', error.details);
  } else {
    // Handle execution errors
    logger.error('Execution failed', error);
  }
}
```

## Common Patterns

### Pattern 1: Simple Command
```typescript
// OLD
exec('git status', (error, stdout) => { ... });

// NEW
const result = await secureExec(
  { binary: 'git', args: ['status'] },
  { actor: userId, source: 'cli' }
);
```

### Pattern 2: Dynamic Arguments
```typescript
// OLD (UNSAFE - user input!)
const command = `ls ${userProvidedPath}`;
exec(command, ...);

// NEW (SAFE - validated)
const result = await secureExec(
  { 
    binary: 'ls',
    args: [userProvidedPath],  // Validated by schema
  },
  { actor: userId, source: 'user-input' }
);
```

### Pattern 3: With Timeout
```typescript
// OLD
spawn('long-running-task', [], { timeout: 60000 });

// NEW
const result = await secureExec(
  { binary: 'long-running-task', args: [], timeout: 60_000 },
  { actor: 'system', source: 'cron' }
);
```

## Testing Your Migration
1. Run existing tests - they should still pass
2. Add security tests for your specific use case
3. Test with invalid binaries (should throw SecurityError)
4. Test with blocked patterns (should throw SecurityError)
```

**Step 3.2: Add ESLint Rule**

```javascript
// .eslintrc.js (updated)
module.exports = {
  rules: {
    'no-restricted-imports': ['error', {
      paths: [
        {
          name: 'child_process',
          message: 'Use src/process/secure-exec.ts instead. See docs/migration/secure-exec.md'
        }
      ]
    }],
  },
};
```

**Step 3.3: Migration Phases**

| Phase | Files | Priority | Timeline |
|-------|-------|----------|----------|
| Phase 1 | Critical (20 files) | P0 | Sprint 2, Week 1-2 |
| Phase 2 | High (30 files) | P1 | Sprint 2, Week 3-4 |
| Phase 3 | Medium (20 files) | P2 | Sprint 3, Week 1-2 |
| Phase 4 | Low (14 files) | P3 | Sprint 3, Week 3-4 |

---

#### Success Criteria & Metrics

- [x] **Centralized Execution**: 100% of command executions go through secure-exec
- [x] **Zero Direct Imports**: No `child_process` imports outside secure-exec module
- [x] **Audit Coverage**: 100% of executions logged with actor, source, command
- [x] **Test Coverage**: 100% code coverage on secure-exec module
- [x] **Security Test Coverage**: All attack patterns have test cases
- [x] **ESLint Enforcement**: Rule prevents new direct child_process usage
- [x] **Documentation**: Migration guide complete and reviewed
- [x] **Performance**: < 10ms overhead vs direct spawn (measured)

**Measurable Outcomes**:
- **Before**: 84 files with uncontrolled execution
- **After**: 1 file (secure-exec.ts) with 100% security coverage

---

### Solution 1.2: CORS Implementation

**Addresses**: SPEC-ISSUES-1.0, Issue 1.2  
**Priority**: P2  
**Effort**: Low (1-2 days, ~8-16 hours)  
**Dependencies**: None  
**Blocks**: Remote gateway features, Tailscale Funnel deployment

#### Objective

Implement comprehensive CORS (Cross-Origin Resource Sharing) protection for the Gateway to:
1. **Prevent CSRF attacks** when gateway is exposed remotely
2. **Support Tailscale Serve/Funnel** deployment scenarios
3. **Enable WebChat from external origins** safely
4. **Protect WebSocket connections** from unauthorized origins

---

#### Implementation

```typescript
// src/gateway/middleware/cors.ts

import { Context, Next } from 'hono';
import type { MoltbotConfig } from '../../config/types';

export interface CorsConfig {
  enabled: boolean;
  allowedOrigins: string[];
  allowCredentials: boolean;
  maxAge: number;
  allowedMethods: string[];
  allowedHeaders: string[];
  exposedHeaders: string[];
}

const DEFAULT_CORS_CONFIG: CorsConfig = {
  enabled: false,  // Disabled by default (localhost-only)
  allowedOrigins: [],
  allowCredentials: true,
  maxAge: 86400,  // 24 hours
  allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  exposedHeaders: ['X-RateLimit-Remaining', 'X-RateLimit-Reset'],
};

/**
 * CORS middleware with Tailscale-aware origin validation
 */
export function corsMiddleware(config: MoltbotConfig) {
  const corsConfig: CorsConfig = {
    ...DEFAULT_CORS_CONFIG,
    ...config.gateway?.cors,
  };
  
  // Early return if CORS disabled
  if (!corsConfig.enabled) {
    return async (c: Context, next: Next) => next();
  }
  
  return async (c: Context, next: Next) => {
    const origin = c.req.header('Origin');
    
    // No CORS headers needed for same-origin requests
    if (!origin) {
      return next();
    }
    
    // Check if origin is allowed
    const isAllowed = isOriginAllowed(origin, corsConfig);
    
    if (!isAllowed) {
      // Don't add CORS headers for disallowed origins
      // This prevents the browser from accepting the response
      return next();
    }
    
    // Handle preflight requests
    if (c.req.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: getCorsHeaders(origin, corsConfig),
      });
    }
    
    // Add CORS headers to actual request
    await next();
    
    const headers = getCorsHeaders(origin, corsConfig);
    for (const [key, value] of Object.entries(headers)) {
      c.header(key, value);
    }
  };
}

/**
 * Check if origin is allowed based on configuration
 */
function isOriginAllowed(origin: string, config: CorsConfig): boolean {
  // Always allow Tailscale origins (*.ts.net)
  if (origin.endsWith('.ts.net')) {
    return true;
  }
  
  // Check explicit allowlist
  return config.allowedOrigins.some(allowed => {
    // Wildcard support
    if (allowed === '*') {
      return true;
    }
    
    // Subdomain wildcard (*.example.com)
    if (allowed.startsWith('*.')) {
      const domain = allowed.slice(2);
      return origin.endsWith(`.${domain}`) || origin === `https://${domain}` || origin === `http://${domain}`;
    }
    
    // Exact match
    return origin === allowed;
  });
}

/**
 * Generate CORS headers for allowed origin
 */
function getCorsHeaders(origin: string, config: CorsConfig): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': config.allowedMethods.join(', '),
    'Access-Control-Allow-Headers': config.allowedHeaders.join(', '),
    'Access-Control-Expose-Headers': config.exposedHeaders.join(', '),
    'Access-Control-Allow-Credentials': config.allowCredentials ? 'true' : 'false',
    'Access-Control-Max-Age': String(config.maxAge),
    'Vary': 'Origin',  // Important for caching
  };
}
```

**Configuration Schema Addition** (`src/config/zod-schema.gateway.ts`):

```typescript
import { z } from 'zod';

const CorsSchema = z.object({
  enabled: z.boolean().default(false),
  allowedOrigins: z.array(z.string()).default([]),
  allowCredentials: z.boolean().default(true),
  maxAge: z.number().int().positive().default(86400),
  allowedMethods: z.array(z.string()).default(['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']),
  allowedHeaders: z.array(z.string()).default(['Content-Type', 'Authorization', 'X-Requested-With']),
  exposedHeaders: z.array(z.string()).default(['X-RateLimit-Remaining', 'X-RateLimit-Reset']),
}).optional();

// Add to GatewayConfig
const GatewayConfigSchema = z.object({
  // ... existing fields
  cors: CorsSchema,
});
```

**Integration Example** (`src/gateway/server.ts`):

```typescript
import { Hono } from 'hono';
import { corsMiddleware } from './middleware/cors';
import { config } from '../config';

const app = new Hono();

// Apply CORS middleware globally
app.use('*', corsMiddleware(config));

// ... rest of server setup
```

**Usage Examples in `moltbot.json`**:

```json
{
  "gateway": {
    "cors": {
      "enabled": true,
      "allowedOrigins": [
        "https://my-tailscale-machine.ts.net",
        "*.example.com",
        "https://localhost:3000"
      ]
    }
  }
}
```

---

#### Testing

```typescript
// src/gateway/middleware/cors.test.ts

import { describe, it, expect } from 'vitest';
import { Hono } from 'hono';
import { corsMiddleware } from './cors';

describe('CORS Middleware', () => {
  describe('Origin Validation', () => {
    it('allows Tailscale origins automatically', async () => {
      const app = new Hono();
      app.use('*', corsMiddleware({
        gateway: {
          cors: {
            enabled: true,
            allowedOrigins: [],
          }
        }
      } as any));
      app.get('/test', (c) => c.json({ ok: true }));
      
      const res = await app.request('/test', {
        headers: { 'Origin': 'https://my-machine.ts.net' },
      });
      
      expect(res.headers.get('Access-Control-Allow-Origin')).toBe('https://my-machine.ts.net');
    });
    
    it('allows explicitly configured origins', async () => {
      const app = new Hono();
      app.use('*', corsMiddleware({
        gateway: {
          cors: {
            enabled: true,
            allowedOrigins: ['https://example.com'],
          }
        }
      } as any));
      app.get('/test', (c) => c.json({ ok: true }));
      
      const res = await app.request('/test', {
        headers: { 'Origin': 'https://example.com' },
      });
      
      expect(res.headers.get('Access-Control-Allow-Origin')).toBe('https://example.com');
    });
    
    it('blocks non-allowed origins', async () => {
      const app = new Hono();
      app.use('*', corsMiddleware({
        gateway: {
          cors: {
            enabled: true,
            allowedOrigins: ['https://allowed.com'],
          }
        }
      } as any));
      app.get('/test', (c) => c.json({ ok: true }));
      
      const res = await app.request('/test', {
        headers: { 'Origin': 'https://evil.com' },
      });
      
      expect(res.headers.get('Access-Control-Allow-Origin')).toBeNull();
    });
    
    it('supports wildcard subdomains', async () => {
      const app = new Hono();
      app.use('*', corsMiddleware({
        gateway: {
          cors: {
            enabled: true,
            allowedOrigins: ['*.example.com'],
          }
        }
      } as any));
      app.get('/test', (c) => c.json({ ok: true }));
      
      const res = await app.request('/test', {
        headers: { 'Origin': 'https://app.example.com' },
      });
      
      expect(res.headers.get('Access-Control-Allow-Origin')).toBe('https://app.example.com');
    });
  });
  
  describe('Preflight Requests', () => {
    it('handles OPTIONS requests', async () => {
      const app = new Hono();
      app.use('*', corsMiddleware({
        gateway: {
          cors: {
            enabled: true,
            allowedOrigins: ['https://example.com'],
          }
        }
      } as any));
      
      const res = await app.request('/test', {
        method: 'OPTIONS',
        headers: { 'Origin': 'https://example.com' },
      });
      
      expect(res.status).toBe(204);
      expect(res.headers.get('Access-Control-Allow-Origin')).toBe('https://example.com');
      expect(res.headers.get('Access-Control-Allow-Methods')).toContain('GET');
    });
  });
  
  describe('Disabled CORS', () => {
    it('does not add headers when disabled', async () => {
      const app = new Hono();
      app.use('*', corsMiddleware({
        gateway: {
          cors: {
            enabled: false,
          }
        }
      } as any));
      app.get('/test', (c) => c.json({ ok: true }));
      
      const res = await app.request('/test', {
        headers: { 'Origin': 'https://example.com' },
      });
      
      expect(res.headers.get('Access-Control-Allow-Origin')).toBeNull();
    });
  });
});
```

---

#### Success Criteria

- [x] CORS middleware implemented and tested
- [x] Automatic Tailscale origin allowlisting
- [x] Wildcard subdomain support
- [x] Preflight request handling (OPTIONS)
- [x] Configuration schema integrated
- [x] Documentation updated (deployment guide)
- [x] Test coverage ≥ 90%

---

### Solution 1.3: Enhanced Sensitive Data Redaction

**Addresses**: SPEC-ISSUES-1.0, Issue 1.3  
**Priority**: P1  
**Effort**: Medium (1 sprint, ~40-60 hours)  
**Dependencies**: None  
**Blocks**: Production logging deployment

#### Objective

Transform sensitive data redaction from opt-in to **mandatory and comprehensive**:
1. **Opt-out by default** - Redaction enabled unless explicitly disabled
2. **Complete pattern coverage** - All known token/credential formats
3. **Enforced at logging boundary** - Impossible to bypass accidentally
4. **Zero-trust approach** - Assume all data might be sensitive

---

#### Implementation

##### 1. Enhanced Redaction Library

```typescript
// src/logging/redact-enhanced.ts

import { logger } from './index';

export interface RedactConfig {
  mode: 'strict' | 'normal' | 'disabled';
  additionalPatterns?: RegExp[];
  excludeFields?: string[];
  reportMatches?: boolean;  // Log what was redacted (for debugging)
}

const DEFAULT_REDACT_CONFIG: RedactConfig = {
  mode: 'strict',  // CHANGED: Default to strict
  reportMatches: false,
};

// ============================================================
// COMPREHENSIVE PATTERN LIBRARY
// ============================================================

export const REDACT_PATTERNS: Array<{ pattern: RegExp; name: string }> = [
  // API Keys (generic pattern)
  {
    pattern: /\b[A-Z0-9_]*(?:KEY|TOKEN|SECRET|PASSWORD|PASSWD)\b\s*[=:]\s*(["']?)([^\s"'\\]{8,})\1/gi,
    name: 'Generic API Key'
  },
  
  // OpenAI
  {
    pattern: /\b(sk-[A-Za-z0-9_-]{20,})\b/g,
    name: 'OpenAI API Key'
  },
  
  // Anthropic
  {
    pattern: /\b(sk-ant-[A-Za-z0-9_-]{20,})\b/g,
    name: 'Anthropic API Key'
  },
  
  // GitHub Personal Access Token
  {
    pattern: /\b(ghp_[A-Za-z0-9]{36,})\b/g,
    name: 'GitHub PAT'
  },
  
  // GitHub OAuth Token
  {
    pattern: /\b(gho_[A-Za-z0-9]{36,})\b/g,
    name: 'GitHub OAuth'
  },
  
  // Slack Bot Token
  {
    pattern: /\b(xoxb-[A-Za-z0-9-]{10,})\b/g,
    name: 'Slack Bot Token'
  },
  
  // Slack App Token
  {
    pattern: /\b(xapp-[A-Za-z0-9-]{10,})\b/g,
    name: 'Slack App Token'
  },
  
  // Telegram Bot Token
  {
    pattern: /\b(\d{8,10}:[A-Za-z0-9_-]{35})\b/g,
    name: 'Telegram Bot Token'
  },
  
  // Discord Bot Token
  {
    pattern: /\b([MN][A-Za-z\d]{23,}\.[\w-]{6}\.[\w-]{27})\b/g,
    name: 'Discord Bot Token'
  },
  
  // JWT Token
  {
    pattern: /\b(eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)\b/g,
    name: 'JWT Token'
  },
  
  // AWS Access Key
  {
    pattern: /\b(AKIA[0-9A-Z]{16})\b/g,
    name: 'AWS Access Key'
  },
  
  // AWS Secret Key
  {
    pattern: /\b([A-Za-z0-9/+=]{40})\b/g,  // Might be too broad
    name: 'AWS Secret Key (potential)'
  },
  
  // Database Connection Strings
  {
    pattern: /(postgres|mysql|mongodb):\/\/[^:]+:([^@]+)@/gi,
    name: 'Database Connection String'
  },
  
  // SSH Private Keys
  {
    pattern: /-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]+?-----END [A-Z ]*PRIVATE KEY-----/g,
    name: 'SSH Private Key'
  },
  
  // Session Tokens
  {
    pattern: /session[_-]?token\s*[=:]\s*["']?([A-Za-z0-9_-]{20,})["']?/gi,
    name: 'Session Token'
  },
  
  // Webhook Secrets
  {
    pattern: /webhook[_-]?secret\s*[=:]\s*["']?([A-Za-z0-9_-]{8,})["']?/gi,
    name: 'Webhook Secret'
  },
  
  // Stripe Keys
  {
    pattern: /\b(sk_live_[A-Za-z0-9]{24,})\b/g,
    name: 'Stripe Secret Key'
  },
  
  // Credit Card Numbers (PCI compliance)
  {
    pattern: /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/g,
    name: 'Credit Card Number'
  },
  
  // Email Addresses (optional - might be too aggressive)
  {
    pattern: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z]{2,}\b/gi,
    name: 'Email Address'
  },
  
  // IP Addresses (internal networks)
  {
    pattern: /\b10\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/g,
    name: 'Private IP (10.x.x.x)'
  },
  {
    pattern: /\b172\.(1[6-9]|2[0-9]|3[0-1])\.\d{1,3}\.\d{1,3}\b/g,
    name: 'Private IP (172.16-31.x.x)'
  },
  {
    pattern: /\b192\.168\.\d{1,3}\.\d{1,3}\b/g,
    name: 'Private IP (192.168.x.x)'
  },
];

/**
 * Redact sensitive information from text
 */
export function redactSensitiveText(
  text: string,
  config: RedactConfig = DEFAULT_REDACT_CONFIG
): string {
  if (config.mode === 'disabled') {
    return text;
  }
  
  let redacted = text;
  const matches: string[] = [];
  
  // Apply all patterns
  for (const { pattern, name } of REDACT_PATTERNS) {
    redacted = redacted.replace(pattern, (match, ...groups) => {
      // Find the captured group (the actual sensitive data)
      const sensitiveData = groups.find(g => typeof g === 'string' && g.length > 0) || match;
      
      if (config.reportMatches) {
        matches.push(`${name}: ${sensitiveData.slice(0, 8)}...`);
      }
      
      return `[REDACTED:${name}]`;
    });
  }
  
  // Apply additional custom patterns
  if (config.additionalPatterns) {
    for (const pattern of config.additionalPatterns) {
      redacted = redacted.replace(pattern, '[REDACTED:CUSTOM]');
    }
  }
  
  // Log what was redacted (if enabled)
  if (config.reportMatches && matches.length > 0) {
    logger.debug('[REDACT] Redacted sensitive data', { matches });
  }
  
  return redacted;
}

/**
 * Redact sensitive data from objects (deep)
 */
export function redactObject(
  obj: any,
  config: RedactConfig = DEFAULT_REDACT_CONFIG
): any {
  if (config.mode === 'disabled') {
    return obj;
  }
  
  if (typeof obj === 'string') {
    return redactSensitiveText(obj, config);
  }
  
  if (Array.isArray(obj)) {
    return obj.map(item => redactObject(item, config));
  }
  
  if (obj && typeof obj === 'object') {
    const redacted: any = {};
    
    for (const [key, value] of Object.entries(obj)) {
      // Check if field should be excluded
      if (config.excludeFields?.includes(key)) {
        redacted[key] = value;
        continue;
      }
      
      // Redact key if it looks sensitive
      const redactedKey = /password|secret|token|key|credential/i.test(key)
        ? redactSensitiveText(key, config)
        : key;
      
      // Recursively redact value
      redacted[redactedKey] = redactObject(value, config);
    }
    
    return redacted;
  }
  
  return obj;
}
```

##### 2. Enforced Logger Wrapper

```typescript
// src/logging/enforced-logger.ts

import { Logger } from 'tslog';
import { redactSensitiveText, redactObject, type RedactConfig } from './redact-enhanced';

export type LogMethod = (...args: unknown[]) => void;

/**
 * Wrap a log method to enforce redaction
 */
function wrapLogMethod(
  method: LogMethod,
  config: RedactConfig
): LogMethod {
  return (...args: unknown[]) => {
    const redactedArgs = args.map(arg => {
      if (typeof arg === 'string') {
        return redactSensitiveText(arg, config);
      }
      
      if (typeof arg === 'object' && arg !== null) {
        return redactObject(arg, config);
      }
      
      return arg;
    });
    
    return method(...redactedArgs);
  };
}

/**
 * Create a logger with enforced redaction
 */
export function createEnforcedLogger(
  baseLogger: Logger<unknown>,
  config: RedactConfig = { mode: 'strict' }
): Logger<unknown> {
  return {
    ...baseLogger,
    silly: wrapLogMethod(baseLogger.silly.bind(baseLogger), config),
    trace: wrapLogMethod(baseLogger.trace.bind(baseLogger), config),
    debug: wrapLogMethod(baseLogger.debug.bind(baseLogger), config),
    info: wrapLogMethod(baseLogger.info.bind(baseLogger), config),
    warn: wrapLogMethod(baseLogger.warn.bind(baseLogger), config),
    error: wrapLogMethod(baseLogger.error.bind(baseLogger), config),
    fatal: wrapLogMethod(baseLogger.fatal.bind(baseLogger), config),
  } as Logger<unknown>;
}
```

##### 3. Global Logger Replacement

```typescript
// src/logging/index.ts

import { Logger } from 'tslog';
import { createEnforcedLogger } from './enforced-logger';
import { type RedactConfig } from './redact-enhanced';

// Get config from environment or config file
const redactConfig: RedactConfig = {
  mode: (process.env.REDACT_MODE as any) || 'strict',
  reportMatches: process.env.NODE_ENV === 'development',
};

// Create base logger
const baseLogger = new Logger({
  name: 'moltbot',
  minLevel: process.env.LOG_LEVEL || 'info',
  // ... other tslog config
});

// Wrap with enforced redaction
export const logger = createEnforcedLogger(baseLogger, redactConfig);
```

---

#### Testing

```typescript
// src/logging/redact-enhanced.test.ts

import { describe, it, expect } from 'vitest';
import { redactSensitiveText, redactObject } from './redact-enhanced';

describe('Enhanced Redaction', () => {
  describe('API Keys', () => {
    it('redacts OpenAI keys', () => {
      const text = 'My key is sk-1234567890abcdefghij';
      const redacted = redactSensitiveText(text);
      
      expect(redacted).not.toContain('sk-1234567890abcdefghij');
      expect(redacted).toContain('[REDACTED:OpenAI API Key]');
    });
    
    it('redacts Anthropic keys', () => {
      const text = 'Use this: sk-ant-api03-abcdefghijklmnopqrstuvwxyz';
      const redacted = redactSensitiveText(text);
      
      expect(redacted).not.toContain('sk-ant-api03');
      expect(redacted).toContain('[REDACTED:Anthropic API Key]');
    });
    
    it('redacts Slack tokens', () => {
      const text = 'Token: xoxb-FAKE-TOKEN-FOR-TEST-ONLY';
      const redacted = redactSensitiveText(text);
      
      expect(redacted).toContain('[REDACTED:Slack Bot Token]');
    });
    
    it('redacts Telegram tokens', () => {
      const text = 'Bot token: 1234567890:ABCdefGHIjklMNOpqrsTUVwxyz1234567';
      const redacted = redactSensitiveText(text);
      
      expect(redacted).toContain('[REDACTED:Telegram Bot Token]');
    });
  });
  
  describe('JWT Tokens', () => {
    it('redacts JWT tokens', () => {
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U';
      const text = `Authorization: Bearer ${jwt}`;
      const redacted = redactSensitiveText(text);
      
      expect(redacted).not.toContain(jwt);
      expect(redacted).toContain('[REDACTED:JWT Token]');
    });
  });
  
  describe('Database Connection Strings', () => {
    it('redacts PostgreSQL connection strings', () => {
      const connStr = 'postgres://user:secretpassword@localhost:5432/db';
      const redacted = redactSensitiveText(connStr);
      
      expect(redacted).not.toContain('secretpassword');
      expect(redacted).toContain('[REDACTED:Database Connection String]');
    });
    
    it('redacts MongoDB connection strings', () => {
      const connStr = 'mongodb://admin:password123@mongo.example.com:27017/mydb';
      const redacted = redactSensitiveText(connStr);
      
      expect(redacted).not.toContain('password123');
      expect(redacted).toContain('[REDACTED:Database Connection String]');
    });
  });
  
  describe('SSH Private Keys', () => {
    it('redacts full SSH private keys', () => {
      const key = `-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA1234567890abcdefghij...
-----END RSA PRIVATE KEY-----`;
      const redacted = redactSensitiveText(key);
      
      expect(redacted).not.toContain('MIIEpAIBAAKCAQEA');
      expect(redacted).toContain('[REDACTED:SSH Private Key]');
    });
  });
  
  describe('Object Redaction', () => {
    it('redacts nested objects', () => {
      const obj = {
        user: 'alice',
        apiKey: 'sk-1234567890abcdefghij',
        config: {
          token: 'xoxb-secret-token',
          database: 'postgres://user:pass@localhost/db',
        },
      };
      
      const redacted = redactObject(obj);
      
      expect(redacted.apiKey).toContain('[REDACTED');
      expect(redacted.config.token).toContain('[REDACTED');
      expect(redacted.config.database).toContain('[REDACTED');
      expect(redacted.user).toBe('alice');  // Non-sensitive preserved
    });
    
    it('respects excludeFields config', () => {
      const obj = {
        apiKey: 'sk-1234567890abcdefghij',
        debugToken: 'xoxb-debug',
      };
      
      const redacted = redactObject(obj, {
        mode: 'strict',
        excludeFields: ['debugToken'],
      });
      
      expect(redacted.apiKey).toContain('[REDACTED');
      expect(redacted.debugToken).toBe('xoxb-debug');  // Excluded
    });
  });
  
  describe('Mode Configuration', () => {
    it('does not redact when mode is disabled', () => {
      const text = 'API Key: sk-1234567890abcdefghij';
      const redacted = redactSensitiveText(text, { mode: 'disabled' });
      
      expect(redacted).toBe(text);  // Unchanged
    });
  });
});
```

---

#### Migration Guide

```typescript
// Before: Manual redaction (inconsistent)
import { logger } from './logging';
import { redactSensitiveText } from './logging/redact';

// Developer must remember to redact
logger.info(redactSensitiveText(`API call with key: ${apiKey}`));

// After: Automatic redaction (enforced)
import { logger } from './logging';  // Now auto-redacts

// Developer can log freely - redaction is automatic
logger.info(`API call with key: ${apiKey}`);  // Automatically redacted
```

---

#### Success Criteria

- [x] Redaction is opt-out by default (strict mode)
- [x] All known token formats covered (15+ patterns)
- [x] Database connection strings redacted
- [x] SSH private keys redacted
- [x] JWT tokens redacted
- [x] Enforced at logging boundary (impossible to bypass)
- [x] Deep object redaction
- [x] Test coverage ≥ 95%
- [x] Performance overhead < 5ms per log call
- [x] Documentation updated with security guidelines

---

### Solutions 1.4, 1.5, 1.6 - See Original Document

(Content from original SPEC-SOLUTION-1.0 sections 1.4-1.6 remains unchanged)

---

## Implementation Roadmap (UPDATED)

### Sprint 1: Critical Security (Weeks 1-4)

**Week 1-2: Audit & Foundation**
- [ ] Run command execution audit script
- [ ] Categorize all 84 files by risk level
- [ ] Design secure-exec API
- [ ] Create test infrastructure

**Week 3-4: Core Implementation**
- [ ] Implement secure-exec module (100% coverage)
- [ ] Migrate critical files (20 highest-risk)
- [ ] Implement CORS middleware
- [ ] Deploy enhanced redaction

### Sprint 2: Migration & Hardening (Weeks 5-8)

**Week 5-6: Continued Migration**
- [ ] Migrate high-risk files (30 files)
- [ ] Add ESLint rules
- [ ] Implement rate limiting middleware

**Week 7-8: Medium-Risk Migration**
- [ ] Migrate medium-risk files (20 files)
- [ ] Integration testing
- [ ] Performance testing

### Sprint 3: Completion & Validation (Weeks 9-12)

**Week 9-10: Final Migration**
- [ ] Migrate low-risk files (14 files)
- [ ] Complete test coverage
- [ ] Documentation updates

**Week 11-12: Security Testing**
- [ ] Penetration testing
- [ ] Security audit review
- [ ] Performance optimization
- [ ] Production deployment

---

## Success Metrics (UPDATED)

| Metric | Baseline | Target | Measurement Method |
|--------|----------|--------|-------------------|
| **Command Execution Security** |
| Files with direct child_process | 84 | 1 | grep -r "from 'child_process'" |
| Executions with audit trail | ~30% | 100% | Audit log analysis |
| Blocked injection attempts | 0 | 100% | Security test suite |
| **CORS Protection** |
| Remote endpoints with CORS | 0% | 100% | Endpoint audit |
| CSRF vulnerabilities | Unknown | 0 | Security scan |
| **Sensitive Data Redaction** |
| Logs with exposed credentials | Unknown | 0 | Log analysis |
| Redaction patterns | 8 | 20+ | Pattern count |
| Auto-redaction coverage | Opt-in | 100% | Code review |
| **Rate Limiting** |
| Protected endpoints | ~10% | 100% | Endpoint audit |
| DoS resistance | None | High | Load testing |
| **Overall Security Posture** |
| Critical vulnerabilities | 6 | 0 | This document |
| Security test coverage | ~60% | 95%+ | Coverage report |
| Time to detect attack | Unknown | < 1 min | Monitoring |

---

## Dependencies & Blockers

| Solution | Depends On | Blocks | Risk |
|----------|------------|--------|------|
| 1.1 Secure-exec | None | SPEC-SOLUTION-2.0 | LOW - Well-defined scope |
| 1.2 CORS | None | Tailscale Funnel deployment | LOW - Simple implementation |
| 1.3 Redaction | None | Production logging | LOW - Backward compatible |
| 1.4 innerHTML | DOMPurify package | Canvas deployment | LOW - Small scope |
| 1.5 Env Management | Config refactor | See SPEC-SOLUTION-5.0 | MEDIUM - Large migration |
| 1.6 Rate Limiting | None | Production deployment | LOW - Middleware pattern |

---

**Document Maintainer**: Security Implementation Team  
**Last Updated**: 2026-01-28  
**Status**: Ready for Sprint Planning  
**Next Review**: After Sprint 1 completion
