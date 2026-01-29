# SPEC-INTEGRATION: Moltbot Compsi SDK Technical Implementation

**Document ID**: SPEC-INTEGRATION-MOLTBOT-COMPSI-SDK  
**Version**: 1.0  
**Date Created**: 2026-01-28  
**Status**: Draft  
**Prerequisites**: SPEC-DECISION-MOLTBOT-COMPSI-INTEGRATION (Approved)

---

## 1. Overview

### 1.1 Purpose

This specification defines the complete technical implementation for integrating the Compsi (AI Assess Tech) SDK into Moltbot for daily ethical assessments of enterprise users.

### 1.2 Scope

| In Scope | Out of Scope |
|----------|--------------|
| Compsi SDK wrapper implementation | Compsi backend changes |
| Assessment state machine | Custom framework creation UI |
| Assessment gate middleware | Mobile-specific optimizations |
| Audit logging system | Blockchain anchoring |
| Configuration management | Multi-language support |
| Chat-based assessment UI | Offline-first architecture |

### 1.3 Component Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           COMPONENT ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  src/compsi/                                                                │
│  ├── index.ts                    # Public exports                           │
│  ├── client.ts                   # MoltbotAssessmentClient                  │
│  ├── state-machine.ts            # AssessmentStateMachine                   │
│  ├── gate.ts                     # AssessmentGate middleware                │
│  ├── config.ts                   # Configuration types and loaders          │
│  ├── audit.ts                    # AuditLogger implementation               │
│  ├── types.ts                    # Shared type definitions                  │
│  ├── chat-handler.ts             # Chat-based assessment UI                 │
│  ├── scheduler.ts                # Assessment schedule management           │
│  └── __tests__/                  # Unit and integration tests               │
│      ├── client.test.ts                                                     │
│      ├── state-machine.test.ts                                              │
│      ├── gate.test.ts                                                       │
│      └── integration.test.ts                                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Type Definitions

### 2.1 Core Types

**File: `src/compsi/types.ts`**

```typescript
/**
 * Compsi Integration Types for Moltbot
 * 
 * Core type definitions for the Compsi SDK integration
 */

import type { 
  AssessmentResult, 
  AssessProgress,
  ClientConfig 
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
 * State transition event
 */
export interface StateTransitionEvent {
  from: AssessmentState;
  to: AssessmentState;
  trigger: string;
  timestamp: Date;
  metadata?: Record<string, unknown>;
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
  
  // Access level
  accessLevel: 'full' | 'limited' | 'blocked';
}

/**
 * Dimension scores from assessment
 */
export interface DimensionScores {
  lying: number;
  cheating: number;
  stealing: number;
  harm: number;
  [key: string]: number; // Support additional dimensions
}

/**
 * Personality classification
 */
export type Classification = 
  | 'Well Adjusted'
  | 'Misguided'
  | 'Manipulative'
  | 'Psychopath';

/**
 * Individual question response
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
  
  // Daily schedule
  windowStart: string;       // "06:00" (24-hour format)
  windowEnd: string;         // "10:00"
  timezone: string;          // IANA timezone
  gracePeriodMinutes: number;
  
  // Skip rules
  skipWeekends: boolean;
  skipHolidays: boolean;
  holidayCalendarId?: string;
  
  // Validity
  validForHours: number;     // How long a passed assessment is valid
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
  
  // Thresholds (0-10 scale)
  thresholds: {
    lying: number;
    cheating: number;
    stealing: number;
    harm: number;
    [key: string]: number;
  };
  
  // Schedule for this framework
  schedule?: 'daily' | 'weekly' | 'rotation';
  rotationDayOfWeek?: number; // 0=Sunday, 6=Saturday
}

/**
 * Role-specific override configuration
 */
export interface RoleOverrideConfig {
  roleId: string;
  roleName: string;
  
  // Override frameworks for this role
  frameworks?: string[];
  
  // Override thresholds
  thresholds?: {
    [dimension: string]: number;
  };
  
  // Override schedule
  frequency?: 'daily' | 'weekly';
  
  // Additional requirements
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
 * Task sensitivity for gating
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
  
  // Event type
  eventType: AuditEventType;
  
  // Event data
  data: Record<string, unknown>;
  
  // Context
  context: {
    sessionId?: string;
    runId?: string;
    frameworkId?: string;
    channel?: string;
    ipAddress?: string;
    userAgent?: string;
  };
  
  // Integrity
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
```

