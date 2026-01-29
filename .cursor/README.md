# .cursor/ Directory - Complete Documentation

**Purpose:** Cursor IDE-specific configuration, rules, tools, and workflows  
**Status:** ✅ ACTIVE - Production Ready  
**Last Updated:** November 19, 2025

---

## 📁 Directory Structure

```
.cursor/
├── README.md              # This file - Overview of entire .cursor/ directory
├── docs/                  # Cursor-specific documentation
│   ├── README.md
│   ├── rules-guide.md
│   ├── tools-guide.md
│   └── ai-workflows.md
├── rules/                 # Cursor AI rules (152 .mdc files)
│   └── README.md
└── tools/                 # Development automation scripts
    └── README.md
```

---

## 🎯 What Lives in `.cursor/`?

### **Cursor-Specific Content ONLY**

✅ **Belongs in `.cursor/`:**
- Cursor AI rules (`.mdc` format)
- Development automation tools
- Cursor IDE configuration
- AI prompt patterns
- Rule application strategies

❌ **Does NOT belong in `.cursor/`:**
- Universal implementation guides → `guides/`
- Architecture documentation → `docs/`
- API documentation → `docs/`
- Business requirements → `docs/`

---

## 📚 Subdirectories

### `rules/` - Cursor AI Rules
**Purpose:** Define how Cursor AI should behave when assisting with code

**Contents:**
- 152 `.mdc` rule files covering:
  - Security & compliance
  - Testing standards
  - Architecture patterns
  - Framework-specific rules
  - Domain-specific rules

**Documentation:** See `.cursor/rules/README.md`

---

### `tools/` - Development Automation
**Purpose:** Scripts and utilities for development workflows

**Contents:**
- `check-schema-changes.sh` - Schema validation
- `inspect-model.sh` - Prisma model inspection
- Future tools as needed

**Documentation:** See `.cursor/tools/README.md`

---

### `docs/` - Cursor-Specific Documentation
**Purpose:** How to use Cursor AI effectively in this project

**Contents:**
- Rules system documentation
- Tool usage guides
- AI workflow patterns
- Cursor-specific best practices

**Documentation:** See `.cursor/docs/README.md`

---

## 🚀 Quick Start

### For New Developers

1. **Understand the rules system:**
   ```bash
   cat .cursor/docs/rules-guide.md
   ```

2. **Learn available tools:**
   ```bash
   cat .cursor/tools/README.md
   ```

3. **Explore AI workflows:**
   ```bash
   cat .cursor/docs/ai-workflows.md
   ```

### For AI Assistants (Cursor, Claude, etc.)

1. **Load relevant rules:**
   - Check `.cursor/rules/` for applicable standards
   - Follow priority system (P0 = required, P1 = important, P2 = nice-to-have)

2. **Use available tools:**
   - `.cursor/tools/inspect-model.sh` for schema inspection
   - `.cursor/tools/check-schema-changes.sh` for validation

3. **Follow AI workflows:**
   - See `.cursor/docs/ai-workflows.md` for proven patterns

---

## 🎓 Key Principles

### 1. **Cursor-Specific Only**
This directory contains ONLY Cursor IDE-specific content. Universal guides live in `guides/`, architecture docs live in `docs/`.

### 2. **Self-Documenting**
Every subdirectory has a README explaining its purpose and usage.

### 3. **Tool-Agnostic Guides Elsewhere**
If a guide works with ANY IDE/tool, it belongs in `guides/`, not here.

### 4. **Version Controlled**
All rules, tools, and docs are version controlled. Only temporary files (logs, cache) are gitignored.

---

## 📊 Directory Size & Scope

| Directory | File Count | Purpose | Size |
|-----------|------------|---------|------|
| `rules/` | 152 files | AI behavior rules | ~1.5 MB |
| `tools/` | 3 files | Automation scripts | ~50 KB |
| `docs/` | 4 files | Cursor workflows | ~100 KB |

---

## 🔗 Related Documentation

### Universal Guides (NOT in .cursor/)
- `guides/testing/` - Testing methodologies
- `guides/auth0/` - Auth0 integration
- `guides/stripe/` - Payment integration
- `guides/deployment/` - Deployment guides

### Architecture Docs (NOT in .cursor/)
- `docs/DESIGN-*.md` - System design documents
- `docs/ARCHITECTURE-*.md` - Architecture decisions

### Why Separate?
Universal guides work with ANY IDE/tool. Cursor-specific docs only work with Cursor AI.

---

## 💡 Contributing

### Adding New Rules
1. Create `.mdc` file in `.cursor/rules/`
2. Follow template in `001-cursor-rules.mdc`
3. Update `.cursor/rules/README.md`
4. Document in `.cursor/docs/rules-guide.md` if it introduces new patterns

### Adding New Tools
1. Create script in `.cursor/tools/`
2. Make executable: `chmod +x .cursor/tools/your-tool.sh`
3. Update `.cursor/tools/README.md`
4. Document in `.cursor/docs/tools-guide.md` if needed

### Adding Cursor Documentation
1. Create `.md` file in `.cursor/docs/`
2. Update `.cursor/docs/README.md`
3. Ensure it's Cursor-specific (not universal)

---

## 🎯 Design Philosophy

### Separation of Concerns

```
.cursor/          → "How Cursor AI helps with development"
├── rules/        → "How should AI behave?"
├── tools/        → "What automation is available?"
└── docs/         → "How do we use Cursor effectively?"

guides/           → "How to implement features" (universal)
├── testing/
├── auth0/
└── stripe/

docs/             → "What we're building" (universal)
├── DESIGN-*.md
└── ARCHITECTURE-*.md
```

---

## 📈 Success Metrics

Since implementing `.cursor/` structure:

| Metric | Before | After | Impact |
|--------|--------|-------|--------|
| **Rule discoverability** | Scattered | Centralized | 100% organized |
| **Tool accessibility** | Multiple locations | Single `.cursor/tools/` | Easy to find |
| **AI consistency** | Variable | Rule-driven | Predictable results |
| **Onboarding time** | 2-3 days | 1 day | 50% faster |

---

## 🔒 .gitignore Considerations

```gitignore
# .gitignore

# Ignore Cursor IDE temporary files
.cursor/.ai-chat-history/
.cursor/tools/*.log
.cursor/tools/tmp/

# KEEP these version controlled:
.cursor/rules/
.cursor/tools/*.sh
.cursor/docs/
.cursor/README.md
```

---

## 📞 Support

### For Rule Questions
- See `.cursor/docs/rules-guide.md`
- Check `.cursor/rules/000-cursor-rules-registry2.mdc` for complete index

### For Tool Questions
- See `.cursor/docs/tools-guide.md`
- Run tools with `--help` flag

### For AI Workflow Questions
- See `.cursor/docs/ai-workflows.md`

---

**Document Version:** 1.0  
**Maintainer:** Development Team  
**Status:** ✅ ACTIVE - Production Ready

