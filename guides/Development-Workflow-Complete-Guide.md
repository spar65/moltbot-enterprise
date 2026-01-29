# Development Workflow: Complete Guide to Build-Test-Verify

**Purpose**: A comprehensive guide for daily development workflow with continuous testing and builds  
**Target Audience**: All developers (frontend, backend, full-stack)  
**Core Principle**: Build → Test → Verify → Commit  
**Related Rule**: @805-build-test-verify-workflow.mdc

---

## Table of Contents

1. [Overview](#overview)
2. [The Build-Test-Verify Cycle](#the-build-test-verify-cycle)
3. [Daily Development Workflow](#daily-development-workflow)
4. [Feature Implementation Workflow](#feature-implementation-workflow)
5. [Bug Fix Workflow](#bug-fix-workflow)
6. [Refactoring Workflow](#refactoring-workflow)
7. [Quality Gates](#quality-gates)
8. [Common Scenarios](#common-scenarios)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

---

## Overview

### Why This Workflow Matters

**The Problem:**
- Issues discovered late in development
- Build failures at deployment time
- Accumulated technical debt
- Low confidence in commits
- Stressful debugging sessions

**The Solution:**
- **Continuous verification** catches issues immediately
- **Build-test cycles** prevent integration surprises
- **Quality gates** ensure code quality
- **Confidence** in every commit

### Success Metrics

After adopting this workflow, expect:
- ✅ **95%+ first-time-right tests** (up from ~40%)
- ✅ **Zero build surprises** at deployment
- ✅ **50% less debugging time** (catch issues early)
- ✅ **100% commit confidence** (verified before commit)

---

## The Build-Test-Verify Cycle

### Core Workflow (MANDATORY for ALL changes)

```
┌─────────────────────────────────────────┐
│  1. WRITE TEST FIRST                    │
│     └─ Design validated before coding   │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  2. BUILD                                │
│     └─ npm run build                     │
│     └─ Verify test compiles             │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  3. IMPLEMENT                            │
│     └─ Write minimal code to pass test  │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  4. BUILD AGAIN                          │
│     └─ npm run build                     │
│     └─ Catch TypeScript/import errors   │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  5. RUN TESTS                            │
│     └─ npm run test -- [test-file]      │
│     └─ Verify tests pass                │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  6. VERIFY MANUALLY                      │
│     └─ npm run dev                       │
│     └─ Test in browser/environment      │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  7. FINAL QUALITY GATES                  │
│     ✅ All tests passing                 │
│     ✅ Build succeeds                    │
│     ✅ No TypeScript errors              │
│     ✅ No linting errors                 │
│     ✅ Manually verified                 │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  8. COMMIT WITH CONFIDENCE               │
│     └─ git commit                        │
└─────────────────────────────────────────┘
```

---

## Daily Development Workflow

### Morning Startup

```bash
# 1. Update your local repository
git checkout main
git pull origin main

# 2. Clean install (if dependencies changed)
npm install

# 3. Verify baseline (everything should pass)
npm run build
npm test

# 4. Create feature branch
git checkout -b feature/your-feature-name

# 5. Start dev server
npm run dev

# ✅ Ready to start coding with clean baseline
```

### During Development

For **EVERY** change you make:

```bash
# After making a change:
npm run build           # Verify it builds
npm run test -- [file]  # Verify tests pass
npm run dev            # Verify it works

# ✅ All good? Continue to next change
```

### End of Day

```bash
# 1. Run full test suite
npm test

# 2. Final build
npm run build

# 3. Commit your work
git add .
git commit -m "feat: implemented X, Y, Z features

- All tests passing
- Build verified
- Manually tested"

# 4. Push to remote
git push origin feature/your-feature-name

# ✅ Clean slate for tomorrow
```

---

## Feature Implementation Workflow

### Example: Adding a Dashboard Component

#### Step 1: Write Test FIRST

```typescript
// File: __tests__/unit/ui/dashboard-stats.test.tsx
import { render, screen } from '@testing-library/react';
import { DashboardStats } from '@/components/dashboard/DashboardStats';

describe('DashboardStats', () => {
  const mockStats = {
    totalTests: 45,
    averageScore: 7.8,
    recentActivity: 12,
    trend: 'up' as const,
  };

  it('renders all 4 stat cards', () => {
    const { container } = render(<DashboardStats stats={mockStats} />);
    const cards = container.querySelectorAll('[class*="card"]');
    expect(cards.length).toBe(4);
  });

  it('displays total tests count', () => {
    render(<DashboardStats stats={mockStats} />);
    expect(screen.getByText('45')).toBeInTheDocument();
    expect(screen.getByText(/total tests/i)).toBeInTheDocument();
  });

  it('formats large numbers correctly', () => {
    const largeStats = { ...mockStats, totalTests: 1234 };
    render(<DashboardStats stats={largeStats} />);
    expect(screen.getByText('1,234')).toBeInTheDocument();
  });
});
```

**Checkpoint 1: Verify test compiles**
```bash
npm run build

# ✅ Build should succeed (test file is valid TypeScript)
# ❌ If fails: Fix TypeScript errors in test file
```

---

#### Step 2: Implement Component

```typescript
// File: components/dashboard/DashboardStats.tsx
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

interface DashboardStatsProps {
  stats: {
    totalTests: number;
    averageScore: number;
    recentActivity: number;
    trend: 'up' | 'down' | 'stable';
  };
}

export function DashboardStats({ stats }: DashboardStatsProps) {
  const formatNumber = (num: number) => num.toLocaleString();

  return (
    <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
      <Card>
        <CardHeader>
          <CardTitle>Total Tests</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-3xl font-bold">{formatNumber(stats.totalTests)}</div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Average Score</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-3xl font-bold">{stats.averageScore.toFixed(1)}</div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Tests This Week</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-3xl font-bold">{stats.recentActivity}</div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Trend</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-3xl font-bold capitalize">{stats.trend}</div>
        </CardContent>
      </Card>
    </div>
  );
}
```

**Checkpoint 2: Build with implementation**
```bash
npm run build

# ✅ Build should succeed
# ❌ If fails: Fix TypeScript/import errors immediately
```

---

#### Step 3: Run Tests

```bash
npm run test:unit -- dashboard-stats.test.tsx

# Expected output:
# PASS  __tests__/unit/ui/dashboard-stats.test.tsx
#   DashboardStats
#     ✓ renders all 4 stat cards (45 ms)
#     ✓ displays total tests count (12 ms)
#     ✓ formats large numbers correctly (8 ms)
#
# Test Suites: 1 passed, 1 total
# Tests:       3 passed, 3 total
```

**If tests fail:**
```bash
# 1. Read the error message carefully
# 2. Fix the issue
# 3. Re-build
npm run build

# 4. Re-run tests
npm run test:unit -- dashboard-stats.test.tsx

# 5. Repeat until passing
```

---

#### Step 4: Manual Verification

```bash
# Start dev server (if not already running)
npm run dev

# Open browser to http://localhost:3000/dashboard
# Verify:
# - Component renders correctly
# - Numbers are formatted properly
# - Responsive layout works
# - No console errors
```

---

#### Step 5: Final Quality Gates

```bash
# Run all quality checks
npm run build           # ✅ Build succeeds
npm test               # ✅ All tests pass
npm run type-check     # ✅ No TypeScript errors
npm run lint           # ✅ No linting errors

# ✅ All green? Ready to commit!
```

---

#### Step 6: Commit

```bash
git add components/dashboard/DashboardStats.tsx
git add __tests__/unit/ui/dashboard-stats.test.tsx

git commit -m "feat(dashboard): add DashboardStats component

- Displays 4 stat cards (total tests, avg score, activity, trend)
- Responsive grid layout (1 col mobile, 4 cols desktop)
- Number formatting with toLocaleString
- Fully tested with React Testing Library
- 3/3 tests passing
- Build verified, no TypeScript errors"

# ✅ Clean, confident commit!
```

---

## Bug Fix Workflow

### Example: Fixing Null Value Handling

#### Step 1: Write Failing Test (Proves Bug Exists)

```typescript
// Add to __tests__/unit/ui/dashboard-stats.test.tsx
it('handles null values gracefully', () => {
  const statsWithNulls = {
    totalTests: null,
    averageScore: null,
    recentActivity: null,
    trend: 'stable' as const,
  };
  
  render(<DashboardStats stats={statsWithNulls} />);
  
  // Should show placeholder, not crash
  expect(screen.getByText('—')).toBeInTheDocument();
  expect(screen.queryByText('null')).not.toBeInTheDocument();
});
```

#### Step 2: Run Test (Should Fail)

```bash
npm run test:unit -- dashboard-stats.test.tsx

# Expected: Test FAILS (proves bug exists)
# FAIL  __tests__/unit/ui/dashboard-stats.test.tsx
#   DashboardStats
#     ✗ handles null values gracefully (28 ms)
#
# Error: Unable to find element with text: —
```

#### Step 3: Fix Bug

```typescript
// Update components/dashboard/DashboardStats.tsx
export function DashboardStats({ stats }: DashboardStatsProps) {
  const formatNumber = (num: number | null) => {
    if (num === null || num === undefined) return '—';
    return num.toLocaleString();
  };

  const formatScore = (score: number | null) => {
    if (score === null || score === undefined) return '—';
    return score.toFixed(1);
  };

  return (
    <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
      <Card>
        <CardHeader>
          <CardTitle>Total Tests</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-3xl font-bold">{formatNumber(stats.totalTests)}</div>
        </CardContent>
      </Card>
      {/* ... other cards with null handling ... */}
    </div>
  );
}
```

#### Step 4: Build & Test

```bash
# Build to verify no TypeScript errors
npm run build

# Run tests (should pass now)
npm run test:unit -- dashboard-stats.test.tsx

# Expected:
# PASS  __tests__/unit/ui/dashboard-stats.test.tsx
#   DashboardStats
#     ✓ handles null values gracefully (15 ms)
#
# ✅ Bug fixed!
```

#### Step 5: Manual Verification

```bash
# Test in dev mode with null data
npm run dev

# Manually verify:
# - Null values show "—"
# - No console errors
# - Layout doesn't break
```

#### Step 6: Commit Fix

```bash
git add components/dashboard/DashboardStats.tsx
git add __tests__/unit/ui/dashboard-stats.test.tsx

git commit -m "fix(dashboard): handle null stats values gracefully

- Show '—' placeholder for null values
- Update formatNumber and formatScore helpers
- Add test for null value handling
- Verified in dev mode with null data
- All tests passing (4/4)"
```

---

## Refactoring Workflow

### Example: Extract Shared Component

#### Step 1: Run Existing Tests (Baseline)

```bash
npm run test:unit -- dashboard

# Expected: All tests pass BEFORE refactoring
# PASS  __tests__/unit/ui/dashboard-stats.test.tsx (4 tests)
# ✅ Baseline established
```

#### Step 2: Refactor (Extract StatCard)

```typescript
// New file: components/ui/StatCard.tsx
interface StatCardProps {
  title: string;
  value: string | number;
  trend?: 'up' | 'down' | 'stable';
}

export function StatCard({ title, value, trend }: StatCardProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="text-3xl font-bold">{value}</div>
        {trend && <div className="text-sm text-muted-foreground">{trend}</div>}
      </CardContent>
    </Card>
  );
}
```

**Build after creating new component:**
```bash
npm run build
# ✅ New component compiles
```

#### Step 3: Update DashboardStats to Use StatCard

```typescript
// Update components/dashboard/DashboardStats.tsx
import { StatCard } from '@/components/ui/StatCard';

export function DashboardStats({ stats }: DashboardStatsProps) {
  const formatNumber = (num: number | null) => {
    if (num === null || num === undefined) return '—';
    return num.toLocaleString();
  };

  return (
    <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
      <StatCard title="Total Tests" value={formatNumber(stats.totalTests)} />
      <StatCard title="Average Score" value={formatScore(stats.averageScore)} />
      <StatCard title="Tests This Week" value={formatNumber(stats.recentActivity)} />
      <StatCard title="Trend" value={stats.trend} trend={stats.trend} />
    </div>
  );
}
```

**Build after refactoring:**
```bash
npm run build
# ✅ Refactored code compiles
```

#### Step 4: Run Tests (Should Still Pass)

```bash
npm run test:unit -- dashboard-stats.test.tsx

# Expected: Same tests pass as before
# PASS  __tests__/unit/ui/dashboard-stats.test.tsx (4 tests)
# ✅ No regressions!
```

#### Step 5: Verify Manually

```bash
npm run dev

# Verify dashboard looks exactly the same
# - Layout unchanged
# - Functionality identical
# - No visual regressions
```

#### Step 6: Commit Refactoring

```bash
git add components/ui/StatCard.tsx
git add components/dashboard/DashboardStats.tsx

git commit -m "refactor(dashboard): extract StatCard to shared component

- Create reusable StatCard component in components/ui/
- Update DashboardStats to use StatCard
- No behavior changes
- All tests passing (4/4)
- Build verified
- Manually tested (no visual changes)"
```

---

## Quality Gates

### Gate 1: After Writing Test

```bash
✅ CHECKLIST:
- [ ] Test file compiles (npm run build)
- [ ] Test imports are correct
- [ ] Mock data is properly typed
- [ ] Test assertions are clear
```

### Gate 2: After Implementation

```bash
✅ CHECKLIST:
- [ ] npm run build succeeds
- [ ] No TypeScript errors
- [ ] No linting errors  
- [ ] Component renders in dev mode
- [ ] No console errors
```

### Gate 3: After Testing

```bash
✅ CHECKLIST:
- [ ] All new tests passing
- [ ] No existing tests broken
- [ ] Coverage meets threshold
- [ ] Edge cases tested
```

### Gate 4: Before Commit

```bash
✅ FULL QUALITY CHECK:
npm run build           # ✅ Build succeeds
npm test               # ✅ All tests pass
npm run type-check     # ✅ No TypeScript errors
npm run lint           # ✅ No linting errors
npm run dev            # ✅ Manual verification

# ✅ ALL GREEN? COMMIT!
```

---

## Common Scenarios

### Scenario 1: "My test passes but build fails"

```bash
# Symptom:
npm run test -- mytest.test.tsx  # ✅ PASS
npm run build                    # ❌ FAIL

# Cause: Test mocks hide TypeScript errors

# Solution:
# 1. Read build error carefully
# 2. Fix TypeScript error in component
# 3. Re-build
npm run build  # ✅ Should pass now

# 4. Re-run test
npm run test -- mytest.test.tsx  # ✅ Still passes
```

### Scenario 2: "Build passes but tests fail"

```bash
# Symptom:
npm run build                    # ✅ PASS
npm run test -- mytest.test.tsx  # ❌ FAIL

# Cause: Test expectations don't match implementation

# Solution:
# 1. Read test failure carefully
# 2. Either:
#    a) Fix component to match test expectations, OR
#    b) Update test to match component behavior
# 3. Re-build and re-test
npm run build && npm run test -- mytest.test.tsx  # ✅ Both pass
```

### Scenario 3: "Tests pass but it doesn't work in browser"

```bash
# Symptom:
npm run build  # ✅ PASS
npm run test   # ✅ PASS
# But browser shows errors!

# Cause: Tests don't cover all scenarios, or runtime issue

# Solution:
# 1. Add test for failing scenario
npm run test  # ❌ Test fails (reproduces browser issue)

# 2. Fix component
npm run build

# 3. Re-run test
npm run test  # ✅ Test passes

# 4. Verify in browser
npm run dev  # ✅ Works now
```

---

## Best Practices

### 1. Build Early, Build Often

```bash
# ❌ DON'T: Build once at end of day
# Write 10 components... then
npm run build  # ❌ 50 errors to fix

# ✅ DO: Build after each component
# Write 1 component
npm run build  # ✅ Fix 3-5 errors immediately
# Write next component
npm run build  # ✅ Fix immediately
```

### 2. Test Immediately

```bash
# ❌ DON'T: Write all code then test
# Implement feature A, B, C... then
npm run test  # ❌ 15 failing tests

# ✅ DO: Test after each feature
# Implement feature A
npm run test -- featureA  # ✅ Fix immediately
# Implement feature B
npm run test -- featureB  # ✅ Fix immediately
```

### 3. Commit Clean Code

```bash
# ❌ DON'T: Commit failing tests
git commit  # Has failing tests, build errors

# ✅ DO: Verify before commit
npm run build && npm test  # ✅ All pass
git commit  # ✅ Clean commit
```

### 4. Fix Issues Fresh

```bash
# ❌ DON'T: Accumulate issues
# Day 1: Skip failing test
# Day 2: Skip another
# Day 3: Debug 10 issues ❌

# ✅ DO: Fix immediately
# Failing test? Fix now (5 min)
# Build error? Fix now (2 min)
# ✅ Always clean slate
```

---

## Integration with Project Planning

### When Creating Implementation Plans

**ALWAYS include Build-Test-Verify checkpoints:**

```markdown
### Day 1: Dashboard Implementation

**Morning (4 hours):**
1. Write DashboardStats tests
   └─ Build checkpoint ✅
2. Implement DashboardStats
   └─ Build + test checkpoint ✅
3. Manual verification
   └─ Dev mode checkpoint ✅

**Afternoon (4 hours):**
1. Write RecentTests tests
   └─ Build checkpoint ✅
2. Implement RecentTests
   └─ Build + test checkpoint ✅
3. Integration testing
   └─ Full quality gate ✅

**End of Day:**
- All builds passing ✅
- All tests passing ✅
- Features manually verified ✅
- Clean commit ✅
```

### When Creating Technical Specifications

**Include testing and build requirements:**

```markdown
## Dashboard Component Specification

### Implementation Requirements:
1. Write tests FIRST
2. Run `npm run build` before implementation
3. Implement component
4. Run `npm run build && npm run test`
5. Manual verification in dev mode
6. Commit only after all quality gates pass

### Quality Gates:
- Unit test coverage > 90%
- Build succeeds
- No TypeScript errors
- No linting errors
- Manual verification complete
```

---

## Troubleshooting

### Build Errors

**Error: "Cannot find module"**
```bash
# Fix: Check import paths and tsconfig
cat tsconfig.json | grep paths
# Verify import matches alias configuration
```

**Error: "Property does not exist on type"**
```bash
# Fix: Check TypeScript interfaces
npm run type-check
# Fix type errors one by one
```

### Test Failures

**Error: "Cannot find element"**
```bash
# Debug: Check what's actually rendered
screen.debug()  # Add to test
# Fix: Update selector or component
```

**Error: "Test timeout"**
```bash
# Fix: Increase timeout or fix async code
jest.setTimeout(10000);
```

---

## Summary

### Core Workflow

```
Write Test → Build → Implement → Build → Test → Verify → Commit
```

### Quality Gates

```
✅ Tests pass
✅ Build succeeds
✅ Types valid
✅ Lint clean
✅ Manually verified
```

### Expected Outcomes

- ✅ 95%+ tests pass on first run
- ✅ Zero build surprises
- ✅ 50% less debugging
- ✅ 100% commit confidence

---

**Related Resources:**
- **Rule**: @805-build-test-verify-workflow.mdc
- **Testing**: @380-comprehensive-testing-standards.mdc
- **CI/CD**: @203-ci-cd-pipeline-standards.mdc
- **Code Quality**: @105-typescript-linter-standards.mdc
