# User Stories: Compsi SDK Integration with Moltbot

**Document ID**: USER-STORIES-COMPSI-MOLTBOT-INTEGRATION  
**Version**: 1.0  
**Date Created**: 2026-01-28  
**Status**: Draft  
**Source SDK**: @aiassesstech/sdk (TypeScript)

---

## Executive Summary

This document defines user stories for integrating the Compsi (AI Assess Tech) SDK with Moltbot to enable daily ethical and operational assessments for enterprise users. The integration enables organizations to:

1. Verify user alignment with organizational values at the start of each workday
2. Assess users across multiple frameworks (Morality, Virtue, Ethics, Operational Excellence)
3. Support role-based assessment profiles
4. Enable AI assistants to help users complete work only after passing assessments
5. Provide comprehensive audit trails for compliance

---

## Personas

### Primary Personas

| Persona | Description | Needs |
|---------|-------------|-------|
| **Enterprise User (EU)** | Employee using Moltbot AI to assist with daily work | Quick daily assessment, clear feedback, work enablement |
| **Team Manager (TM)** | Manager overseeing team of users | Team compliance dashboard, aggregate reports, escalation handling |
| **Compliance Officer (CO)** | Organizational compliance and ethics oversight | Audit trails, regulatory reports, policy enforcement |
| **IT Administrator (ITA)** | Configures and maintains Moltbot deployment | Easy setup, SSO integration, role management |
| **Organization Owner (OO)** | Executive sponsor of ethics program | ROI metrics, board-level reporting, strategic insights |

### Secondary Personas

| Persona | Description | Needs |
|---------|-------------|-------|
| **AI Bot (BOT)** | The Moltbot instance assisting users | Clear authorization signals, assessment state awareness |
| **External Auditor (EA)** | Third-party compliance auditor | Immutable records, verification capabilities |

---

## Epic 1: Daily Assessment Infrastructure

**Epic Goal**: Enable daily start-of-day assessments for enterprise users before they can access AI assistance.

---

### Story 1.1: Daily Check-In Assessment Flow

**As an** Enterprise User  
**I want** to complete a quick ethical assessment at the start of my workday  
**So that** I am verified to use the AI assistant and demonstrate my alignment with organizational values

**Acceptance Criteria:**

- [ ] User receives a prompt when first interacting with Moltbot each day (configurable time window)
- [ ] Assessment uses Compsi SDK `assess()` method with organization's Health Check Key
- [ ] Questions are presented one at a time via Moltbot's chat interface
- [ ] Progress indicator shows completion percentage (e.g., "Question 15 of 30")
- [ ] Assessment completes within 5-10 minutes (depending on question count)
- [ ] Upon passing, user receives confirmation and can proceed to work
- [ ] Upon failing, user receives guidance and escalation path
- [ ] Assessment state persists across sessions (resume if interrupted)

**Technical Notes:**

```typescript
// Integration pattern
const client = new AIAssessClient({
  healthCheckKey: organization.compsiKey
});

const result = await client.assess(
  async (question) => {
    // Present question via Moltbot chat interface
    return await moltbot.askUser(question);
  },
  {
    onProgress: (progress) => {
      moltbot.updateStatus(`Assessment: ${progress.percentage}%`);
    }
  }
);
```

**Priority**: P0 (Critical)  
**Estimated Effort**: 13 story points

---

### Story 1.2: Assessment Schedule Configuration

**As an** IT Administrator  
**I want** to configure when daily assessments are required  
**So that** assessments align with work schedules and don't disrupt productivity

**Acceptance Criteria:**

- [ ] Configure assessment window (e.g., "first interaction between 6 AM - 10 AM")
- [ ] Configure assessment frequency (daily, weekly, on-demand, event-triggered)
- [ ] Configure grace period for late starts (e.g., 2-hour grace)
- [ ] Configure bypass rules (e.g., "skip if passed within last 24 hours")
- [ ] Configure timezone per user or organization
- [ ] Support for shift workers with multiple work windows
- [ ] Holiday/vacation bypass configuration
- [ ] Emergency bypass with audit logging

**Configuration Schema:**

```typescript
interface AssessmentSchedule {
  frequency: 'daily' | 'weekly' | 'monthly' | 'on_demand';
  windowStart: string; // "06:00"
  windowEnd: string;   // "10:00"
  timezone: string;    // "America/New_York"
  gracePeriodMinutes: number;
  bypassRules: {
    hoursUntilReassessment: number; // Skip if passed within X hours
    skipOnHolidays: boolean;
    skipOnVacation: boolean;
  };
  emergencyBypass: {
    requiresApproval: boolean;
    approverRoleId: string;
    maxBypassesPerMonth: number;
  };
}
```

**Priority**: P1 (Important)  
**Estimated Effort**: 8 story points

---

### Story 1.3: Assessment Gating for AI Access

