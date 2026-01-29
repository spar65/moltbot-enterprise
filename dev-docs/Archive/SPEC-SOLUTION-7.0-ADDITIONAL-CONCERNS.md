# SPEC-SOLUTION 7.0: Additional Concerns Resolution

**Document ID**: SPEC-SOLUTION-7.0  
**Addresses**: SPEC-ISSUES-7.0  
**Category**: Miscellaneous  
**Priority**: P2-P3 (Various)  
**Date Created**: 2026-01-28  
**Status**: Draft

---

## Executive Summary

This document provides solutions for miscellaneous concerns identified in SPEC-ISSUES-7.0, including operational safety, credential management, session handling, and compliance requirements.

---

## Solution Registry

### Solution 7.1: Multi-Agent Safety Guardrails

**Addresses**: Issue 7.1 - Multi-Agent Safety  
**Priority**: P1  
**Effort**: Medium (1 sprint)

#### Implementation

```typescript
// src/infra/git-guardrails.ts

/**
 * Git operation guardrails for multi-agent safety
 * Per CLAUDE.md guidelines
 */

type GitOperation = 
  | 'stash'
  | 'checkout'
  | 'switch'
  | 'worktree'
  | 'push --force'
  | 'reset --hard'
  | 'rebase'
  | 'merge';

interface AgentContext {
  agentId: string;
  sessionId: string;
  explicitlyRequested: boolean;
}

const DANGEROUS_OPERATIONS: GitOperation[] = [
  'stash',
  'checkout',
  'switch',
  'worktree',
  'push --force',
  'reset --hard',
];

const OPERATION_PATTERNS: Record<GitOperation, RegExp> = {
  'stash': /git\s+stash/i,
  'checkout': /git\s+checkout/i,
  'switch': /git\s+switch/i,
  'worktree': /git\s+worktree/i,
  'push --force': /git\s+push\s+.*(-f|--force)/i,
  'reset --hard': /git\s+reset\s+--hard/i,
  'rebase': /git\s+rebase/i,
  'merge': /git\s+merge/i,
};

export function validateGitOperation(
  command: string,
  context: AgentContext
): { allowed: boolean; reason?: string } {
  // Check each dangerous pattern
  for (const op of DANGEROUS_OPERATIONS) {
    if (OPERATION_PATTERNS[op].test(command)) {
      if (!context.explicitlyRequested) {
        return {
          allowed: false,
          reason: `Git operation '${op}' requires explicit user request. ` +
                  `Multi-agent safety: this operation could affect other agents' work.`,
        };
      }
    }
  }
  
  // Log non-dangerous but notable operations
  if (OPERATION_PATTERNS.rebase.test(command) || OPERATION_PATTERNS.merge.test(command)) {
    logGitOperation(command, context);
  }
  
  return { allowed: true };
}

function logGitOperation(command: string, context: AgentContext): void {
  console.log(`[GIT-AUDIT] Agent ${context.agentId} executing: ${command}`);
}

// Integration with exec layer
export function wrapGitCommand(
  execFn: (cmd: string) => Promise<string>,
  context: AgentContext
) {
  return async (command: string): Promise<string> => {
    if (command.includes('git ')) {
      const validation = validateGitOperation(command, context);
      if (!validation.allowed) {
        throw new Error(validation.reason);
      }
    }
    return execFn(command);
  };
}
```

#### Testing

```typescript
describe('Git Guardrails', () => {
  it('blocks stash without explicit request', () => {
    const result = validateGitOperation('git stash', { 
      agentId: 'test',
      sessionId: '123',
      explicitlyRequested: false,
    });
    expect(result.allowed).toBe(false);
    expect(result.reason).toContain('stash');
  });
  
  it('allows stash with explicit request', () => {
    const result = validateGitOperation('git stash', {
      agentId: 'test',
      sessionId: '123',
      explicitlyRequested: true,
    });
    expect(result.allowed).toBe(true);
  });
  
  it('allows safe operations', () => {
    const safeOps = ['git status', 'git log', 'git diff', 'git add .', 'git commit -m "msg"'];
    for (const op of safeOps) {
      const result = validateGitOperation(op, {
        agentId: 'test',
        sessionId: '123',
        explicitlyRequested: false,
      });
      expect(result.allowed).toBe(true);
    }
  });
});
```

---

### Solution 7.2: Encrypted Credential Storage

**Addresses**: Issue 7.2 - Credential Storage Security  
**Priority**: P1  
**Effort**: High (2 sprints)

#### Implementation

```typescript
// src/security/credential-store.ts