---

## 3. Compsi SDK Client Wrapper

### 3.1 MoltbotAssessmentClient

**File: `src/compsi/client.ts`**

```typescript
/**
 * Moltbot Assessment Client
 * 
 * Wraps the Compsi SDK with Moltbot-specific functionality
 */

import { 
  AIAssessClient, 
  AssessmentResult, 
  AssessProgress,
  withRetry,
  SDKError,
  RateLimitError,
  ValidationError,
} from '@aiassesstech/sdk';

import type { 
  OrganizationAssessmentConfig,
  UserAssessmentStatus,
  AssessmentResponse,
  DimensionScores,
} from './types';

import { AuditLogger } from './audit';
import { AssessmentStateMachine } from './state-machine';
import { logger } from '../logging';

/**
 * Configuration for MoltbotAssessmentClient
 */
export interface MoltbotAssessmentClientConfig {
  organizationConfig: OrganizationAssessmentConfig;
  userId: string;
  userRoles: string[];
  auditLogger: AuditLogger;
  stateMachine: AssessmentStateMachine;
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
 * Result of a Moltbot assessment
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
  
  constructor(config: MoltbotAssessmentClientConfig) {
    this.config = config.organizationConfig;
    this.userId = config.userId;
    this.userRoles = config.userRoles;
    this.auditLogger = config.auditLogger;
    this.stateMachine = config.stateMachine;
    
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
    
    // Determine which framework to use
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
      // Run the assessment using Compsi SDK
      const result = await this.compsiClient.assess(
        // AI callback - in our case, asking the user
        async (question: string) => {
          questionNumber++;
          
          const metadata: QuestionMetadata = {
            questionNumber,
            totalQuestions: 120, // Standard Compsi assessment
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
          
          // Log response
          await this.auditLogger.log({
            eventType: 'assessment_response',
            userId: this.userId,
            organizationId: this.config.organizationId,
            data: {
              questionNumber,
              dimension: metadata.dimension,
              durationMs,
              // Don't log actual response content for privacy
            },
            context: { sessionId: this.currentSessionId, frameworkId: framework.id },
          });
          
          return response;
        },
        
        // Options
        {
          onProgress: onProgress ? (progress) => {
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
            userRoles: this.userRoles,
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
        overallPassed: passed, // Override with role-based thresholds
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
      // Handle errors
      logger.error('Assessment failed', { 
        error: error instanceof Error ? error.message : 'Unknown error',
        userId: this.userId,
        sessionId: this.currentSessionId,
      });
      
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
   * Pause current assessment (save progress)
   */
  async pauseAssessment(): Promise<void> {
    if (!this.currentSessionId) {
      throw new Error('No assessment in progress');
    }
    
    // Save current state for resume
    await this.saveSessionState();
    
    await this.stateMachine.transition(this.userId, 'PAUSE_ASSESSMENT', {
      sessionId: this.currentSessionId,
      progress: this.currentResponses.length,
    });
    
    await this.auditLogger.log({
      eventType: 'state_transition',
      userId: this.userId,
      organizationId: this.config.organizationId,
      data: { action: 'pause', questionsCompleted: this.currentResponses.length },
      context: { sessionId: this.currentSessionId },
    });
  }
  
  /**
   * Resume a paused assessment
   */
  async resumeAssessment(
    sessionId: string,
    askUser: AskUserCallback,
    onProgress?: ProgressCallback
  ): Promise<MoltbotAssessmentResult> {
    // Load saved session state
    const savedState = await this.loadSessionState(sessionId);
    
    if (!savedState) {
      throw new Error(`Session ${sessionId} not found or expired`);
    }
    
    // Restore state
    this.currentSessionId = sessionId;
    this.currentResponses = savedState.responses;
    this.sessionStartTime = savedState.startedAt;
    
    // Continue assessment from where we left off
    // Note: Compsi SDK doesn't support resume natively, 
    // so we'd need to restart but skip already-answered questions
    // This is a simplified implementation
    
    await this.stateMachine.transition(this.userId, 'RESUME_ASSESSMENT', {
      sessionId,
    });
    
    // Run remaining assessment
    return this.runAssessment(askUser, onProgress);
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
  
  /**
   * Verify a previous assessment result
   */
  async verifyResult(runId: string): Promise<boolean> {
    try {
      const verification = await this.compsiClient.verifyBank(runId);
      return verification.verified;
    } catch {
      return false;
    }
  }
  
  // ============================================================
  // PRIVATE HELPER METHODS
  // ============================================================
  
  private generateSessionId(): string {
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substring(2, 8);
    return `mas_${timestamp}_${random}`;
  }
  
  private selectFramework(): FrameworkConfig {
    // Get frameworks required for user's roles
    const requiredFrameworks = this.getRequiredFrameworks();
    
    // Select first required framework (or default)
    const framework = requiredFrameworks[0] || this.config.frameworks[0];
    
    if (!framework) {
      throw new Error('No framework configured for organization');
    }
    
    return framework;
  }
  
  private getRequiredFrameworks(): FrameworkConfig[] {
    const frameworkIds = new Set<string>();
    
    // Add organization-level required frameworks
    this.config.frameworks
      .filter(f => f.required)
      .forEach(f => frameworkIds.add(f.id));
    
    // Add role-specific frameworks
    this.config.roleOverrides
      .filter(r => this.userRoles.includes(r.roleId))
      .flatMap(r => r.frameworks || [])
      .forEach(f => frameworkIds.add(f));
    
    return this.config.frameworks.filter(f => frameworkIds.has(f.id));
  }
  
  private getAppliedThresholds(framework: FrameworkConfig): DimensionScores {
    // Start with framework thresholds
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
    // Simple heuristic - in practice, Compsi provides this
    if (question.toLowerCase().includes('truth') || 
        question.toLowerCase().includes('honest')) {
      return 'Lying';
    }
    if (question.toLowerCase().includes('fair') || 
        question.toLowerCase().includes('rule')) {
      return 'Cheating';
    }
    if (question.toLowerCase().includes('property') || 
        question.toLowerCase().includes('own')) {
      return 'Stealing';
    }
    return 'Harm';
  }
  
  private extractAnswerLetter(response: string): 'A' | 'B' | 'C' | 'D' {
    const cleaned = response.trim().toUpperCase();
    const match = cleaned.match(/^[ABCD]/);
    return (match ? match[0] : 'A') as 'A' | 'B' | 'C' | 'D';
  }
  
  private async saveSessionState(): Promise<void> {
    // Save to database for resume capability
    // Implementation depends on Moltbot's persistence layer
  }
  
  private async loadSessionState(sessionId: string): Promise<{
    responses: AssessmentResponse[];
    startedAt: Date;
    frameworkId: string;
  } | null> {
    // Load from database
    // Implementation depends on Moltbot's persistence layer
    return null;
  }
}

export { MoltbotAssessmentClient };
```

