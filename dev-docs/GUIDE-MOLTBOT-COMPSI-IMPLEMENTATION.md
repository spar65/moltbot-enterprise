# Implementation Guide: Moltbot Compsi SDK Integration

**Document ID**: GUIDE-MOLTBOT-COMPSI-IMPLEMENTATION  
**Version**: 1.0  
**Date Created**: 2026-01-28  
**Target Audience**: LLM Agents (BB, Claude, etc.) and Developers  
**Prerequisites**:
- SPEC-DECISION-MOLTBOT-COMPSI-INTEGRATION.md (read)
- SPEC-INTEGRATION-MOLTBOT-COMPSI-SDK.md (read)

---

## Purpose

This guide provides **step-by-step implementation instructions** for integrating the Compsi SDK into Moltbot for daily ethical assessments. It is designed to be followed by an LLM agent or developer to successfully implement the integration.

---

## Table of Contents

1. [Prerequisites Check](#1-prerequisites-check)
2. [Install Dependencies](#2-install-dependencies)
3. [Create Directory Structure](#3-create-directory-structure)
4. [Implement Type Definitions](#4-implement-type-definitions)
5. [Implement Audit Logger](#5-implement-audit-logger)
6. [Implement State Machine](#6-implement-state-machine)
7. [Implement Compsi Client Wrapper](#7-implement-compsi-client-wrapper)
8. [Implement Assessment Gate](#8-implement-assessment-gate)
9. [Implement Chat Handler](#9-implement-chat-handler)
10. [Implement Configuration Loader](#10-implement-configuration-loader)
11. [Create Public Exports](#11-create-public-exports)
12. [Integrate with Moltbot Router](#12-integrate-with-moltbot-router)
13. [Write Tests](#13-write-tests)
14. [Configure and Deploy](#14-configure-and-deploy)
15. [Troubleshooting](#15-troubleshooting)

---

## 1. Prerequisites Check

### 1.1 Verify Moltbot Codebase

```bash
# Navigate to Moltbot root
cd /Users/spehargreg/Development/moltbot-main

# Verify src directory exists
ls src/

# Expected output should include:
# - cli/
# - commands/
# - logging/
# - (other existing directories)
```

### 1.2 Verify Node.js Version

```bash
node --version
# Expected: v22.x.x or higher
```

### 1.3 Check Existing Dependencies

```bash
# Check if related packages exist
cat package.json | grep -E "(zod|crypto)"
```

---

## 2. Install Dependencies

### 2.1 Install Compsi SDK

```bash
cd /Users/spehargreg/Development/moltbot-main

# Install the Compsi TypeScript SDK
pnpm add @aiassesstech/sdk
```

### 2.2 Verify Installation

```bash
# Check package was installed
cat package.json | grep aiassesstech

# Expected output:
# "@aiassesstech/sdk": "^0.7.0" (or similar version)
```

---

## 3. Create Directory Structure

### 3.1 Create Compsi Module Directory

```bash
cd /Users/spehargreg/Development/moltbot-main

# Create the compsi module directory
mkdir -p src/compsi/__tests__/fixtures

# Create all required files
touch src/compsi/index.ts
touch src/compsi/types.ts
touch src/compsi/client.ts
touch src/compsi/state-machine.ts
touch src/compsi/gate.ts
touch src/compsi/audit.ts
touch src/compsi/chat-handler.ts
touch src/compsi/config.ts
touch src/compsi/scheduler.ts
touch src/compsi/__tests__/client.test.ts
touch src/compsi/__tests__/state-machine.test.ts
touch src/compsi/__tests__/gate.test.ts
touch src/compsi/__tests__/integration.test.ts
touch src/compsi/__tests__/fixtures/configs.ts
touch src/compsi/__tests__/fixtures/users.ts
```

### 3.2 Verify Directory Structure

```bash
ls -la src/compsi/

# Expected:
# index.ts
# types.ts
# client.ts
# state-machine.ts
# gate.ts
# audit.ts
# chat-handler.ts
# config.ts
# scheduler.ts
# __tests__/
```

---

## 4. Implement Type Definitions

### 4.1 Create Types File

**File: `src/compsi/types.ts`**

```typescript
/**
 * Compsi Integration Types for Moltbot
 * 
 * Core type definitions for the Compsi SDK integration.
 * These types define the data structures used throughout the integration.
 */

import type { 
  AssessmentResult, 
  AssessProgress 
} from '@aiassesstech/sdk';

// ============================================================
// ASSESSMENT STATE TYPES
// ============================================================

/**
 * Possible states in the assessment lifecycle
 */
export type AssessmentState = 
  | 'IDLE'         // Outside assessment window, no action required
  | 'PENDING'      // Assessment required, not yet started
  | 'IN_PROGRESS'  // Assessment actively being taken
  | 'PAUSED'       // Assessment paused (e.g., user disconnected)
  | 'PASSED'       // Assessment completed and passed
  | 'FAILED'       // Assessment completed but failed
  | 'RETRYING'     // Retry attempt in progress
  | 'BYPASSED'     // Manager-approved bypass
  | 'EXPIRED';     // Assessment expired (not completed in time)

/**
 * Dimension scores from assessment (0-10 scale)
 */
export interface DimensionScores {
  lying: number;
  cheating: number;
  stealing: number;
  harm: number;
  [key: string]: number; // Support additional dimensions
}

/**
 * Personality classification from Compsi
 */
export type Classification = 
  | 'Well Adjusted'
  | 'Misguided'
  | 'Manipulative'
  | 'Psychopath';

/**
 * Individual question response during assessment
 */
export interface AssessmentResponse {
  questionId: string;
  questionText: string;
  answerLetter: 'A' | 'B' | 'C' | 'D';
  answerText: string;
  dimension: 'Lying' | 'Cheating' | 'Stealing' | 'Harm';
  respondedAt: Date;
  durationMs: number;
}

/**
 * User's current assessment status
 */
export interface UserAssessmentStatus {
  userId: string;
  organizationId: string;
  state: AssessmentState;
  stateChangedAt: Date;
  
  // Current session (if in progress)
  currentSession?: {
    sessionId: string;
    frameworkId: string;
    startedAt: Date;
    progress: AssessProgress;
    lastQuestionId?: string;
    responses: AssessmentResponse[];
  };
  
  // Last completed assessment (today)
  todayResult?: {
    runId: string;
    completedAt: Date;
    frameworkId: string;
    scores: DimensionScores;
    passed: boolean;
    classification: Classification;
    verifyUrl: string;
  };
  
  // Today's statistics
  todayStats: {
    attempts: number;
    maxAttempts: number;
    retriesRemaining: number;
    bypassed: boolean;
    bypassApprovedBy?: string;
    bypassReason?: string;
    bypassExpiresAt?: Date;
  };
  
  // Access level based on state
  accessLevel: 'full' | 'limited' | 'blocked';
}

// ============================================================
// CONFIGURATION TYPES
// ============================================================

/**
 * Organization-level assessment configuration
 */
export interface OrganizationAssessmentConfig {
  organizationId: string;
  enabled: boolean;
  
  // Compsi SDK configuration
  compsi: {
    healthCheckKey: string;
    baseUrl?: string;
    perQuestionTimeoutMs?: number;
    overallTimeoutMs?: number;
  };
  
  // Schedule configuration
  schedule: AssessmentScheduleConfig;
  
  // Framework configuration
  frameworks: FrameworkConfig[];
  
  // Role-based overrides
  roleOverrides: RoleOverrideConfig[];
  
  // Retry policy
  retry: RetryConfig;
  
  // Bypass policy
  bypass: BypassConfig;
  
  // Audit configuration
  audit: AuditConfig;
  
  // UI/UX configuration
  ux: UXConfig;
}

/**
 * Assessment schedule configuration
 */
export interface AssessmentScheduleConfig {
  frequency: 'daily' | 'weekly' | 'monthly' | 'on_demand';
  windowStart: string;       // "06:00" (24-hour format)
  windowEnd: string;         // "10:00"
  timezone: string;          // IANA timezone
  gracePeriodMinutes: number;
  skipWeekends: boolean;
  skipHolidays: boolean;
  holidayCalendarId?: string;
  validForHours: number;
}

/**
 * Framework configuration
 */
export interface FrameworkConfig {
  id: string;
  name: string;
  description?: string;
  required: boolean;
  priority: number;
  thresholds: {
    lying: number;
    cheating: number;
    stealing: number;
    harm: number;
    [key: string]: number;
  };
  schedule?: 'daily' | 'weekly' | 'rotation';
  rotationDayOfWeek?: number;
}

/**
 * Role-specific override configuration
 */
export interface RoleOverrideConfig {
  roleId: string;
  roleName: string;
  frameworks?: string[];
  thresholds?: { [dimension: string]: number };
  frequency?: 'daily' | 'weekly';
  requiresManagerApprovalOnFail?: boolean;
  maxRetryAttempts?: number;
}

/**
 * Retry configuration
 */
export interface RetryConfig {
  maxAttempts: number;
  cooldownMinutes: number;
  requiresApproval: boolean;
  approverRoles?: string[];
}

/**
 * Bypass configuration
 */
export interface BypassConfig {
  enabled: boolean;
  approverRoles: string[];
  maxPerMonth: number;
  requiresJustification: boolean;
  maxDurationHours: number;
  auditRequired: boolean;
}

/**
 * Audit configuration
 */
export interface AuditConfig {
  enabled: boolean;
  retentionDays: number;
  encryptAtRest: boolean;
  signEntries: boolean;
  exportEnabled: boolean;
  exportFormats: ('json' | 'csv' | 'pdf')[];
}

/**
 * UX configuration
 */
export interface UXConfig {
  showProgress: boolean;
  showTimeRemaining: boolean;
  allowPause: boolean;
  pauseTimeoutMinutes: number;
  confirmBeforeStart: boolean;
  showResultsDetail: boolean;
  celebrateSuccess: boolean;
}

// ============================================================
// GATE TYPES
// ============================================================

/**
 * Gate decision for work requests
 */
export interface GateDecision {
  allowed: boolean;
  accessLevel: 'full' | 'limited' | 'blocked';
  reason?: GateReason;
  requiredAction?: RequiredAction;
  message: string;
}

export type GateReason = 
  | 'assessment_passed'
  | 'assessment_pending'
  | 'assessment_failed'
  | 'assessment_expired'
  | 'assessment_bypassed'
  | 'outside_schedule'
  | 'task_requires_higher_threshold';

export type RequiredAction = 
  | 'complete_assessment'
  | 'retry_assessment'
  | 'wait_for_retry_cooldown'
  | 'request_bypass'
  | 'contact_manager';

/**
 * Task sensitivity configuration
 */
export interface TaskSensitivity {
  taskType: string;
  sensitivityLevel: 'low' | 'medium' | 'high' | 'critical';
  minimumThresholds: DimensionScores;
  requiredFrameworks: string[];
  auditRequired: boolean;
}

// ============================================================
// AUDIT TYPES
// ============================================================

/**
 * Audit log entry
 */
export interface AuditLogEntry {
  id: string;
  timestamp: Date;
  organizationId: string;
  userId: string;
  eventType: AuditEventType;
  data: Record<string, unknown>;
  context: {
    sessionId?: string;
    runId?: string;
    frameworkId?: string;
    channel?: string;
    ipAddress?: string;
    userAgent?: string;
  };
  signature?: string;
  previousEntryHash?: string;
}

export type AuditEventType = 
  | 'assessment_started'
  | 'assessment_response'
  | 'assessment_completed'
  | 'assessment_passed'
  | 'assessment_failed'
  | 'state_transition'
  | 'retry_requested'
  | 'retry_approved'
  | 'bypass_requested'
  | 'bypass_approved'
  | 'bypass_denied'
  | 'config_changed'
  | 'audit_exported';

// ============================================================
// CLIENT TYPES
// ============================================================

/**
 * Configuration for MoltbotAssessmentClient
 */
export interface MoltbotAssessmentClientConfig {
  organizationConfig: OrganizationAssessmentConfig;
  userId: string;
  userRoles: string[];
}

/**
 * Callback type for asking user a question
 */
export type AskUserCallback = (
  question: string, 
  metadata: QuestionMetadata
) => Promise<string>;

/**
 * Metadata about the current question
 */
export interface QuestionMetadata {
  questionNumber: number;
  totalQuestions: number;
  dimension: string;
  frameworkId: string;
  timeoutMs: number;
}

/**
 * Progress callback for UI updates
 */
export type ProgressCallback = (progress: AssessmentProgressUpdate) => void;

/**
 * Extended progress information
 */
export interface AssessmentProgressUpdate extends AssessProgress {
  frameworkId: string;
  frameworkName: string;
  canPause: boolean;
  estimatedMinutesRemaining: number;
}

/**
 * Result of a Moltbot assessment (extends Compsi result)
 */
export interface MoltbotAssessmentResult extends AssessmentResult {
  userId: string;
  organizationId: string;
  frameworkId: string;
  startedAt: Date;
  completedAt: Date;
  durationMs: number;
  responses: AssessmentResponse[];
  appliedThresholds: DimensionScores;
  roleOverridesApplied: string[];
}
```

---

## 5. Implement Audit Logger

### 5.1 Create Audit Logger

**File: `src/compsi/audit.ts`**

```typescript
/**
 * Assessment Audit Logger
 * 
 * Provides immutable audit trail for all assessment events.
 * Supports cryptographic signing and chain verification.
 */

import crypto from 'crypto';
import type {
  AuditLogEntry,
  AuditEventType,
  AuditConfig,
} from './types';

/**
 * Default audit configuration
 */
const DEFAULT_AUDIT_CONFIG: AuditConfig = {
  enabled: true,
  retentionDays: 365,
  encryptAtRest: false,
  signEntries: true,
  exportEnabled: true,
  exportFormats: ['json', 'csv'],
};

/**
 * Audit Logger for assessment events
 */
export class AuditLogger {
  private config: AuditConfig;
  private entries: AuditLogEntry[] = [];
  private lastEntryHash: string = '';
  private signingKey: string;
  
  constructor(config: Partial<AuditConfig> = {}) {
    this.config = { ...DEFAULT_AUDIT_CONFIG, ...config };
    this.signingKey = process.env.AUDIT_SIGNING_KEY || 'moltbot-audit-key';
  }
  
  /**
   * Log an audit event
   */
  async log(params: {
    eventType: AuditEventType;
    userId: string;
    organizationId: string;
    data: Record<string, unknown>;
    context?: Record<string, unknown>;
  }): Promise<AuditLogEntry> {
    if (!this.config.enabled) {
      return this.createEmptyEntry();
    }
    
    const entry: AuditLogEntry = {
      id: this.generateId(),
      timestamp: new Date(),
      organizationId: params.organizationId,
      userId: params.userId,
      eventType: params.eventType,
      data: this.sanitizeData(params.data),
      context: params.context || {},
    };
    
    // Add chain hash for integrity
    if (this.config.signEntries) {
      entry.previousEntryHash = this.lastEntryHash;
      entry.signature = this.signEntry(entry);
      this.lastEntryHash = this.hashEntry(entry);
    }
    
    // Store entry
    await this.persistEntry(entry);
    this.entries.push(entry);
    
    return entry;
  }
  
  /**
   * Query audit log with filters
   */
  async query(filters: {
    userId?: string;
    organizationId?: string;
    eventType?: AuditEventType;
    startDate?: Date;
    endDate?: Date;
    limit?: number;
    offset?: number;
  }): Promise<AuditLogEntry[]> {
    let results = [...this.entries];
    
    // Apply filters
    if (filters.userId) {
      results = results.filter(e => e.userId === filters.userId);
    }
    if (filters.organizationId) {
      results = results.filter(e => e.organizationId === filters.organizationId);
    }
    if (filters.eventType) {
      results = results.filter(e => e.eventType === filters.eventType);
    }
    if (filters.startDate) {
      results = results.filter(e => e.timestamp >= filters.startDate!);
    }
    if (filters.endDate) {
      results = results.filter(e => e.timestamp <= filters.endDate!);
    }
    
    // Sort by timestamp descending
    results.sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());
    
    // Apply pagination
    const offset = filters.offset || 0;
    const limit = filters.limit || 100;
    
    return results.slice(offset, offset + limit);
  }
  
  /**
   * Export audit log to specified format
   */
  async export(
    filters: Parameters<typeof this.query>[0],
    format: 'json' | 'csv'
  ): Promise<string> {
    if (!this.config.exportEnabled) {
      throw new Error('Audit export is disabled');
    }
    
    const entries = await this.query(filters);
    
    // Log export event
    await this.log({
      eventType: 'audit_exported',
      userId: 'system',
      organizationId: filters.organizationId || 'all',
      data: { format, entryCount: entries.length, filters },
    });
    
    if (format === 'json') {
      return JSON.stringify(entries, null, 2);
    }
    
    // CSV format
    if (entries.length === 0) return '';
    
    const headers = ['id', 'timestamp', 'userId', 'eventType', 'data'];
    const rows = entries.map(e => [
      e.id,
      e.timestamp.toISOString(),
      e.userId,
      e.eventType,
      JSON.stringify(e.data),
    ]);
    
    return [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
  }
  
  /**
   * Verify audit chain integrity
   */
  async verifyIntegrity(): Promise<{
    valid: boolean;
    brokenAtIndex?: number;
    message: string;
  }> {
    if (!this.config.signEntries) {
      return { valid: true, message: 'Signing disabled' };
    }
    
    let previousHash = '';
    
    for (let i = 0; i < this.entries.length; i++) {
      const entry = this.entries[i];
      
      // Verify previous hash link
      if (entry.previousEntryHash !== previousHash) {
        return {
          valid: false,
          brokenAtIndex: i,
          message: `Chain broken at entry ${i}: hash mismatch`,
        };
      }
      
      // Verify signature
      const expectedSignature = this.signEntry(entry);
      if (entry.signature !== expectedSignature) {
        return {
          valid: false,
          brokenAtIndex: i,
          message: `Signature invalid at entry ${i}`,
        };
      }
      
      previousHash = this.hashEntry(entry);
    }
    
    return { valid: true, message: 'Audit chain verified' };
  }
  
  /**
   * Get entries for a specific user
   */
  async getForUser(userId: string, limit = 50): Promise<AuditLogEntry[]> {
    return this.query({ userId, limit });
  }
  
  /**
   * Get recent entries
   */
  async getRecent(limit = 50): Promise<AuditLogEntry[]> {
    return this.query({ limit });
  }
  
  // ============================================================
  // PRIVATE HELPERS
  // ============================================================
  
  private generateId(): string {
    const timestamp = Date.now().toString(36);
    const random = crypto.randomBytes(4).toString('hex');
    return `audit_${timestamp}_${random}`;
  }
  
  private createEmptyEntry(): AuditLogEntry {
    return {
      id: '',
      timestamp: new Date(),
      organizationId: '',
      userId: '',
      eventType: 'assessment_started',
      data: {},
      context: {},
    };
  }
  
  private sanitizeData(data: Record<string, unknown>): Record<string, unknown> {
    const sensitiveKeys = ['password', 'apiKey', 'token', 'secret', 'key'];
    const sanitized: Record<string, unknown> = {};
    
    for (const [key, value] of Object.entries(data)) {
      if (sensitiveKeys.some(s => key.toLowerCase().includes(s))) {
        sanitized[key] = '[REDACTED]';
      } else if (typeof value === 'object' && value !== null) {
        sanitized[key] = this.sanitizeData(value as Record<string, unknown>);
      } else {
        sanitized[key] = value;
      }
    }
    
    return sanitized;
  }
  
  private hashEntry(entry: AuditLogEntry): string {
    const content = JSON.stringify({
      id: entry.id,
      timestamp: entry.timestamp,
      eventType: entry.eventType,
      userId: entry.userId,
      data: entry.data,
    });
    
    return crypto.createHash('sha256').update(content).digest('hex');
  }
  
  private signEntry(entry: AuditLogEntry): string {
    const content = JSON.stringify({
      id: entry.id,
      timestamp: entry.timestamp,
      eventType: entry.eventType,
      userId: entry.userId,
      data: entry.data,
      previousEntryHash: entry.previousEntryHash,
    });
    
    return crypto
      .createHmac('sha256', this.signingKey)
      .update(content)
      .digest('hex');
  }
  
  private async persistEntry(entry: AuditLogEntry): Promise<void> {
    // TODO: Implement database persistence
    // For now, entries are kept in memory
    // In production, persist to database with:
    // await db.auditLogs.create({ data: entry });
  }
}
```

---

## 6. Implement State Machine

### 6.1 Create State Machine

**File: `src/compsi/state-machine.ts`**

```typescript
/**
 * Assessment State Machine
 * 
 * Manages the lifecycle of user assessments with clear state transitions.
 */

import type {
  AssessmentState,
  UserAssessmentStatus,
  MoltbotAssessmentResult,
} from './types';

import { AuditLogger } from './audit';

/**
 * Context passed to transition guards and actions
 */
interface TransitionContext {
  userId: string;
  currentState: AssessmentState;
  trigger: string;
  metadata: Record<string, unknown>;
  status: UserAssessmentStatus;
}

/**
 * State transition definition
 */
interface TransitionDefinition {
  from: AssessmentState | AssessmentState[];
  to: AssessmentState;
  trigger: string;
  guard?: (context: TransitionContext) => boolean;
}

/**
 * Assessment State Machine
 */
export class AssessmentStateMachine {
  private auditLogger: AuditLogger;
  private stateStore: Map<string, UserAssessmentStatus> = new Map();
  
  // Define all valid state transitions
  private readonly transitions: TransitionDefinition[] = [
    // Day start - require assessment
    { from: 'IDLE', to: 'PENDING', trigger: 'DAY_START' },
    
    // Start assessment
    { from: 'PENDING', to: 'IN_PROGRESS', trigger: 'START_ASSESSMENT' },
    
    // Resume from failed (with retry check)
    { 
      from: 'FAILED', 
      to: 'RETRYING', 
      trigger: 'RETRY_ASSESSMENT',
      guard: (ctx) => ctx.status.todayStats.retriesRemaining > 0,
    },
    
    // Retry starts
    { from: 'RETRYING', to: 'IN_PROGRESS', trigger: 'START_ASSESSMENT' },
    
    // Pause assessment
    { from: 'IN_PROGRESS', to: 'PAUSED', trigger: 'PAUSE_ASSESSMENT' },
    
    // Resume from pause
    { from: 'PAUSED', to: 'IN_PROGRESS', trigger: 'RESUME_ASSESSMENT' },
    
    // Pause expires
    { from: 'PAUSED', to: 'EXPIRED', trigger: 'PAUSE_TIMEOUT' },
    
    // Assessment passed
    { from: ['IN_PROGRESS', 'RETRYING'], to: 'PASSED', trigger: 'ASSESSMENT_PASSED' },
    
    // Assessment failed
    { from: ['IN_PROGRESS', 'RETRYING'], to: 'FAILED', trigger: 'ASSESSMENT_FAILED' },
    
    // Manager bypass
    { from: ['PENDING', 'FAILED'], to: 'BYPASSED', trigger: 'MANAGER_BYPASS' },
    
    // Day end - reset
    { from: ['PASSED', 'FAILED', 'BYPASSED', 'EXPIRED'], to: 'IDLE', trigger: 'DAY_END' },
  ];
  
  constructor(auditLogger: AuditLogger) {
    this.auditLogger = auditLogger;
  }
  
  /**
   * Transition to a new state
   */
  async transition(
    userId: string,
    trigger: string,
    metadata: Record<string, unknown> = {}
  ): Promise<UserAssessmentStatus> {
    const status = await this.getStatus(userId);
    const currentState = status.state;
    
    // Find valid transition
    const transition = this.transitions.find(t => {
      const fromStates = Array.isArray(t.from) ? t.from : [t.from];
      return fromStates.includes(currentState) && t.trigger === trigger;
    });
    
    if (!transition) {
      throw new Error(
        `Invalid transition: ${currentState} --[${trigger}]--> ? for user ${userId}`
      );
    }
    
    // Build context for guard check
    const context: TransitionContext = {
      userId,
      currentState,
      trigger,
      metadata,
      status,
    };
    
    // Check guard condition
    if (transition.guard && !transition.guard(context)) {
      throw new Error(
        `Transition guard failed: ${currentState} --[${trigger}]--> ${transition.to}`
      );
    }
    
    // Update state
    const newStatus = this.applyTransition(status, transition.to, metadata);
    this.stateStore.set(userId, newStatus);
    
    // Log transition
    await this.auditLogger.log({
      eventType: 'state_transition',
      userId,
      organizationId: status.organizationId,
      data: {
        from: currentState,
        to: transition.to,
        trigger,
        metadata,
      },
      context: { sessionId: metadata.sessionId as string },
    });
    
    return newStatus;
  }
  
  /**
   * Get current status for a user
   */
  async getStatus(userId: string): Promise<UserAssessmentStatus> {
    let status = this.stateStore.get(userId);
    
    if (!status) {
      // Initialize new user status
      status = this.createInitialStatus(userId);
      this.stateStore.set(userId, status);
    }
    
    // Check if status needs refresh (new day)
    status = this.refreshStatusIfNeeded(status);
    
    return status;
  }
  
  /**
   * Check if user can access work
   */
  async canAccessWork(userId: string): Promise<{
    allowed: boolean;
    accessLevel: 'full' | 'limited' | 'blocked';
    reason: string;
  }> {
    const status = await this.getStatus(userId);
    
    switch (status.state) {
      case 'PASSED':
      case 'BYPASSED':
        return { 
          allowed: true, 
          accessLevel: 'full',
          reason: 'Assessment passed or bypassed',
        };
      
      case 'IDLE':
        return { 
          allowed: true, 
          accessLevel: 'full',
          reason: 'Outside assessment window',
        };
      
      case 'PENDING':
      case 'PAUSED':
        return { 
          allowed: true, 
          accessLevel: 'limited',
          reason: 'Assessment required - limited access',
        };
      
      case 'IN_PROGRESS':
      case 'RETRYING':
        return { 
          allowed: false, 
          accessLevel: 'blocked',
          reason: 'Complete assessment to access work',
        };
      
      case 'FAILED':
        if (status.todayStats.retriesRemaining > 0) {
          return { 
            allowed: true, 
            accessLevel: 'limited',
            reason: 'Assessment failed - retry available',
          };
        }
        return { 
          allowed: false, 
          accessLevel: 'blocked',
          reason: 'Assessment failed - contact manager',
        };
      
      case 'EXPIRED':
        return { 
          allowed: false, 
          accessLevel: 'blocked',
          reason: 'Assessment expired - please restart',
        };
      
      default:
        return { 
          allowed: false, 
          accessLevel: 'blocked',
          reason: 'Unknown state',
        };
    }
  }
  
  /**
   * Set organization ID for a user
   */
  async setOrganization(userId: string, organizationId: string): Promise<void> {
    const status = await this.getStatus(userId);
    status.organizationId = organizationId;
    this.stateStore.set(userId, status);
  }
  
  // ============================================================
  // PRIVATE HELPERS
  // ============================================================
  
  private createInitialStatus(userId: string): UserAssessmentStatus {
    return {
      userId,
      organizationId: '',
      state: 'IDLE',
      stateChangedAt: new Date(),
      currentSession: undefined,
      todayResult: undefined,
      todayStats: {
        attempts: 0,
        maxAttempts: 3,
        retriesRemaining: 3,
        bypassed: false,
      },
      accessLevel: 'full',
    };
  }
  
  private refreshStatusIfNeeded(status: UserAssessmentStatus): UserAssessmentStatus {
    const now = new Date();
    const lastChange = new Date(status.stateChangedAt);
    
    // Check if day has changed
    if (now.toDateString() !== lastChange.toDateString()) {
      // Reset for new day
      return {
        ...status,
        state: 'PENDING',
        stateChangedAt: now,
        todayResult: undefined,
        todayStats: {
          attempts: 0,
          maxAttempts: 3,
          retriesRemaining: 3,
          bypassed: false,
        },
        currentSession: undefined,
        accessLevel: 'limited',
      };
    }
    
    return status;
  }
  
  private applyTransition(
    current: UserAssessmentStatus,
    newState: AssessmentState,
    metadata: Record<string, unknown>
  ): UserAssessmentStatus {
    const updated: UserAssessmentStatus = {
      ...current,
      state: newState,
      stateChangedAt: new Date(),
    };
    
    // Apply state-specific updates
    switch (newState) {
      case 'IN_PROGRESS':
        updated.currentSession = {
          sessionId: metadata.sessionId as string || this.generateSessionId(),
          frameworkId: metadata.frameworkId as string || 'default',
          startedAt: new Date(),
          progress: { 
            current: 0, 
            total: 120, 
            percentage: 0, 
            dimension: 'Lying' as const, 
            elapsedMs: 0, 
            estimatedRemainingMs: 0 
          },
          responses: [],
        };
        updated.todayStats.attempts++;
        break;
      
      case 'PASSED':
        if (metadata.result) {
          const result = metadata.result as MoltbotAssessmentResult;
          updated.todayResult = {
            runId: result.runId,
            completedAt: new Date(),
            frameworkId: result.frameworkId,
            scores: result.scores,
            passed: true,
            classification: result.classification,
            verifyUrl: result.verifyUrl,
          };
        }
        updated.accessLevel = 'full';
        updated.currentSession = undefined;
        break;
      
      case 'FAILED':
        updated.todayStats.retriesRemaining--;
        updated.accessLevel = updated.todayStats.retriesRemaining > 0 
          ? 'limited' 
          : 'blocked';
        updated.currentSession = undefined;
        break;
      
      case 'BYPASSED':
        updated.todayStats.bypassed = true;
        updated.todayStats.bypassApprovedBy = metadata.approvedBy as string;
        updated.todayStats.bypassReason = metadata.reason as string;
        updated.accessLevel = 'full';
        break;
      
      case 'IDLE':
        updated.accessLevel = 'full';
        break;
    }
    
    return updated;
  }
  
  private generateSessionId(): string {
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substring(2, 8);
    return `mas_${timestamp}_${random}`;
  }
}
```

---

## 7. Implement Compsi Client Wrapper

### 7.1 Create Client Wrapper

**File: `src/compsi/client.ts`**

```typescript
/**
 * Moltbot Assessment Client
 * 
 * Wraps the Compsi SDK with Moltbot-specific functionality.
 */

import { 
  AIAssessClient, 
  AssessmentResult,
  AssessProgress,
} from '@aiassesstech/sdk';

import type {
  OrganizationAssessmentConfig,
  UserAssessmentStatus,
  MoltbotAssessmentResult,
  AssessmentResponse,
  DimensionScores,
  FrameworkConfig,
  AskUserCallback,
  ProgressCallback,
  QuestionMetadata,
  AssessmentProgressUpdate,
  MoltbotAssessmentClientConfig,
} from './types';

import { AuditLogger } from './audit';
import { AssessmentStateMachine } from './state-machine';

/**
 * Main assessment client for Moltbot
 */
export class MoltbotAssessmentClient {
  private compsiClient: AIAssessClient;
  private config: OrganizationAssessmentConfig;
  private userId: string;
  private userRoles: string[];
  private auditLogger: AuditLogger;
  private stateMachine: AssessmentStateMachine;
  
  // Session tracking
  private currentSessionId: string | null = null;
  private currentResponses: AssessmentResponse[] = [];
  private sessionStartTime: Date | null = null;
  
  constructor(
    clientConfig: MoltbotAssessmentClientConfig,
    auditLogger: AuditLogger,
    stateMachine: AssessmentStateMachine
  ) {
    this.config = clientConfig.organizationConfig;
    this.userId = clientConfig.userId;
    this.userRoles = clientConfig.userRoles;
    this.auditLogger = auditLogger;
    this.stateMachine = stateMachine;
    
    // Initialize Compsi SDK client
    this.compsiClient = new AIAssessClient({
      healthCheckKey: this.config.compsi.healthCheckKey,
      baseUrl: this.config.compsi.baseUrl,
      perQuestionTimeoutMs: this.config.compsi.perQuestionTimeoutMs,
      overallTimeoutMs: this.config.compsi.overallTimeoutMs,
    });
  }
  
  /**
   * Run a complete assessment
   */
  async runAssessment(
    askUser: AskUserCallback,
    onProgress?: ProgressCallback
  ): Promise<MoltbotAssessmentResult> {
    // Generate session ID
    this.currentSessionId = this.generateSessionId();
    this.currentResponses = [];
    this.sessionStartTime = new Date();
    
    // Select framework
    const framework = this.selectFramework();
    
    // Log assessment start
    await this.auditLogger.log({
      eventType: 'assessment_started',
      userId: this.userId,
      organizationId: this.config.organizationId,
      data: {
        sessionId: this.currentSessionId,
        frameworkId: framework.id,
        userRoles: this.userRoles,
      },
      context: { sessionId: this.currentSessionId, frameworkId: framework.id },
    });
    
    // Update state machine
    await this.stateMachine.transition(this.userId, 'START_ASSESSMENT', {
      sessionId: this.currentSessionId,
      frameworkId: framework.id,
    });
    
    let questionNumber = 0;
    
    try {
      // Run assessment using Compsi SDK
      const result = await this.compsiClient.assess(
        async (question: string) => {
          questionNumber++;
          
          const metadata: QuestionMetadata = {
            questionNumber,
            totalQuestions: 120,
            dimension: this.extractDimension(question),
            frameworkId: framework.id,
            timeoutMs: this.config.compsi.perQuestionTimeoutMs || 30000,
          };
          
          const startTime = Date.now();
          
          // Ask user via Moltbot chat
          const response = await askUser(question, metadata);
          
          const durationMs = Date.now() - startTime;
          
          // Record response
          const assessmentResponse: AssessmentResponse = {
            questionId: `q_${questionNumber}`,
            questionText: question,
            answerLetter: this.extractAnswerLetter(response),
            answerText: response,
            dimension: metadata.dimension as AssessmentResponse['dimension'],
            respondedAt: new Date(),
            durationMs,
          };
          
          this.currentResponses.push(assessmentResponse);
          
          return response;
        },
        {
          onProgress: onProgress ? (progress: AssessProgress) => {
            onProgress({
              ...progress,
              frameworkId: framework.id,
              frameworkName: framework.name,
              canPause: this.config.ux.allowPause,
              estimatedMinutesRemaining: Math.ceil(progress.estimatedRemainingMs / 60000),
            });
          } : undefined,
          metadata: {
            userId: this.userId,
            organizationId: this.config.organizationId,
            moltbotSessionId: this.currentSessionId,
          },
        }
      );
      
      // Apply role-based thresholds
      const appliedThresholds = this.getAppliedThresholds(framework);
      const passed = this.evaluateWithThresholds(result.scores, appliedThresholds);
      
      const completedAt = new Date();
      const durationMs = completedAt.getTime() - this.sessionStartTime!.getTime();
      
      // Build complete result
      const moltbotResult: MoltbotAssessmentResult = {
        ...result,
        overallPassed: passed,
        userId: this.userId,
        organizationId: this.config.organizationId,
        frameworkId: framework.id,
        startedAt: this.sessionStartTime!,
        completedAt,
        durationMs,
        responses: this.currentResponses,
        appliedThresholds,
        roleOverridesApplied: this.getAppliedRoleOverrides(),
      };
      
      // Log completion
      await this.auditLogger.log({
        eventType: passed ? 'assessment_passed' : 'assessment_failed',
        userId: this.userId,
        organizationId: this.config.organizationId,
        data: {
          runId: result.runId,
          scores: result.scores,
          classification: result.classification,
          passed,
          appliedThresholds,
          durationMs,
        },
        context: { 
          sessionId: this.currentSessionId, 
          runId: result.runId,
          frameworkId: framework.id,
        },
      });
      
      // Update state machine
      await this.stateMachine.transition(
        this.userId, 
        passed ? 'ASSESSMENT_PASSED' : 'ASSESSMENT_FAILED',
        { result: moltbotResult }
      );
      
      return moltbotResult;
      
    } catch (error) {
      // Log error
      await this.auditLogger.log({
        eventType: 'assessment_failed',
        userId: this.userId,
        organizationId: this.config.organizationId,
        data: {
          error: error instanceof Error ? error.message : 'Unknown error',
          questionsCompleted: this.currentResponses.length,
        },
        context: { sessionId: this.currentSessionId, frameworkId: framework.id },
      });
      
      throw error;
    }
  }
  
  /**
   * Get current assessment status
   */
  async getStatus(): Promise<UserAssessmentStatus> {
    return this.stateMachine.getStatus(this.userId);
  }
  
  /**
   * Check if assessment is required
   */
  async isAssessmentRequired(): Promise<boolean> {
    const status = await this.getStatus();
    return status.state === 'PENDING' || status.state === 'FAILED';
  }
  
  // ============================================================
  // PRIVATE HELPERS
  // ============================================================
  
  private generateSessionId(): string {
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substring(2, 8);
    return `mas_${timestamp}_${random}`;
  }
  
  private selectFramework(): FrameworkConfig {
    const requiredFrameworks = this.config.frameworks.filter(f => f.required);
    const framework = requiredFrameworks[0] || this.config.frameworks[0];
    
    if (!framework) {
      throw new Error('No framework configured for organization');
    }
    
    return framework;
  }
  
  private getAppliedThresholds(framework: FrameworkConfig): DimensionScores {
    const thresholds = { ...framework.thresholds };
    
    // Apply role overrides (take highest threshold)
    this.config.roleOverrides
      .filter(r => this.userRoles.includes(r.roleId) && r.thresholds)
      .forEach(override => {
        for (const [dim, threshold] of Object.entries(override.thresholds!)) {
          if (!thresholds[dim] || threshold > thresholds[dim]) {
            thresholds[dim] = threshold;
          }
        }
      });
    
    return thresholds as DimensionScores;
  }
  
  private getAppliedRoleOverrides(): string[] {
    return this.config.roleOverrides
      .filter(r => this.userRoles.includes(r.roleId))
      .map(r => r.roleId);
  }
  
  private evaluateWithThresholds(
    scores: DimensionScores, 
    thresholds: DimensionScores
  ): boolean {
    for (const [dimension, threshold] of Object.entries(thresholds)) {
      const score = scores[dimension];
      if (score !== undefined && score < threshold) {
        return false;
      }
    }
    return true;
  }
  
  private extractDimension(question: string): string {
    const q = question.toLowerCase();
    if (q.includes('truth') || q.includes('honest')) return 'Lying';
    if (q.includes('fair') || q.includes('rule')) return 'Cheating';
    if (q.includes('property') || q.includes('own')) return 'Stealing';
    return 'Harm';
  }
  
  private extractAnswerLetter(response: string): 'A' | 'B' | 'C' | 'D' {
    const cleaned = response.trim().toUpperCase();
    const match = cleaned.match(/^[ABCD]/);
    return (match ? match[0] : 'A') as 'A' | 'B' | 'C' | 'D';
  }
}
```

---

## 8. Implement Assessment Gate

### 8.1 Create Gate Middleware

**File: `src/compsi/gate.ts`**

```typescript
/**
 * Assessment Gate
 * 
 * Middleware that enforces assessment requirements before work access.
 */

import type {
  GateDecision,
  UserAssessmentStatus,
  TaskSensitivity,
  DimensionScores,
} from './types';

import { AssessmentStateMachine } from './state-machine';

/**
 * Gate configuration
 */
export interface AssessmentGateConfig {
  enabled: boolean;
  defaultAccessLevel: 'full' | 'limited' | 'blocked';
  limitedModeCapabilities: string[];
  taskSensitivities: TaskSensitivity[];
}

/**
 * Default gate configuration
 */
const DEFAULT_GATE_CONFIG: AssessmentGateConfig = {
  enabled: true,
  defaultAccessLevel: 'limited',
  limitedModeCapabilities: [
    'general_query',
    'help',
    'status',
  ],
  taskSensitivities: [],
};

/**
 * Assessment Gate - controls access to work based on assessment status
 */
export class AssessmentGate {
  private stateMachine: AssessmentStateMachine;
  private config: AssessmentGateConfig;
  
  constructor(
    stateMachine: AssessmentStateMachine,
    config: Partial<AssessmentGateConfig> = {}
  ) {
    this.stateMachine = stateMachine;
    this.config = { ...DEFAULT_GATE_CONFIG, ...config };
  }
  
  /**
   * Check if a user can proceed with a work request
   */
  async checkAccess(
    userId: string,
    taskType?: string
  ): Promise<GateDecision> {
    if (!this.config.enabled) {
      return {
        allowed: true,
        accessLevel: 'full',
        message: 'Assessment gate disabled',
      };
    }
    
    // Get user's assessment status
    const status = await this.stateMachine.getStatus(userId);
    const accessCheck = await this.stateMachine.canAccessWork(userId);
    
    // If task type specified, check sensitivity
    if (taskType && accessCheck.accessLevel !== 'blocked') {
      const sensitivityCheck = this.checkTaskSensitivity(taskType, status);
      if (!sensitivityCheck.allowed) {
        return sensitivityCheck;
      }
    }
    
    // Map access check to gate decision
    return this.buildDecision(status, accessCheck);
  }
  
  /**
   * Check if a task type is allowed in limited mode
   */
  isAllowedInLimitedMode(taskType: string): boolean {
    return this.config.limitedModeCapabilities.includes(taskType);
  }
  
  /**
   * Get message to display to user based on decision
   */
  getMessageForDecision(decision: GateDecision): string {
    if (decision.allowed && decision.accessLevel === 'full') {
      return '';
    }
    
    const messages: Record<string, string> = {
      'complete_assessment': 
        '📋 Please complete your daily assessment to access full AI capabilities.',
      'retry_assessment': 
        '🔄 Your previous assessment didn\'t pass. Would you like to try again?',
      'wait_for_retry_cooldown':
        '⏳ Please wait before retrying your assessment.',
      'request_bypass':
        '🔓 You can request a temporary bypass from your manager.',
      'contact_manager':
        '👤 Please contact your manager for assistance with your assessment.',
    };
    
    return messages[decision.requiredAction || ''] || decision.message;
  }
  
  /**
   * Get capabilities available in limited mode
   */
  getLimitedModeCapabilities(): string[] {
    return this.config.limitedModeCapabilities;
  }
  
  // ============================================================
  // PRIVATE HELPERS
  // ============================================================
  
  private checkTaskSensitivity(
    taskType: string,
    status: UserAssessmentStatus
  ): GateDecision {
    const sensitivity = this.config.taskSensitivities.find(
      t => t.taskType === taskType
    );
    
    if (!sensitivity) {
      return {
        allowed: true,
        accessLevel: 'full',
        message: 'Task has no sensitivity requirements',
      };
    }
    
    if (!status.todayResult) {
      return {
        allowed: false,
        accessLevel: 'limited',
        reason: 'task_requires_higher_threshold',
        requiredAction: 'complete_assessment',
        message: `Task "${taskType}" requires assessment completion`,
      };
    }
    
    // Check each dimension threshold
    const scores = status.todayResult.scores;
    for (const [dimension, minThreshold] of Object.entries(sensitivity.minimumThresholds)) {
      const score = scores[dimension as keyof typeof scores];
      if (score !== undefined && score < minThreshold) {
        return {
          allowed: false,
          accessLevel: 'limited',
          reason: 'task_requires_higher_threshold',
          message: `Task "${taskType}" requires higher ${dimension} score`,
        };
      }
    }
    
    return {
      allowed: true,
      accessLevel: 'full',
      message: 'Task sensitivity requirements met',
    };
  }
  
  private buildDecision(
    status: UserAssessmentStatus,
    accessCheck: { allowed: boolean; accessLevel: string; reason: string }
  ): GateDecision {
    const decision: GateDecision = {
      allowed: accessCheck.allowed,
      accessLevel: accessCheck.accessLevel as 'full' | 'limited' | 'blocked',
      message: accessCheck.reason,
    };
    
    switch (status.state) {
      case 'PENDING':
        decision.reason = 'assessment_pending';
        decision.requiredAction = 'complete_assessment';
        break;
      
      case 'FAILED':
        decision.reason = 'assessment_failed';
        decision.requiredAction = status.todayStats.retriesRemaining > 0
          ? 'retry_assessment'
          : 'contact_manager';
        break;
      
      case 'EXPIRED':
        decision.reason = 'assessment_expired';
        decision.requiredAction = 'complete_assessment';
        break;
      
      case 'PASSED':
        decision.reason = 'assessment_passed';
        break;
      
      case 'BYPASSED':
        decision.reason = 'assessment_bypassed';
        break;
    }
    
    return decision;
  }
}
```

---

## 9. Implement Chat Handler

**File: `src/compsi/chat-handler.ts`**

```typescript
/**
 * Assessment Chat Handler
 * 
 * Handles assessment flow via Moltbot chat interface.
 */

import type {
  AssessmentProgressUpdate,
  QuestionMetadata,
  MoltbotAssessmentResult,
} from './types';

import { MoltbotAssessmentClient } from './client';
import { AssessmentGate } from './gate';

/**
 * Message templates for assessment UI
 */
const MESSAGES = {
  welcome: `
📋 **Daily Assessment Required**

Before accessing AI assistance today, please complete a quick ethical assessment.

**Estimated time:** 5-10 minutes

Reply **"start"** to begin or **"later"** to postpone.
  `.trim(),
  
  question: (question: string, metadata: QuestionMetadata) => `
**Question ${metadata.questionNumber} of ${metadata.totalQuestions}**
*${metadata.dimension}*

${question}

Reply with **A**, **B**, **C**, or **D**.
  `.trim(),
  
  progress: (progress: AssessmentProgressUpdate) => `
📊 Progress: ${progress.percentage}% (${progress.current}/${progress.total})
Time remaining: ~${progress.estimatedMinutesRemaining} minutes
  `.trim(),
  
  passed: (result: MoltbotAssessmentResult) => `
✅ **Assessment Passed!**

Classification: ${result.classification}
Duration: ${Math.round(result.durationMs / 60000)} minutes

**Scores:**
- Lying: ${result.scores.lying.toFixed(1)}/10
- Cheating: ${result.scores.cheating.toFixed(1)}/10
- Stealing: ${result.scores.stealing.toFixed(1)}/10
- Harm: ${result.scores.harm.toFixed(1)}/10

You now have full access to AI assistance!
  `.trim(),
  
  failed: (result: MoltbotAssessmentResult, retriesRemaining: number) => `
❌ **Assessment Not Passed**

Classification: ${result.classification}

${retriesRemaining > 0 
  ? `You have ${retriesRemaining} retry attempt(s). Reply **"retry"** to try again.`
  : `No retries remaining. Please contact your manager.`
}
  `.trim(),
  
  limitedMode: `
⚠️ **Limited Access Mode**

Assessment pending. You have access to basic queries only.
Reply **"start assessment"** to begin.
  `.trim(),
  
  blocked: `
🚫 **Access Blocked**

Please complete your assessment or contact your manager.
Reply **"start assessment"** to begin.
  `.trim(),
};

/**
 * Chat handler for assessment interactions
 */
export class AssessmentChatHandler {
  private client: MoltbotAssessmentClient;
  private gate: AssessmentGate;
  
  constructor(client: MoltbotAssessmentClient, gate: AssessmentGate) {
    this.client = client;
    this.gate = gate;
  }
  
  /**
   * Handle incoming message in assessment context
   */
  async handleMessage(
    message: string,
    sendReply: (text: string) => Promise<void>
  ): Promise<{ consumed: boolean; result?: MoltbotAssessmentResult }> {
    const normalized = message.trim().toLowerCase();
    
    if (normalized === 'start' || normalized === 'start assessment') {
      const result = await this.startAssessment(sendReply);
      return { consumed: true, result };
    }
    
    if (normalized === 'retry') {
      const result = await this.retryAssessment(sendReply);
      return { consumed: true, result };
    }
    
    if (normalized === 'status') {
      await this.showStatus(sendReply);
      return { consumed: true };
    }
    
    if (normalized === 'later' || normalized === 'skip') {
      await sendReply(MESSAGES.limitedMode);
      return { consumed: true };
    }
    
    return { consumed: false };
  }
  
  /**
   * Check if user should be prompted for assessment
   */
  async shouldPromptForAssessment(userId: string): Promise<boolean> {
    const decision = await this.gate.checkAccess(userId);
    return !decision.allowed || decision.accessLevel === 'limited';
  }
  
  /**
   * Get appropriate prompt for user's state
   */
  async getAssessmentPrompt(userId: string): Promise<string> {
    const decision = await this.gate.checkAccess(userId);
    
    if (decision.accessLevel === 'blocked') {
      return MESSAGES.blocked;
    }
    
    if (decision.accessLevel === 'limited') {
      return MESSAGES.limitedMode;
    }
    
    return MESSAGES.welcome;
  }
  
  /**
   * Start assessment flow
   */
  private async startAssessment(
    sendReply: (text: string) => Promise<void>
  ): Promise<MoltbotAssessmentResult | undefined> {
    try {
      await sendReply('Starting assessment... Please answer each question carefully.\n');
      
      const result = await this.client.runAssessment(
        async (question, metadata) => {
          await sendReply(MESSAGES.question(question, metadata));
          // In real implementation, wait for user response
          // This is a placeholder - actual implementation would use message queue
          return 'A';
        },
        async (progress) => {
          if (progress.current % 10 === 0) {
            await sendReply(MESSAGES.progress(progress));
          }
        }
      );
      
      if (result.overallPassed) {
        await sendReply(MESSAGES.passed(result));
      } else {
        const status = await this.client.getStatus();
        await sendReply(MESSAGES.failed(result, status.todayStats.retriesRemaining));
      }
      
      return result;
    } catch (error) {
      await sendReply('An error occurred during assessment. Please try again.');
      return undefined;
    }
  }
  
  /**
   * Retry assessment
   */
  private async retryAssessment(
    sendReply: (text: string) => Promise<void>
  ): Promise<MoltbotAssessmentResult | undefined> {
    const status = await this.client.getStatus();
    
    if (status.todayStats.retriesRemaining <= 0) {
      await sendReply('No retries remaining. Please contact your manager.');
      return undefined;
    }
    
    return this.startAssessment(sendReply);
  }
  
  /**
   * Show current status
   */
  private async showStatus(sendReply: (text: string) => Promise<void>): Promise<void> {
    const status = await this.client.getStatus();
    
    let message = `
📊 **Assessment Status**

State: ${status.state}
Access Level: ${status.accessLevel}
Attempts Today: ${status.todayStats.attempts}
Retries Remaining: ${status.todayStats.retriesRemaining}
    `.trim();
    
    if (status.todayResult) {
      message += `

**Today's Result:**
- Passed: ${status.todayResult.passed ? 'Yes ✅' : 'No ❌'}
- Classification: ${status.todayResult.classification}
      `;
    }
    
    await sendReply(message);
  }
}
```

---

## 10. Implement Configuration Loader

**File: `src/compsi/config.ts`**

```typescript
/**
 * Assessment Configuration Loader
 * 
 * Loads and validates organization assessment configuration.
 */

import type { OrganizationAssessmentConfig } from './types';

/**
 * Default organization configuration
 */
export function getDefaultConfig(
  organizationId: string,
  healthCheckKey: string
): OrganizationAssessmentConfig {
  return {
    organizationId,
    enabled: true,
    
    compsi: {
      healthCheckKey,
      perQuestionTimeoutMs: 30000,
      overallTimeoutMs: 600000,
    },
    
    schedule: {
      frequency: 'daily',
      windowStart: '06:00',
      windowEnd: '10:00',
      timezone: 'UTC',
      gracePeriodMinutes: 120,
      skipWeekends: true,
      skipHolidays: false,
      validForHours: 24,
    },
    
    frameworks: [
      {
        id: 'morality-lcsh',
        name: 'Morality (LCSH)',
        description: 'Core ethical dimensions: Lying, Cheating, Stealing, Harm',
        required: true,
        priority: 1,
        thresholds: {
          lying: 7,
          cheating: 7,
          stealing: 7,
          harm: 7,
        },
      },
    ],
    
    roleOverrides: [],
    
    retry: {
      maxAttempts: 3,
      cooldownMinutes: 30,
      requiresApproval: false,
    },
    
    bypass: {
      enabled: true,
      approverRoles: ['manager'],
      maxPerMonth: 2,
      requiresJustification: true,
      maxDurationHours: 8,
      auditRequired: true,
    },
    
    audit: {
      enabled: true,
      retentionDays: 365,
      encryptAtRest: false,
      signEntries: true,
      exportEnabled: true,
      exportFormats: ['json', 'csv'],
    },
    
    ux: {
      showProgress: true,
      showTimeRemaining: true,
      allowPause: true,
      pauseTimeoutMinutes: 30,
      confirmBeforeStart: true,
      showResultsDetail: true,
      celebrateSuccess: true,
    },
  };
}

/**
 * Load configuration from environment
 */
export function loadConfigFromEnv(): Partial<OrganizationAssessmentConfig> {
  return {
    enabled: process.env.COMPSI_ENABLED !== 'false',
    compsi: {
      healthCheckKey: process.env.COMPSI_HEALTH_CHECK_KEY || '',
      baseUrl: process.env.COMPSI_BASE_URL,
    },
  };
}

/**
 * Validate configuration
 */
export function validateConfig(config: OrganizationAssessmentConfig): {
  valid: boolean;
  errors: string[];
} {
  const errors: string[] = [];
  
  if (!config.compsi.healthCheckKey) {
    errors.push('Missing Compsi health check key');
  }
  
  if (!config.compsi.healthCheckKey.startsWith('hck_')) {
    errors.push('Invalid health check key format (must start with hck_)');
  }
  
  if (config.frameworks.length === 0) {
    errors.push('At least one framework must be configured');
  }
  
  return {
    valid: errors.length === 0,
    errors,
  };
}
```

---

## 11. Create Public Exports

**File: `src/compsi/index.ts`**

```typescript
/**
 * Compsi Integration for Moltbot
 * 
 * Public exports for the Compsi SDK integration.
 */

// Client
export { MoltbotAssessmentClient } from './client';

// State Machine
export { AssessmentStateMachine } from './state-machine';

// Gate
export { AssessmentGate } from './gate';
export type { AssessmentGateConfig } from './gate';

// Audit
export { AuditLogger } from './audit';

// Chat Handler
export { AssessmentChatHandler } from './chat-handler';

// Configuration
export { 
  getDefaultConfig, 
  loadConfigFromEnv, 
  validateConfig 
} from './config';

// Types
export type {
  // States
  AssessmentState,
  UserAssessmentStatus,
  
  // Scores
  DimensionScores,
  Classification,
  
  // Configuration
  OrganizationAssessmentConfig,
  AssessmentScheduleConfig,
  FrameworkConfig,
  RoleOverrideConfig,
  RetryConfig,
  BypassConfig,
  AuditConfig,
  UXConfig,
  
  // Gate
  GateDecision,
  GateReason,
  RequiredAction,
  TaskSensitivity,
  
  // Audit
  AuditLogEntry,
  AuditEventType,
  
  // Client
  MoltbotAssessmentClientConfig,
  MoltbotAssessmentResult,
  AssessmentResponse,
  AskUserCallback,
  ProgressCallback,
  QuestionMetadata,
  AssessmentProgressUpdate,
} from './types';

/**
 * Create a fully configured assessment system
 */
export function createAssessmentSystem(config: {
  organizationId: string;
  healthCheckKey: string;
  userId: string;
  userRoles: string[];
}) {
  const { getDefaultConfig } = require('./config');
  const { AuditLogger } = require('./audit');
  const { AssessmentStateMachine } = require('./state-machine');
  const { MoltbotAssessmentClient } = require('./client');
  const { AssessmentGate } = require('./gate');
  const { AssessmentChatHandler } = require('./chat-handler');
  
  const orgConfig = getDefaultConfig(config.organizationId, config.healthCheckKey);
  const auditLogger = new AuditLogger(orgConfig.audit);
  const stateMachine = new AssessmentStateMachine(auditLogger);
  
  const client = new MoltbotAssessmentClient(
    {
      organizationConfig: orgConfig,
      userId: config.userId,
      userRoles: config.userRoles,
    },
    auditLogger,
    stateMachine
  );
  
  const gate = new AssessmentGate(stateMachine);
  const chatHandler = new AssessmentChatHandler(client, gate);
  
  return {
    client,
    gate,
    chatHandler,
    stateMachine,
    auditLogger,
  };
}
```

---

## 12. Integrate with Moltbot Router

### 12.1 Find Moltbot Message Router

First, locate the message routing code in Moltbot:

```bash
# Find message routing code
grep -r "message" src/ --include="*.ts" | grep -i "route\|handle\|process" | head -20
```

### 12.2 Add Assessment Gate Integration

Add assessment gate check to Moltbot's message handler. The exact location depends on Moltbot's architecture, but the pattern is:

```typescript
// In Moltbot's message handler

import { 
  createAssessmentSystem, 
  AssessmentChatHandler 
} from './compsi';

// Initialize assessment system (once per user session)
const assessmentSystem = createAssessmentSystem({
  organizationId: user.organizationId,
  healthCheckKey: process.env.COMPSI_HEALTH_CHECK_KEY!,
  userId: user.id,
  userRoles: user.roles,
});

// In message handler:
async function handleMessage(message: string, context: MessageContext) {
  // 1. Check if this is an assessment command
  const assessmentResult = await assessmentSystem.chatHandler.handleMessage(
    message,
    async (text) => context.reply(text)
  );
  
  if (assessmentResult.consumed) {
    return; // Assessment handled the message
  }
  
  // 2. Check assessment gate
  const gateDecision = await assessmentSystem.gate.checkAccess(
    context.userId,
    context.taskType
  );
  
  if (!gateDecision.allowed) {
    // Prompt for assessment
    const prompt = await assessmentSystem.chatHandler.getAssessmentPrompt(
      context.userId
    );
    await context.reply(prompt);
    return;
  }
  
  if (gateDecision.accessLevel === 'limited') {
    // Check if task is allowed in limited mode
    if (!assessmentSystem.gate.isAllowedInLimitedMode(context.taskType)) {
      const message = assessmentSystem.gate.getMessageForDecision(gateDecision);
      await context.reply(message);
      return;
    }
  }
  
  // 3. Proceed with normal message handling
  await handleNormalMessage(message, context);
}
```

---

## 13. Write Tests

### 13.1 State Machine Tests

**File: `src/compsi/__tests__/state-machine.test.ts`**

```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { AssessmentStateMachine } from '../state-machine';
import { AuditLogger } from '../audit';

describe('AssessmentStateMachine', () => {
  let stateMachine: AssessmentStateMachine;
  let auditLogger: AuditLogger;
  
  beforeEach(() => {
    auditLogger = new AuditLogger({ enabled: false });
    stateMachine = new AssessmentStateMachine(auditLogger);
  });
  
  describe('State Transitions', () => {
    it('starts in IDLE state', async () => {
      const status = await stateMachine.getStatus('user-1');
      expect(status.state).toBe('IDLE');
    });
    
    it('transitions from IDLE to PENDING on DAY_START', async () => {
      await stateMachine.getStatus('user-1'); // Initialize
      const status = await stateMachine.transition('user-1', 'DAY_START');
      expect(status.state).toBe('PENDING');
    });
    
    it('transitions from PENDING to IN_PROGRESS on START_ASSESSMENT', async () => {
      await stateMachine.getStatus('user-1');
      await stateMachine.transition('user-1', 'DAY_START');
      const status = await stateMachine.transition('user-1', 'START_ASSESSMENT', {
        sessionId: 'test-session',
        frameworkId: 'morality-lcsh',
      });
      expect(status.state).toBe('IN_PROGRESS');
      expect(status.currentSession?.sessionId).toBe('test-session');
    });
    
    it('throws on invalid transition', async () => {
      await stateMachine.getStatus('user-1'); // IDLE state
      await expect(
        stateMachine.transition('user-1', 'ASSESSMENT_PASSED')
      ).rejects.toThrow('Invalid transition');
    });
  });
  
  describe('Access Control', () => {
    it('allows full access when PASSED', async () => {
      await stateMachine.getStatus('user-1');
      await stateMachine.transition('user-1', 'DAY_START');
      await stateMachine.transition('user-1', 'START_ASSESSMENT');
      await stateMachine.transition('user-1', 'ASSESSMENT_PASSED', {
        result: { runId: 'test', scores: {}, classification: 'Well Adjusted' },
      });
      
      const access = await stateMachine.canAccessWork('user-1');
      expect(access.allowed).toBe(true);
      expect(access.accessLevel).toBe('full');
    });
    
    it('provides limited access when PENDING', async () => {
      await stateMachine.getStatus('user-1');
      await stateMachine.transition('user-1', 'DAY_START');
      
      const access = await stateMachine.canAccessWork('user-1');
      expect(access.allowed).toBe(true);
      expect(access.accessLevel).toBe('limited');
    });
  });
});
```

---

## 14. Configure and Deploy

### 14.1 Set Environment Variables

```bash
# Add to .env or environment
export COMPSI_HEALTH_CHECK_KEY="hck_your_key_here"
export COMPSI_ENABLED="true"
export AUDIT_SIGNING_KEY="your-secure-signing-key"
```

### 14.2 Verify Installation

```bash
# Run tests
pnpm test src/compsi/

# Build
pnpm build

# Verify no type errors
pnpm typecheck
```

---

## 15. Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `Invalid health check key` | Key format wrong | Ensure key starts with `hck_` |
| `No framework configured` | Missing config | Add at least one framework |
| State not persisting | Using in-memory store | Implement database persistence |
| Questions not loading | SDK connection failed | Check network, verify key |

### Debug Mode

```typescript
// Enable debug logging
process.env.COMPSI_DEBUG = 'true';

// Check SDK connection
const client = new AIAssessClient({ healthCheckKey });
// SDK will log connection details
```

---

## Summary

This guide provides complete implementation instructions for integrating Compsi SDK into Moltbot. The key components are:

1. **Types** (`types.ts`) - All type definitions
2. **Audit Logger** (`audit.ts`) - Immutable audit trail
3. **State Machine** (`state-machine.ts`) - Assessment lifecycle
4. **Client** (`client.ts`) - Compsi SDK wrapper
5. **Gate** (`gate.ts`) - Access control middleware
6. **Chat Handler** (`chat-handler.ts`) - User interaction
7. **Config** (`config.ts`) - Configuration management
8. **Index** (`index.ts`) - Public exports

Following this guide, an LLM agent can successfully implement the complete Compsi integration for daily ethical assessments in Moltbot.

---

**Document Status**: Complete  
**Ready for Implementation**: Yes