**As an** Enterprise User  
**I want** the AI assistant to know my assessment status  
**So that** it can provide appropriate access based on my verification state

**Acceptance Criteria:**

- [ ] Moltbot checks assessment status before processing work requests
- [ ] If assessment not completed today, user is prompted to complete it
- [ ] If assessment failed, user sees remediation guidance
- [ ] If assessment passed, full AI capabilities are available
- [ ] Assessment status is visible in Moltbot status bar
- [ ] Status refreshes automatically when assessment completes
- [ ] Graceful degradation: limited "safety mode" if assessment pending

**State Machine:**

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ASSESSMENT STATE MACHINE                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌─────────┐    start_day    ┌─────────────┐                      │
│   │         │ ───────────────►│             │                      │
│   │  IDLE   │                 │  PENDING    │                      │
│   │         │◄─────────────── │             │                      │
│   └─────────┘    day_ends     └──────┬──────┘                      │
│                                      │                              │
│                              assessment_complete                    │
│                                      │                              │
│                        ┌─────────────┴─────────────┐               │
│                        ▼                           ▼                │
│              ┌─────────────┐             ┌─────────────┐           │
│              │             │             │             │           │
│              │  PASSED     │             │  FAILED     │           │
│              │  (Full AI)  │             │  (Limited)  │           │
│              │             │             │             │           │
│              └─────────────┘             └──────┬──────┘           │
│                                                 │                  │
│                                          retry_available           │
│                                                 │                  │
│                                                 ▼                  │
│                                         ┌─────────────┐            │
│                                         │             │            │
│                                         │  RETRYING   │            │
│                                         │             │            │
│                                         └─────────────┘            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Priority**: P0 (Critical)  
**Estimated Effort**: 8 story points

---

### Story 1.4: Assessment Resume and Recovery

**As an** Enterprise User  
**I want** to resume an interrupted assessment  
**So that** I don't lose progress if my session is interrupted

**Acceptance Criteria:**

- [ ] Assessment progress is persisted after each answered question
- [ ] If user disconnects, they can resume from last answered question
- [ ] Resume is offered automatically on next interaction
- [ ] User can choose to restart from beginning if desired
- [ ] Progress expires after configurable timeout (e.g., 2 hours)
- [ ] Expired progress requires restart from beginning
- [ ] Partial progress is logged for audit purposes

**Priority**: P1 (Important)  
**Estimated Effort**: 5 story points

---

## Epic 2: Multi-Framework Assessment

**Epic Goal**: Support multiple assessment frameworks beyond the base Morality (LCSH) framework.

---

### Story 2.1: Framework Selection and Configuration

**As an** IT Administrator  
**I want** to configure which assessment frameworks are used for my organization  
**So that** assessments align with our specific values and compliance requirements

**Acceptance Criteria:**

- [ ] Support for multiple frameworks:
  - **Morality** (LCSH: Lying, Cheating, Stealing, Harm)
  - **Virtue** (Courage, Wisdom, Temperance, Justice) - Future
  - **Ethics** (Professional ethics frameworks) - Future
  - **Operational Excellence** (Quality, Reliability, Accountability) - Future
- [ ] Configure framework priority/order
- [ ] Configure which frameworks are required vs. optional
- [ ] Set passing thresholds per framework
- [ ] Configure framework rotation (e.g., different framework each day)
- [ ] Framework bundles for industry-specific compliance
- [ ] A/B testing support for new frameworks

**Configuration Schema:**

```typescript
interface FrameworkConfiguration {
  organizationId: string;
  frameworks: Array<{
    frameworkId: string;
    name: string;
    required: boolean;
    priority: number;
    thresholds: {
      [dimension: string]: number; // 0-10 passing threshold
    };
    schedule: 'daily' | 'weekly' | 'rotation';
    rotationDayOfWeek?: number; // 0-6 for rotation schedule
  }>;
  bundleId?: string; // e.g., "healthcare-compliance", "financial-services"
}
```

**Priority**: P1 (Important)  
**Estimated Effort**: 13 story points

---

### Story 2.2: Multi-Framework Assessment Sequence

**As an** Enterprise User  
**I want** to understand which frameworks I'm being assessed on  
**So that** I can prepare mentally and understand the expectations

**Acceptance Criteria:**

- [ ] Clear indication of current framework at assessment start
- [ ] Framework-specific introduction/context provided
- [ ] Progress shows framework name and dimension being tested
- [ ] Results show scores per framework and per dimension
- [ ] Aggregate pass/fail considers all required frameworks
- [ ] Partial pass is possible (some frameworks passed, some failed)
- [ ] Framework-specific remediation guidance

**UI Flow:**

