# Cursor Rules System - Complete Guide

**Purpose:** Understand and effectively use the Cursor rules system  
**Audience:** Developers + AI Assistants  
**Status:** ✅ ACTIVE

---

## 📋 Table of Contents

1. [What Are Cursor Rules?](#what-are-cursor-rules)
2. [Rule Priority System](#rule-priority-system)
3. [Rule Categories](#rule-categories)
4. [How to Use Rules](#how-to-use-rules)
5. [Rule Application Patterns](#rule-application-patterns)
6. [Creating New Rules](#creating-new-rules)
7. [Rule Discovery](#rule-discovery)

---

## What Are Cursor Rules?

### Definition

**Cursor Rules** are `.mdc` files that define how Cursor AI should behave when assisting with code development.

**Key Characteristics:**
- ✅ Machine-readable (Cursor AI parses them automatically)
- ✅ Structured format (description, context, requirements, examples)
- ✅ Domain-specific (security, testing, architecture, etc.)
- ✅ Priority-based (P0 = required, P1 = important, P2 = nice-to-have)

### Rules vs Documentation

| Aspect | Cursor Rules | Documentation |
|--------|-------------|---------------|
| **Location** | `.cursor/rules/` | `docs/`, `guides/` |
| **Format** | `.mdc` | `.md` |
| **Audience** | Cursor AI | Humans |
| **Purpose** | Define AI behavior | Explain architecture |
| **Usage** | Auto-loaded by Cursor | Manually read |

### Example Rule Structure

```mdc
---
description: ACTION when TRIGGER to OUTCOME
globs: "**/*.ts"
---

# Rule Title

## Context
- When to apply this rule
- Prerequisites

## Requirements
- Specific, testable requirements
- Clear do's and don'ts

## Examples
<example>
Good example with explanation
</example>

<example type="invalid">
Bad example with explanation
</example>
```

---

## Rule Priority System

### Three Priority Levels

#### **P0 - Required** 🔴
**Definition:** MUST be followed for all code changes

**Characteristics:**
- No exceptions without explicit team approval
- Violations block merges
- Critical for security, correctness, stability

**Examples:**
- `010-security-compliance.mdc`
- `012-api-security.mdc`
- `105-typescript-linter-standards.mdc`
- `375-api-test-first-time-right.mdc`

**When to Apply:** ALWAYS

#### **P1 - Important** 🟡
**Definition:** SHOULD be followed for most code changes

**Characteristics:**
- Temporary exceptions allowed with TODO comments
- Apply within 2 weeks of initial implementation
- Important for maintainability, consistency

**Examples:**
- `030-visual-design-system.mdc`
- `042-ui-component-architecture.mdc`
- `370-api-testing-database.mdc`

**When to Apply:** Most features

#### **P2 - Nice to Have** 🟢
**Definition:** Good practices to follow when possible

**Characteristics:**
- Apply when time allows
- Should be considered for mature/stable features
- Enhances quality but not blocking

**Examples:**
- `045-ux-enhancements.mdc`
- `062-optimization.mdc`

**When to Apply:** Refinement phase

### How to Identify Priority

**Look in the rules registry:**
```bash
cat .cursor/rules/000-cursor-rules-registry2.mdc
```

**Look for markings in rule files:**
- Some rules have "P0", "P1", "P2" in their description
- Registry categorizes by priority

---

## Rule Categories

### By Domain

Our 152 rules are organized into these categories:

#### **1. Core Standards (0XX)**
- `000-core-guidelines.mdc`
- `001-cursor-rules.mdc`
- `002-rule-application.mdc` ⭐ START HERE

#### **2. Security (01X-02X)**
- `010-security-compliance.mdc`
- `011-env-var-security.mdc`
- `012-api-security.mdc`
- `020-payment-security.mdc`

#### **3. UI/UX (03X-05X)**
- `030-visual-design-system.mdc`
- `042-ui-component-architecture.mdc`
- `054-accessibility-requirements.mdc`

#### **4. Database & API (06X-08X)**
- `060-api-standards.mdc`
- `065-database-access-patterns.mdc`
- `080-cross-service-data-consistency.mdc`

#### **5. Framework-Specific (07X)**
- `070-nextjs-architecture.mdc`
- `070-nextjs-api-organization.mdc`

#### **6. Development Practices (10X-15X)**
- `100-coding-patterns.mdc`
- `105-typescript-linter-standards.mdc` ⭐ CRITICAL
- `150-technical-debt-prevention.mdc`

#### **7. Infrastructure (20X)**
- `200-deployment-infrastructure.mdc`
- `201-vercel-deployment-standards.mdc`
- `220-security-monitoring.mdc`

#### **8. Testing (30X-39X)**
- `300-testing-standards.mdc`
- `350-debug-test-failures.mdc`
- `370-api-testing-database.mdc`
- `375-api-test-first-time-right.mdc` ⭐ NEW
- `376-database-test-isolation.mdc` ⭐ NEW
- `380-comprehensive-testing-standards.mdc`

#### **9. Workflows (80X)**
- `800-workflow-guidelines.mdc`
- `801-implementation-plan.mdc`

---

## How to Use Rules

### For Human Developers

#### 1. **Reference Rules Explicitly in Conversations**

```
✅ GOOD:
"Let's implement this API test following @375-api-test-first-time-right.mdc"

❌ BAD:
"Let's write an API test" (AI might not know which patterns to use)
```

#### 2. **Check Rules Before Starting Work**

```bash
# Find relevant rules for your task
cat .cursor/rules/000-cursor-rules-registry2.mdc | grep -i "testing"
cat .cursor/rules/000-cursor-rules-registry2.mdc | grep -i "api"
```

#### 3. **Combine Rules for Complex Tasks**

Example: Building an API endpoint with tests
```
@060-api-standards.mdc
+ @012-api-security.mdc
+ @375-api-test-first-time-right.mdc
+ @025-multi-tenancy.mdc
```

#### 4. **Update Rules When You Learn**

If you discover a new pattern or best practice:
```bash
# Follow template
cat .cursor/rules/001-cursor-rules.mdc
```

### For AI Assistants (Cursor, Claude, etc.)

#### 1. **Load Relevant Rules Automatically**

When user mentions a task, check:
- `.cursor/rules/002-rule-application.mdc` - Priority system
- Rules matching the domain (API, testing, security, etc.)

#### 2. **Apply Priority System**

```
P0 rules → Apply ALWAYS (no exceptions)
P1 rules → Apply for most features (suggest when appropriate)
P2 rules → Mention when time permits (optional refinements)
```

#### 3. **Reference Rules in Responses**

```
✅ GOOD:
"Following Rule 375 (API Test First Time Right), let's start by inspecting the schema..."

❌ BAD:
"Let's write a test" (no context on which patterns to use)
```

#### 4. **Suggest Tool Usage**

```
When user asks about schema:
→ "Let's use .cursor/tools/inspect-model.sh to see exact field names"

When user is about to commit:
→ "Run .cursor/tools/check-schema-changes.sh to validate"
```

---

## Rule Application Patterns

### Pattern 1: Feature Planning

**Before starting ANY feature:**

1. **Review Rule 002** (Rule Application Framework)
2. **Identify applicable rules** by domain
3. **List P0 rules** (must apply)
4. **List P1 rules** (should apply)
5. **Note P2 rules** (nice to have)

**Example: Building User Authentication**
```markdown
### P0 (Required)
- 010: Security Compliance
- 014: Third-party Auth
- 046: Session Validation

### P1 (Important)
- 047: Security Design System
- 131: Error Handling

### P2 (Nice to Have)
- 045: UX Enhancements
```

### Pattern 2: API Endpoint Development

**Standard combination:**
```
1. @060-api-standards.mdc (organization-scoped data)
2. @012-api-security.mdc (authentication, validation)
3. @025-multi-tenancy.mdc (tenant isolation)
4. @375-api-test-first-time-right.mdc (testing)
```

### Pattern 3: Database Work

**Standard combination:**
```
1. @002-rule-application.mdc (Source of Truth Hierarchy)
2. @065-database-access-patterns.mdc (query patterns)
3. @376-database-test-isolation.mdc (test cleanup)
4. @060-api-standards.mdc (organization scoping)
```

### Pattern 4: UI Component Development

**Standard combination:**
```
1. @030-visual-design-system.mdc (design system)
2. @042-ui-component-architecture.mdc (structure)
3. @054-accessibility-requirements.mdc (a11y)
4. @055-button-transparency-prevention.mdc (visual quality)
```

---

## Creating New Rules

### When to Create a New Rule

✅ **Create a rule when:**
- Pattern is used 3+ times
- Pattern prevents significant bugs
- Pattern saves significant time
- Pattern enforces critical standards

❌ **Don't create a rule when:**
- One-off situation
- Already covered by existing rule
- Too specific to be reusable
- Universal guide would be better

### Rule Creation Process

#### Step 1: Use Template

```bash
cat .cursor/rules/001-cursor-rules.mdc
```

#### Step 2: Choose Naming Convention

```
PREFIX-descriptive-name.mdc

Prefixes:
0XX: Core standards
1XX: Tool configs, language rules
2XX: Framework rules
3XX: Testing standards
8XX: Workflows
9XX: Templates
```

#### Step 3: Write Clear Requirements

```mdc
## Requirements

### Requirement Name

Description of what must be done.

```typescript
// ✅ CORRECT: Example of good implementation
const example = "good";
```

```typescript
// ❌ WRONG: Example of bad implementation
const example = "bad";
```

**Why:** Explanation of why this matters.
```

#### Step 4: Add to Registry

Update `.cursor/rules/000-cursor-rules-registry2.mdc` with your new rule.

#### Step 5: Document Priority

Mark as P0, P1, or P2 in the registry.

---

## Rule Discovery

### Finding Rules by Topic

```bash
# Search by keyword
grep -r "authentication" .cursor/rules/*.mdc
grep -r "testing" .cursor/rules/*.mdc
grep -r "database" .cursor/rules/*.mdc

# List all rules
ls .cursor/rules/*.mdc

# View registry
cat .cursor/rules/000-cursor-rules-registry2.mdc
```

### Most Referenced Rules

Based on usage frequency:

1. **002-rule-application.mdc** - Rule priority system
2. **105-typescript-linter-standards.mdc** - TypeScript standards
3. **375-api-test-first-time-right.mdc** - API testing
4. **376-database-test-isolation.mdc** - Database testing
5. **012-api-security.mdc** - API security
6. **025-multi-tenancy.mdc** - Multi-tenant patterns

### Rules by Use Case

**"I'm writing an API endpoint"**
→ 060, 012, 025, 375

**"I'm writing a test"**
→ 300, 375, 376, 380

**"I'm working with the database"**
→ 065, 066, 376, 002

**"I'm building a UI component"**
→ 030, 042, 054, 055

**"I'm deploying to production"**
→ 200, 201, 220

---

## Success Metrics

Since implementing the rules system:

| Metric | Before | After | Impact |
|--------|--------|-------|--------|
| **Code consistency** | Variable | High | Predictable patterns |
| **AI effectiveness** | Good | Excellent | AI follows standards |
| **Onboarding time** | 2-3 days | 1 day | 50% faster |
| **Bug prevention** | Reactive | Proactive | Rules catch issues early |

---

## Quick Reference

### Essential Rules to Know

**Everyone:**
- 002: Rule Application Framework
- 105: TypeScript Linter Standards
- 150: Technical Debt Prevention

**API Developers:**
- 060: API Standards
- 012: API Security
- 375: API Test First Time Right

**Database Work:**
- 002: Source of Truth Hierarchy
- 065: Database Access Patterns
- 376: Database Test Isolation

**UI Developers:**
- 030: Visual Design System
- 042: UI Component Architecture
- 054: Accessibility Requirements

---

**Document Version:** 1.0  
**Last Updated:** November 19, 2025  
**Maintainer:** Development Team

