# Infrastructure Verification Guide

**Last Updated**: December 9, 2025  
**Status**: Production-Ready  
**Purpose**: Verify actual infrastructure configuration matches documentation before making changes or deploying

---

## 🎯 Quick Reference

### Pre-Structural-Change Checklist

```bash
# 1. Find all path references
grep -r "app/" --include="*.{ts,tsx,js,jsx,sh,yml,yaml}" . | grep -v node_modules

# 2. Check GitHub Actions
ls -la .github/workflows/

# 3. Test deployment tools
./.cursor/tools/pre-deployment-check.sh

# 4. Create backup
git checkout -b backup/before-[change-description]
```

### Pre-Deployment Verification

```bash
# 1. Verify environment variables
vercel env ls

# 2. Check CI/CD exists (if documented)
ls -la .github/workflows/ci-cd.yml

# 3. Verify monitoring
# Check Vercel Dashboard → Analytics

# 4. Run pre-deployment check
./.cursor/tools/pre-deployment-check.sh
```

---

## 📋 Table of Contents

1. [The Problem](#the-problem)
2. [Verification Checklist](#verification-checklist)
3. [Structural Change Verification](#structural-change-verification)
4. [Deployment Infrastructure Verification](#deployment-infrastructure-verification)
5. [Documentation Gap Detection](#documentation-gap-detection)
6. [Common Gaps Found](#common-gaps-found)
7. [Prevention Strategies](#prevention-strategies)

---

## The Problem

### What Happened

During structure flattening (Dec 9, 2025), we discovered:

1. **Documentation ≠ Reality**: Comprehensive deployment guides existed, but:

   - CI/CD pipeline was documented but NOT implemented
   - Monitoring was documented but NOT configured
   - Environment variables were documented but status unknown

2. **Hidden Dependencies**: Structural changes broke:

   - GitHub Actions workflows (path references)
   - Deployment scripts (`cd app` commands)
   - Tool scripts (path fallbacks that should be cleaned up)

3. **Verification Gap**: We assumed documentation matched reality without verifying

### The Cost

- **Time Lost**: Hours debugging deployment failures
- **Risk**: Production deployments without proper validation
- **Confusion**: Not knowing what's actually configured vs. what's documented

---

## Verification Checklist

### Before Making Major Changes

- [ ] **Search for path references**

  ```bash
  grep -r "old-path/" --include="*.{ts,tsx,js,jsx,sh,yml,yaml}" . | grep -v node_modules
  ```

- [ ] **Check GitHub Actions workflows**

  ```bash
  ls -la .github/workflows/
  cat .github/workflows/*.yml | grep -i "old-path"
  ```

- [ ] **Check deployment scripts**

  ```bash
  find . -name "*.sh" -exec grep -l "old-path" {} \;
  ```

- [ ] **Test deployment tools**

  ```bash
  ./.cursor/tools/pre-deployment-check.sh
  ```

- [ ] **Create backup branch**
  ```bash
  git checkout -b backup/before-[change-description]
  git checkout main
  ```

---

## Structural Change Verification

### Step 1: Impact Analysis

**Before** making structural changes (e.g., flattening directories):

1. **Find all references**:

   ```bash
   # Find all references to old structure
   grep -rn "app/" --include="*.{ts,tsx,js,jsx,sh,yml,yaml}" . \
     | grep -v node_modules \
     | grep -v ".next" \
     | grep -v "deployment/"
   ```

2. **Categorize findings**:

   - **Critical**: GitHub Actions, deployment scripts, build configs
   - **Important**: Test configs, tool scripts, documentation
   - **Low Priority**: Historical docs, old deployment artifacts

3. **Plan updates**:
   - List all files that need updating
   - Prioritize critical files first
   - Document what will change

### Step 2: Create Backup

**ALWAYS** create backup before structural changes:

```bash
# Create backup branch
git checkout -b backup/before-flatten-structure

# Tag current state (optional)
git tag backup/before-flatten-$(date +%Y%m%d)

# Return to main
git checkout main
```

### Step 3: Make Changes Incrementally

1. **Update critical files first**:

   - GitHub Actions workflows
   - Deployment scripts
   - Build configurations

2. **Test after each category**:

   ```bash
   # After updating GitHub Actions
   # Test: git push (should trigger workflow)

   # After updating scripts
   # Test: ./script-name.sh
   ```

3. **Verify tools still work**:
   ```bash
   ./.cursor/tools/pre-deployment-check.sh
   ./.cursor/tools/validate-deployment.sh
   ```

### Step 4: Post-Change Verification

After structural changes:

- [ ] All GitHub Actions workflows updated and tested
- [ ] All deployment scripts updated and tested
- [ ] All tool scripts updated and tested
- [ ] Build still works (`npm run build`)
- [ ] Tests still work (`npm test`)
- [ ] Deployment tools still work
- [ ] Documentation updated

---

## Deployment Infrastructure Verification

### Step 1: Verify Environment Variables

**Don't assume they're configured just because docs list them!**

```bash
# List actual environment variables in Vercel
vercel env ls

# Compare with documentation requirements
# See: guides/Vercel-Deployment-Guide.md

# Required variables (per documentation):
# - DATABASE_URL
# - AUTH_SECRET
# - AUTH_URL
# - ANTHROPIC_API_KEY
# - (others as needed)
```

**Check for each environment**:

- Production
- Preview
- Development

**Action**: If missing, add them in Vercel Dashboard → Settings → Environment Variables

### Step 2: Verify CI/CD Pipeline

**Documentation may reference CI/CD, but it might not exist!**

```bash
# Check if workflows exist
ls -la .github/workflows/

# Expected workflows (if documented):
# - ci-cd.yml (may not exist!)
# - schema-validation.yml (should exist)
# - (others as documented)
```

**Action**: If documented but missing, create it or document that it's not implemented

### Step 3: Verify Monitoring

**Monitoring is often documented but not configured!**

**Check**:

- Vercel Analytics: Dashboard → Analytics → Is it enabled?
- Error Tracking: Is Sentry or similar configured?
- Uptime Monitoring: Is external monitoring set up?
- Performance Monitoring: Are metrics being collected?

**Action**: If documented but missing, set it up or document the gap

### Step 4: Verify Security Configuration

**Security settings may not match documentation!**

**Check in Vercel Dashboard**:

- Advanced Protection: Settings → Security → Is it enabled?
- Rate Limiting: Are rate limits configured?
- Bot Protection: Is bot protection enabled?
- WAF Rules: Are custom rules configured?

**Action**: Verify settings match documentation or update docs to reflect reality

### Step 5: Test Deployment Tools

**Tools exist, but do they work with current structure?**

```bash
# Run pre-deployment check
./.cursor/tools/pre-deployment-check.sh

# Expected: All checks pass
# If failures: Fix before deploying
```

**Common Issues**:

- Path references to old structure
- Missing environment variables
- Broken tool dependencies

---

## Documentation Gap Detection

### The Gap Detection Process

1. **Read Documentation**: Understand what SHOULD be configured
2. **Verify Reality**: Check what's ACTUALLY configured
3. **Document Gaps**: Record differences
4. **Fix or Document**: Either fix the gap or document it

### Gap Documentation Template

Create `docs/INFRASTRUCTURE-GAPS-[DATE].md`:

```markdown
# Infrastructure Gaps - [Date]

## What's Documented

- CI/CD pipeline in guides/Deployment-Workflow-Complete-Guide.md
- Monitoring in .cursor/rules/221-application-monitoring.mdc
- Environment variables in guides/Vercel-Deployment-Guide.md

## What's Actually Configured

- ✅ Environment variables: Verified in Vercel Dashboard
- ❌ CI/CD pipeline: Documented but NOT implemented
- ❌ Monitoring: Documented but NOT configured

## Impact

- No automated testing on PRs
- No automated deployments
- No error tracking
- No performance monitoring

## Action Items

1. Create CI/CD pipeline (if needed)
2. Set up monitoring
3. Update documentation to reflect reality
```

---

## Common Gaps Found

### 1. CI/CD Pipeline

**Documented**: Comprehensive CI/CD workflow in guides  
**Reality**: Only schema validation workflow exists

**Impact**: No automated testing, no automated deployments

**Fix**: Create `.github/workflows/ci-cd.yml` or document that deployments are manual

### 2. Environment Variables

**Documented**: Complete list in deployment guides  
**Reality**: Unknown - need to verify in Vercel Dashboard

**Impact**: Deployment may fail if variables missing

**Fix**: Run `vercel env ls` and compare with documentation

### 3. Monitoring

**Documented**: Comprehensive monitoring standards  
**Reality**: Probably not configured

**Impact**: No visibility into production issues

**Fix**: Enable Vercel Analytics, set up error tracking

### 4. Security Configuration

**Documented**: WAF, rate limiting, bot protection  
**Reality**: Unknown - need to verify

**Impact**: Security vulnerabilities

**Fix**: Check Vercel Dashboard → Security settings

### 5. Tool Path References

**Documented**: Tools should work  
**Reality**: Tools may reference old paths

**Impact**: Tools fail silently or work incorrectly

**Fix**: Search for path references and update

---

## Prevention Strategies

### 1. Regular Infrastructure Audits

**Schedule**: Monthly or before major releases

**Process**:

```bash
# 1. Run verification checklist
./.cursor/tools/check-infrastructure.sh

# 2. Compare documentation vs reality
# Create gap analysis document

# 3. Fix gaps or update documentation
```

### 2. Pre-Change Impact Analysis

**Before** making structural changes:

- [ ] Search for all path references
- [ ] List all affected systems
- [ ] Plan updates for each system
- [ ] Create backup
- [ ] Test incrementally

### 3. Documentation Maintenance

**When** documentation is updated:

- [ ] Verify it matches reality
- [ ] If it describes ideal state, mark it clearly
- [ ] If it describes actual state, verify it's accurate
- [ ] Update when infrastructure changes

### 4. Deployment Readiness Checklist

**Before** every deployment:

- [ ] Run `pre-deployment-check.sh`
- [ ] Verify environment variables (`vercel env ls`)
- [ ] Check monitoring is working
- [ ] Verify security settings
- [ ] Test deployment tools

---

## Quick Start

### Before Structural Changes

```bash
# 1. Find all references
grep -rn "old-path/" --include="*.{ts,tsx,js,jsx,sh,yml,yaml}" . | grep -v node_modules

# 2. Create backup
git checkout -b backup/before-[change]

# 3. Make changes incrementally
# 4. Test after each category
# 5. Verify tools still work
```

### Before Deployment

```bash
# 1. Verify env vars
vercel env ls

# 2. Verify CI/CD (if documented)
ls -la .github/workflows/ci-cd.yml

# 3. Run pre-deployment check
./.cursor/tools/pre-deployment-check.sh

# 4. Fix any failures
# 5. Deploy
```

---

## Related Resources

- **Rule**: @207-infrastructure-verification.mdc - Infrastructure verification standards
- **Rule**: @203-production-deployment-safety.mdc - Pre-deployment validation
- **Tool**: `.cursor/tools/pre-deployment-check.sh` - Comprehensive validation
- **Tool**: `.cursor/tools/check-infrastructure.sh` - Infrastructure health check
- **Document**: `docs/DEPLOYMENT-INFRASTRUCTURE-GAPS.md` - Gap analysis template

---

**Remember**: Documentation describes what SHOULD be, but verification reveals what IS. Always verify before trusting!