```
┌─────────────────────────────────────────────────────────────────────┐
│  DAILY ASSESSMENT                                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  📋 Today's Assessment: 2 Frameworks                                │
│                                                                     │
│  1. ✅ Morality Framework (30 questions) ─────────────── PASSED     │
│     └─ Lying: 8.5  Cheating: 9.0  Stealing: 8.0  Harm: 9.5         │
│                                                                     │
│  2. 🔄 Operational Excellence (20 questions) ────────── IN PROGRESS │
│     └─ Quality: --  Reliability: --  Accountability: --            │
│     └─ Progress: 12/20 (60%)                                       │
│                                                                     │
│  Estimated time remaining: 4 minutes                                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Priority**: P1 (Important)  
**Estimated Effort**: 8 story points

---

### Story 2.3: Custom Framework Builder

**As a** Compliance Officer  
**I want** to create custom assessment frameworks specific to my organization  
**So that** assessments reflect our unique values and compliance requirements

**Acceptance Criteria:**

- [ ] Create custom frameworks with custom dimensions
- [ ] Import questions from question bank or create custom questions
- [ ] Set custom thresholds per dimension
- [ ] Map custom frameworks to personality classifications
- [ ] Test frameworks before deployment (preview mode)
- [ ] Version frameworks with change history
- [ ] Deprecate frameworks without losing historical data
- [ ] Export/import frameworks for sharing

**Priority**: P2 (Nice to Have)  
**Estimated Effort**: 21 story points

---

## Epic 3: Role-Based Assessment

**Epic Goal**: Support different assessment requirements based on user roles within the organization.

---

### Story 3.1: Role Definition and Assignment

**As an** IT Administrator  
**I want** to define roles and assign users to them  
**So that** assessment requirements are tailored to job responsibilities

**Acceptance Criteria:**

- [ ] Create organizational roles (e.g., "Financial Analyst", "Manager", "Executive")
- [ ] Assign users to one or more roles
- [ ] Roles can inherit from parent roles (hierarchy)
- [ ] Role assignment can be synced from SSO/LDAP
- [ ] Bulk role assignment via CSV import
- [ ] Role changes trigger re-assessment if requirements change
- [ ] Historical role tracking for audit purposes

**Role Hierarchy Example:**

```
Organization
├── Executive
│   ├── C-Suite
│   └── VP
├── Manager
│   ├── Department Head
│   └── Team Lead
├── Individual Contributor
│   ├── Senior IC
│   └── Junior IC
└── Contractor
    ├── Full Access
    └── Limited Access
```

**Priority**: P1 (Important)  
**Estimated Effort**: 13 story points

---

### Story 3.2: Role-Based Framework Requirements

**As a** Compliance Officer  
**I want** to specify which frameworks are required for each role  
**So that** sensitive roles have additional assessment requirements

**Acceptance Criteria:**

- [ ] Map frameworks to roles (many-to-many relationship)
- [ ] Specify required vs. optional frameworks per role
- [ ] Set role-specific thresholds (stricter for sensitive roles)
- [ ] Define assessment frequency per role
- [ ] Role with multiple framework requirements assesses all
- [ ] Dashboard shows role compliance across organization
- [ ] Alerts when role requirements change

**Configuration Example:**

```typescript
interface RoleFrameworkRequirements {
  roleId: string;
  roleName: string;
  frameworks: Array<{
    frameworkId: string;
    required: boolean;
    thresholds: { [dimension: string]: number };
    frequency: 'daily' | 'weekly' | 'monthly';
  }>;
  additionalRequirements: {
    requiresManagerApprovalOnFail: boolean;
    maxRetryAttempts: number;
    cooldownBetweenRetries: number; // minutes
  };
}

// Example: Financial roles require stricter thresholds
const financialAnalystRole: RoleFrameworkRequirements = {
  roleId: 'financial-analyst',
  roleName: 'Financial Analyst',
  frameworks: [
    {
      frameworkId: 'morality-lcsh',
      required: true,
      thresholds: { lying: 8, cheating: 8, stealing: 9, harm: 7 }, // Higher thresholds
      frequency: 'daily'
    },
    {
      frameworkId: 'ethics-professional',
      required: true,
      thresholds: { integrity: 8, accountability: 8 },
      frequency: 'weekly'
    }
  ],
  additionalRequirements: {
    requiresManagerApprovalOnFail: true,
    maxRetryAttempts: 2,
    cooldownBetweenRetries: 60
  }
};
```

**Priority**: P1 (Important)  
**Estimated Effort**: 8 story points

---

### Story 3.3: Multi-Role User Assessment

**As an** Enterprise User with multiple roles  
**I want** to complete assessments for all my roles efficiently  
**So that** I can fulfill all my job responsibilities

**Acceptance Criteria:**

- [ ] Users with multiple roles see combined assessment requirements
- [ ] Overlapping frameworks are assessed only once
- [ ] Most stringent threshold applies when frameworks overlap
- [ ] Assessment results apply to all relevant roles
- [ ] Clear indication of which roles are satisfied by each assessment
- [ ] Role-specific results can be viewed separately
- [ ] Manager sees which roles employee is cleared for

**Priority**: P1 (Important)  
**Estimated Effort**: 8 story points

---

## Epic 4: Work Enablement Integration

**Epic Goal**: Enable Moltbot to assist users with work only after successful assessment.

---

### Story 4.1: Work Task Gating

**As an** Enterprise User who has passed assessment  
**I want** the AI to help me with my work tasks  
**So that** I can be productive throughout the day

**Acceptance Criteria:**

- [ ] Moltbot provides full AI capabilities after passing assessment
- [ ] Task categories are defined (email, documents, data analysis, etc.)
- [ ] Sensitive tasks can require higher assessment thresholds
- [ ] Work history is tracked with assessment status at time of work
- [ ] No work assistance is provided without valid assessment
- [ ] Clear messaging when work is blocked due to assessment status

**Task Sensitivity Levels:**

```typescript
interface TaskSensitivity {
  taskType: string;
  sensitivityLevel: 'low' | 'medium' | 'high' | 'critical';
  minimumAssessmentThresholds: {
    [dimension: string]: number;
  };
  requiresFrameworks: string[];
  auditRequired: boolean;
}

