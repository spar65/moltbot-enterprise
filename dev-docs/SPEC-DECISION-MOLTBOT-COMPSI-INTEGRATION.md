# SPEC-DECISION: Moltbot Integration with Compsi SDK for Daily Ethical Assessments

**Document ID**: SPEC-DECISION-MOLTBOT-COMPSI-INTEGRATION  
**Version**: 1.0  
**Date Created**: 2026-01-28  
**Status**: Approved  
**Decision**: Direct SDK Integration with Assessment State Machine

---

## Executive Summary

This document records the architectural decision to integrate Moltbot with the Compsi (AI Assess Tech) SDK for daily ethical assessments of enterprise users. The integration enables organizations to verify user alignment with organizational values before granting access to AI-assisted work capabilities.

---

## Decision Context

### Problem Statement

Enterprise organizations deploying Moltbot as an AI work assistant need to:

1. **Verify user ethics alignment** before allowing AI-assisted work
2. **Support multiple assessment frameworks** (Morality, Virtue, Ethics, Operational Excellence)
3. **Enforce role-based requirements** with different thresholds per role
4. **Maintain comprehensive audit trails** for compliance
5. **Gate AI capabilities** based on assessment status
6. **Support daily recurring assessments** at scale

### Options Evaluated

| Option | Description | Recommendation |
|--------|-------------|----------------|
| **Option 1: Direct SDK Integration** | Integrate @aiassesstech/sdk directly into Moltbot core | ⭐ **Selected** |
| **Option 2: Compsi API Gateway** | Run Compsi as separate service, call via HTTP | Not recommended |
| **Option 3: Plugin/Extension Model** | Build as Moltbot extension/plugin | Possible alternative |

---

## Decision

### Selected Approach: Option 1 - Direct SDK Integration

We will integrate the Compsi TypeScript SDK (`@aiassesstech/sdk`) directly into Moltbot's core codebase, with a dedicated assessment state machine managing user assessment lifecycle.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         APPROVED ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   MOLTBOT CORE                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                                                                     │  │
│   │  ┌─────────────────┐    ┌─────────────────┐    ┌────────────────┐  │  │
│   │  │                 │    │                 │    │                │  │  │
│   │  │  Message        │───►│  Assessment     │───►│  Work          │  │  │
│   │  │  Router         │    │  Gate           │    │  Processor     │  │  │
│   │  │                 │    │                 │    │                │  │  │
│   │  └─────────────────┘    └────────┬────────┘    └────────────────┘  │  │
│   │                                  │                                  │  │
│   │                                  ▼                                  │  │
│   │                     ┌─────────────────────────┐                    │  │
│   │                     │                         │                    │  │
│   │                     │  Assessment State       │                    │  │
│   │                     │  Machine                │                    │  │
│   │                     │                         │                    │  │
│   │                     │  States:                │                    │  │
│   │                     │  - IDLE                 │                    │  │
│   │                     │  - PENDING              │                    │  │
│   │                     │  - IN_PROGRESS          │                    │  │
│   │                     │  - PASSED               │                    │  │
│   │                     │  - FAILED               │                    │  │
│   │                     │  - BYPASSED             │                    │  │
│   │                     │                         │                    │  │
│   │                     └────────────┬────────────┘                    │  │
│   │                                  │                                  │  │
│   │                                  ▼                                  │  │
│   │                     ┌─────────────────────────┐                    │  │
│   │                     │                         │                    │  │
│   │                     │  Compsi SDK Wrapper     │                    │  │
│   │                     │  (MoltbotAssessClient)  │                    │  │
│   │                     │                         │                    │  │
│   │                     └────────────┬────────────┘                    │  │
│   │                                  │                                  │  │
│   └──────────────────────────────────┼──────────────────────────────────┘  │
│                                      │                                      │
│                                      ▼                                      │
│                     ┌─────────────────────────────────┐                    │
│                     │                                 │                    │
│                     │  @aiassesstech/sdk              │                    │
│                     │  (Compsi TypeScript SDK)        │                    │
│                     │                                 │                    │
│                     │  - assess()                     │                    │
│                     │  - blockUntilPass()             │                    │
│                     │  - verifyBank()                 │                    │
│                     │                                 │                    │
│                     └────────────────┬────────────────┘                    │
│                                      │                                      │
│                                      ▼                                      │
│                     ┌─────────────────────────────────┐                    │
│                     │                                 │                    │
│                     │  AI Assess Tech Cloud           │                    │
│                     │  (aiassesstech.com)             │                    │
│                     │                                 │                    │
│                     │  - Question delivery            │                    │
│                     │  - Score calculation            │                    │
│                     │  - Result verification          │                    │
│                     │                                 │                    │
│                     └─────────────────────────────────┘                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Rationale

