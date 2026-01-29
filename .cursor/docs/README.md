# Cursor-Specific Documentation

**Purpose:** How to use Cursor AI effectively in this project  
**Audience:** Developers using Cursor IDE + AI assistants  
**Status:** ✅ ACTIVE

---

## 📚 Documentation Index

| Document | Purpose | For Whom |
|----------|---------|----------|
| **rules-guide.md** | Understanding and using the rules system | Developers, AI assistants |
| **tools-guide.md** | Development automation tools | Developers |
| **ai-workflows.md** | Proven AI workflow patterns | Developers, AI assistants |

---

## 🎯 Quick Links

### For Human Developers
- [How to Use Rules](#) → `rules-guide.md`
- [Available Tools](#) → `tools-guide.md`
- [AI Workflow Patterns](#) → `ai-workflows.md`

### For AI Assistants (Cursor, Claude, etc.)
- [Rule Priority System](#) → `rules-guide.md#priority-system`
- [When to Apply Rules](#) → `rules-guide.md#rule-application`
- [Tool Integration](#) → `tools-guide.md#ai-integration`
- [Proven Patterns](#) → `ai-workflows.md`

---

## 🚀 Getting Started

### Step 1: Understand the Rules System
```bash
cat .cursor/docs/rules-guide.md
```

**Learn:**
- What are Cursor rules?
- How does the priority system work?
- When should rules be applied?
- How to reference rules in conversations?

### Step 2: Explore Available Tools
```bash
cat .cursor/docs/tools-guide.md
```

**Learn:**
- What automation is available?
- How to use schema validation tools?
- How to inspect Prisma models?
- When to run which tool?

### Step 3: Learn AI Workflows
```bash
cat .cursor/docs/ai-workflows.md
```

**Learn:**
- Proven patterns for API development
- Schema-first workflows
- Test-driven development with AI
- Debugging with AI assistance

---

## 📋 Document Summaries

### rules-guide.md
**What it covers:**
- Rule format and structure
- Priority system (P0/P1/P2)
- Rule categories and domains
- How to apply rules
- How to create new rules
- Rule combination patterns

**Why it exists:**
We have 152 rules. This guide helps you navigate them effectively.

### tools-guide.md
**What it covers:**
- Available automation tools
- Tool usage examples
- Integration with AI workflows
- When to use which tool
- Tool development guidelines

**Why it exists:**
Tools enhance AI-assisted development. This guide shows how to use them.

### ai-workflows.md
**What it covers:**
- Schema-first development pattern
- API test creation workflow
- Database test patterns
- Debugging workflows
- Real-world examples

**Why it exists:**
Based on 40+ hours of documented AI sessions, these patterns work.

---

## 🎓 Key Concepts

### 1. **Cursor Rules Are Not Documentation**
Rules tell Cursor AI **HOW** to behave. Documentation tells humans **WHAT** to do.

**Rules:**
- Located in `.cursor/rules/`
- `.mdc` format
- Applied automatically by Cursor AI
- Define behavior, patterns, standards

**Documentation:**
- Located in `docs/` and `guides/`
- `.md` format
- Read by humans
- Explain architecture, design, how-to

### 2. **Tools Complement AI**
AI is smart, but automation is consistent.

**Use AI for:**
- Understanding code
- Generating boilerplate
- Refactoring
- Explaining concepts

**Use Tools for:**
- Schema validation
- Model inspection
- Consistency checks
- Automated testing

### 3. **Workflows Are Battle-Tested**
Every workflow in `ai-workflows.md` is based on real sessions that achieved:
- 95%+ first-run test success
- 80% reduction in debugging time
- 70% reduction in test writing time

---

## 💡 Best Practices

### For Developers

1. **Reference Rules Explicitly**
   ```
   "Let's implement this following @375-api-test-first-time-right.mdc"
   ```

2. **Use Tools Before Asking AI**
   ```bash
   # Before asking "What fields does HealthCheckApiKey have?"
   ./.cursor/tools/inspect-model.sh HealthCheckApiKey
   ```

3. **Follow Proven Workflows**
   - Schema-first for database work
   - Test-first for API endpoints
   - Type-safe for TypeScript

### For AI Assistants

1. **Load Relevant Rules**
   - Check `002-rule-application.mdc` for priority system
   - Apply P0 rules always
   - Apply P1 rules when appropriate
   - Apply P2 rules when time permits

2. **Recommend Tools**
   - Suggest `.cursor/tools/inspect-model.sh` before schema queries
   - Recommend `.cursor/tools/check-schema-changes.sh` before commits

3. **Follow Established Patterns**
   - Reference `ai-workflows.md` for proven approaches
   - Don't reinvent workflows that already work

---

## 📊 Impact Metrics

Since implementing Cursor-specific documentation:

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Rule awareness** | Variable | Consistent | Developers know rules exist |
| **Tool usage** | Rare | Regular | Tools used proactively |
| **AI effectiveness** | Good | Excellent | AI follows proven patterns |
| **Onboarding time** | 2-3 days | 1 day | 50% faster |

---

## 🔗 Related Resources

### Universal Documentation (NOT Cursor-Specific)
- `guides/testing/` - Testing methodologies
- `guides/auth0/` - Auth0 integration
- `docs/DESIGN-*.md` - System design

### Cursor-Specific Configuration
- `.cursor/rules/` - All Cursor AI rules
- `.cursor/tools/` - Automation scripts
- `.cursor/README.md` - Overview

---

## 📝 Contributing

### Adding New Cursor Documentation

1. **Determine if it's truly Cursor-specific:**
   - ✅ "How to use Cursor AI for testing" → `.cursor/docs/`
   - ❌ "How to write tests" → `guides/testing/`

2. **Create document:**
   ```bash
   touch .cursor/docs/your-topic.md
   ```

3. **Update this README:**
   - Add to documentation index
   - Add to quick links
   - Add to document summaries

4. **Cross-reference:**
   - Link from `.cursor/README.md` if major topic
   - Reference in rules if applicable

---

## 🎯 Success Criteria

This documentation is successful when:

✅ New developers can onboard in 1 day using these docs  
✅ AI assistants consistently apply rules correctly  
✅ Tools are used proactively, not reactively  
✅ Workflows are followed, not reinvented  
✅ Questions about "how to use Cursor" have clear answers

---

**Document Version:** 1.0  
**Last Updated:** November 19, 2025  
**Maintainer:** Development Team