const taskSensitivities: TaskSensitivity[] = [
  {
    taskType: 'general_inquiry',
    sensitivityLevel: 'low',
    minimumAssessmentThresholds: { overall: 6 },
    requiresFrameworks: ['morality-lcsh'],
    auditRequired: false
  },
  {
    taskType: 'financial_analysis',
    sensitivityLevel: 'high',
    minimumAssessmentThresholds: { lying: 8, cheating: 8, stealing: 9 },
    requiresFrameworks: ['morality-lcsh', 'ethics-professional'],
    auditRequired: true
  },
  {
    taskType: 'customer_pii_access',
    sensitivityLevel: 'critical',
    minimumAssessmentThresholds: { lying: 9, stealing: 9, harm: 8 },
    requiresFrameworks: ['morality-lcsh', 'ethics-professional', 'operational-excellence'],
    auditRequired: true
  }
];
```

**Priority**: P0 (Critical)  
**Estimated Effort**: 13 story points

---

### Story 4.2: Limited Mode for Failed/Pending Assessments

**As an** Enterprise User who hasn't passed assessment  
**I want** limited AI functionality for non-sensitive tasks  
**So that** I'm not completely blocked while completing or retrying assessment

**Acceptance Criteria:**

- [ ] "Safety mode" provides limited AI capabilities
- [ ] Safety mode allows: general questions, non-sensitive information
- [ ] Safety mode blocks: data access, document generation, sensitive queries
- [ ] Clear indication that user is in safety mode
- [ ] Persistent prompt to complete assessment
- [ ] Time limit on safety mode (e.g., 2 hours max)
- [ ] Safety mode usage is logged for audit

**Priority**: P1 (Important)  
**Estimated Effort**: 8 story points

---

### Story 4.3: Context-Aware Task Assistance

**As an** Enterprise User  
**I want** the AI to understand my role and assessment status  
**So that** it can provide appropriately scoped assistance

**Acceptance Criteria:**

- [ ] Moltbot knows user's roles and current assessment status
- [ ] Moltbot tailors responses based on role context
- [ ] Moltbot proactively enforces task sensitivity limits
- [ ] Moltbot provides role-appropriate guidance and suggestions
- [ ] Moltbot can explain why certain tasks are restricted
- [ ] Moltbot tracks role context across conversation

**Priority**: P1 (Important)  
**Estimated Effort**: 8 story points

---

## Epic 5: Compliance and Audit Trail

**Epic Goal**: Provide comprehensive audit capabilities for regulatory compliance.

---

### Story 5.1: Immutable Assessment Audit Log

**As a** Compliance Officer  
**I want** complete, immutable records of all assessments  
**So that** I can demonstrate compliance to auditors and regulators

**Acceptance Criteria:**

- [ ] Every assessment is logged with unique identifier
- [ ] Log includes: user, timestamp, framework, all responses, scores, result
- [ ] Logs are cryptographically signed and immutable
- [ ] Logs include assessment metadata (device, location if available)
- [ ] Logs reference question bank version used
- [ ] Logs can be verified against blockchain anchor (future)
- [ ] Export logs in compliance-friendly formats (JSON, CSV, PDF)

**Audit Log Schema:**

```typescript
interface AssessmentAuditLog {
  // Identity
  auditId: string;           // UUID
  assessmentRunId: string;   // From Compsi SDK
  sdkSessionId: string;      // From Compsi SDK
  
  // Subject
  userId: string;
  userRoles: string[];
  organizationId: string;
  
  // Context
  timestamp: Date;
  timezone: string;
  deviceInfo: {
    platform: string;
    channel: string;       // Which Moltbot channel
    ipAddress?: string;    // If available
  };
  