import * as crypto from 'crypto';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';

// ============================================================
// CREDENTIAL ENCRYPTION
// ============================================================

interface EncryptedCredential {
  version: number;
  algorithm: string;
  iv: string;
  salt: string;
  data: string;
  tag: string;
}

const CURRENT_VERSION = 1;
const ALGORITHM = 'aes-256-gcm';
const KEY_LENGTH = 32;
const SALT_LENGTH = 32;
const IV_LENGTH = 16;

async function deriveKey(password: string, salt: Buffer): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    crypto.pbkdf2(password, salt, 100000, KEY_LENGTH, 'sha256', (err, key) => {
      if (err) reject(err);
      else resolve(key);
    });
  });
}

export async function encryptCredential(
  data: string,
  masterPassword: string
): Promise<EncryptedCredential> {
  const salt = crypto.randomBytes(SALT_LENGTH);
  const iv = crypto.randomBytes(IV_LENGTH);
  const key = await deriveKey(masterPassword, salt);
  
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
  let encrypted = cipher.update(data, 'utf8', 'base64');
  encrypted += cipher.final('base64');
  const tag = cipher.getAuthTag();
  
  return {
    version: CURRENT_VERSION,
    algorithm: ALGORITHM,
    iv: iv.toString('base64'),
    salt: salt.toString('base64'),
    data: encrypted,
    tag: tag.toString('base64'),
  };
}

export async function decryptCredential(
  encrypted: EncryptedCredential,
  masterPassword: string
): Promise<string> {
  const salt = Buffer.from(encrypted.salt, 'base64');
  const iv = Buffer.from(encrypted.iv, 'base64');
  const tag = Buffer.from(encrypted.tag, 'base64');
  const key = await deriveKey(masterPassword, salt);
  
  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
  decipher.setAuthTag(tag);
  
  let decrypted = decipher.update(encrypted.data, 'base64', 'utf8');
  decrypted += decipher.final('utf8');
  
  return decrypted;
}

// ============================================================
// CREDENTIAL STORE
// ============================================================

interface Credential {
  key: string;
  value: string;
  createdAt: string;
  updatedAt: string;
}

export class SecureCredentialStore {
  private storePath: string;
  private masterPassword: string | null = null;
  private auditLog: AuditLogger;
  
  constructor(storePath?: string) {
    this.storePath = storePath ?? path.join(os.homedir(), '.clawdbot', 'credentials');
    this.auditLog = createAuditLogger('credential-store');
  }
  
  async unlock(masterPassword: string): Promise<void> {
    // Verify password by trying to decrypt test credential
    const testFile = path.join(this.storePath, '.test');
    
    try {
      const exists = await fs.access(testFile).then(() => true).catch(() => false);
      
      if (exists) {
        const encrypted = JSON.parse(await fs.readFile(testFile, 'utf-8'));
        await decryptCredential(encrypted, masterPassword);
      } else {
        // First time: create test credential
        const encrypted = await encryptCredential('test', masterPassword);
        await fs.mkdir(this.storePath, { recursive: true, mode: 0o700 });
        await fs.writeFile(testFile, JSON.stringify(encrypted), { mode: 0o600 });
      }
      
      this.masterPassword = masterPassword;
      this.auditLog.log({ action: 'unlock', actor: 'user', resource: 'store', result: 'success' });
    } catch (error) {
      this.auditLog.log({ action: 'unlock', actor: 'user', resource: 'store', result: 'failure' });
      throw new Error('Invalid master password');
    }
  }
  