### Why Direct SDK Integration (Option 1)?

| Factor | Direct SDK | API Gateway | Plugin |
|--------|------------|-------------|--------|
| **Latency** | ✅ Minimal (in-process) | ❌ HTTP overhead | ✅ Minimal |
| **Complexity** | ✅ Simple | ❌ Separate service | ⚠️ Plugin boundaries |
| **Reliability** | ✅ No network dep | ❌ Network required | ✅ In-process |
| **Maintenance** | ✅ Single codebase | ❌ Two codebases | ⚠️ Plugin updates |
| **Type Safety** | ✅ Full TypeScript | ⚠️ API contracts | ✅ Full TypeScript |
| **State Management** | ✅ Unified | ❌ Distributed | ⚠️ Plugin isolation |

### Key Benefits

1. **Zero Network Latency** - SDK runs in-process with Moltbot
2. **Single Codebase** - All assessment logic in Moltbot repo
3. **Type Safety** - Full TypeScript integration
4. **Unified State** - Assessment state managed with Moltbot state
5. **Simpler Deployment** - No separate services to manage
6. **Privacy** - User's AI responses never leave Moltbot process

### Why Not API Gateway (Option 2)?

```
REJECTED: API Gateway Integration

Drawbacks:
- Additional service to deploy and maintain
- Network latency for every question
- Distributed state management complexity
- Additional failure points
- More complex deployment

Trade-off: Better isolation but unacceptable complexity
Decision: Complexity outweighs isolation benefit
```

### Why Not Plugin/Extension (Option 3)?

```
CONSIDERED BUT NOT SELECTED: Plugin Model

Drawbacks:
- Plugin boundary adds complexity
- Assessment is core to work enablement (not optional)
- State sharing between plugin and core is complex
- Update coordination between plugin and core

Trade-off: Modularity vs. integration depth
Decision: Assessment is too core for plugin isolation
Note: Could be reconsidered for future multi-tenant SaaS model
```

---

## Technical Architecture

### Core Components

#### 1. Assessment State Machine

Manages the lifecycle of daily assessments per user.

```typescript
// States
type AssessmentState = 
  | 'IDLE'        // No assessment required (after hours, weekend)
  | 'PENDING'     // Assessment required, not started
  | 'IN_PROGRESS' // Assessment in progress
  | 'PASSED'      // Assessment completed, passed
  | 'FAILED'      // Assessment completed, failed
  | 'RETRYING'    // Failed but retry in progress
  | 'BYPASSED';   // Emergency bypass by manager

// State transitions
interface StateTransition {
  from: AssessmentState;
  to: AssessmentState;
  trigger: string;
  guard?: () => boolean;
  action?: () => void;
}

const transitions: StateTransition[] = [
  { from: 'IDLE', to: 'PENDING', trigger: 'DAY_START' },
  { from: 'PENDING', to: 'IN_PROGRESS', trigger: 'START_ASSESSMENT' },
  { from: 'IN_PROGRESS', to: 'PASSED', trigger: 'ASSESSMENT_PASSED' },
  { from: 'IN_PROGRESS', to: 'FAILED', trigger: 'ASSESSMENT_FAILED' },
  { from: 'FAILED', to: 'RETRYING', trigger: 'RETRY_ASSESSMENT', guard: () => retriesRemaining > 0 },
  { from: 'RETRYING', to: 'PASSED', trigger: 'ASSESSMENT_PASSED' },
  { from: 'RETRYING', to: 'FAILED', trigger: 'ASSESSMENT_FAILED' },
  { from: 'FAILED', to: 'BYPASSED', trigger: 'MANAGER_BYPASS' },
  { from: 'PASSED', to: 'IDLE', trigger: 'DAY_END' },
  { from: 'FAILED', to: 'IDLE', trigger: 'DAY_END' },
  { from: 'BYPASSED', to: 'IDLE', trigger: 'DAY_END' },
];
```