  // Assessment
  frameworkId: string;
  frameworkVersion: string;
  questionSetVersion: string;
  testMode: 'ISOLATED' | 'CONVERSATIONAL';
  
  // Responses
  responses: Array<{
    questionId: string;
    questionText: string;
    answerLetter: string;
    selectedAnswer: string;
    durationMs: number;
    timestamp: Date;
  }>;
  
  // Results
  scores: { [dimension: string]: number };
  passed: { [dimension: string]: boolean };
  overallPassed: boolean;
  classification: string;
  confidence: number;
  
  // Verification
  resultHash: string;
  verifyUrl: string;
  
  // Cryptographic Integrity
  signatureAlgorithm: string;
  signature: string;
  publicKeyFingerprint: string;
}
```

**Priority**: P0 (Critical)  
**Estimated Effort**: 13 story points

---

### Story 5.2: Compliance Dashboard

**As a** Compliance Officer  
**I want** a dashboard showing organization-wide assessment compliance  
**So that** I can monitor ethics program effectiveness

**Acceptance Criteria:**

- [ ] Real-time compliance percentage (% of users passed today)
- [ ] Trend charts (compliance over time)
- [ ] Department/team breakdown
- [ ] Role-based compliance view
- [ ] Framework-specific compliance metrics
- [ ] Dimension score distributions
- [ ] Anomaly detection (unusual score patterns)
- [ ] Export reports for board/regulatory submissions

**Dashboard Metrics:**

```
┌─────────────────────────────────────────────────────────────────────┐
│  COMPLIANCE DASHBOARD                          Last updated: 2m ago │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  TODAY'S COMPLIANCE                                                 │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  ████████████████████████████████████░░░░░░░░  85%           │  │
│  │  425 of 500 users have passed daily assessment               │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  BY DEPARTMENT                              BY FRAMEWORK            │
│  ┌─────────────────────────┐               ┌────────────────────┐  │
│  │ Engineering      92%    │               │ Morality    88%    │  │
│  │ Sales           78%     │               │ Ethics      82%    │  │
│  │ Finance         95%     │               │ OpEx        79%    │  │
│  │ HR              88%     │               └────────────────────┘  │
│  │ Executive       100%    │                                       │
│  └─────────────────────────┘                                       │
│                                                                     │
│  ALERTS                                                             │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ ⚠️  Sales department below 80% threshold (78%)               │  │
│  │ ⚠️  3 users have failed assessment 2+ times today            │  │
│  │ 🔴  1 user classified as "Psychopath" - requires review      │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Priority**: P1 (Important)  
**Estimated Effort**: 21 story points

---

### Story 5.3: Regulatory Reporting

**As a** Compliance Officer  
**I want** to generate regulatory compliance reports  
**So that** I can meet reporting requirements for various frameworks

**Acceptance Criteria:**

- [ ] Pre-built report templates for common frameworks (SOC2, ISO 27001, etc.)
- [ ] Custom report builder
- [ ] Scheduled report generation and distribution
- [ ] Report includes assessment statistics, trends, and insights
- [ ] Report includes verification URLs for spot-checking
- [ ] Report signing for authenticity
- [ ] Retention policy management (keep reports for X years)

**Priority**: P2 (Nice to Have)  
**Estimated Effort**: 13 story points

---

### Story 5.4: External Auditor Access

**As an** External Auditor  
**I want** read-only access to assessment records  
**So that** I can verify compliance independently

**Acceptance Criteria:**

- [ ] Create time-limited auditor accounts
- [ ] Auditor sees only assessment data (no operational data)
- [ ] Auditor can verify individual assessments via Compsi API
- [ ] Auditor can export data in standard formats
- [ ] All auditor actions are logged
- [ ] Auditor access can be revoked immediately
- [ ] Auditor access requires organization approval

**Priority**: P2 (Nice to Have)  
**Estimated Effort**: 8 story points

---

## Epic 6: Manager and Team Oversight

**Epic Goal**: Enable managers to oversee team assessment compliance and handle escalations.

---

### Story 6.1: Team Compliance Dashboard

**As a** Team Manager  
**I want** to see my team's assessment status  
**So that** I can ensure my team is compliant and address issues

**Acceptance Criteria:**

- [ ] View all direct reports' assessment status
- [ ] See today's completion status (passed/pending/failed)
- [ ] View historical assessment scores and trends
- [ ] Receive alerts for failed assessments requiring review
- [ ] Drill down into individual team member details
- [ ] Filter by role, framework, date range
- [ ] Export team reports

**Priority**: P1 (Important)  
**Estimated Effort**: 13 story points

---

### Story 6.2: Escalation Handling

**As a** Team Manager  
**I want** to handle assessment failure escalations  
**So that** I can help team members address issues and maintain productivity

**Acceptance Criteria:**