  async set(key: string, value: string): Promise<void> {
    this.ensureUnlocked();
    
    const credential: Credential = {
      key,
      value,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    
    const encrypted = await encryptCredential(
      JSON.stringify(credential),
      this.masterPassword!
    );
    
    const filePath = path.join(this.storePath, `${this.sanitizeKey(key)}.enc`);
    await fs.writeFile(filePath, JSON.stringify(encrypted), { mode: 0o600 });
    
    this.auditLog.log({ action: 'set', actor: 'user', resource: key, result: 'success' });
  }
  
  async get(key: string): Promise<string | null> {
    this.ensureUnlocked();
    
    const filePath = path.join(this.storePath, `${this.sanitizeKey(key)}.enc`);
    
    try {
      const encrypted = JSON.parse(await fs.readFile(filePath, 'utf-8'));
      const decrypted = await decryptCredential(encrypted, this.masterPassword!);
      const credential: Credential = JSON.parse(decrypted);
      
      this.auditLog.log({ action: 'get', actor: 'user', resource: key, result: 'success' });
      return credential.value;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
        return null;
      }
      this.auditLog.log({ action: 'get', actor: 'user', resource: key, result: 'failure' });
      throw error;
    }
  }
  
  async delete(key: string): Promise<void> {
    this.ensureUnlocked();
    
    const filePath = path.join(this.storePath, `${this.sanitizeKey(key)}.enc`);
    
    try {
      // Secure delete: overwrite with random data before unlinking
      const size = (await fs.stat(filePath)).size;
      await fs.writeFile(filePath, crypto.randomBytes(size));
      await fs.unlink(filePath);
      
      this.auditLog.log({ action: 'delete', actor: 'user', resource: key, result: 'success' });
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') {
        throw error;
      }
    }
  }
  
  private ensureUnlocked(): void {
    if (!this.masterPassword) {
      throw new Error('Credential store is locked. Call unlock() first.');
    }
  }
  
  private sanitizeKey(key: string): string {
    return key.replace(/[^a-zA-Z0-9_-]/g, '_');
  }
}

// Keychain integration (macOS)
export async function useKeychain(): Promise<SecureCredentialStore | null> {
  if (process.platform !== 'darwin') {
    return null;
  }
  
  // Use macOS Keychain via security command
  // Implementation would use child_process to call `security` command
  // This is a placeholder for the concept
  
  return null;
}
```

---

### Solution 7.3: Session State Management

**Addresses**: Issue 7.3 - Session State Management  
**Priority**: P2  
**Effort**: Medium (1 sprint)

#### Implementation

```typescript
// src/sessions/robust-store.ts

import * as fs from 'fs/promises';
import * as path from 'path';
import { z } from 'zod';

// ============================================================
// SESSION SCHEMA
// ============================================================

const SessionDataSchema = z.object({
  id: z.string(),
  agentId: z.string(),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
  expiresAt: z.string().datetime().optional(),
  data: z.record(z.unknown()),
  checksum: z.string(),
});

type SessionData = z.infer<typeof SessionDataSchema>;

// ============================================================
// SESSION STORE WITH INTEGRITY
// ============================================================

export class RobustSessionStore {
  private basePath: string;
  private lockManager: LockManager;
  
  constructor(basePath: string) {
    this.basePath = basePath;
    this.lockManager = new LockManager();
  }
  
  async save(session: Omit<SessionData, 'checksum'>): Promise<void> {
    const sessionPath = this.getSessionPath(session.id);
    
    // Add checksum for integrity verification
    const withChecksum: SessionData = {
      ...session,
      updatedAt: new Date().toISOString(),
      checksum: this.calculateChecksum(session),
    };
    
    // Acquire lock
    const release = await this.lockManager.acquire(session.id);
    
    try {
      // Atomic write
      const tempPath = `${sessionPath}.tmp.${Date.now()}`;
      await fs.mkdir(path.dirname(sessionPath), { recursive: true });
      await fs.writeFile(tempPath, JSON.stringify(withChecksum, null, 2));
      await fs.rename(tempPath, sessionPath);
    } finally {
      release();
    }
  }
  