#### 2. Assessment Gate

Intercepts work requests and enforces assessment requirements.

```typescript
interface AssessmentGate {
  // Check if user can proceed with work
  canProceed(userId: string, taskType: string): Promise<GateDecision>;
  
  // Get user's current assessment status
  getStatus(userId: string): Promise<AssessmentStatus>;
  
  // Start assessment for user
  startAssessment(userId: string): Promise<void>;
}

interface GateDecision {
  allowed: boolean;
  reason?: string;
  requiredAction?: 'complete_assessment' | 'retry_assessment' | 'contact_manager';
  limitedMode?: boolean; // If true, allow limited functionality
}
```

#### 3. Compsi SDK Wrapper

Wraps the Compsi SDK with Moltbot-specific functionality.

```typescript
class MoltbotAssessmentClient {
  private compsiClient: AIAssessClient;
  
  constructor(config: {
    healthCheckKey: string;
    userId: string;
    organizationId: string;
  });
  
  // Run assessment via Moltbot chat interface
  async runAssessment(
    askUser: (question: string) => Promise<string>,
    onProgress?: (progress: AssessProgress) => void
  ): Promise<AssessmentResult>;
  
  // Resume interrupted assessment
  async resumeAssessment(
    sessionId: string,
    askUser: (question: string) => Promise<string>
  ): Promise<AssessmentResult>;
  
  // Check assessment validity
  async isAssessmentValid(result: AssessmentResult): Promise<boolean>;
}
```

#### 4. Audit Logger

Records all assessment events for compliance.

```typescript
interface AssessmentAuditLogger {
  // Log assessment start
  logStart(userId: string, frameworkId: string): Promise<void>;
  
  // Log individual response
  logResponse(userId: string, questionId: string, response: string): Promise<void>;
  
  // Log assessment result
  logResult(userId: string, result: AssessmentResult): Promise<void>;
  
  // Log state transition
  logTransition(userId: string, from: AssessmentState, to: AssessmentState): Promise<void>;
  
  // Query audit log
  query(filters: AuditLogFilters): Promise<AuditLogEntry[]>;
}
```

---

## Data Flow

