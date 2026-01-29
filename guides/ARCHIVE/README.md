# Archived Testing Guides

This directory contains testing guides that have been **superseded** by the Universal Testing Framework.

## ⚠️ IMPORTANT: These Files Are Archived

**DO NOT USE** the files in this directory. They contain **outdated patterns** that conflict with the current testing standards.

## Files Archived

### **Testing-Strategy-Guide.md.bak**
- **Archived**: January 5, 2025
- **Reason**: Conflicted with Universal Testing Framework visual indicators
- **Replaced by**: `guides/testing/Universal-Testing-Framework-Guide.md`

## ✅ Current Testing Documentation

Use these **current** files instead:

### **Universal Testing Framework:**
- **`guides/testing/Universal-Testing-Framework-Guide.md`** - Complete implementation guide
- **`guides/testing/Complete-Testing-Infrastructure-Summary.md`** - Framework summary and roadmap

### **Test Organization:**
- **`tests/README-TEST-FRAMEWORK.md`** - Updated to reference Universal Testing Framework
- **`tests/README-TESTING-APPROACH.md`** - Updated testing approach

### **Rules:**
- **`.cursor/rules/380-comprehensive-testing-standards.mdc`** - Primary testing rule

## 🎯 What Changed

The archived files used **old patterns** like:
```typescript
// ❌ OLD PATTERN (archived)
it("shows loading state when user is loading", () => {
  
// ✅ NEW PATTERN (current)
it("✅ Should show loading state when user is loading", () => {
  console.log("🧪 Testing loading state display");
```

## 📊 Migration Results

- **✅ 171 test files** updated with Universal Testing Framework
- **✅ 1,409 tests** now follow visual indicator standards  
- **✅ 160 test suites** passing with clean visual output

---

**For current testing guidance, refer to the Universal Testing Framework documentation above.**