  async load(sessionId: string): Promise<SessionData | null> {
    const sessionPath = this.getSessionPath(sessionId);
    
    try {
      const content = await fs.readFile(sessionPath, 'utf-8');
      const parsed = JSON.parse(content);
      
      // Validate schema
      const validated = SessionDataSchema.parse(parsed);
      
      // Verify checksum
      const expectedChecksum = this.calculateChecksum({
        id: validated.id,
        agentId: validated.agentId,
        createdAt: validated.createdAt,
        updatedAt: validated.updatedAt,
        expiresAt: validated.expiresAt,
        data: validated.data,
      });
      
      if (validated.checksum !== expectedChecksum) {
        console.warn(`Session ${sessionId} integrity check failed, attempting recovery`);
        return await this.attemptRecovery(sessionId);
      }
      
      // Check expiry
      if (validated.expiresAt && new Date(validated.expiresAt) < new Date()) {
        await this.delete(sessionId);
        return null;
      }
      
      return validated;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
        return null;
      }
      
      console.warn(`Session ${sessionId} load failed, attempting recovery`);
      return await this.attemptRecovery(sessionId);
    }
  }
  
  async delete(sessionId: string): Promise<void> {
    const sessionPath = this.getSessionPath(sessionId);
    const backupPath = this.getBackupPath(sessionId);
    
    const release = await this.lockManager.acquire(sessionId);
    
    try {
      // Move to backup instead of delete
      await fs.rename(sessionPath, backupPath);
    } catch {
      // Ignore if doesn't exist
    } finally {
      release();
    }
  }
  
  async cleanup(maxAge: number = 7 * 24 * 60 * 60 * 1000): Promise<number> {
    const cutoff = Date.now() - maxAge;
    let cleaned = 0;
    
    const files = await fs.readdir(this.basePath);
    
    for (const file of files) {
      if (!file.endsWith('.json')) continue;
      
      const filePath = path.join(this.basePath, file);
      const stats = await fs.stat(filePath);
      
      if (stats.mtimeMs < cutoff) {
        await fs.unlink(filePath);
        cleaned++;
      }
    }
    
    return cleaned;
  }
  
  private async attemptRecovery(sessionId: string): Promise<SessionData | null> {
    // Try to load from backup
    const backupPath = this.getBackupPath(sessionId);
    
    try {
      const content = await fs.readFile(backupPath, 'utf-8');
      const parsed = SessionDataSchema.parse(JSON.parse(content));
      
      // Restore from backup
      await this.save(parsed);
      console.log(`Session ${sessionId} recovered from backup`);
      
      return parsed;
    } catch {
      console.error(`Session ${sessionId} recovery failed`);
      return null;
    }
  }
  
  private getSessionPath(sessionId: string): string {
    return path.join(this.basePath, `${sessionId}.json`);
  }
  
  private getBackupPath(sessionId: string): string {
    return path.join(this.basePath, 'backups', `${sessionId}.json`);
  }
  
  private calculateChecksum(data: Omit<SessionData, 'checksum'>): string {
    const crypto = require('crypto');
    return crypto
      .createHash('sha256')
      .update(JSON.stringify(data))
      .digest('hex')
      .slice(0, 16);
  }
}

// Simple lock manager
class LockManager {
  private locks = new Map<string, Promise<void>>();
  
  async acquire(key: string): Promise<() => void> {
    while (this.locks.has(key)) {
      await this.locks.get(key);
    }
    
    let release: () => void;
    const lockPromise = new Promise<void>(resolve => {
      release = resolve;
    });
    
    this.locks.set(key, lockPromise);
    
    return () => {
      this.locks.delete(key);
      release!();
    };
  }
}
```

---

### Solution 7.4: Memory Database Resilience

**Addresses**: Issue 7.4 - Memory/Vector Database Resilience  
**Priority**: P2  
**Effort**: Medium (1 sprint)

#### Implementation

```typescript
// src/memory/resilient-store.ts

import * as fs from 'fs/promises';
import * as path from 'path';

interface BackupConfig {
  enabled: boolean;
  interval: number; // ms
  maxBackups: number;
  backupPath: string;
}

export class ResilientMemoryStore {
  private dbPath: string;
  private backupConfig: BackupConfig;
  private backupTimer?: NodeJS.Timer;
  
