# Code Review Complete Guide

**The definitive guide to effective code reviews that maintain quality, share knowledge, and build team culture.**

---

## Table of Contents

1. [Philosophy & Purpose](#philosophy--purpose)
2. [For Authors: Preparing Your PR](#for-authors-preparing-your-pr)
3. [For Reviewers: Reviewing Effectively](#for-reviewers-reviewing-effectively)
4. [Review Patterns & Examples](#review-patterns--examples)
5. [Common Pitfalls & Solutions](#common-pitfalls--solutions)
6. [Metrics & Continuous Improvement](#metrics--continuous-improvement)
7. [Tools & Automation](#tools--automation)
8. [Case Studies](#case-studies)

---

## Philosophy & Purpose

### Why Code Reviews Matter

Code reviews are the single most effective quality assurance practice in software development:

**Quality Benefits:**
- **60-90% of bugs** caught before production
- Enforces coding standards consistently
- Identifies security vulnerabilities early
- Prevents technical debt accumulation

**Team Benefits:**
- Spreads knowledge across team
- Mentors junior developers
- Builds shared ownership
- Creates discussion opportunities

**Business Benefits:**
- Reduces production incidents
- Lowers maintenance costs
- Speeds up onboarding
- Improves time-to-market (by preventing rework)

### Core Principles

**1. Collaboration Over Gatekeeping**
- Reviews are discussions, not approvals
- Goal is better code, not perfect code
- Authors and reviewers work together

**2. Learn and Teach**
- Every review is learning opportunity
- Share knowledge generously
- Ask questions respectfully

**3. Be Kind, Be Constructive**
- Focus on code, not the person
- Offer alternatives, not just criticism
- Praise good solutions

**4. Context Matters**
- Understand the why before critiquing the how
- Respect tradeoffs and constraints
- Don't nitpick style (automate it)

---

## For Authors: Preparing Your PR

### 1. Before You Write Code

**Plan Your PR:**
```markdown
## PR Planning Checklist

- [ ] Break feature into small, reviewable chunks
- [ ] Each PR should have single, clear purpose
- [ ] Identify reviewers early (domain experts)
- [ ] Understand acceptance criteria
- [ ] Know what tests need to be added
```

**Think About Your Reviewer:**
- How can I make this easy to review?
- What context will they need?
- What questions might they have?
- How can I show my thinking?

### 2. Writing Review-Friendly Code

**Keep PRs Small:**

| Size | Lines | Files | Review Time | Approval Rate |
|------|-------|-------|-------------|---------------|
| XS | < 10 | 1-2 | 5 min | 99% |
| S | 10-100 | 2-5 | 15 min | 95% |
| M | 100-200 | 5-10 | 30 min | 85% |
| L | 200-400 | 10-20 | 1 hour | 60% |
| XL | > 400 | 20+ | 2+ hours | 30% |

**Research shows:** PRs > 400 lines have 60% lower approval rate and find fewer bugs.

**Breaking Up Large Changes:**

```markdown
## Example: Authentication Feature (1000 lines total)

❌ BAD: Single PR
PR #1: Add authentication (1000 lines, 25 files)
- Hard to review thoroughly
- Takes 2+ hours
- High chance of missing issues

✅ GOOD: Split into 4 PRs
PR #1: Add user model and database schema (100 lines)
PR #2: Add authentication API endpoints (200 lines)
PR #3: Add login UI components (150 lines)
PR #4: Integrate auth across app (200 lines)

Each PR:
- Easy to review (< 30 min)
- Clear scope
- Can be tested independently
- Higher quality feedback
```

### 3. Self-Review Before Requesting

**The Self-Review Checklist:**

```bash
# 1. Read Your Own Code First
# Open PR in GitHub, review as if you're the reviewer
# You'll catch 30-50% of issues yourself

# 2. Run All Checks Locally
npm run lint           # No warnings
npm run type-check     # No TypeScript errors
npm test               # All tests pass
npm run build          # Builds successfully

# 3. Check for Common Issues
grep -r "console.log" src/     # No debug statements
grep -r "TODO" src/            # Address or document TODOs
grep -r "FIXME" src/           # Fix or create issues

# 4. Review Test Coverage
npm run test:coverage
# Ensure new code has adequate tests

# 5. Check Bundle Size (if applicable)
npm run build
# Check for unexpected size increases
```

**Self-Review Questions:**
- Would I understand this code in 6 months?
- Are variable names descriptive?
- Is there duplicate code?
- Are edge cases handled?
- Are errors handled appropriately?
- Is the code tested?
- Is documentation updated?

### 4. Writing Great PR Descriptions

**The Perfect PR Description:**

```markdown
## Add Email Verification for User Registration

### Summary
Implements email verification to ensure users provide valid email addresses during registration.

### Motivation
**Problem:** Users were registering with fake/invalid emails, causing:
- Failed password reset attempts
- Support unable to contact users
- Bounced marketing emails

**Solution:** Require email verification before account activation.

### Changes
- Add `emailVerified` boolean and `verificationToken` to User model
- Create verification email template
- Add `/api/verify-email/:token` endpoint
- Update registration flow to send verification email
- Add "Resend verification email" functionality
- Update UI to show verification pending state

### Technical Approach
- Generate crypto-secure token (32 bytes, hex)
- Store hashed token in database (prevent token theft)
- Send email via Resend API
- Token expires in 24 hours
- Rate limit: 3 verification emails per hour per user

### Testing

#### Automated Tests
- [x] Unit: Token generation and validation
- [x] Unit: Email template rendering
- [x] Integration: Verification flow end-to-end
- [x] Integration: Token expiration
- [x] Integration: Rate limiting

#### Manual Testing
- [x] Tested happy path (register → email → verify)
- [x] Tested expired token (shows clear error)
- [x] Tested resend email (works, rate limited)
- [x] Tested with real email provider
- [x] Tested mobile responsive (email + UI)

#### Edge Cases Covered
- [x] Token already used
- [x] Token doesn't exist
- [x] User already verified
- [x] Email service down (queued for retry)

### Screenshots

**Verification Email:**
![Email screenshot]

**Pending Verification State:**
![UI screenshot - before]

**After Verification:**
![UI screenshot - after]

### Database Migrations
```sql
-- Migration: add_email_verification
ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN verification_token VARCHAR(255);
ALTER TABLE users ADD COLUMN verification_token_expires_at TIMESTAMP;
CREATE INDEX idx_users_verification_token ON users(verification_token);
```

**Migration tested:** ✅ Up and down migrations work

### Performance Impact
- **Email sending:** Async, doesn't block registration (< 50ms overhead)
- **Verification endpoint:** Single DB query (< 20ms)
- **No impact on** existing endpoints

### Security Considerations
- Tokens are cryptographically secure (crypto.randomBytes)
- Tokens stored hashed (SHA-256)
- Rate limiting prevents abuse
- Tokens expire in 24 hours
- HTTPS only (tokens in URL)

### Breaking Changes
**None.** Existing users are grandfathered (emailVerified defaults to true for existing records).

### Configuration
```env
# New environment variables required
EMAIL_VERIFICATION_TOKEN_EXPIRY=86400  # 24 hours in seconds
EMAIL_VERIFICATION_RATE_LIMIT=3       # emails per hour
```

### Rollback Plan
If issues arise:
1. Feature flag: `FEATURE_EMAIL_VERIFICATION=false`
2. Database rollback: Migration reversible
3. Zero data loss

### Follow-up Work
- [ ] Add email verification reminder (after 48h)
- [ ] Analytics: Track verification completion rate
- [ ] Admin UI: Manually verify users if needed

### Related Issues
- Closes #PRD-123
- Related to #PRD-100 (user authentication)
- Blocks #PRD-150 (password reset flow)

### Reviewers
@backend-lead - Review security and token handling
@frontend-lead - Review UI/UX flow
@product-manager - Verify meets requirements

### Timeline
- Not urgent, can wait for thorough review
- Target merge: End of sprint
- Deploy: Next release (Tuesday)

---

## For Reviewers

**Review Focus:**
- **Security:** Token generation and storage
- **Edge Cases:** Expired tokens, already verified
- **UX:** Clear messaging, mobile responsive
- **Performance:** Email sending doesn't block

**Questions to Consider:**
- Does the token expiration make sense?
- Is rate limiting too strict/too lenient?
- Should we allow changing email after registration?
```

**Why This Is Great:**
- ✅ Complete context (reviewer doesn't need to guess)
- ✅ Technical details (approach, security, performance)
- ✅ Testing thorough (gives reviewer confidence)
- ✅ Screenshots (visual confirmation)
- ✅ Specific reviewer requests (guides review)
- ✅ Rollback plan (shows thoughtfulness)

### 5. Responding to Feedback

**The Art of Receiving Feedback:**

**Response Patterns:**

```markdown
# ✅ GOOD: Accepting and Acknowledging
"Great catch! Fixed in abc123. Thanks for spotting this!"

# ✅ GOOD: Asking for Clarification
"Could you elaborate on the security concern here? I want to make 
sure I understand the attack vector you're thinking of."

# ✅ GOOD: Respectful Disagreement
"I see your point about using approach A. I chose approach B because
[reason]. However, I'm open to switching if you feel strongly. What
do you think about [tradeoff]?"

# ✅ GOOD: Deferring to Follow-up
"Excellent suggestion! This PR is already pretty large. Would you be
okay if I tackled this in a follow-up PR? I'll create issue #456 to
track it."

# ✅ GOOD: Explaining Context
"Good question. The reason I did it this way is [context]. That said,
if there's a better approach I'm definitely open to it."

# ❌ BAD: Dismissive
"I disagree." (No explanation)

# ❌ BAD: Defensive  
"This is how we've always done it."

# ❌ BAD: Ignoring
(No response to comment)

# ❌ BAD: Aggressive
"This comment doesn't make sense."
```

**Timeline for Responses:**
- Acknowledge feedback: Within 4 hours
- Address feedback: Within 24 hours
- Re-request review: After all feedback addressed

---

## For Reviewers: Reviewing Effectively

### 1. Before You Start

**Set the Right Mindset:**
- You're helping improve code, not judging the author
- You might learn something from this code
- The author worked hard on this - respect that effort
- Your feedback helps the whole team

**Time Management:**
- Block dedicated time for reviews (don't multitask)
- 15-30 min for most PRs
- If > 30 min, probably PR is too large

### 2. The Review Process

**Step-by-Step Review:**

```markdown
## 30-Minute Review Process

**Minutes 0-5: Context & Understanding**
- [ ] Read PR title and description thoroughly
- [ ] Understand the why (business need)
- [ ] Understand the what (technical approach)
- [ ] Check linked issues/tickets
- [ ] Note any questions

**Minutes 5-10: High-Level Review**
- [ ] Review changed files list
- [ ] Check overall architecture/approach
- [ ] Identify any major concerns
- [ ] Verify tests are included

**Minutes 10-20: Detailed Code Review**
- [ ] Review each file carefully
- [ ] Check for bugs and edge cases
- [ ] Verify error handling
- [ ] Check security implications
- [ ] Review test quality and coverage
- [ ] Note style/readability issues

**Minutes 20-25: Testing & Documentation**
- [ ] Verify tests run and pass
- [ ] Check test covers new functionality
- [ ] Verify documentation updated
- [ ] Check for breaking changes

**Minutes 25-30: Provide Feedback**
- [ ] Write comments (specific, actionable)
- [ ] Start with positive feedback
- [ ] Use appropriate severity (nit/issue/blocking)
- [ ] Provide examples where helpful
- [ ] Decide: Approve / Request Changes / Comment
```

### 3. What to Look For

**Code Quality Checklist:**

**Readability:**
```typescript
// ❌ BAD: Unclear naming
const d = new Date();
const x = users.filter(u => u.a);

// ✅ GOOD: Descriptive naming
const createdAt = new Date();
const activeUsers = users.filter(user => user.isActive);
```

**Correctness:**
```typescript
// ❌ BAD: Off-by-one error
for (let i = 0; i <= array.length; i++) {  // Will crash!
  console.log(array[i]);
}

// ✅ GOOD: Correct bounds
for (let i = 0; i < array.length; i++) {
  console.log(array[i]);
}
```

**Error Handling:**
```typescript
// ❌ BAD: No error handling
const data = await fetch(url);
const json = data.json();

// ✅ GOOD: Proper error handling
try {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
  const data = await response.json();
  return data;
} catch (error) {
  logger.error('Failed to fetch data', { url, error });
  throw new AppError('Unable to load data', { cause: error });
}
```

**Security:**
```typescript
// ❌ BAD: SQL injection vulnerability
const query = `SELECT * FROM users WHERE id = ${userId}`;

// ✅ GOOD: Parameterized query
const query = 'SELECT * FROM users WHERE id = $1';
const result = await db.query(query, [userId]);
```

**Performance:**
```typescript
// ❌ BAD: N+1 queries
for (const user of users) {
  const posts = await db.query('SELECT * FROM posts WHERE user_id = $1', [user.id]);
}

// ✅ GOOD: Single query
const posts = await db.query('SELECT * FROM posts WHERE user_id = ANY($1)', 
  [users.map(u => u.id)]);
```

### 4. Writing Effective Feedback

**Use Conventional Comments:**

- **nit:** Minor style/preference (not blocking)
- **suggestion:** Optional improvement
- **question:** Asking for clarification
- **issue:** Problem that should be fixed
- **blocking:** Must be fixed before merge
- **praise:** Highlight good solutions!

**Feedback Examples:**

```markdown
### ✅ EXCELLENT Feedback

**praise:** Love this solution! Using `Map` here is much more efficient 
than the array approach. This will scale well.

**question:** Why did we choose 30 seconds for the timeout? Is this based
on user research or a technical constraint? Just curious about the reasoning.

**suggestion:** Consider extracting this validation logic into a separate
function for reusability.

```typescript
// Current
if (!email || !email.includes('@') || email.length < 3) {
  return false;
}

// Suggestion
function isValidEmail(email: string): boolean {
  return !!email && email.includes('@') && email.length >= 3;
}
```

This would make it easier to test and reuse in other places.

**issue:** Missing error handling for the network request. If the API is
down, this will crash the application. Wrap in try/catch?

**blocking:** Security vulnerability - user input isn't sanitized before 
rendering. This is vulnerable to XSS attacks.

```typescript
// Current (vulnerable)
<div dangerouslySetInnerHTML={{ __html: userComment }} />

// Fix needed
import DOMPurify from 'dompurify';
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userComment) }} />
```

---

### ❌ POOR Feedback (Don't Do This)

**Too vague:**
"This isn't good." 
→ What specifically is the problem?

**Not actionable:**
"Fix this."
→ How? What's wrong with it?

**Harsh tone:**
"This is terrible. Who wrote this?"
→ Focus on code, not person. Be kind.

**Nitpicking without context:**
"Use const instead of let."
→ If it's just style, use an automated linter instead.

**Asking for major rewrites:**
"Can you refactor this entire module to use Redux instead?"
→ Should be discussed before PR, not during review.
```

### 5. Making the Decision

**When to Approve:**
- Code meets quality standards
- Tests pass and provide good coverage
- No security vulnerabilities
- Minor nits can be fixed later
- You would be comfortable maintaining this code

**When to Request Changes:**
- Bugs or correctness issues
- Security vulnerabilities
- Missing tests for critical functionality
- Significant performance problems
- Breaking changes without discussion

**When to Comment (no approval/rejection):**
- Have questions but code looks okay
- Want to see discussion before deciding
- Waiting for another reviewer's expertise
- Want author's response before approving

---

## Review Patterns & Examples

### Pattern 1: The Teaching Moment

```markdown
**suggestion:** This works, but there's a more TypeScript-idiomatic way.

Current approach:
```typescript
const names = users.map(function(u) { return u.name; });
```

TypeScript-idiomatic:
```typescript
const names = users.map(user => user.name);
```

Benefits:
- More concise (easier to read)
- Arrow function has lexical `this` binding
- Standard TypeScript convention

Not blocking since current code works fine!
```

### Pattern 2: The Security Catch

```markdown
**blocking:** XSS vulnerability detected

This code renders user input without sanitization:

```tsx
<div>{userComment}</div>  // If userComment contains <script>, it executes!
```

Fix required:
```tsx
import DOMPurify from 'dompurify';

<div dangerouslySetInnerHTML={{ 
  __html: DOMPurify.sanitize(userComment) 
}} />
```

Or better, use a markdown library that sanitizes:
```tsx
import ReactMarkdown from 'react-markdown';

<ReactMarkdown>{userComment}</ReactMarkdown>
```

Security test case needed:
```typescript
it('should prevent XSS attacks in user comments', () => {
  const malicious = '<script>alert("XSS")</script>';
  render(<Comment text={malicious} />);
  expect(screen.queryByText(/script/i)).not.toBeInTheDocument();
});
```
```

### Pattern 3: The Performance Optimization

```markdown
**issue:** N+1 query problem detected

This loop makes 100 database queries (one per user):

```typescript
for (const user of users) {  // 100 users = 100 queries
  const posts = await prisma.post.findMany({
    where: { userId: user.id }
  });
  user.posts = posts;
}
```

Optimize to single query with include:

```typescript
const usersWithPosts = await prisma.user.findMany({
  include: { posts: true }  // Single query, joined in database
});
```

Performance impact:
- Before: 100 queries × 20ms = 2000ms
- After: 1 query × 30ms = 30ms
- **67x faster!**

Should add performance test:
```typescript
it('should fetch users with posts efficiently', async () => {
  const start = Date.now();
  await getUsersWithPosts();
  const duration = Date.now() - start;
  expect(duration).toBeLessThan(100); // Should be < 100ms
});
```
```

### Pattern 4: The Praise (Do More of This!)

```markdown
**praise:** Excellent error handling! 🎉

I love how you:
1. Caught the specific error type
2. Logged with context for debugging
3. Showed user-friendly message
4. Included retry logic

```typescript
try {
  return await sendEmail(to, subject, body);
} catch (error) {
  if (error instanceof RateLimitError) {
    logger.warn('Rate limit hit', { to, retryAfter: error.retryAfter });
    return { success: false, retryAfter: error.retryAfter };
  }
  logger.error('Email send failed', { to, subject, error });
  throw new AppError('Unable to send email', { cause: error });
}
```

This is exactly how we should handle errors. Great example for the team!
```

---

## Common Pitfalls & Solutions

### Pitfall 1: Review Fatigue

**Problem:** Large PRs cause reviewers to skim, missing issues.

**Solution:**
- **Authors:** Keep PRs < 200 lines (split if needed)
- **Reviewers:** Push back on large PRs
- **Team:** Establish PR size guidelines

### Pitfall 2: Rubber Stamp Reviews

**Problem:** Reviewers approve without reading (just to clear queue).

**Solution:**
- **Track:** Time spent reviewing (should be > 5 min)
- **Require:** At least one substantial comment per review
- **Culture:** Reward thorough reviews, not quick approvals

### Pitfall 3: Endless Debates

**Problem:** Reviewers and authors argue over subjective preferences.

**Solution:**
- **Automate:** Use linters for style (Prettier, ESLint)
- **Document:** Team coding standards
- **Escalate:** If can't agree, bring in tech lead
- **Timebox:** If discussion > 15 min, move to video call

### Pitfall 4: Delayed Reviews

**Problem:** PRs sit for days waiting for review.

**Solution:**
- **Track:** Time to first review (target < 24 hours)
- **Rotate:** Assign reviews fairly across team
- **Block Time:** Dedicated review time daily (e.g., 10-11am)
- **Notify:** Slack/email when review requested

### Pitfall 5: Harsh Feedback

**Problem:** Reviewers come across as mean or dismissive.

**Solution:**
- **Train:** Code review etiquette for all team members
- **Model:** Tech leads should demonstrate good feedback
- **Template:** Use conventional comments (nit, suggestion, etc.)
- **Remember:** Focus on code, not person

---

## Metrics & Continuous Improvement

### Key Metrics to Track

**Review Efficiency:**
- Time to first review (target: < 24 hours)
- Time to approval (target: < 48 hours)
- Number of review rounds (target: 1-2)

**Code Quality:**
- Bugs caught in review vs production
- % of PRs with tests
- Test coverage trend

**Team Health:**
- Review participation (all team members)
- PR size distribution (should be mostly < 200 lines)
- Review sentiment (anonymous survey)

### Continuous Improvement

**Quarterly Review:**
```markdown
## Code Review Retrospective

**What's working well?**
- Fast review turnaround (avg 18 hours)
- Catching bugs early (85% in review)

**What could improve?**
- Some PRs too large (20% > 400 lines)
- Not enough performance review

**Action items:**
- Add PR size checks in CI/CD
- Create performance review checklist
- Share performance optimization examples
```

---

## Tools & Automation

### Essential Tools

**GitHub/GitLab:**
- PR templates
- CODEOWNERS for auto-assignment
- Required reviewers
- Protected branches

**CI/CD Integration:**
- Linting (ESLint, Prettier)
- Type checking (TypeScript)
- Tests (Jest)
- Security scanning (Snyk)
- Bundle size checks

**Review Automation:**
- Danger JS (automate common checks)
- CodeClimate (code quality metrics)
- SonarQube (code analysis)

### Sample Danger JS Rules

```javascript
// dangerfile.js
import { danger, warn, fail, message } from 'danger';

// PR size check
const bigPRThreshold = 400;
if (danger.github.pr.additions > bigPRThreshold) {
  warn(`This PR is quite large (${danger.github.pr.additions} lines). Consider splitting it up.`);
}

// Tests required
const hasTests = danger.git.created_files.some(f => f.includes('.test.'));
if (!hasTests) {
  warn('This PR doesn't include tests. Consider adding tests for new functionality.');
}

// Changelog updated
const hasChangelog = danger.git.modified_files.includes('CHANGELOG.md');
if (!hasChangelog) {
  warn('Please update CHANGELOG.md with this change.');
}

// Good practices
if (danger.git.created_files.length > 10) {
  message('Nice work on the new feature! 🎉');
}
```

---

## Case Studies

### Case Study 1: Catching a Critical Bug

**PR:** Add user authentication  
**Reviewer:** @security-expert  

**Issue Found:**
```typescript
// Author's code
const token = Math.random().toString(36);  // WEAK!
```

**Reviewer Comment:**
```markdown
**blocking:** Insecure token generation

`Math.random()` is not cryptographically secure. An attacker could 
predict token values and hijack sessions.

Use crypto.randomBytes instead:

```typescript
import { randomBytes } from 'crypto';

const token = randomBytes(32).toString('hex');
```

This generates a cryptographically secure 64-character hex string.
```

**Outcome:** Critical security vulnerability caught before production. Author implemented fix and added test. Bug would have affected all users.

**Lesson:** Security review is crucial. Domain experts catch issues others might miss.

---

### Case Study 2: Performance Optimization Discussion

**PR:** Optimize dashboard loading  
**Reviewer:** @performance-expert  

**Initial Code:**
```typescript
// Fetch data sequentially
const users = await getUsers();
const posts = await getPosts();
const comments = await getComments();
```

**Reviewer Suggestion:**
```markdown
**suggestion:** Parallel fetching would speed this up

Current: 300ms + 200ms + 150ms = 650ms total (sequential)

Suggested:
```typescript
const [users, posts, comments] = await Promise.all([
  getUsers(),    // These run in parallel
  getPosts(),
  getComments()
]);
```

New: max(300ms, 200ms, 150ms) = 300ms total (parallel)

**2x faster!**
```

**Outcome:** Author implemented suggestion. Dashboard loading improved from 650ms to 300ms. Great collaborative optimization!

**Lesson:** Constructive performance suggestions improve the product.

---

## Quick Reference

### For Authors

✅ **DO:**
- Keep PRs small (< 200 lines)
- Self-review before requesting
- Write clear descriptions
- Respond to feedback promptly
- Thank your reviewers

❌ **DON'T:**
- Submit > 400 line PRs without justification
- Request review before self-reviewing
- Be defensive about feedback
- Ignore comments

### For Reviewers

✅ **DO:**
- Review within 24 hours
- Be specific and constructive
- Provide examples
- Praise good solutions
- Focus on impact (bugs, security, performance)

❌ **DON'T:**
- Nitpick style (automate it)
- Be vague or harsh
- Request major rewrites during review
- Rubber stamp without reading

---

## Related Resources

- **Rules:** @101-code-review-standards.mdc
- **Workflow:** @803-pull-request-workflow.mdc
- **Git:** @802-git-workflow-standards.mdc
- **Hotfixes:** @804-hotfix-procedures.mdc

---

**Remember:** Code reviews are about collaboration, learning, and building better software together. Be kind, be constructive, and help your team succeed! 🚀