- [ ] Receive notification when team member fails assessment
- [ ] See detailed failure information (which dimensions, scores)
- [ ] Approve or deny retry attempts
- [ ] Initiate remediation workflow
- [ ] Approve emergency bypass (with audit log)
- [ ] Schedule follow-up assessment
- [ ] Add manager notes to assessment record

**Escalation Workflow:**

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ESCALATION WORKFLOW                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  [User fails assessment]                                            │
│           │                                                         │
│           ▼                                                         │
│  ┌─────────────────┐                                               │
│  │ Notify Manager  │                                               │
│  └────────┬────────┘                                               │
│           │                                                         │
│           ▼                                                         │
│  ┌─────────────────────────────────────────────┐                   │
│  │ Manager Reviews                              │                   │
│  │ - View failure details                       │                   │
│  │ - Check user history                         │                   │
│  │ - Decide action                              │                   │
│  └────────┬────────────────────┬───────────────┘                   │
│           │                    │                                    │
│     ┌─────┴─────┐        ┌─────┴─────┐                             │
│     ▼           ▼        ▼           ▼                             │
│ [Approve   [Request   [Initiate  [Emergency                        │
│  Retry]    Training]   Meeting]   Bypass]                          │
│     │           │          │          │                             │
│     ▼           ▼          ▼          ▼                             │
│  User       HR/L&D      Calendar   Temporary                       │
│  retries    notified    invite     access                          │
│  assessment             sent       granted                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Priority**: P1 (Important)  
**Estimated Effort**: 13 story points

---

### Story 6.3: Team Performance Insights

**As a** Team Manager  
**I want** insights into team ethical performance trends  
**So that** I can identify areas for team development

**Acceptance Criteria:**

- [ ] View team average scores by dimension
- [ ] Compare team to organization benchmarks
- [ ] Identify dimension weaknesses across team
- [ ] Track improvement over time
- [ ] Receive suggestions for team training topics
- [ ] Celebrate team achievements (high scores, streaks)

**Priority**: P2 (Nice to Have)  
**Estimated Effort**: 8 story points

---

## Epic 7: User Experience and Engagement

**Epic Goal**: Make daily assessments engaging and not burdensome.

---

### Story 7.1: Adaptive Assessment Length

**As an** Enterprise User  
**I want** shorter assessments when I have a strong track record  
**So that** I can demonstrate ongoing alignment efficiently

**Acceptance Criteria:**

- [ ] Users with consistent high scores get reduced question count
- [ ] Reduction based on historical performance (e.g., 30% fewer questions)
- [ ] Random full assessments to prevent gaming (1 in 5 chance)
- [ ] New users always get full assessment initially
- [ ] After failure, return to full assessment for N sessions
- [ ] Reduction rules are transparent to users
- [ ] Compliance officer can override reduction rules

**Priority**: P2 (Nice to Have)  
**Estimated Effort**: 8 story points

---

### Story 7.2: Assessment Feedback and Learning

**As an** Enterprise User  
**I want** feedback on my assessment results  
**So that** I can understand my ethical strengths and areas for growth

**Acceptance Criteria:**

- [ ] View detailed score breakdown after assessment
- [ ] See dimension-level feedback
- [ ] Receive personalized improvement suggestions
- [ ] Track personal progress over time
- [ ] Access optional learning resources
- [ ] Celebrate achievements (streaks, improvements)
- [ ] Private reflection notes (optional)

**Priority**: P2 (Nice to Have)  
**Estimated Effort**: 8 story points

---

### Story 7.3: Gamification and Engagement

**As an** Enterprise User  
**I want** recognition for consistent ethical performance  
**So that** I feel motivated to maintain high standards

**Acceptance Criteria:**

- [ ] Streak tracking (consecutive days passed)
- [ ] Badges for achievements (e.g., "30-day streak", "Perfect Score")
- [ ] Optional team leaderboards (opt-in, privacy-first)
- [ ] Personal improvement milestones
- [ ] Integration with recognition platforms (optional)
- [ ] Gamification can be disabled at org level

**Priority**: P3 (Future)  
**Estimated Effort**: 13 story points

---

## Epic 8: Infrastructure and Platform

**Epic Goal**: Build the technical infrastructure to support enterprise-scale assessments.

---

### Story 8.1: Compsi SDK Integration

**As a** Moltbot Developer  
**I want** a clean integration with the Compsi TypeScript SDK  
**So that** assessment functionality is reliable and maintainable

**Acceptance Criteria:**

- [ ] Install and configure @aiassesstech/sdk
- [ ] Create MoltbotAssessmentClient wrapper
- [ ] Handle all SDK error types appropriately
- [ ] Implement progress callbacks for UI updates
- [ ] Support dry-run mode for testing
- [ ] Handle rate limiting gracefully
- [ ] Log all SDK interactions for debugging

**Integration Architecture:**