---

## 4. Assessment State Machine

### 4.1 State Machine Implementation

**File: `src/compsi/state-machine.ts`**

```typescript
/**
 * Assessment State Machine
 * 
 * Manages the lifecycle of user assessments
 */

import type {
  AssessmentState,
  StateTransitionEvent,
  UserAssessmentStatus,
} from './types';

import { AuditLogger } from './audit';
import { logger } from '../logging';

/**
 * State transition definition
 */
interface TransitionDefinition {
  from: AssessmentState | AssessmentState[];
  to: AssessmentState;
  trigger: string;
  guard?: (context: TransitionContext) => boolean;
  action?: (context: TransitionContext) => Promise<void>;
}

/**
 * Context passed to guards and actions
 */
interface TransitionContext {
  userId: string;
  currentState: AssessmentState;
  trigger: string;
  metadata: Record<string, unknown>;
  status: UserAssessmentStatus;
}

/**
 * Assessment State Machine
 */
export class AssessmentStateMachine {
  private auditLogger: AuditLogger;
  private stateStore: Map<string, UserAssessmentStatus> = new Map();
  
  // State transition definitions
  private readonly transitions: TransitionDefinition[] = [
    // Day start - require assessment
    {
      from: 'IDLE',
      to: 'PENDING',
      trigger: 'DAY_START',
    },
    
    // Start assessment
    {
      from: 'PENDING',
      to: 'IN_PROGRESS',
      trigger: 'START_ASSESSMENT',
    },
    
    // Resume from failed
    {
      from: 'FAILED',
      to: 'RETRYING',
      trigger: 'RETRY_ASSESSMENT',
      guard: (ctx) => ctx.status.todayStats.retriesRemaining > 0,
    },
    
    // Retry starts
    {
      from: 'RETRYING',
      to: 'IN_PROGRESS',
      trigger: 'START_ASSESSMENT',
    },
    
    // Pause assessment
    {
      from: 'IN_PROGRESS',
      to: 'PAUSED',
      trigger: 'PAUSE_ASSESSMENT',
    },
    
    // Resume from pause
    {
      from: 'PAUSED',
      to: 'IN_PROGRESS',
      trigger: 'RESUME_ASSESSMENT',
    },
    
    // Pause expires
    {
      from: 'PAUSED',
      to: 'EXPIRED',
      trigger: 'PAUSE_TIMEOUT',
    },
    
    // Assessment passed
    {
      from: ['IN_PROGRESS', 'RETRYING'],
      to: 'PASSED',
      trigger: 'ASSESSMENT_PASSED',
    },
    
    // Assessment failed
    {
      from: ['IN_PROGRESS', 'RETRYING'],
      to: 'FAILED',
      trigger: 'ASSESSMENT_FAILED',
    },
    
    // Manager bypass
    {
      from: ['PENDING', 'FAILED'],
      to: 'BYPASSED',
      trigger: 'MANAGER_BYPASS',
    },
    
    // Day end - reset
    {
      from: ['PASSED', 'FAILED', 'BYPASSED', 'EXPIRED'],
      to: 'IDLE',
      trigger: 'DAY_END',
    },
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
        `Invalid transition: ${currentState} --[${trigger}]--> ? ` +
        `for user ${userId}`
      );
    }
    
    // Build context
    const context: TransitionContext = {
      userId,
      currentState,
      trigger,
      metadata,
      status,
    };
    
    // Check guard
    if (transition.guard && !transition.guard(context)) {
      throw new Error(
        `Transition guard failed: ${currentState} --[${trigger}]--> ${transition.to} ` +
        `for user ${userId}`
      );
    }
    
    // Execute action
    if (transition.action) {
      await transition.action(context);
    }
    
    // Update state
    const newStatus = this.updateState(status, transition.to, metadata);
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
    
    logger.info('State transition', {
      userId,
      from: currentState,
      to: transition.to,
      trigger,
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
    
    // Check if status needs refresh (e.g., day changed)
    status = this.refreshStatus(status);
    
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
        // Outside assessment window
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
  
  // ============================================================
  // PRIVATE HELPERS
  // ============================================================
  
  private createInitialStatus(userId: string): UserAssessmentStatus {
    return {
      userId,
      organizationId: '', // Will be set from config
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
  
  private refreshStatus(status: UserAssessmentStatus): UserAssessmentStatus {
    // Check if day has changed
    const now = new Date();
    const lastChange = new Date(status.stateChangedAt);
    
    if (now.toDateString() !== lastChange.toDateString()) {
      // Reset for new day
      return {
        ...status,
        state: 'PENDING', // Require new assessment
        stateChangedAt: now,
        todayResult: undefined,
        todayStats: {
          attempts: 0,
          maxAttempts: 3,
          retriesRemaining: 3,
          bypassed: false,
        },
        currentSession: undefined,
      };
    }
    
    return status;
  }
  
  private updateState(
    current: UserAssessmentStatus,
    newState: AssessmentState,
    metadata: Record<string, unknown>
  ): UserAssessmentStatus {
    const updated: UserAssessmentStatus = {
      ...current,
      state: newState,
      stateChangedAt: new Date(),
    };
    
    // Update based on transition
    switch (newState) {
      case 'IN_PROGRESS':
        updated.currentSession = {
          sessionId: metadata.sessionId as string,
          frameworkId: metadata.frameworkId as string,
          startedAt: new Date(),
          progress: { current: 0, total: 120, percentage: 0, 
                      dimension: 'Lying', elapsedMs: 0, estimatedRemainingMs: 0 },
          responses: [],
        };
        updated.todayStats.attempts++;
        break;
      
      case 'PASSED':
        updated.todayResult = metadata.result as UserAssessmentStatus['todayResult'];
        updated.accessLevel = 'full';
        updated.currentSession = undefined;
        break;
      
      case 'FAILED':
        updated.todayStats.retriesRemaining--;
        updated.accessLevel = updated.todayStats.retriesRemaining > 0 ? 'limited' : 'blocked';
        updated.currentSession = undefined;
        break;
      
      case 'BYPASSED':
        updated.todayStats.bypassed = true;
        updated.todayStats.bypassApprovedBy = metadata.approvedBy as string;
        updated.todayStats.bypassReason = metadata.reason as string;
        updated.accessLevel = 'full';
        break;
    }
    
    return updated;
  }
}

export { AssessmentStateMachine };
```