  constructor(dbPath: string, backupConfig?: Partial<BackupConfig>) {
    this.dbPath = dbPath;
    this.backupConfig = {
      enabled: true,
      interval: 60 * 60 * 1000, // 1 hour
      maxBackups: 24,
      backupPath: path.join(path.dirname(dbPath), 'backups'),
      ...backupConfig,
    };
    
    if (this.backupConfig.enabled) {
      this.startBackupSchedule();
    }
  }
  
  async backup(): Promise<string> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupFile = path.join(
      this.backupConfig.backupPath,
      `memory-${timestamp}.db`
    );
    
    await fs.mkdir(this.backupConfig.backupPath, { recursive: true });
    await fs.copyFile(this.dbPath, backupFile);
    
    // Cleanup old backups
    await this.cleanupOldBackups();
    
    return backupFile;
  }
  
  async restore(backupFile?: string): Promise<void> {
    const fileToRestore = backupFile ?? await this.getLatestBackup();
    
    if (!fileToRestore) {
      throw new Error('No backup available to restore');
    }
    
    // Verify backup integrity before restore
    await this.verifyIntegrity(fileToRestore);
    
    // Backup current (potentially corrupted) file
    const corruptedPath = `${this.dbPath}.corrupted.${Date.now()}`;
    await fs.rename(this.dbPath, corruptedPath).catch(() => {});
    
    // Restore from backup
    await fs.copyFile(fileToRestore, this.dbPath);
  }
  
  async verifyIntegrity(dbPath?: string): Promise<boolean> {
    const pathToCheck = dbPath ?? this.dbPath;
    
    try {
      // SQLite integrity check
      const sqlite = await import('better-sqlite3');
      const db = new sqlite.default(pathToCheck, { readonly: true });
      
      const result = db.pragma('integrity_check');
      db.close();
      
      return result[0]?.integrity_check === 'ok';
    } catch {
      return false;
    }
  }
  
  async healthCheck(): Promise<{
    healthy: boolean;
    size: number;
    lastBackup: string | null;
    backupCount: number;
  }> {
    const stats = await fs.stat(this.dbPath).catch(() => null);
    const backups = await this.listBackups();
    const healthy = await this.verifyIntegrity();
    
    return {
      healthy,
      size: stats?.size ?? 0,
      lastBackup: backups[0]?.name ?? null,
      backupCount: backups.length,
    };
  }
  
  private startBackupSchedule(): void {
    this.backupTimer = setInterval(async () => {
      try {
        await this.backup();
      } catch (error) {
        console.error('Scheduled backup failed:', error);
      }
    }, this.backupConfig.interval);
  }
  
  private async listBackups(): Promise<{ name: string; mtime: Date }[]> {
    try {
      const files = await fs.readdir(this.backupConfig.backupPath);
      const backups = await Promise.all(
        files
          .filter(f => f.startsWith('memory-') && f.endsWith('.db'))
          .map(async f => {
            const stats = await fs.stat(path.join(this.backupConfig.backupPath, f));
            return { name: f, mtime: stats.mtime };
          })
      );
      
      return backups.sort((a, b) => b.mtime.getTime() - a.mtime.getTime());
    } catch {
      return [];
    }
  }
  
  private async getLatestBackup(): Promise<string | null> {
    const backups = await this.listBackups();
    if (backups.length === 0) return null;
    return path.join(this.backupConfig.backupPath, backups[0].name);
  }
  
  private async cleanupOldBackups(): Promise<void> {
    const backups = await this.listBackups();
    
    if (backups.length > this.backupConfig.maxBackups) {
      const toDelete = backups.slice(this.backupConfig.maxBackups);
      
      for (const backup of toDelete) {
        await fs.unlink(path.join(this.backupConfig.backupPath, backup.name));
      }
    }
  }
  
  stop(): void {
    if (this.backupTimer) {
      clearInterval(this.backupTimer);
    }
  }
}
```

---

### Solution 7.5-7.12: Quick Reference Solutions

#### 7.5: Plugin Security

```typescript
// Plugin permission model
interface PluginPermissions {
  network: boolean;
  fileSystem: 'none' | 'read' | 'write';
  credentials: boolean;
  exec: boolean;
}