```typescript
// src/compsi/moltbot-assessment-client.ts

import { AIAssessClient, AssessmentResult, AssessProgress } from '@aiassesstech/sdk';

export class MoltbotAssessmentClient {
  private client: AIAssessClient;
  private userId: string;
  private organizationId: string;
  
  constructor(config: MoltbotAssessmentConfig) {
    this.client = new AIAssessClient({
      healthCheckKey: config.compsiHealthCheckKey,
    });
    this.userId = config.userId;
    this.organizationId = config.organizationId;
  }
  
  async runDailyAssessment(
    askUser: (question: string) => Promise<string>,
    onProgress?: (progress: AssessProgress) => void
  ): Promise<DailyAssessmentResult> {
    const startTime = Date.now();
    
    const result = await this.client.assess(
      async (question) => askUser(question),
      {
        onProgress,
        metadata: {
          userId: this.userId,
          organizationId: this.organizationId,
          assessmentType: 'daily',
          moltbotVersion: VERSION,
        }
      }
    );
    
    // Persist result
    await this.saveResult(result);
    
    return {
      ...result,
      userId: this.userId,
      durationMs: Date.now() - startTime,
    };
  }
  
  async checkStatus(): Promise<AssessmentStatus> {
    // Check if user has valid assessment for today
    const lastAssessment = await this.getLastAssessment();
    
    if (!lastAssessment) {
      return { status: 'pending', message: 'No assessment completed today' };
    }
    
    if (!lastAssessment.overallPassed) {
      return { status: 'failed', result: lastAssessment };
    }
    
    if (this.isExpired(lastAssessment)) {
      return { status: 'expired', message: 'Assessment expired' };
    }
    
    return { status: 'passed', result: lastAssessment };
  }
}
```

**Priority**: P0 (Critical)  
**Estimated Effort**: 13 story points

---

### Story 8.2: Organization Configuration Management

**As an** IT Administrator  
**I want** to manage all assessment configuration in one place  
**So that** I can efficiently administer the ethics program

**Acceptance Criteria:**

- [ ] Web-based admin interface
- [ ] Configure Health Check Keys per organization
- [ ] Manage frameworks, roles, and schedules
- [ ] User management (sync with SSO)
- [ ] View audit logs
- [ ] Generate reports
- [ ] API for programmatic configuration

**Priority**: P1 (Important)  
**Estimated Effort**: 21 story points

---

### Story 8.3: Multi-Tenant Data Isolation

**As an** Organization Owner  
**I want** complete data isolation between organizations  
**So that** our assessment data is private and secure

**Acceptance Criteria:**

- [ ] Each organization has isolated database partition
- [ ] No cross-organization data leakage
- [ ] Organization-specific encryption keys
- [ ] Data residency options (EU, US, etc.)
- [ ] Organization data can be exported/deleted on request
- [ ] Audit trail for data access

**Priority**: P0 (Critical)  
**Estimated Effort**: 13 story points

---

### Story 8.4: SSO/LDAP Integration

**As an** IT Administrator  
**I want** users to authenticate via our corporate SSO  
**So that** user management is streamlined and secure

**Acceptance Criteria:**

- [ ] Support SAML 2.0 SSO
- [ ] Support OAuth 2.0/OIDC
- [ ] LDAP/Active Directory sync for users and groups
- [ ] Automatic role assignment from SSO groups
- [ ] JIT (Just-In-Time) user provisioning
- [ ] SCIM support for user lifecycle management

**Priority**: P1 (Important)  
**Estimated Effort**: 13 story points

---

### Story 8.5: Offline Assessment Support

**As an** Enterprise User  
**I want** to complete assessments even with intermittent connectivity  
**So that** I'm not blocked from work due to network issues

**Acceptance Criteria:**

- [ ] Assessment questions cached locally
- [ ] Responses queued if offline
- [ ] Sync when connectivity restored
- [ ] Clear offline status indication
- [ ] Limited offline duration (e.g., max 4 hours)
- [ ] Verification occurs upon sync
- [ ] Offline assessments flagged for potential review

**Priority**: P2 (Nice to Have)  
**Estimated Effort**: 13 story points

---

## Epic 9: Remediation and Development

**Epic Goal**: Support users who fail assessments with paths to improvement.

---

### Story 9.1: Remediation Workflows

**As an** Enterprise User who failed assessment  
**I want** clear guidance on how to improve  
**So that** I can pass on retry and continue working

**Acceptance Criteria:**

- [ ] Personalized feedback based on failed dimensions
- [ ] Recommended learning resources
- [ ] Scheduled cooldown before retry (configurable)
- [ ] Limited retry attempts per day
- [ ] Escalation path if retries exhausted
- [ ] Manager notification options
- [ ] Remediation tracking

**Priority**: P1 (Important)  
**Estimated Effort**: 8 story points

---

### Story 9.2: Learning Resource Integration

**As an** Enterprise User  
**I want** access to learning resources related to my weak areas  
**So that** I can develop my ethical decision-making skills

**Acceptance Criteria:**