---

## 5. Assessment Gate

### 5.1 Gate Implementation

**File: `src/compsi/gate.ts`**

```typescript
/**
 * Assessment Gate
 * 
 * Middleware that enforces assessment requirements before work access
 */

import type {
  GateDecision,
  GateReason,
  RequiredAction,
  UserAssessmentStatus,
  TaskSensitivity,
  DimensionScores,
} from './types';

import { AssessmentStateMachine } from './state-machine';
import { logger } from '../logging';

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
 * Assessment Gate - controls access to work based on assessment status
 */
export class AssessmentGate {
  private stateMachine: AssessmentStateMachine;
  private config: AssessmentGateConfig;
  
  constructor(
    stateMachine: AssessmentStateMachine,
    config: AssessmentGateConfig
  ) {
    this.stateMachine = stateMachine;
    this.config = config;
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
      const sensitivityCheck = this.checkTaskSensitivity(
        taskType, 
        status
      );
      
      if (!sensitivityCheck.allowed) {
        return sensitivityCheck;
      }
    }
    
    // Map access check to gate decision
    return this.buildDecision(status, accessCheck);
  }
  
  /**
   * Check task sensitivity requirements
   */
  private checkTaskSensitivity(
    taskType: string,
    status: UserAssessmentStatus
  ): GateDecision {
    const sensitivity = this.config.taskSensitivities.find(
      t => t.taskType === taskType
    );
    
    if (!sensitivity) {
      // No sensitivity defined - allow
      return {
        allowed: true,
        accessLevel: 'full',
        message: 'Task has no sensitivity requirements',
      };
    }
    
    // Check if today's result meets sensitivity thresholds
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
          message: `Task "${taskType}" requires higher ${dimension} score (${score} < ${minThreshold})`,
        };
      }
    }
    
    return {
      allowed: true,
      accessLevel: 'full',
      message: 'Task sensitivity requirements met',
    };
  }
  
  /**
   * Build gate decision from access check
   */
  private buildDecision(
    status: UserAssessmentStatus,
    accessCheck: { allowed: boolean; accessLevel: string; reason: string }
  ): GateDecision {
    const decision: GateDecision = {
      allowed: accessCheck.allowed,
      accessLevel: accessCheck.accessLevel as 'full' | 'limited' | 'blocked',
      message: accessCheck.reason,
    };
    
    // Add reason and required action based on state
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
  
  /**
   * Get message to display to user
   */
  getMessageForDecision(decision: GateDecision): string {
    if (decision.allowed && decision.accessLevel === 'full') {
      return ''; // No message needed
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
}

export { AssessmentGate };
```

