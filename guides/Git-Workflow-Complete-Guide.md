# Git Workflow Complete Guide

**The definitive guide to Git workflows, branching strategies, commit conventions, and collaboration patterns for effective version control.**

---

## Table of Contents

1. [Git Workflow Strategies](#git-workflow-strategies)
2. [Branching Patterns](#branching-patterns)
3. [Commit Conventions](#commit-conventions)
4. [Pull Request Workflow](#pull-request-workflow)
5. [Hotfix Procedures](#hotfix-procedures)
6. [Common Git Operations](#common-git-operations)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)
9. [Tools & Automation](#tools--automation)

---

## Git Workflow Strategies

### GitHub Flow (Recommended)

**Best for:** Continuous deployment, fast-moving teams, SaaS products

**Structure:**
```
main (production) ← Always deployable
  ├── feature/user-auth
  ├── feature/payments
  ├── fix/login-bug
  └── hotfix/security-patch
```

**Workflow:**
1. Branch from `main`
2. Make changes
3. Create PR
4. Review and approve
5. Merge to `main`
6. Auto-deploy to production

**Pros:**
- ✅ Simple (only one long-lived branch)
- ✅ Fast (changes reach production quickly)
- ✅ Clear (what's in main is in production)
- ✅ Works well with CI/CD

**Cons:**
- ❌ Requires good CI/CD
- ❌ Requires feature flags for incomplete features
- ❌ Main must always be deployable

**When to Use:**
- Continuous deployment
- Small to medium teams
- Modern SaaS products
- Fast iteration cycles

---

### Git Flow

**Best for:** Scheduled releases, multiple environments, complex release cycles

**Structure:**
```
main (production)
  └── develop (integration)
      ├── feature/user-auth
      ├── feature/payments
      └── release/v2.0.0
          └── hotfix/critical-bug
```

**Branches:**
- `main` - Production releases only
- `develop` - Integration branch for next release
- `feature/*` - New features (from develop)
- `release/*` - Release preparation (from develop)
- `hotfix/*` - Production fixes (from main)

**Workflow:**
1. Feature: Branch from `develop` → merge back to `develop`
2. Release: Branch from `develop` → merge to `main` and `develop`
3. Hotfix: Branch from `main` → merge to `main` and `develop`

**Pros:**
- ✅ Clear separation of development vs production
- ✅ Supports scheduled releases
- ✅ Parallel development and release prep
- ✅ Hot fixes don't disrupt development

**Cons:**
- ❌ More complex (many branches)
- ❌ Slower (changes take longer to reach production)
- ❌ Merge conflicts more common

**When to Use:**
- Scheduled releases (monthly, quarterly)
- Multiple environments (dev, staging, prod)
- Large teams
- Enterprise products

---

### Trunk-Based Development

**Best for:** Highly disciplined teams, very fast deployment

**Structure:**
```
main (production) ← Everyone commits here
  └── short-lived branches (< 1 day)
```

**Workflow:**
1. Create short-lived branch (< 1 day)
2. Small changes (< 200 lines)
3. Fast review
4. Merge to main
5. Deploy continuously

**Pros:**
- ✅ Fastest possible integration
- ✅ Minimal merge conflicts
- ✅ Forces small changes

**Cons:**
- ❌ Requires strong discipline
- ❌ Requires excellent CI/CD
- ❌ Requires feature flags

**When to Use:**
- Very mature teams
- Excellent CI/CD infrastructure
- Need for speed
- Large codebases (Google, Facebook use this)

---

## Branching Patterns

### Branch Naming Convention

```
<type>/<ticket>-<description>

Types:
- feature/  - New features
- fix/      - Bug fixes
- hotfix/   - Production emergencies
- refactor/ - Code refactoring
- docs/     - Documentation
- test/     - Test improvements
- chore/    - Maintenance tasks
```

**Examples:**
```bash
feature/PRD-123-user-authentication
fix/BUG-456-login-timeout
hotfix/SEC-789-xss-vulnerability
refactor/TECH-012-database-layer
docs/DOC-034-api-documentation
test/TEST-056-integration-tests
chore/DEP-078-upgrade-dependencies
```

**Why This Format:**
- ✅ Clear purpose (`feature`, `fix`, etc.)
- ✅ Linked to ticket (`PRD-123`)
- ✅ Descriptive (`user-authentication`)
- ✅ Searchable (`git branch | grep PRD-123`)

### Branch Lifecycle

```bash
# 1. Create branch
git checkout main
git pull origin main
git checkout -b feature/PRD-123-user-auth

# 2. Work on branch
git add src/auth/
git commit -m "feat(auth): add login form"
git push origin feature/PRD-123-user-auth

# 3. Keep branch updated
git fetch origin
git rebase origin/main

# 4. Create PR and merge

# 5. Delete branch
git checkout main
git branch -d feature/PRD-123-user-auth
git push origin --delete feature/PRD-123-user-auth
```

### Branch Protection

**Main Branch Protection (GitHub Settings):**
```yaml
Protect matching branches: main

✅ Require pull request before merging
   ✅ Require approvals: 1-2
   ✅ Dismiss stale reviews
   ✅ Require review from Code Owners

✅ Require status checks to pass
   ✅ tests
   ✅ lint
   ✅ type-check
   ✅ Require branches to be up to date

✅ Require conversation resolution

✅ Include administrators

❌ Allow force pushes

❌ Allow deletions
```

---

## Commit Conventions

### Conventional Commits Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `style` - Formatting (no code change)
- `refactor` - Code refactoring
- `perf` - Performance improvement
- `test` - Adding/updating tests
- `chore` - Maintenance (dependencies, build)
- `ci` - CI/CD changes
- `revert` - Revert previous commit

**Scope (Optional):**
- Component, module, or area affected
- Examples: `auth`, `api`, `ui`, `db`

**Subject:**
- Imperative mood ("Add feature" not "Added feature")
- Lowercase first letter
- No period at end
- Max 50 characters

**Body (Optional):**
- Explain what and why, not how
- Wrap at 72 characters
- Blank line after subject

**Footer (Optional):**
- Breaking changes: `BREAKING CHANGE:`
- Issue references: `Closes #123`, `Fixes #456`

### Commit Examples

```bash
# ✅ GOOD: Simple feature
feat(auth): add login form

# ✅ GOOD: Bug fix with issue reference
fix(api): prevent race condition in payment processing

Adds transaction lock to prevent duplicate charges when
user double-clicks payment button.

Fixes #BUG-456

# ✅ GOOD: Performance improvement
perf(db): optimize user query with eager loading

Reduces N+1 queries by using Prisma include. Improves
response time from 2s to 200ms for user dashboard.

# ✅ GOOD: Breaking change
chore(deps): upgrade Next.js to 14.0.0

BREAKING CHANGE: Requires Node.js 18.17 or higher

# ✅ GOOD: Multiple related changes
refactor(auth): improve error handling

- Add specific error types
- Improve error messages
- Add error logging with context

Closes #TECH-123

# ❌ BAD: Vague
"fixed bug"

# ❌ BAD: Too detailed (put in body)
"fix(api): prevent race condition in payment processing by adding database transaction lock using BEGIN TRANSACTION and COMMIT statements in PostgreSQL"

# ❌ BAD: Work in progress (squash before merge)
"WIP"

# ❌ BAD: Multiple unrelated changes
"fix login, update deps, add tests"
```

### Atomic Commits

**One Logical Change Per Commit:**

```bash
# ✅ GOOD: Separate logical changes
git commit -m "feat(auth): add User model and schema"
git commit -m "feat(auth): add authentication API endpoints"
git commit -m "feat(auth): add login UI component"
git commit -m "test(auth): add authentication integration tests"

# Each commit:
- Can be understood independently
- Tests pass after commit
- Can be reverted independently
- Has clear purpose

# ❌ BAD: Everything in one commit
git commit -m "add authentication feature"
# Includes: model, API, UI, tests - hard to understand, review, revert
```

**Benefits of Atomic Commits:**
- ✅ Easier code review (review commit by commit)
- ✅ Better git history (see exactly what changed)
- ✅ Easier debugging (git bisect works better)
- ✅ Easier rollback (revert specific changes)

---

## Pull Request Workflow

### Creating a PR

**Before Creating PR:**
```bash
# 1. Self-review
git diff origin/main

# 2. Run checks locally
npm run lint
npm run type-check
npm test
npm run build

# 3. Update branch with main
git fetch origin
git rebase origin/main

# 4. Push
git push origin feature/my-branch

# 5. Create PR on GitHub
```

**PR Title Format:**
```
<type>(<scope>): <description>

Examples:
feat(auth): add email verification
fix(api): prevent race condition in payments
docs(readme): update installation instructions
```

**PR Description (see Code Review Guide for full template):**
```markdown
## Summary
Brief description of changes

## Motivation
Why is this needed?

## Changes
- Key change 1
- Key change 2

## Testing
- [x] Tests added
- [x] Tested locally

## Screenshots
(if UI change)

## Checklist
- [x] Self-reviewed
- [x] Tests pass
- [x] Documentation updated

Closes #123
```

### PR Review Process

**As Author:**
1. Create PR with complete description
2. Request specific reviewers
3. Respond to feedback within 24h
4. Re-request review after changes
5. Merge after approval

**As Reviewer:**
1. Review within 24h
2. Be specific and constructive
3. Use conventional comments (nit, issue, blocking)
4. Approve or request changes
5. Re-review within 4h if re-requested

**See:** `guides/Code-Review-Complete-Guide.md` for details

### Merge Strategies

**1. Squash and Merge (Recommended for most PRs):**

```bash
# Multiple commits → Single commit on main
feat(auth): add email verification (#123)

* feat(auth): add verification model
* feat(auth): add verification endpoint
* test(auth): add verification tests
```

**When to use:**
- Most feature branches
- Want clean history
- Individual commits not important

**2. Merge Commit:**

```bash
# Preserves all commits + merge commit
Merge pull request #123 from feature/user-auth

feat(auth): add user authentication
```

**When to use:**
- Want to preserve commit history
- Important to show when feature was integrated
- Hotfixes (track what was deployed)

**3. Rebase and Merge:**

```bash
# Linear history with all commits
feat(auth): add verification model
feat(auth): add verification endpoint
test(auth): add verification tests
```

**When to use:**
- Want linear history
- Each commit is valuable
- Author cleaned up commits

---

## Hotfix Procedures

### Emergency Hotfix Workflow

```bash
# 1. Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/SEC-789-fix-xss

# 2. Make MINIMAL fix
git add src/utils/sanitize.ts
git commit -m "fix(security): sanitize user input to prevent XSS

SECURITY: Critical XSS vulnerability in comment system.
Added DOMPurify sanitization for all user-generated content.

Fixes #SEC-789"

# 3. Push immediately
git push origin hotfix/SEC-789-fix-xss

# 4. Create PR with HOTFIX label
# 5. Request immediate review (< 1 hour)
# 6. Deploy as soon as approved

# 7. If using Git Flow, merge to develop too
git checkout develop
git merge hotfix/SEC-789-fix-xss
git push origin develop
```

**Hotfix Criteria:**
- P0: Site down, security breach (< 30 min)
- P1: Major feature broken (< 2 hours)

**See:** @804-hotfix-procedures.mdc for complete process

---

## Common Git Operations

### Syncing with Main

```bash
# Method 1: Rebase (recommended - cleaner history)
git checkout feature/my-branch
git fetch origin
git rebase origin/main

# If conflicts:
# 1. Resolve conflicts in files
# 2. git add <resolved-files>
# 3. git rebase --continue

git push --force-with-lease origin feature/my-branch

# Method 2: Merge (safer but messier history)
git checkout feature/my-branch
git fetch origin
git merge origin/main
git push origin feature/my-branch
```

### Fixing Mistakes

**Amend Last Commit:**
```bash
# Change commit message
git commit --amend -m "fix(auth): correct typo in message"

# Add forgotten file
git add forgotten-file.ts
git commit --amend --no-edit

# Push amended commit (if already pushed)
git push --force-with-lease origin feature/my-branch
```

**Undo Last Commit (keep changes):**
```bash
git reset --soft HEAD~1
# Changes are still staged, commit message gone
```

**Undo Last Commit (discard changes):**
```bash
git reset --hard HEAD~1
# ⚠️ WARNING: Changes are lost forever!
```

**Revert a Commit (safe, creates new commit):**
```bash
git revert <commit-hash>
# Creates new commit that undoes the changes
# Safe for commits already pushed
```

### Cleaning Up Branches

```bash
# Delete local branch
git branch -d feature/my-branch  # Safe (won't delete if unmerged)
git branch -D feature/my-branch  # Force delete

# Delete remote branch
git push origin --delete feature/my-branch

# Delete merged local branches
git branch --merged | grep -v "\*" | xargs -n 1 git branch -d

# Prune remote branches (remove deleted remotes)
git remote prune origin

# See all branches (local and remote)
git branch -a
```

### Stashing Changes

```bash
# Save work in progress
git stash save "WIP: working on auth feature"

# List stashes
git stash list

# Apply most recent stash
git stash pop

# Apply specific stash
git stash apply stash@{2}

# Delete stash
git stash drop stash@{0}

# Clear all stashes
git stash clear
```

### Interactive Rebase (Clean Up Commits)

```bash
# Clean up last 3 commits
git rebase -i HEAD~3

# Editor opens:
pick abc123 feat(auth): add login form
pick def456 fix typo
pick ghi789 add tests

# Change to:
pick abc123 feat(auth): add login form
fixup def456 fix typo      # Merge into previous commit
pick ghi789 test(auth): add login tests

# Save and close
# Result: 2 clean commits instead of 3
```

**Rebase Actions:**
- `pick` - Keep commit as is
- `reword` - Change commit message
- `edit` - Stop to amend commit
- `squash` - Merge with previous (keep both messages)
- `fixup` - Merge with previous (discard this message)
- `drop` - Remove commit

### Cherry-Picking Commits

```bash
# Apply specific commit to current branch
git cherry-pick <commit-hash>

# Cherry-pick multiple commits
git cherry-pick abc123 def456 ghi789

# Cherry-pick without committing (to modify)
git cherry-pick -n <commit-hash>
```

**When to use:**
- Apply hotfix to multiple branches
- Port feature to different version
- Recover commit from deleted branch

---

## Best Practices

### Commit Best Practices

**DO:**
- ✅ Commit often (multiple times per day)
- ✅ Write clear commit messages
- ✅ Use conventional commits format
- ✅ Make atomic commits (one logical change)
- ✅ Test before committing
- ✅ Reference issues in commits

**DON'T:**
- ❌ Commit broken code
- ❌ Commit secrets or credentials
- ❌ Use `git commit -m "WIP"` (clean up before pushing)
- ❌ Commit commented-out code
- ❌ Commit `console.log` or debug statements

### Branch Best Practices

**DO:**
- ✅ Branch from latest main
- ✅ Keep branches short-lived (< 1 week)
- ✅ Push daily
- ✅ Sync with main regularly
- ✅ Delete after merging

**DON'T:**
- ❌ Keep long-lived branches (> 2 weeks)
- ❌ Let branches diverge from main
- ❌ Work directly on main
- ❌ Force push to main (ever!)

### Force Push Safety

```bash
# ❌ DANGEROUS: Can overwrite others' work
git push --force

# ✅ SAFER: Only force if remote hasn't changed
git push --force-with-lease

# This will fail if someone else pushed to the branch
# Protecting you from overwriting their work
```

**When force push is okay:**
- Your feature branch (not shared)
- After rebase or amend
- With `--force-with-lease`

**When force push is NEVER okay:**
- Main/production branches
- Shared branches
- After others reviewed your code

---

## Troubleshooting

### Merge Conflicts

```bash
# 1. Conflict occurs during merge/rebase
git merge main
# CONFLICT (content): Merge conflict in src/auth.ts

# 2. Open conflicted file
# src/auth.ts:
<<<<<<< HEAD
const timeout = 5000;  // Your changes
=======
const timeout = 10000; // Their changes
>>>>>>> main

# 3. Resolve conflict (choose one or combine)
const timeout = 10000;  // Keep their version

# 4. Mark as resolved
git add src/auth.ts

# 5. Continue merge
git commit  # For merge
# OR
git rebase --continue  # For rebase
```

**Conflict Resolution Tips:**
- Understand both changes before resolving
- Test after resolving
- When in doubt, ask the other author
- Use merge tool: `git mergetool`

### Accidentally Committed to Wrong Branch

```bash
# You're on main, but meant to be on feature branch
git log  # Note the commit hash (abc123)

# Reset main to before your commit
git reset --hard HEAD~1

# Create/checkout feature branch
git checkout -b feature/my-feature

# Cherry-pick your commit
git cherry-pick abc123
```

### Recover Deleted Branch

```bash
# Find the commit hash of deleted branch
git reflog
# abc123 HEAD@{5}: checkout: moving from feature/my-branch to main

# Recreate branch at that commit
git checkout -b feature/my-branch abc123
```

### Undo Pushed Commit

```bash
# If commit not yet pulled by others:
git reset --hard HEAD~1
git push --force-with-lease

# If commit pulled by others (safer):
git revert <commit-hash>
git push origin main
# Creates new commit that undoes changes
```

### Merge vs Rebase - Which to Use?

**Use Merge When:**
- Feature complete and ready to integrate
- Merging to main/develop
- Want to preserve branch history
- Multiple people worked on branch

**Use Rebase When:**
- Updating feature branch with main
- Cleaning up commit history
- Working alone on branch
- Want linear history

```bash
# Merge: Preserves history
git merge origin/main
# Creates merge commit

# Rebase: Rewrites history
git rebase origin/main
# Replays your commits on top of main
```

---

## Tools & Automation

### Git Aliases

Add to `~/.gitconfig`:

```ini
[alias]
  # Shortcuts
  co = checkout
  br = branch
  ci = commit
  st = status
  
  # Useful aliases
  lg = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
  unstage = reset HEAD --
  last = log -1 HEAD
  amend = commit --amend --no-edit
  
  # Clean up
  cleanup = !git branch --merged | grep -v \"\\*\" | xargs -n 1 git branch -d
  prune-all = !git remote prune origin && git cleanup
```

### Commit Message Template

Create `~/.gitmessage`:

```
<type>(<scope>): <subject>

<body>

<footer>

# Types: feat, fix, docs, style, refactor, perf, test, chore
# Scope: auth, api, ui, db, etc.
# Subject: imperative mood, lowercase, no period, max 50 chars
# Body: explain what and why (not how), wrap at 72 chars
# Footer: breaking changes, issue references
```

Configure:
```bash
git config --global commit.template ~/.gitmessage
```

### Pre-commit Hooks

Install husky:
```bash
npm install --save-dev husky
npx husky install
```

Add hooks:
```bash
# .husky/pre-commit
#!/bin/sh
npm run lint
npm run type-check
npm test
```

### Git LFS (Large File Storage)

For large files (images, videos, datasets):

```bash
# Install
git lfs install

# Track file types
git lfs track "*.psd"
git lfs track "*.mp4"

# Commit .gitattributes
git add .gitattributes
git commit -m "chore: configure git lfs"
```

---

## Workflow Cheat Sheet

### Daily Workflow

```bash
# Morning: Start work
git checkout main
git pull origin main
git checkout -b feature/PRD-123-new-feature

# During day: Work and commit
git add src/
git commit -m "feat(auth): add login form"
git push origin feature/PRD-123-new-feature

# End of day: Sync and push
git fetch origin
git rebase origin/main
git push --force-with-lease origin feature/PRD-123-new-feature

# Create PR when ready
# Review, approve, merge
# Delete branch after merge
git checkout main
git pull origin main
git branch -d feature/PRD-123-new-feature
```

### Emergency Hotfix

```bash
# 1. Quick fix
git checkout main
git pull origin main
git checkout -b hotfix/fix-critical-bug

# 2. Fix and commit
git add src/
git commit -m "fix(api): prevent data corruption"

# 3. Push and deploy ASAP
git push origin hotfix/fix-critical-bug
# Create PR, fast-track review, merge, deploy

# 4. Clean up
git checkout main
git pull origin main
git branch -d hotfix/fix-critical-bug
```

---

## Related Resources

- **Rules:**
  - @802-git-workflow-standards.mdc - Git workflow standards
  - @803-pull-request-workflow.mdc - PR workflow
  - @804-hotfix-procedures.mdc - Emergency procedures
  - @101-code-review-standards.mdc - Code review

- **Guides:**
  - `guides/Code-Review-Complete-Guide.md` - Code review guide
  - `.cursor/docs/ai-workflows.md` - AI-assisted workflows

- **Tools:**
  - `.cursor/tools/check-schema-changes.sh` - Schema validation
  - `.cursor/tools/inspect-model.sh` - Model inspection

---

## Quick Reference

### Essential Commands

```bash
# Branch
git checkout -b feature/my-branch    # Create and switch
git branch -d feature/my-branch      # Delete local
git push origin --delete my-branch   # Delete remote

# Commit
git add .                            # Stage all
git commit -m "feat: add feature"    # Commit
git commit --amend --no-edit         # Amend last commit

# Sync
git fetch origin                     # Fetch changes
git rebase origin/main               # Rebase on main
git push --force-with-lease          # Safe force push

# Undo
git reset --soft HEAD~1              # Undo commit, keep changes
git reset --hard HEAD~1              # Undo commit, discard changes
git revert <hash>                    # Revert commit (safe)

# Cleanup
git stash                            # Save work in progress
git stash pop                        # Restore work
git branch --merged | xargs git branch -d  # Delete merged branches
```

---

**Remember:** Git is a tool for collaboration. Use it to help your team work together effectively, maintain code quality, and ship features safely! 🚀

