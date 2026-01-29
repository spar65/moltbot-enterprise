# Incident Response Complete Guide

**The definitive playbook for handling production incidents with speed, coordination, and learning.**

## Table of Contents

1. [Overview](#overview)
2. [Incident Severity Levels](#incident-severity-levels)
3. [Incident Roles](#incident-roles)
4. [Detection & Declaration](#detection--declaration)
5. [Response Workflow](#response-workflow)
6. [Communication](#communication)
7. [Resolution & Recovery](#resolution--recovery)
8. [Post-Incident Review](#post-incident-review)
9. [On-Call Management](#on-call-management)
10. [Runbooks](#runbooks)

---

## Overview

### What is an Incident?

> **An incident is any event that degrades or threatens the availability, performance, or security of your service.**

Examples:
- API returning 500 errors
- Database connection failures
- Security breach or suspicious activity
- Deployment causing regression
- Third-party service outage affecting your system

### Incident Response Goals

1. **Minimize Impact**: Reduce the blast radius and duration
2. **Communicate Clearly**: Keep stakeholders informed
3. **Restore Service**: Get back to normal operations quickly
4. **Learn & Improve**: Prevent similar incidents in the future

### Key Metrics

- **MTTD (Mean Time to Detect)**: How fast do we find problems?
- **MTTR (Mean Time to Resolve)**: How fast do we fix them?
- **MTBF (Mean Time Between Failures)**: How often do incidents occur?

Target: MTTD < 5 minutes, MTTR < 30 minutes

---

## Incident Severity Levels

### Severity 1 (Critical)
**Impact**: Service completely unavailable or major security breach

**Examples**:
- All API requests failing
- Database unavailable
- Data breach or security compromise
- Payment processing completely broken

**Response Time**: Immediate (< 5 minutes)

**Escalation**: Page on-call primary immediately, escalate to secondary after 5 minutes

**Communication**: Real-time updates every 15 minutes

---

### Severity 2 (High)
**Impact**: Significant degradation affecting multiple users

**Examples**:
- API latency > 5 seconds
- Error rate > 10%
- Critical feature broken for all users
- Database replication lag > 5 minutes

**Response Time**: Within 15 minutes

**Escalation**: Notify on-call primary, page if no response in 15 minutes

**Communication**: Updates every 30 minutes

---

### Severity 3 (Medium)
**Impact**: Partial degradation affecting some users

**Examples**:
- Single feature broken
- Error rate 1-10%
- Slow performance for specific endpoints
- Non-critical service degraded

**Response Time**: Within 1 hour

**Escalation**: Notify on-call primary (no page)

**Communication**: Updates as major progress occurs

---

### Severity 4 (Low)
**Impact**: Minor issue with workaround available

**Examples**:
- UI glitch
- Cosmetic bug
- Performance issue affecting < 1% of requests
- Non-critical feature degraded

**Response Time**: Next business day

**Escalation**: Create ticket, no immediate notification

**Communication**: Included in regular updates

---

## Incident Roles

### Incident Commander (IC)
**Primary responsibility**: Coordinate incident response

**Duties**:
- Declare incident and severity
- Assign roles to responders
- Drive incident to resolution
- Maintain timeline of events
- Coordinate communication
- Declare incident resolved
- Schedule post-incident review

**Who**: On-call engineer or senior engineer for complex incidents

---

### Technical Lead
**Primary responsibility**: Drive technical investigation and resolution

**Duties**:
- Investigate root cause
- Propose and implement fixes
- Coordinate with other engineers
- Provide technical updates to IC
- Ensure fix doesn't cause additional issues

**Who**: Engineer with relevant domain expertise

---

### Communications Lead
**Primary responsibility**: Manage stakeholder communication

**Duties**:
- Post updates to status page
- Notify affected customers
- Coordinate with support team
- Draft incident summary
- Respond to escalations

**Who**: Engineering manager or designated communications person

---

### Scribe
**Primary responsibility**: Document incident timeline

**Duties**:
- Record all actions taken
- Note timestamps of key events
- Capture decisions and rationale
- Document hypothesis and testing
- Maintain shared incident document

**Who**: Any available engineer

---

## Detection & Declaration

### Detection Methods

#### 1. Automated Monitoring
```typescript
// Alert triggers incident
{
  alert: 'High Error Rate',
  severity: 'critical',
  metric: 'api_error_rate',
  value: 15,  // %
  threshold: 1,  // %
  duration: '5m'
}
```

#### 2. User Reports
```
Subject: Can't login to application
From: customer@example.com

I'm getting "500 Internal Server Error" when trying to log in.
This has been happening for the last 10 minutes.
```

#### 3. Internal Discovery
```
Engineer: "Hey, I'm seeing database connection timeouts in logs.
Anyone else seeing this?"
```

### Incident Declaration

**When to declare an incident**:
- Service is degraded or unavailable
- Security concern identified
- Multiple users reporting issues
- Alert indicates system health problem
- When in doubt, declare! (Better safe than sorry)

**How to declare**:
```bash
# Via Slack command
/incident declare severity=1 "API returning 500 errors"

# Via PagerDuty
# Create incident via UI or API with severity and description
```

**Incident Declaration Checklist**:
- [ ] Assign severity level
- [ ] Create incident channel (#incident-YYYY-MM-DD-short-description)
- [ ] Assign Incident Commander
- [ ] Create shared incident document
- [ ] Post initial status update
- [ ] Start timer for MTTR tracking

---

## Response Workflow

### Phase 1: Assess (First 5 minutes)

1. **Gather Information**
   - What is the user-facing impact?
   - How many users are affected?
   - When did the problem start?
   - What changed recently?

2. **Check Dashboards**
   - Error rates spiking?
   - Latency increased?
   - Resource utilization abnormal?
   - Database issues?

3. **Review Recent Changes**
   - Deployments in last hour?
   - Configuration changes?
   - Database migrations?
   - Third-party service issues?

4. **Confirm Severity**
   - Validate initial severity assessment
   - Escalate or de-escalate as needed

---

### Phase 2: Mitigate (First 15 minutes)

**Goal**: Reduce blast radius and stop the bleeding

**Quick Mitigation Options**:

#### Option 1: Rollback
```bash
# Rollback to previous deployment
vercel rollback

# Verify rollback successful
curl https://api.example.com/health
```

#### Option 2: Toggle Feature Flag
```typescript
// Disable problematic feature
await disableFeatureFlag('new-payment-flow');
```

#### Option 3: Scale Resources
```bash
# Scale up database connections
# Scale up serverless concurrency
# Add more containers
```

#### Option 4: Circuit Breaker
```typescript
// Stop calling failing external service
circuitBreaker.open('external-payment-api');
```

#### Option 5: Maintenance Mode
```typescript
// Enable maintenance mode to stop traffic
await enableMaintenanceMode({
  message: 'We are experiencing technical difficulties. Back soon!',
  estimatedDuration: '30 minutes'
});
```

---

### Phase 3: Investigate (Ongoing)

**Parallel to mitigation**, investigate root cause:

1. **Check Logs**
   ```bash
   # Search for errors in time range
   grep -A 10 "ERROR" logs/app.log | grep "2024-11-20 14:"
   ```

2. **Review Metrics**
   - Database connection pool exhausted?
   - Memory leak?
   - Slow query?
   - Rate limit hit?

3. **Test Hypothesis**
   ```
   Hypothesis: Database connection pool exhausted
   Test: Check connection pool metrics
   Result: 100/100 connections in use, 50 waiting
   Conclusion: Confirmed! Need to increase pool size or find leak
   ```

4. **Narrow Down**
   - Specific endpoint affected?
   - Specific user segment?
   - Specific database table?
   - Specific time range?

---

### Phase 4: Resolve (Goal: < 30 minutes)

1. **Implement Fix**
   ```typescript
   // Example: Increase connection pool size
   const prisma = new PrismaClient({
     datasources: {
       db: {
         url: process.env.DATABASE_URL,
       },
     },
     // Increase pool size
     connection_limit: 20,  // Was 10
   });
   ```

2. **Test Fix**
   - Validate in staging if possible
   - Canary deploy if available
   - Monitor closely after deployment

3. **Deploy Fix**
   ```bash
   git commit -m "fix: increase database connection pool size"
   git push origin hotfix/increase-db-pool
   # Deploy via CI/CD
   ```

4. **Verify Resolution**
   - Error rate back to normal?
   - Latency back to baseline?
   - Users can complete workflows?
   - No new issues introduced?

---

## Communication

### Status Page Updates

#### During Incident
```markdown
🔴 Investigating: Users may experience login failures

We are investigating reports of login failures affecting some users.
Our team is actively working on a resolution.

Last updated: 2024-11-20 14:35 PST
```

```markdown
🟡 Identified: Database connection issues causing login failures

We have identified the root cause as database connection pool exhaustion.
Our team is implementing a fix.

Last updated: 2024-11-20 14:50 PST
```

```markdown
🟢 Resolved: Login functionality restored

The issue has been resolved. All systems are operating normally.
We will continue to monitor closely.

Last updated: 2024-11-20 15:10 PST
```

### Internal Communication

**Incident Channel (#incident-YYYY-MM-DD-description)**:
```
[14:30] @alice (IC): Incident declared - SEV1 - API 500 errors
[14:30] @alice (IC): @bob you're Technical Lead, @charlie Communications
[14:32] @bob (TL): Checking dashboards... seeing 15% error rate
[14:33] @charlie (Comms): Status page updated
[14:35] @bob (TL): Found issue: database connection pool exhausted
[14:36] @alice (IC): Any quick mitigation options?
[14:37] @bob (TL): Increasing pool size and deploying now
[14:42] @bob (TL): Fix deployed, monitoring...
[14:45] @bob (TL): Error rate dropping, now at 2%
[14:50] @bob (TL): Error rate back to baseline (0.1%)
[14:51] @alice (IC): Excellent! Declaring incident resolved
[14:51] @charlie (Comms): Status page updated to resolved
```

### Customer Communication

```
Subject: Incident Report - Login Service Interruption

Dear Valued Customer,

On November 20, 2024, between 14:30 and 15:10 PST, some users 
experienced difficulties logging into our application.

What happened:
Our database connection pool reached capacity, causing login 
requests to fail with error messages.

What we did:
Our engineering team identified the issue within 5 minutes and 
deployed a fix within 40 minutes. We have also implemented 
additional monitoring to prevent similar issues.

Impact:
Approximately 15% of login attempts failed during this window.
No data was lost or compromised.

We sincerely apologize for this disruption and have taken steps 
to prevent recurrence.

If you have any questions, please contact support@example.com.

Best regards,
Engineering Team
```

---

## Resolution & Recovery

### Resolution Criteria

An incident is resolved when:
- [ ] Root cause identified and addressed
- [ ] User-facing symptoms eliminated
- [ ] Metrics returned to normal
- [ ] No ongoing monitoring alerts
- [ ] Fix validated in production
- [ ] Incident Commander declares resolution

### Recovery Checklist

- [ ] Verify fix addresses root cause
- [ ] Check for any side effects of fix
- [ ] Confirm all systems operating normally
- [ ] Validate with affected users if possible
- [ ] Update status page to "Resolved"
- [ ] Close incident in PagerDuty/monitoring system
- [ ] Thank responders in incident channel
- [ ] Schedule post-incident review

---

## Post-Incident Review

### Purpose
- Understand what happened and why
- Identify action items to prevent recurrence
- Celebrate effective response
- Learn and improve

### Timeline
Schedule within 2 business days of incident resolution

### Participants
- Incident Commander
- Technical Lead(s)
- Engineering Manager
- Any other key responders

### Review Structure

#### 1. Timeline Review
```
14:30 - Alert triggered: API error rate > 10%
14:31 - On-call engineer paged
14:32 - Incident declared (SEV1)
14:35 - Root cause identified: DB connection pool exhausted
14:37 - Fix implemented: Increased pool size
14:42 - Fix deployed to production
14:50 - Error rate returned to normal
14:51 - Incident declared resolved
```

#### 2. Root Cause Analysis (5 Whys)
```
Problem: Login API returned 500 errors

Why? Database connections failed
Why? Connection pool exhausted
Why? More connections requested than available
Why? Traffic spike from new feature launch
Why? Connection pool size not adjusted for increased traffic

Root cause: Connection pool size not scaled with traffic growth
```

#### 3. What Went Well
- Alert triggered within 1 minute of issue starting
- Incident declared quickly (< 2 minutes)
- Root cause identified in 5 minutes
- Fix deployed within 40 minutes
- Clear communication throughout
- No data loss or security impact

#### 4. What Could Be Improved
- Connection pool monitoring was insufficient
- Load testing didn't catch this scenario
- No automatic scaling for connection pool
- Status page updates could have been more frequent

#### 5. Action Items
| Action | Owner | Priority | Due Date |
|--------|-------|----------|----------|
| Add connection pool metrics to dashboard | @bob | P0 | Nov 22 |
| Implement connection pool auto-scaling | @alice | P1 | Nov 30 |
| Add load tests for new features | @charlie | P1 | Nov 30 |
| Document connection pool tuning | @bob | P2 | Dec 5 |

### Post-Incident Document Template

```markdown
# Incident Report: Login Service Degradation

## Summary
On November 20, 2024, users experienced login failures due to 
database connection pool exhaustion.

**Duration**: 40 minutes (14:30 - 15:10 PST)
**Severity**: SEV1 (Critical)
**Impact**: ~15% of login attempts failed

## Timeline
[Detailed timeline here]

## Root Cause
[5 Whys analysis here]

## Resolution
[What fixed it]

## Action Items
[Table of action items with owners and due dates]

## Lessons Learned
[What went well, what could improve]
```

---

## On-Call Management

### On-Call Schedule

**Primary On-Call**:
- First responder to all alerts
- Incident Commander for new incidents
- Expected response time: < 5 minutes

**Secondary On-Call**:
- Escalation point if primary doesn't respond
- Backup for complex incidents
- Expected response time: < 15 minutes

**Rotation**: Weekly rotation, Monday to Monday

### On-Call Responsibilities

**Before Your Shift**:
- [ ] Review recent incidents
- [ ] Check open action items
- [ ] Test alert delivery (phone, Slack, email)
- [ ] Review runbooks
- [ ] Ensure laptop/phone charged
- [ ] Have stable internet access

**During Your Shift**:
- [ ] Respond to alerts within SLA
- [ ] Declare incidents when appropriate
- [ ] Act as Incident Commander
- [ ] Document all incidents
- [ ] Escalate when needed
- [ ] Keep laptop nearby

**After Your Shift**:
- [ ] Hand off any ongoing issues
- [ ] Update runbooks based on learnings
- [ ] Complete incident reports
- [ ] Create tickets for follow-up work

### On-Call Compensation

- Base on-call pay: $X per week
- Incident response pay: $Y per hour of active incident
- Day-of-week rates may vary
- Holiday rates typically 2x normal

---

## Runbooks

### Runbook Template

```markdown
# Runbook: [Problem Name]

## Symptoms
- What the user sees
- What monitoring shows
- Common error messages

## Severity
SEV1 / SEV2 / SEV3 / SEV4

## Detection
- How this is usually detected
- Relevant alerts
- Monitoring dashboards

## Triage Steps
1. Check [Dashboard X]
2. Review logs: `grep "ERROR" /var/log/app.log`
3. Verify [Service Y] is responding

## Quick Mitigation
### Option 1: Rollback
```bash
vercel rollback
```

### Option 2: Restart Service
```bash
systemctl restart app-service
```

## Investigation
1. Check recent deployments
2. Review database slow queries
3. Check external API status

## Resolution Steps
1. [Step-by-step fix]
2. [Verification]
3. [Monitoring]

## Escalation
- If issue persists > 15 minutes, escalate to @team-lead
- For database issues, page @database-admin

## Related Incidents
- [Link to similar past incidents]

## Related Documentation
- [Architecture docs]
- [Monitoring dashboards]
```

### Common Runbooks

1. **High Error Rate** - API returning 500s
2. **High Latency** - Slow response times
3. **Database Issues** - Connection failures, slow queries
4. **Deployment Failures** - Rollback procedures
5. **Security Incidents** - Breach response
6. **Third-Party Outages** - External API failures

---

## Related Resources

### Rules
- @210-operations-incidents.mdc - Operations and incidents
- @221-application-monitoring.mdc - Application monitoring
- @804-hotfix-procedures.mdc - Hotfix emergency response

### Tools
- `.cursor/tools/check-incident-status.sh` - Check active incidents
- `.cursor/tools/create-incident.sh` - Declare new incident

### Guides
- `guides/Monitoring-Complete-Guide.md` - Monitoring best practices
- `guides/Hotfix-Deployment-Guide.md` - Emergency deployment procedures

---

## Quick Start Checklist

- [ ] Define severity levels for your organization
- [ ] Set up on-call rotation
- [ ] Create incident response Slack channel
- [ ] Write runbooks for common issues
- [ ] Configure alerting and escalation
- [ ] Document communication procedures
- [ ] Schedule post-incident review template
- [ ] Train team on incident response
- [ ] Conduct incident response drills
- [ ] Review and update procedures quarterly

---

**Remember**: The goal is not to eliminate all incidents (impossible), but to:
1. **Detect** them quickly
2. **Respond** effectively
3. **Learn** from each one
4. **Prevent** recurrence through systemic improvements

**You've got this! 💪**