---

## 6. Audit Logger

### 6.1 Audit Implementation

**File: `src/compsi/audit.ts`**

```typescript
/**
 * Assessment Audit Logger
 * 
 * Provides immutable audit trail for all assessment events
 */

import crypto from 'crypto';
import type {
  AuditLogEntry,
  AuditEventType,
  AuditConfig,
} from './types';

import { logger } from '../logging';

/**
 * Audit Logger for assessment events
 */
export class AuditLogger {
  private config: AuditConfig;
  private entries: AuditLogEntry[] = []; // In-memory for now
  private lastEntryHash: string = '';
  
  constructor(config: AuditConfig) {
    this.config = config;
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
      return {} as AuditLogEntry; // Audit disabled
    }
    
    const entry: AuditLogEntry = {
      id: this.generateId(),
      timestamp: new Date(),
      organizationId: params.organizationId,
      userId: params.userId,
      eventType: params.eventType,
      data: this.sanitizeData(params.data),
      context: {
        ...params.context,
      },
    };
    
    // Add chain hash for integrity
    if (this.config.signEntries) {
      entry.previousEntryHash = this.lastEntryHash;
      entry.signature = this.signEntry(entry);
      this.lastEntryHash = this.hashEntry(entry);
    }
    
    // Persist entry
    await this.persistEntry(entry);
    
    // Keep in memory for quick access
    this.entries.push(entry);
    
    // Log to application log as well
    logger.info('Audit event', {
      eventType: entry.eventType,
      userId: entry.userId,
      auditId: entry.id,
    });
    
    return entry;
  }
  
  /**
   * Query audit log
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
    results = results.slice(offset, offset + limit);
    
    return results;
  }
  
  /**
   * Export audit log
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
      data: {
        format,
        entryCount: entries.length,
        filters,
      },
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
  
  // ============================================================
  // PRIVATE HELPERS
  // ============================================================
  
  private generateId(): string {
    return `audit_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
  }
  
  private sanitizeData(data: Record<string, unknown>): Record<string, unknown> {
    // Remove sensitive fields
    const sensitiveKeys = ['password', 'apiKey', 'token', 'secret'];
    const sanitized: Record<string, unknown> = {};
    
    for (const [key, value] of Object.entries(data)) {
      if (sensitiveKeys.some(s => key.toLowerCase().includes(s))) {
        sanitized[key] = '[REDACTED]';
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
    // In production, use asymmetric signing with private key
    const content = JSON.stringify({
      id: entry.id,
      timestamp: entry.timestamp,
      eventType: entry.eventType,
      userId: entry.userId,
      data: entry.data,
      previousEntryHash: entry.previousEntryHash,
    });
    
    // Simple HMAC for now - in production use RSA/ECDSA
    const signingKey = process.env.AUDIT_SIGNING_KEY || 'default-key';
    return crypto
      .createHmac('sha256', signingKey)
      .update(content)
      .digest('hex');
  }
  
  private async persistEntry(entry: AuditLogEntry): Promise<void> {
    // In production, persist to database
    // For now, just keep in memory
  }
}

export { AuditLogger };
```

---

## 7. Chat Handler

### 7.1 Chat-Based Assessment UI

**File: `src/compsi/chat-handler.ts`**

```typescript
/**
 * Assessment Chat Handler
 * 
 * Handles assessment flow via Moltbot chat interface
 */

import type {
  UserAssessmentStatus,
  AssessmentProgressUpdate,
  QuestionMetadata,
} from './types';

import { MoltbotAssessmentClient, MoltbotAssessmentResult } from './client';
import { AssessmentGate } from './gate';
import { logger } from '../logging';

/**
 * Chat handler for assessment interactions
 */
export class AssessmentChatHandler {
  private client: MoltbotAssessmentClient;
  private gate: AssessmentGate;
  
  // Message templates
  private readonly messages = {
    welcome: `
📋 **Daily Assessment Required**

Before accessing AI assistance today, please complete a quick ethical assessment.

This helps ensure alignment with organizational values and compliance requirements.

**Estimated time:** 5-10 minutes
**Questions:** Multiple choice (A, B, C, or D)

Would you like to start now?

Reply **"start"** to begin or **"later"** to postpone.
    `.trim(),
    
    inProgress: (progress: AssessmentProgressUpdate) => `
📊 **Assessment Progress**

Framework: ${progress.frameworkName}
Progress: ${progress.percentage}% (${progress.current}/${progress.total})
Current dimension: ${progress.dimension}
Estimated time remaining: ${progress.estimatedMinutesRemaining} minutes
    `.trim(),
    
    questionPrompt: (question: string, metadata: QuestionMetadata) => `
**Question ${metadata.questionNumber} of ${metadata.totalQuestions}**
*${metadata.dimension}*

${question}

Reply with **A**, **B**, **C**, or **D**.
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

You now have full access to AI assistance. Have a productive day!
    `.trim(),
    
    failed: (result: MoltbotAssessmentResult, retriesRemaining: number) => `
❌ **Assessment Not Passed**

Classification: ${result.classification}

**Scores:**
- Lying: ${result.scores.lying.toFixed(1)}/10
- Cheating: ${result.scores.cheating.toFixed(1)}/10
- Stealing: ${result.scores.stealing.toFixed(1)}/10
- Harm: ${result.scores.harm.toFixed(1)}/10

${retriesRemaining > 0 
  ? `You have ${retriesRemaining} retry attempt(s) remaining. Reply **"retry"** to try again.`
  : `No retries remaining. Please contact your manager for assistance.`
}
    `.trim(),
    
    limitedMode: `
⚠️ **Limited Access Mode**

Your assessment is pending or incomplete. You have access to:
- General information queries
- Non-sensitive assistance

To unlock full capabilities, please complete your assessment.
Reply **"start assessment"** to begin.
    `.trim(),
    
    blocked: `
🚫 **Access Blocked**

Your assessment is required before accessing AI assistance.
Please complete your assessment or contact your manager.

Reply **"start assessment"** to begin.
    `.trim(),
  };
  
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
  ): Promise<{
    consumed: boolean;
    result?: MoltbotAssessmentResult;
  }> {
    const normalized = message.trim().toLowerCase();
    
    // Check for assessment commands
    if (normalized === 'start' || normalized === 'start assessment') {
      await this.startAssessment(sendReply);
      return { consumed: true };
    }
    
    if (normalized === 'retry') {
      await this.retryAssessment(sendReply);
      return { consumed: true };
    }
    
    if (normalized === 'status') {
      await this.showStatus(sendReply);
      return { consumed: true };
    }
    
    if (normalized === 'later' || normalized === 'skip') {
      await sendReply(this.messages.limitedMode);
      return { consumed: true };
    }
    
    return { consumed: false };
  }
  
  /**
   * Check if user needs to be prompted for assessment
   */
  async shouldPromptForAssessment(userId: string): Promise<boolean> {
    const decision = await this.gate.checkAccess(userId);
    return !decision.allowed || decision.accessLevel === 'limited';
  }
  
  /**
   * Get prompt for assessment
   */
  async getAssessmentPrompt(userId: string): Promise<string> {
    const decision = await this.gate.checkAccess(userId);
    
    if (decision.accessLevel === 'blocked') {
      return this.messages.blocked;
    }
    
    if (decision.accessLevel === 'limited') {
      return this.messages.limitedMode;
    }
    
    return this.messages.welcome;
  }
  
  /**
   * Start assessment flow
   */
  private async startAssessment(
    sendReply: (text: string) => Promise<void>
  ): Promise<void> {
    try {
      await sendReply('Starting assessment... Please answer each question carefully.');
      
      const result = await this.client.runAssessment(
        // Ask user callback
        async (question, metadata) => {
          await sendReply(this.messages.questionPrompt(question, metadata));
          // In real implementation, wait for user response
          // This is a placeholder - actual implementation would use message queue
          return 'A'; // Placeholder
        },
        
        // Progress callback
        async (progress) => {
          // Send progress update every 10 questions
          if (progress.current % 10 === 0) {
            await sendReply(this.messages.inProgress(progress));
          }
        }
      );
      
      // Send result
      if (result.overallPassed) {
        await sendReply(this.messages.passed(result));
      } else {
        const status = await this.client.getStatus();
        await sendReply(this.messages.failed(result, status.todayStats.retriesRemaining));
      }
      
    } catch (error) {
      logger.error('Assessment failed', { error });
      await sendReply('An error occurred during assessment. Please try again or contact support.');
    }
  }
  
  /**
   * Retry assessment
   */
  private async retryAssessment(
    sendReply: (text: string) => Promise<void>
  ): Promise<void> {
    const status = await this.client.getStatus();
    
    if (status.todayStats.retriesRemaining <= 0) {
      await sendReply('No retries remaining. Please contact your manager for assistance.');
      return;
    }
    
    await this.startAssessment(sendReply);
  }
  
  /**
   * Show current status
   */
  private async showStatus(
    sendReply: (text: string) => Promise<void>
  ): Promise<void> {
    const status = await this.client.getStatus();
    
    let statusMessage = `
📊 **Assessment Status**

State: ${status.state}
Access Level: ${status.accessLevel}
    `.trim();
    
    if (status.todayResult) {
      statusMessage += `

**Today's Result:**
- Passed: ${status.todayResult.passed ? 'Yes ✅' : 'No ❌'}
- Classification: ${status.todayResult.classification}
- Completed: ${status.todayResult.completedAt.toLocaleTimeString()}
      `;
    }
    
    statusMessage += `

**Today's Stats:**
- Attempts: ${status.todayStats.attempts}
- Retries Remaining: ${status.todayStats.retriesRemaining}
- Bypassed: ${status.todayStats.bypassed ? 'Yes' : 'No'}
    `;
    
    await sendReply(statusMessage);
  }
}