// Default: minimal permissions
const DEFAULT_PERMISSIONS: PluginPermissions = {
  network: false,
  fileSystem: 'none',
  credentials: false,
  exec: false,
};
```

#### 7.6: API Key Rotation

```typescript
// Key rotation reminder
async function checkKeyAge(): Promise<void> {
  const keys = await getConfiguredApiKeys();
  const maxAge = 90 * 24 * 60 * 60 * 1000; // 90 days
  
  for (const [name, metadata] of keys) {
    if (Date.now() - metadata.createdAt > maxAge) {
      console.warn(`API key '${name}' is over 90 days old. Consider rotating.`);
    }
  }
}
```

#### 7.7: Error Message Sanitization

```typescript
// User-facing error sanitization
function sanitizeErrorForUser(error: Error): string {
  // Remove file paths, stack traces, internal details
  const message = error.message
    .replace(/\/Users\/[^\/]+\//g, '~/')
    .replace(/at\s+.+\(.+\)/g, '')
    .replace(/\n\s+at\s+/g, '');
  
  return message.slice(0, 200);
}
```

#### 7.8: Webhook Signature Verification

See **SPEC-SOLUTION-2.0** Section 2.2 for webhook signature implementation.

#### 7.9: Timezone Handling

```typescript
// Always use UTC internally
function normalizeToUTC(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  return d.toISOString();
}

// Display in user's timezone
function displayInUserTz(utc: string, timezone: string): string {
  return new Date(utc).toLocaleString('en-US', { timeZone: timezone });
}
```

#### 7.10: Graceful Shutdown

```typescript
// Graceful shutdown handler
const shutdownHandlers: (() => Promise<void>)[] = [];

export function registerShutdownHandler(handler: () => Promise<void>): void {
  shutdownHandlers.push(handler);
}

async function gracefulShutdown(signal: string): Promise<void> {
  console.log(`Received ${signal}, starting graceful shutdown...`);
  
  const timeout = setTimeout(() => {
    console.error('Shutdown timeout, forcing exit');
    process.exit(1);
  }, 30_000);
  
  for (const handler of shutdownHandlers) {
    try {
      await handler();
    } catch (error) {
      console.error('Shutdown handler error:', error);
    }
  }
  
  clearTimeout(timeout);
  process.exit(0);
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
```

#### 7.11: Audit Trail

See **SPEC-SOLUTION-5.0** Section 5.4 for structured logging and audit implementation.

#### 7.12: Resource Limits

```typescript
// Resource monitoring
const RESOURCE_LIMITS = {
  maxMemoryPercent: 90,
  maxDiskPercent: 95,
  maxOpenFiles: 10000,
};

async function checkResourceLimits(): Promise<{
  healthy: boolean;
  warnings: string[];
}> {
  const warnings: string[] = [];
  
  // Memory check
  const mem = process.memoryUsage();
  const memPercent = (mem.heapUsed / mem.heapTotal) * 100;
  if (memPercent > RESOURCE_LIMITS.maxMemoryPercent) {
    warnings.push(`Memory usage at ${memPercent.toFixed(1)}%`);
  }
  
  // Disk check would require platform-specific implementation
  
  return {
    healthy: warnings.length === 0,
    warnings,
  };
}
```

---

## Implementation Roadmap

### Sprint 1: Critical Safety
- [ ] Multi-agent git guardrails
- [ ] Credential encryption
- [ ] Graceful shutdown

### Sprint 2: Data Integrity
- [ ] Robust session store
- [ ] Memory database resilience
- [ ] Backup automation

### Sprint 3: Operational
- [ ] Plugin security model
- [ ] Resource monitoring
- [ ] Audit trail

---

## Success Criteria

- [ ] No git safety violations in multi-agent scenarios
- [ ] Credentials encrypted at rest
- [ ] Session integrity checks passing
- [ ] Memory database has automated backups
- [ ] Graceful shutdown completing within timeout
- [ ] Resource monitoring alerts configured

---

**Document Maintainer**: Operations Team  
**Last Updated**: 2026-01-28