### Daily Assessment Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DAILY ASSESSMENT FLOW                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. User starts day / first message                                         │
│     │                                                                       │
│     ▼                                                                       │
│  2. Assessment Gate checks status                                           │
│     │                                                                       │
│     ├── If PASSED (today) ──────────────────────────► 8. Proceed to work   │
│     │                                                                       │
│     ├── If BYPASSED ─────────────────────────────────► 8. Proceed to work   │
│     │                                                                       │
│     └── If PENDING/FAILED ──────────► 3. Prompt for assessment             │
│                                        │                                    │
│                                        ▼                                    │
│                                     4. User confirms start                  │
│                                        │                                    │
│                                        ▼                                    │
│                                     5. State → IN_PROGRESS                  │
│                                        │                                    │
│                                        ▼                                    │
│                             ┌──────────────────────────┐                   │
│                             │  6. Assessment Loop      │                   │
│                             │                          │                   │
│                             │  For each question:      │                   │
│                             │  a. SDK delivers question│                   │
│                             │  b. Moltbot asks user    │                   │
│                             │  c. User responds        │                   │
│                             │  d. Response sent to SDK │                   │
│                             │  e. Log response         │                   │
│                             │  f. Update progress      │                   │
│                             │                          │                   │
│                             └────────────┬─────────────┘                   │
│                                          │                                  │
│                                          ▼                                  │
│                             7. SDK calculates scores                        │
│                                          │                                  │
│                             ┌────────────┴────────────┐                    │
│                             │                         │                    │
│                             ▼                         ▼                    │
│                    7a. PASSED                  7b. FAILED                  │
│                             │                         │                    │
│                             ▼                         ▼                    │
│                    State → PASSED            State → FAILED                │
│                             │                         │                    │
│                             ▼                         ├──► Retry available?│
│                    8. Proceed to work                 │         │          │
│                                                       │    Yes  │  No      │
│                                                       │    ▼    ▼          │
│                                                       │ Retry  Escalate   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Configuration Architecture

### Organization Configuration

```typescript
interface OrganizationAssessmentConfig {
  organizationId: string;
  
  // Compsi Configuration
  compsi: {
    healthCheckKey: string;  // hck_...
    baseUrl?: string;        // Override for self-hosted
  };
  
  // Schedule Configuration
  schedule: {
    enabled: boolean;
    frequency: 'daily' | 'weekly' | 'on_demand';
    windowStart: string;      // "06:00" local time
    windowEnd: string;        // "10:00" local time
    timezone: string;         // "America/New_York"
    gracePeriodMinutes: number;
    skipWeekends: boolean;
    skipHolidays: boolean;
    holidayCalendar?: string; // Calendar ID
  };
  
  // Framework Configuration
  frameworks: Array<{
    id: string;
    name: string;
    required: boolean;
    thresholds: { [dimension: string]: number };
  }>;
  
  // Role Overrides
  roleOverrides: Array<{
    roleId: string;
    frameworks: string[];
    thresholds: { [dimension: string]: number };
    frequency: 'daily' | 'weekly';
  }>;
  
  // Retry Policy
  retry: {
    maxAttempts: number;
    cooldownMinutes: number;
    requiresApproval: boolean;
  };
  
  // Bypass Policy
  bypass: {
    enabled: boolean;
    approverRoles: string[];
    maxPerMonth: number;
    requiresJustification: boolean;
  };
  
  // Audit Configuration
  audit: {
    retentionDays: number;
    encryptionEnabled: boolean;
    externalExportEnabled: boolean;
  };
}
```

### User Assessment State

```typescript
interface UserAssessmentState {
  userId: string;
  organizationId: string;
  
  // Current state
  state: AssessmentState;
  stateChangedAt: Date;
  
  // Current/last assessment
  currentAssessment?: {
    sessionId: string;
    startedAt: Date;
    frameworkId: string;
    progress: {
      current: number;
      total: number;
      percentage: number;
    };
  };
  
  // Last completed assessment
  lastAssessment?: {
    runId: string;
    completedAt: Date;
    frameworkId: string;
    scores: { [dimension: string]: number };
    passed: boolean;
    classification: string;
    verifyUrl: string;
  };
  
  // Today's stats
  today: {
    assessmentRequired: boolean;
    assessmentCompleted: boolean;
    attempts: number;
    bypassed: boolean;
    bypassApprovedBy?: string;
    bypassReason?: string;
  };
  
  // Historical stats
  stats: {
    totalAssessments: number;
    passRate: number;
    averageScore: number;
    currentStreak: number;
    longestStreak: number;
  };
}
```

---

## Security Considerations

### Data Protection

1. **Health Check Key Protection**
   - Stored encrypted at rest
   - Never exposed in logs or error messages
   - Rotatable without downtime

