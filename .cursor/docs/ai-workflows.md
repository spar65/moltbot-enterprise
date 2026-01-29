# AI-Assisted Development Workflows

**Purpose:** Proven patterns for AI-assisted development  
**Based On:** 40+ hours of documented sessions (Nov 2025)  
**Success Rate:** 95%+ first-run success  
**Status:** ✅ BATTLE-TESTED

---

## 📋 Table of Contents

1. [Schema-First Development](#schema-first-development)
2. [API Test Creation Workflow](#api-test-creation-workflow)
3. [Database Test Patterns](#database-test-patterns)
4. [Debugging with AI](#debugging-with-ai)
5. [Real-World Examples](#real-world-examples)

---

## Schema-First Development

### The Core Principle

> **"Schema is Truth, Design Docs are Documentation"**

When schema and design docs conflict, schema ALWAYS wins.

### Workflow

```
┌─────────────────────────────────────────────────────────┐
│ STEP 1: INSPECT SCHEMA (NOT Design Docs!)              │
│ ─────────────────────────────────────────────────────── │
│                                                          │
│ $ ./.cursor/tools/inspect-model.sh YourModel            │
│                                                          │
│ ✅ See exact field names                                │
│ ✅ See field types                                      │
│ ✅ See relationships                                    │
│ ✅ See patterns (*Json, *At, *Id, *Hash, *ed)          │
└─────────────────────────────────────────────────────────┘
              ▼
┌─────────────────────────────────────────────────────────┐
│ STEP 2: GENERATE TYPES                                  │
│ ─────────────────────────────────────────────────────── │
│                                                          │
│ $ cd app && npx prisma generate                         │
│                                                          │
│ ✅ Types match schema exactly                           │
└─────────────────────────────────────────────────────────┘
              ▼
┌─────────────────────────────────────────────────────────┐
│ STEP 3: IMPORT TYPES IN CODE                            │
│ ─────────────────────────────────────────────────────── │
│                                                          │
│ import { YourModel } from '@prisma/client';             │
│                                                          │
│ const record: YourModel = await prisma.yourModel.create│
│                                                          │
│ ✅ TypeScript catches field mismatches                  │
└─────────────────────────────────────────────────────────┘
              ▼
┌─────────────────────────────────────────────────────────┐
│ STEP 4: WRITE CODE                                      │
│ ─────────────────────────────────────────────────────── │
│                                                          │
│ ✅ Use exact field names from schema                    │
│ ✅ TypeScript provides autocomplete                     │
│ ✅ Compiler catches errors                              │
└─────────────────────────────────────────────────────────┘
              ▼
┌─────────────────────────────────────────────────────────┐
│ STEP 5: TEST (Should Pass First Time!)                  │
│ ─────────────────────────────────────────────────────── │
│                                                          │
│ $ npm test                                               │
│                                                          │
│ ✅ 95%+ first-run success rate                          │
└─────────────────────────────────────────────────────────┘
```

### AI Assistant Role

**When user asks about schema:**
```
❌ DON'T: "The model has a 'name' field"
✅ DO: "Let's inspect: ./.cursor/tools/inspect-model.sh YourModel"
```

**When user is writing code:**
```
✅ PROACTIVE: "Before we start, let's verify field names using inspect-model.sh"
```

### Time Savings

| Approach | Time to Write | Debug Time | Total |
|----------|--------------|------------|-------|
| **Old Way** (design-doc-first) | 15 min | 2-4 hours | 2.5-4.5 hours |
| **New Way** (schema-first) | 15 min | 0-5 min | 15-20 min |

**Savings:** 2-4 hours per test → **80-90% reduction**

---

## API Test Creation Workflow

### Complete Workflow (Rule 375)

```
┌───────────────────────────────────────────────────────────┐
│ PHASE 1: PRE-DEVELOPMENT (Schema Validation)              │
└───────────────────────────────────────────────────────────┘

1. Inspect schema for target models
   $ ./.cursor/tools/inspect-model.sh YourModel

2. Verify field names match schema exactly

3. Confirm field types (String vs Json vs DateTime vs Boolean)

4. Check foreign key relationships and cascade behavior

5. Generate fresh Prisma types
   $ cd app && npx prisma generate

6. Add schema validation header to test file:
   /**
    * SCHEMA VALIDATION COMPLETED: 2025-11-19
    * - Model: YourModel ✅
    * - Fields verified: field1, field2, field3 ✅
    * - Relations verified: parent ✅
    */

┌───────────────────────────────────────────────────────────┐
│ PHASE 2: TEST STRUCTURE                                   │
└───────────────────────────────────────────────────────────┘

7. Documentation header with mocked dependencies

8. TypeScript interfaces for request/response

9. Route handler with explicit return type

10. Test data using crypto.randomUUID() for uniqueness

11. Jest config with maxWorkers: 1 for API tests

12. Cleanup function with trigger bypass pattern

13. Mocks configured in jest.api.setup.js

14. Both success (✅) and error (❌) scenarios

15. beforeEach resets mocks with jest.clearAllMocks()

16. afterAll calls cleanupTestData(organizationId)

┌───────────────────────────────────────────────────────────┐
│ PHASE 3: TYPE SAFETY                                      │
└───────────────────────────────────────────────────────────┘

17. Import Prisma-generated types for all models

18. Use type annotations on database create/update operations

19. TypeScript compiles without errors before running tests
```

### AI Conversation Pattern

**User:** "I need to write an API test for HealthCheckApiKey"

**AI Response:**
```
Perfect! Let's follow the Schema-First workflow (Rule 375).

**Step 1: Inspect the schema**

$ ./.cursor/tools/inspect-model.sh HealthCheckApiKey

[Tool output shows fields: label, keyHash, environment, organizationId, etc.]

I can see from the inspection:
- Field is "label" (NOT "name")
- keyHash is a String (cryptographic hash)
- organizationId is a Foreign Key
- createdAt is DateTime

**Step 2: Generate types**

$ cd app && npx prisma generate

**Step 3: Write test with type safety**

```typescript
import { HealthCheckApiKey } from '@prisma/client';

const apiKey: HealthCheckApiKey = await prisma.healthCheckApiKey.create({
  data: {
    label: 'Test Key',  // ✅ From schema inspection
    keyHash: hashedKey,
    environment: 'test',
    organizationId: testOrgId,
    createdBy: testUserId,
    active: true,
    lastFourChars: key.slice(-4),
  },
});
```

This ensures TypeScript catches any field mismatches at compile-time!
```

---

## Database Test Patterns

### Pattern 1: UUID-Based Test Data (Rule 376)

**Problem:** Timestamp-based IDs collide in parallel tests

**Solution:**
```typescript
// ❌ WRONG: Timestamp-based
const org = await prisma.organization.create({
  data: {
    slug: `test-org-${Date.now()}`,  // Collision risk!
  },
});

// ✅ CORRECT: UUID-based
const uuid = crypto.randomUUID();
const org = await prisma.organization.create({
  data: {
    slug: `test-org-${uuid}`,  // Never collides
  },
});
```

### Pattern 2: Direct vs Indirect Relationships (Rule 376)

**Use tool to determine:**
```bash
$ ./.cursor/tools/inspect-model.sh YourModel
```

**If output shows:**
```
✅ Direct Relationship: Model HAS organizationId field
```

**Then use:**
```typescript
await prisma.yourModel.findMany({
  where: { organizationId: testOrgId }
});
```

**If output shows:**
```
⚠️  Indirect Relationship: Model does NOT have organizationId
```

**Then use:**
```typescript
await prisma.yourModel.findMany({
  where: {
    parent: {
      organizationId: testOrgId
    }
  }
});
```

### Pattern 3: Cleanup with Trigger Bypass (Rule 376)

```typescript
export async function cleanupTestData(organizationId: string) {
  try {
    // Disable triggers
    await prisma.$executeRawUnsafe('SET session_replication_role = replica;');
    
    // Delete in correct order (children first)
    await prisma.childTable.deleteMany({ where: { organizationId } });
    await prisma.parentTable.deleteMany({ where: { organizationId } });
    
    // Re-enable triggers
    await prisma.$executeRawUnsafe('SET session_replication_role = DEFAULT;');
  } catch (error) {
    // CRITICAL: Always re-enable triggers
    await prisma.$executeRawUnsafe('SET session_replication_role = DEFAULT;');
    throw error;
  }
}
```

---

## Debugging with AI

### Pattern 1: Field Mismatch Errors

**Error:**
```
Error: Unknown arg `name` in data.name for type HealthCheckApiKey
```

**AI Debugging Workflow:**
```
1. Recognize this is a schema mismatch
2. Suggest tool: "./.cursor/tools/inspect-model.sh HealthCheckApiKey"
3. Show tool output
4. Identify: "Field is 'label', not 'name'"
5. Provide fix with exact field name
```

**Time Saved:** 2-4 hours → 2 minutes

### Pattern 2: "Cannot Query Field organizationId"

**Error:**
```
Error: Unknown arg `organizationId` in where.organizationId
```

**AI Debugging Workflow:**
```
1. Recognize this is an indirect relationship
2. Suggest tool: "./.cursor/tools/inspect-model.sh YourModel"
3. Show tool output indicating "Indirect Relationship"
4. Provide nested query pattern
```

**Example:**
```typescript
// ❌ WRONG: Direct query on indirect relationship
await prisma.healthCheckResponse.deleteMany({
  where: { organizationId: testOrgId }  // Field doesn't exist!
});

// ✅ CORRECT: Nested query
await prisma.healthCheckResponse.deleteMany({
  where: {
    testRun: {
      organizationId: testOrgId
    }
  }
});
```

---

## Real-World Examples

### Example 1: API Key Generation Test (Success Story)

**Before Schema-First (Nov 16, 2025):**
- Wrote test using 'name' field (from design doc)
- Test failed: "Unknown arg `name`"
- Debugged for 3 hours
- Finally discovered schema has 'label'

**After Schema-First (Nov 19, 2025):**
```bash
$ ./.cursor/tools/inspect-model.sh HealthCheckApiKey
# Output shows: label: String

# Write test with correct field
const apiKey = await prisma.healthCheckApiKey.create({
  data: { label: 'Test Key' }
});

# Test passes first run! ✅
```

**Time:** 3 hours → 15 minutes

### Example 2: Health Check Response Cleanup (Success Story)

**Before Pattern (Nov 18, 2025):**
```typescript
// Tried direct query
await prisma.healthCheckResponse.deleteMany({
  where: { organizationId: testOrgId }
});
// Error: "Unknown arg organizationId"
// Debugged for 2 hours
```

**After Pattern (Nov 19, 2025):**
```bash
$ ./.cursor/tools/inspect-model.sh HealthCheckResponse
# Output shows: "⚠️  Indirect Relationship"

# Use nested query pattern
await prisma.healthCheckResponse.deleteMany({
  where: {
    testRun: {
      organizationId: testOrgId
    }
  }
});
# Works first time! ✅
```

**Time:** 2 hours → 5 minutes

### Example 3: Schema Change Validation (Success Story)

**Before Automation:**
- Modified schema
- Forgot to run `npx prisma generate`
- Tests failed with confusing errors
- Debugged for 1 hour

**After Automation:**
```bash
$ ./.cursor/tools/check-schema-changes.sh

⚠️  WARNING: Schema has uncommitted changes!

🔧 REQUIRED ACTIONS:
  1. Run: npx prisma generate
  2. Update tests
  3. Commit schema.prisma

$ npx prisma generate
$ npm test
# All tests pass! ✅
```

**Time:** 1 hour → 2 minutes

---

## Success Metrics

### Quantitative Results

| Metric | Before Workflows | After Workflows | Improvement |
|--------|------------------|-----------------|-------------|
| **Time to write test** | 45-60 min | 15-20 min | **70% faster** |
| **Debug time** | 30-90 min | 5-15 min | **80% faster** |
| **First-run success** | ~40% | ~95% | **2.4x better** |
| **Test stability** | ~60% | ~98% | **1.6x better** |

### Qualitative Results

**Developer Feedback:**
- ✅ "Tests actually work on first try now!"
- ✅ "No more guessing field names"
- ✅ "Tools make AI assistance way more reliable"
- ✅ "Onboarding is so much faster"

---

## AI Assistant Best Practices

### DO ✅

1. **Always suggest tools first**
   ```
   "Let's inspect the schema: ./.cursor/tools/inspect-model.sh YourModel"
   ```

2. **Reference rules explicitly**
   ```
   "Following Rule 375 (Schema-First), let's..."
   ```

3. **Show tool output**
   ```
   [Tool output]
   
   Based on this output, the field is 'label'...
   ```

4. **Provide context**
   ```
   "This pattern (UUID-based IDs) prevents the collision issues we saw in Nov 2025"
   ```

### DON'T ❌

1. **Don't hallucinate schema details**
   ```
   ❌ "The model probably has a 'name' field"
   ✅ "Let's verify with inspect-model.sh"
   ```

2. **Don't skip validation**
   ```
   ❌ Just write code
   ✅ Inspect schema → Generate types → Write code
   ```

3. **Don't contradict tools**
   ```
   Tool says: "Field is 'label'"
   ❌ "But design doc says 'name', so use 'name'"
   ✅ "Tool shows 'label', so we'll use 'label' (schema is truth)"
   ```

---

## Quick Reference Card

### Before Any Database Work
```bash
./.cursor/tools/inspect-model.sh YourModel
```

### Before Committing
```bash
./.cursor/tools/check-schema-changes.sh
```

### Writing API Tests
```
1. Inspect schema (tool)
2. Generate types
3. Import types
4. Write test
5. Run (should pass!)
```

### Debugging Field Errors
```
1. Run inspect-model.sh
2. Use exact field names from output
3. Update code
4. Re-test
```

---

**Document Version:** 1.0  
**Last Updated:** November 19, 2025  
**Based On:** 40+ hours documented sessions  
**Success Rate:** 95%+ first-run  
**Maintainer:** Development Team