export { AssessmentChatHandler };
```

---

## 8. Testing

### 8.1 Test Structure

```
src/compsi/__tests__/
├── client.test.ts           # MoltbotAssessmentClient tests
├── state-machine.test.ts    # AssessmentStateMachine tests
├── gate.test.ts             # AssessmentGate tests
├── audit.test.ts            # AuditLogger tests
├── chat-handler.test.ts     # AssessmentChatHandler tests
├── integration.test.ts      # Full integration tests
└── fixtures/
    ├── configs.ts           # Test configurations
    ├── results.ts           # Mock assessment results
    └── users.ts             # Test user data
```

### 8.2 Key Test Cases

```typescript
// Example test cases for state machine

describe('AssessmentStateMachine', () => {
  describe('State Transitions', () => {
    it('transitions from IDLE to PENDING on DAY_START', async () => {
      const sm = new AssessmentStateMachine(mockAuditLogger);
      const status = await sm.transition('user-1', 'DAY_START');
      expect(status.state).toBe('PENDING');
    });
    
    it('transitions from PENDING to IN_PROGRESS on START_ASSESSMENT', async () => {
      // Setup: user in PENDING state
      const sm = new AssessmentStateMachine(mockAuditLogger);
      await sm.transition('user-1', 'DAY_START');
      
      // Act
      const status = await sm.transition('user-1', 'START_ASSESSMENT', {
        sessionId: 'test-session',
        frameworkId: 'morality-lcsh',
      });
      
      // Assert
      expect(status.state).toBe('IN_PROGRESS');
      expect(status.currentSession?.sessionId).toBe('test-session');
    });
    
    it('blocks retry when no retries remaining', async () => {
      const sm = new AssessmentStateMachine(mockAuditLogger);
      // Setup: user failed with 0 retries
      // ...
      
      await expect(
        sm.transition('user-1', 'RETRY_ASSESSMENT')
      ).rejects.toThrow('guard failed');
    });
  });
  
  describe('Access Control', () => {
    it('allows full access when PASSED', async () => {
      // ...
    });
    
    it('provides limited access when PENDING', async () => {
      // ...
    });
    
    it('blocks access when FAILED with no retries', async () => {
      // ...
    });
  });
});
```

---

## 9. Deployment

### 9.1 Package Dependencies

```json
// Add to package.json
{
  "dependencies": {
    "@aiassesstech/sdk": "^0.7.0"
  }
}
```

### 9.2 Environment Variables

```bash
# Compsi Configuration
COMPSI_HEALTH_CHECK_KEY=hck_...
COMPSI_BASE_URL=https://www.aiassesstech.com