2. **Assessment Response Privacy**
   - User responses stay in Moltbot process
   - Only answer letters sent to Compsi (not full text)
   - Local caching encrypted

3. **Audit Log Security**
   - Cryptographically signed entries
   - Immutable append-only storage
   - Access controlled by role

### Access Control

```typescript
interface AssessmentPermissions {
  // User permissions
  user: {
    canViewOwnResults: true;
    canRetryAssessment: true;
    canRequestBypass: true;
  };
  
  // Manager permissions
  manager: {
    canViewTeamStatus: true;
    canApproveBypass: true;
    canViewTeamHistory: true;
    canViewIndividualDetails: false; // Privacy protection
  };
  
  // Compliance Officer permissions
  complianceOfficer: {
    canViewAllResults: true;
    canExportAuditLogs: true;
    canConfigureFrameworks: true;
    canViewIndividualDetails: true;
  };
  
  // Admin permissions
  admin: {
    canConfigureOrganization: true;
    canManageHealthCheckKeys: true;
    canManageRoles: true;
  };
}
```

---

## Implementation Phases

### Phase 1: Core Integration (MVP)

**Duration**: 2-3 sprints

**Deliverables**:
- Compsi SDK integration (`MoltbotAssessmentClient`)
- Assessment state machine
- Basic assessment gate (pass/fail blocking)
- Simple audit logging
- Single framework support (Morality/LCSH)

### Phase 2: Enterprise Features

**Duration**: 2-3 sprints

**Deliverables**:
- Multi-framework support
- Role-based requirements
- Manager dashboard
- Bypass workflow
- Enhanced audit logging

### Phase 3: Advanced Features

**Duration**: 2-3 sprints

**Deliverables**:
- Compliance dashboard
- Custom framework builder
- SSO integration
- Regulatory reporting
- Gamification

---

## Success Criteria

### Technical Success

- [ ] SDK integration passes all unit tests
- [ ] Assessment flow completes in < 10 minutes
- [ ] State machine handles all edge cases
- [ ] Audit log captures 100% of events
- [ ] Zero assessment data leaks

### Business Success

- [ ] 90%+ daily assessment completion rate
- [ ] < 5% assessment failure rate
- [ ] < 1% emergency bypass rate
- [ ] Manager satisfaction > 4.0/5.0
- [ ] Compliance audit passed

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Compsi service outage | Low | High | Graceful degradation, cached questions |
| User abandons assessment | Medium | Medium | Resume capability, progress persistence |
| Gaming/cheating | Low | High | Random question order, consistency checks |
| Performance degradation | Low | Medium | Async processing, progress caching |
| Key compromise | Low | Critical | Key rotation, monitoring, alerts |

---

## Dependencies

### External Dependencies

1. **@aiassesstech/sdk** - Compsi TypeScript SDK
2. **Compsi Health Check Key** - Per-organization
3. **AI Assess Tech Cloud** - Question delivery, scoring

### Internal Dependencies

1. **Moltbot User System** - User identity, organization membership
2. **Moltbot Message Router** - Intercept messages for gating
3. **Moltbot Database** - State and audit persistence
4. **Moltbot Config System** - Organization configuration

---

## Approval

| Role | Name | Date | Decision |
|------|------|------|----------|
| Architecture | - | 2026-01-28 | Approved |
| Security | - | 2026-01-28 | Approved |
| Product | - | 2026-01-28 | Approved |

---

## References

- **USER-STORIES-COMPSI-MOLTBOT-INTEGRATION.md** - User stories
- **Compsi SDK README** - `packages/sdk-ts/README.md`
- **Compsi Ethical Framework** - `docs/00a-ethical-frameworks-definition.md`
- **Moltbot CLAUDE.md** - Project guidelines

---

**Document Status**: APPROVED  
**Next Step**: Proceed to SPEC-INTEGRATION-MOLTBOT-COMPSI-SDK.md