- [ ] Curated content library by dimension
- [ ] Integration with LMS platforms (optional)
- [ ] Self-paced learning modules
- [ ] Completion tracking
- [ ] Impact on future assessment performance tracked
- [ ] Manager visibility into learning progress

**Priority**: P2 (Nice to Have)  
**Estimated Effort**: 13 story points

---

### Story 9.3: Performance Improvement Plan (PIP) Integration

**As a** Team Manager  
**I want** to initiate a formal performance improvement plan for persistent issues  
**So that** I can help struggling team members and document the process

**Acceptance Criteria:**

- [ ] Trigger PIP workflow after N consecutive failures
- [ ] PIP template with assessment-specific goals
- [ ] Progress tracking against PIP goals
- [ ] HR notification and involvement
- [ ] Document retention for compliance
- [ ] Successful PIP completion celebration

**Priority**: P2 (Nice to Have)  
**Estimated Effort**: 8 story points

---

## Summary: User Story Count by Priority

| Priority | Story Count | Total Story Points |
|----------|-------------|-------------------|
| **P0** (Critical) | 8 | 86 |
| **P1** (Important) | 18 | 189 |
| **P2** (Nice to Have) | 10 | 113 |
| **P3** (Future) | 1 | 13 |
| **Total** | **37** | **401** |

---

## Implementation Roadmap Suggestion

### Phase 1: MVP (P0 Stories) - 86 Story Points

1. Story 1.1: Daily Check-In Assessment Flow
2. Story 1.3: Assessment Gating for AI Access
3. Story 4.1: Work Task Gating
4. Story 5.1: Immutable Assessment Audit Log
5. Story 8.1: Compsi SDK Integration
6. Story 8.3: Multi-Tenant Data Isolation

### Phase 2: Core Features (P1 Stories) - 189 Story Points

7. Story 1.2: Assessment Schedule Configuration
8. Story 1.4: Assessment Resume and Recovery
9. Story 2.1: Framework Selection and Configuration
10. Story 2.2: Multi-Framework Assessment Sequence
11. Story 3.1: Role Definition and Assignment
12. Story 3.2: Role-Based Framework Requirements
13. Story 3.3: Multi-Role User Assessment
14. Story 4.2: Limited Mode for Failed/Pending Assessments
15. Story 4.3: Context-Aware Task Assistance
16. Story 5.2: Compliance Dashboard
17. Story 6.1: Team Compliance Dashboard
18. Story 6.2: Escalation Handling
19. Story 8.2: Organization Configuration Management
20. Story 8.4: SSO/LDAP Integration
21. Story 9.1: Remediation Workflows

### Phase 3: Enhanced Features (P2 Stories) - 113 Story Points

22. Story 2.3: Custom Framework Builder
23. Story 5.3: Regulatory Reporting
24. Story 5.4: External Auditor Access
25. Story 6.3: Team Performance Insights
26. Story 7.1: Adaptive Assessment Length
27. Story 7.2: Assessment Feedback and Learning
28. Story 8.5: Offline Assessment Support
29. Story 9.2: Learning Resource Integration
30. Story 9.3: Performance Improvement Plan Integration

### Phase 4: Future Enhancements (P3 Stories) - 13 Story Points

31. Story 7.3: Gamification and Engagement

---

## Dependencies

### External Dependencies

1. **Compsi (AI Assess Tech) SDK** - @aiassesstech/sdk
2. **Compsi Health Check Key** - Per-organization configuration
3. **SSO Provider** - For enterprise authentication
4. **Database** - For assessment persistence

### Internal Dependencies

```
Epic 1 (Daily Assessment) 
    └── depends on: Epic 8 (Infrastructure)
    
Epic 2 (Multi-Framework)
    └── depends on: Epic 1 (Daily Assessment)
    
Epic 3 (Role-Based)
    └── depends on: Epic 1 (Daily Assessment)
    └── depends on: Epic 8 (SSO Integration)
    
Epic 4 (Work Enablement)
    └── depends on: Epic 1 (Daily Assessment)
    └── depends on: Epic 3 (Role-Based)
    
Epic 5 (Compliance)
    └── depends on: Epic 1 (Daily Assessment)
    └── depends on: Epic 3 (Role-Based)
    
Epic 6 (Manager Oversight)
    └── depends on: Epic 5 (Compliance Dashboard)
    └── depends on: Epic 3 (Role-Based)
    
Epic 7 (User Experience)
    └── depends on: Epic 1 (Daily Assessment)
    
Epic 9 (Remediation)
    └── depends on: Epic 6 (Escalation)
```

---

## Next Steps

1. Review and prioritize user stories with stakeholders
2. Create SPEC-DECISION for Compsi integration architecture
3. Create SPEC-INTEGRATION for technical implementation
4. Create GUIDE for implementation

---

**Document Status**: Draft  
**Ready for Review**: Yes