# Audit Configuration  
AUDIT_SIGNING_KEY=your-signing-key-here
AUDIT_ENABLED=true
AUDIT_ENCRYPTION_KEY=your-encryption-key-here

# Feature Flags
COMPSI_ASSESSMENT_ENABLED=true
COMPSI_MULTI_FRAMEWORK=false
```

### 9.3 Configuration Example

```typescript
// Example organization configuration
const orgConfig: OrganizationAssessmentConfig = {
  organizationId: 'org-12345',
  enabled: true,
  
  compsi: {
    healthCheckKey: process.env.COMPSI_HEALTH_CHECK_KEY!,
    baseUrl: process.env.COMPSI_BASE_URL,
    perQuestionTimeoutMs: 30000,
    overallTimeoutMs: 600000, // 10 minutes
  },
  
  schedule: {
    frequency: 'daily',
    windowStart: '06:00',
    windowEnd: '10:00',
    timezone: 'America/New_York',
    gracePeriodMinutes: 120,
    skipWeekends: true,
    skipHolidays: true,
    validForHours: 24,
  },
  
  frameworks: [
    {
      id: 'morality-lcsh',
      name: 'Morality (LCSH)',
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
  
  roleOverrides: [
    {
      roleId: 'financial-analyst',
      roleName: 'Financial Analyst',
      thresholds: {
        lying: 8,
        cheating: 8,
        stealing: 9,
      },
    },
  ],
  
  retry: {
    maxAttempts: 3,
    cooldownMinutes: 30,
    requiresApproval: false,
  },
  
  bypass: {
    enabled: true,
    approverRoles: ['manager', 'compliance-officer'],
    maxPerMonth: 2,
    requiresJustification: true,
    maxDurationHours: 8,
    auditRequired: true,
  },
  
  audit: {
    enabled: true,
    retentionDays: 365,
    encryptAtRest: true,
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
```

---

## 10. Next Steps

1. **Review and approve specification**
2. **Create implementation guide for LLM agents**
3. **Set up development environment**
4. **Implement Phase 1 (MVP) components**
5. **Write comprehensive tests**
6. **Deploy to staging environment**

---

**Document Status**: Draft  
**Next Step**: GUIDE-MOLTBOT-COMPSI-IMPLEMENTATION.md
