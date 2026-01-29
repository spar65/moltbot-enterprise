# Email Deliverability Complete Guide

**Last Updated**: November 20, 2025  
**Version**: 2.0 (Gmail/Yahoo 2024 Requirements)  
**Status**: Production-Ready ✅

---

## 📋 Table of Contents

1. [Introduction](#introduction)
2. [Gmail & Yahoo 2024 Requirements (CRITICAL)](#gmail-yahoo-2024)
3. [Email Authentication Setup](#email-authentication)
4. [Sender Reputation Management](#sender-reputation)
5. [One-Click Unsubscribe Implementation](#one-click-unsubscribe)
6. [Spam Complaint Rate Management](#spam-complaint-rate)
7. [Content Optimization for Deliverability](#content-optimization)
8. [Monitoring and Maintenance](#monitoring)
9. [Troubleshooting Deliverability Issues](#troubleshooting)
10. [Emergency Response Procedures](#emergency-response)

---

## <a name="introduction"></a>1. Introduction

### Why This Guide Exists

Email deliverability has fundamentally changed in 2024. Gmail and Yahoo announced **mandatory requirements** that went into effect February 2024, affecting all bulk email senders. Non-compliance results in email rejection or spam folder placement.

This guide provides **step-by-step implementation** for meeting these requirements and maintaining excellent deliverability.

### Who Should Read This

- ✅ Email marketing developers and administrators
- ✅ DevOps engineers managing email infrastructure
- ✅ Marketing managers overseeing email campaigns
- ✅ Anyone sending bulk marketing emails (500+ per day)

### Critical Success Factors

| Factor | Requirement | Impact if Missing |
|--------|-------------|-------------------|
| **SPF Authentication** | REQUIRED | Emails rejected |
| **DKIM Authentication** | REQUIRED | Emails rejected |
| **DMARC Policy** | REQUIRED | Emails rejected |
| **One-Click Unsubscribe** | REQUIRED | Emails go to spam |
| **Spam Rate < 0.3%** | REQUIRED | Emails blocked |

---

## <a name="gmail-yahoo-2024"></a>2. Gmail & Yahoo 2024 Requirements (CRITICAL)

### What Changed in February 2024

Gmail and Yahoo implemented **mandatory requirements** for all senders of marketing emails:

#### 🚨 **MANDATORY REQUIREMENT #1: Email Authentication**

All bulk emails MUST have:
- ✅ SPF record configured
- ✅ DKIM signing enabled
- ✅ DMARC policy set (minimum `p=none`)

**Impact**: Emails without authentication are **REJECTED**.

#### 🚨 **MANDATORY REQUIREMENT #2: One-Click Unsubscribe (RFC 8058)**

All marketing emails MUST include:
- ✅ `List-Unsubscribe` header with HTTPS URL
- ✅ `List-Unsubscribe-Post` header (RFC 8058)
- ✅ Unsubscribe processed within 2 seconds
- ✅ No login or additional steps required

**Impact**: Emails without one-click unsubscribe go to **SPAM FOLDER**.

#### 🚨 **MANDATORY REQUIREMENT #3: Spam Complaint Rate < 0.3%**

Maintain spam complaint rate below 0.3% as measured in Google Postmaster Tools.

**Impact**: Exceeding 0.3% results in email **BLOCKING** or spam folder placement.

### Compliance Checklist

Use this checklist to verify compliance:

```bash
# Run automated compliance check
./.cursor/tools/check-email-compliance.sh --domain yourdomain.com

# Manual verification checklist:
□ SPF record exists for sending domain
□ DKIM signing configured in email service provider
□ DMARC policy set (minimum p=none)
□ List-Unsubscribe header in all marketing emails
□ List-Unsubscribe-Post header in all marketing emails
□ Unsubscribe endpoint processes requests < 2 seconds
□ Spam complaint rate monitored in Google Postmaster Tools
□ Spam complaint rate < 0.3% (target: < 0.2%)
```

---

## <a name="email-authentication"></a>3. Email Authentication Setup

### SPF (Sender Policy Framework)

**Purpose**: Authorize mail servers to send on behalf of your domain.

#### Step 1: Create SPF Record

Add TXT record to your DNS:

```dns
# Basic SPF record
v=spf1 include:_spf.google.com include:mailchimp.com ~all

# Breakdown:
# v=spf1          - SPF version
# include:...     - Authorized senders
# ~all            - Soft fail (recommended during testing)
# -all            - Hard fail (use after testing)
```

#### Step 2: Verify SPF Record

```bash
# Check SPF record
dig +short TXT yourdomain.com | grep spf

# Or use online tool
# https://mxtoolbox.com/spf.aspx
```

#### Step 3: SPF Best Practices

- ✅ Use `include:` for third-party senders (MailChimp, SendGrid, etc.)
- ✅ Limit DNS lookups to 10 maximum (SPF limit)
- ✅ Use subdomains for different email types (marketing.yourdomain.com)
- ✅ Test with `~all` before switching to `-all`
- ❌ Don't use multiple SPF records (only one per domain)

### DKIM (DomainKeys Identified Mail)

**Purpose**: Cryptographically sign emails to prove authenticity.

#### Step 1: Generate DKIM Keys

Most email service providers (MailChimp, SendGrid) generate DKIM keys automatically.

**For MailChimp**:
1. Go to Settings → Domains → Verify Domain
2. MailChimp generates DKIM record
3. Add TXT record to DNS

**Example DKIM Record**:
```dns
# Record name
k1._domainkey.yourdomain.com

# Record value
v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC...
```

#### Step 2: Verify DKIM Record

```bash
# Check DKIM record (replace k1 with your selector)
dig +short TXT k1._domainkey.yourdomain.com

# Verify DKIM signing (send test email)
# Check email headers for "DKIM-Signature" header
```

#### Step 3: DKIM Best Practices

- ✅ Use 2048-bit keys (more secure than 1024-bit)
- ✅ Rotate keys annually for security
- ✅ Use separate keys per subdomain
- ✅ Test DKIM signing before production use
- ✅ Monitor DKIM failures in DMARC reports

### DMARC (Domain-based Message Authentication)

**Purpose**: Tell recipients how to handle emails that fail SPF/DKIM checks.

#### Step 1: Create DMARC Record

Add TXT record to DNS for `_dmarc.yourdomain.com`:

```dns
# Basic DMARC record (monitoring only)
v=DMARC1; p=none; rua=mailto:dmarc@yourdomain.com; ruf=mailto:dmarc@yourdomain.com; pct=100

# Breakdown:
# v=DMARC1                          - DMARC version
# p=none                            - Policy: monitor only (start here)
# rua=mailto:dmarc@yourdomain.com   - Aggregate reports
# ruf=mailto:dmarc@yourdomain.com   - Forensic reports
# pct=100                           - Apply to 100% of emails
```

#### Step 2: DMARC Policy Progression

**Phase 1: Monitoring (p=none)** - Start here
```dns
v=DMARC1; p=none; rua=mailto:dmarc@yourdomain.com; pct=100
```
- Monitor for 2-4 weeks
- Review aggregate reports
- Identify legitimate senders
- Fix authentication issues

**Phase 2: Quarantine (p=quarantine)** - After monitoring
```dns
v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com; pct=10
```
- Start with 10% of emails (pct=10)
- Gradually increase to 100%
- Failed emails go to spam folder

**Phase 3: Reject (p=reject)** - Final state
```dns
v=DMARC1; p=reject; rua=mailto:dmarc@yourdomain.com; pct=100
```
- Failed emails are rejected
- Maximum protection against spoofing

#### Step 3: Verify DMARC Record

```bash
# Check DMARC record
dig +short TXT _dmarc.yourdomain.com

# Expected output should contain "v=DMARC1"
```

#### Step 4: DMARC Report Analysis

**Tools for DMARC Report Analysis**:
- [Postmark DMARC Digests](https://dmarc.postmarkapp.com/) (Free)
- [Dmarcian](https://dmarcian.com/) (Paid)
- [EasyDMARC](https://easydmarc.com/) (Paid)

**What to Look For in Reports**:
- ✅ SPF pass rate > 99%
- ✅ DKIM pass rate > 99%
- ✅ DMARC alignment pass rate > 99%
- ⚠️ Identify unauthorized senders
- ⚠️ Fix legitimate senders failing authentication

### BIMI (Brand Indicators for Message Identification)

**Purpose**: Display brand logo in email clients (optional but recommended).

#### Step 1: Requirements for BIMI

- ✅ DMARC policy set to `p=quarantine` or `p=reject`
- ✅ SVG logo file (specific requirements)
- ✅ VMC (Verified Mark Certificate) from authorized CA

#### Step 2: Create BIMI Record

```dns
# Record name
default._bimi.yourdomain.com

# Record value
v=BIMI1; l=https://yourdomain.com/logo.svg; a=https://yourdomain.com/vmc.pem
```

#### Step 3: BIMI Logo Requirements

- Format: SVG Tiny 1.2
- Size: Square (1:1 aspect ratio)
- File size: < 32 KB
- Centered in canvas
- No external dependencies

---

## <a name="sender-reputation"></a>4. Sender Reputation Management

### Understanding Sender Reputation

**Sender reputation** is a score (0-100) assigned to your sending IP address and domain based on:
- Email authentication (SPF, DKIM, DMARC)
- Spam complaint rates
- Bounce rates
- Engagement rates (opens, clicks)
- Sending patterns and volume
- Spam trap hits
- Blacklist status

### IP Warming for New Senders

**Why IP Warming is Critical**: Cold IPs have no reputation. Sending high volumes immediately triggers spam filters.

#### IP Warming Schedule

| Week | Daily Volume | Notes |
|------|--------------|-------|
| Week 1 | 50-100 | Start with most engaged users |
| Week 2 | 100-500 | Monitor bounce/complaint rates |
| Week 3 | 500-1,000 | Gradually expand audience |
| Week 4 | 1,000-5,000 | Continue monitoring closely |
| Week 5-6 | 5,000-10,000 | Approach target volume |
| Week 7+ | 10,000+ | Full volume (monitor continuously) |

#### IP Warming Best Practices

- ✅ Start with highly engaged subscribers
- ✅ Use best-performing content
- ✅ Monitor bounce/complaint rates daily
- ✅ Pause if complaint rate exceeds 0.2%
- ✅ Maintain consistent sending schedule
- ❌ Don't skip days (maintains rhythm)
- ❌ Don't send to old/inactive lists during warming

### Monitoring Sender Reputation

#### Google Postmaster Tools (CRITICAL)

**Setup**:
1. Visit [https://postmaster.google.com](https://postmaster.google.com)
2. Add your domain
3. Verify domain ownership (TXT record)

**Key Metrics**:
- **Spam Rate**: MUST stay below 0.3% (target < 0.1%)
- **Domain Reputation**: High (green) = good, Medium/Low (yellow/red) = problems
- **IP Reputation**: Similar to domain reputation
- **Authentication**: Should show 100% passing
- **Encryption**: Should show 100% TLS

#### Microsoft SNDS (Smart Network Data Services)

**Setup**:
1. Visit [https://postmaster.live.com/snds](https://postmaster.live.com/snds)
2. Register your sending IP addresses

**Color Codes**:
- 🟢 Green: Good reputation
- 🟡 Yellow: Some issues detected
- 🔴 Red: Poor reputation, deliverability impacted

#### Other Reputation Monitoring Tools

- **SenderScore** ([https://senderscore.org](https://senderscore.org))
  - Free score (0-100)
  - Update daily
  - Target: > 90

- **Barracuda Reputation**
  - Check IP/domain reputation
  - Free lookup

### Bounce Management

#### Types of Bounces

**Hard Bounces** (Permanent failures):
- Invalid email address
- Domain doesn't exist
- Mailbox doesn't exist

**Action**: Remove immediately from list

**Soft Bounces** (Temporary failures):
- Mailbox full
- Server temporarily unavailable
- Email too large

**Action**: Retry 3-5 times, then remove

#### Bounce Rate Targets

| Bounce Type | Target Rate | Warning Threshold | Critical Threshold |
|-------------|-------------|-------------------|-------------------|
| Hard Bounces | < 2% | > 3% | > 5% |
| Soft Bounces | < 3% | > 5% | > 10% |
| Total Bounces | < 5% | > 8% | > 15% |

### Complaint Management

#### Spam Complaint Sources

1. **Feedback Loops (FBL)**
   - ISPs send complaint notifications
   - Set up FBLs with major ISPs (Gmail, Yahoo, Outlook)

2. **Google Postmaster Tools**
   - Real-time spam rate monitoring
   - CRITICAL for Gmail deliverability

3. **Email Service Provider Reports**
   - MailChimp, SendGrid provide complaint rates

#### Complaint Rate Targets (2024 Requirements)

| Status | Complaint Rate | Action Required |
|--------|----------------|-----------------|
| 🟢 Excellent | < 0.1% | Maintain current practices |
| 🟡 Good | 0.1% - 0.2% | Monitor closely |
| 🟠 Warning | 0.2% - 0.3% | Immediate investigation |
| 🔴 CRITICAL | > 0.3% | **EMERGENCY** - Email blocking |

#### Response to High Complaint Rates

**Immediate Actions (< 1 hour)**:
1. Pause all email campaigns
2. Investigate recent sends (content, segments, frequency)
3. Check for list hygiene issues
4. Review unsubscribe process (is it easy?)

**Short-term Actions (24 hours)**:
1. Clean email list (remove inactive subscribers)
2. Implement re-permission campaign
3. Review content for spam triggers
4. Reduce sending frequency

**Long-term Actions (1 week)**:
1. Implement engagement-based sending
2. Improve content relevance
3. Set up preference center
4. Monitor complaint rates daily

---

## <a name="one-click-unsubscribe"></a>5. One-Click Unsubscribe Implementation

### RFC 8058 Requirements

The **List-Unsubscribe-Post** header (RFC 8058) enables one-click unsubscribe in email clients.

#### Required Email Headers

Every marketing email MUST include both headers:

```
List-Unsubscribe: <https://yourdomain.com/unsubscribe?token=ABC123>
List-Unsubscribe-Post: List-Unsubscribe=One-Click
```

### Implementation Guide

#### Step 1: Create Unsubscribe Endpoint

```typescript
// pages/api/unsubscribe.ts
import { NextApiRequest, NextApiResponse } from 'next';
import { prisma } from '@/lib/db';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  // Support both GET and POST
  if (req.method !== 'GET' && req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const token = req.query.token as string;

  if (!token) {
    return res.status(400).json({ error: 'Missing token' });
  }

  try {
    // Verify token and get user
    const unsubscribeData = await verifyUnsubscribeToken(token);

    if (!unsubscribeData) {
      return res.status(400).json({ error: 'Invalid token' });
    }

    // CRITICAL: Process within 2 seconds (Gmail/Yahoo requirement)
    const startTime = Date.now();

    // Unsubscribe user from list
    await prisma.emailSubscription.update({
      where: { userId: unsubscribeData.userId },
      data: {
        marketingEmails: false,
        unsubscribedAt: new Date(),
        unsubscribeMethod: 'one-click',
      },
    });

    const processingTime = Date.now() - startTime;
    console.log(`Unsubscribe processed in ${processingTime}ms`);

    // POST requests should return 200 with no body
    if (req.method === 'POST') {
      return res.status(200).end();
    }

    // GET requests show confirmation page
    return res.status(200).send(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>Unsubscribed</title>
        </head>
        <body>
          <h1>You've been unsubscribed</h1>
          <p>You will no longer receive marketing emails from us.</p>
          <p>Processing time: ${processingTime}ms</p>
        </body>
      </html>
    `);
  } catch (error) {
    console.error('Unsubscribe error:', error);
    return res.status(500).json({ error: 'Failed to unsubscribe' });
  }
}

// Helper function to verify unsubscribe token
async function verifyUnsubscribeToken(token: string) {
  // Implement your token verification logic
  // Could be JWT, database lookup, etc.
  // Return { userId: string } or null
}
```

#### Step 2: Add Headers to Outgoing Emails

**For MailChimp**:
```typescript
// MailChimp automatically adds List-Unsubscribe header
// For List-Unsubscribe-Post, contact MailChimp support
// Most major ESPs support this automatically
```

**For Custom Email Sending**:
```typescript
import nodemailer from 'nodemailer';

const transporter = nodemailer.createTransporter({
  // Your SMTP config
});

async function sendMarketingEmail(to: string, subject: string, html: string) {
  // Generate unique unsubscribe token
  const token = await generateUnsubscribeToken(to);

  const mailOptions = {
    from: 'marketing@yourdomain.com',
    to,
    subject,
    html,
    headers: {
      // RFC 8058 one-click unsubscribe headers
      'List-Unsubscribe': `<https://yourdomain.com/api/unsubscribe?token=${token}>`,
      'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
    },
  };

  await transporter.sendMail(mailOptions);
}
```

#### Step 3: Performance Optimization

**CRITICAL**: Gmail/Yahoo require unsubscribe processing within **2 seconds**.

**Optimization Strategies**:

1. **Use Fast Database Queries**
```typescript
// ✅ Good: Simple update with index
await prisma.emailSubscription.update({
  where: { userId }, // Indexed field
  data: { marketingEmails: false },
});

// ❌ Bad: Complex query with joins
await prisma.user.update({
  where: { id: userId },
  include: { subscriptions: true, preferences: true },
  data: { /* ... */ },
});
```

2. **Queue Non-Critical Operations**
```typescript
// Process unsubscribe immediately
await quickUnsubscribe(userId);

// Queue slower operations (analytics, webhooks, etc.)
await queue.add('unsubscribe-followup', {
  userId,
  timestamp: new Date(),
});

return res.status(200).end(); // Respond fast
```

3. **Use CDN for Unsubscribe Endpoint**
- Deploy endpoint to edge locations
- Reduce latency globally

#### Step 4: Testing One-Click Unsubscribe

```bash
# Test POST request (one-click unsubscribe)
curl -X POST "https://yourdomain.com/api/unsubscribe?token=TEST123"

# Should return 200 OK within 2 seconds

# Test GET request (manual unsubscribe)
curl "https://yourdomain.com/api/unsubscribe?token=TEST123"

# Should return HTML confirmation page
```

### Unsubscribe Best Practices

- ✅ No login required to unsubscribe
- ✅ No additional steps beyond clicking link
- ✅ Process within 2 seconds
- ✅ Send optional confirmation email (not required)
- ✅ Provide preference center as alternative
- ✅ Allow re-subscription if user changes mind
- ❌ Don't ask "Are you sure?" (one click means one click!)
- ❌ Don't require reason for unsubscribing (optional survey is OK)

---

## <a name="spam-complaint-rate"></a>6. Spam Complaint Rate Management

### Understanding Spam Complaints

**What is a spam complaint?**
A recipient clicks "Report Spam" or "This is Spam" in their email client.

**Gmail/Yahoo 2024 Requirement**: Maintain complaint rate **< 0.3%**

### Monitoring Spam Complaints

#### Google Postmaster Tools (PRIMARY SOURCE)

1. **Set Up Daily Monitoring**
```bash
# Create script to check Google Postmaster Tools daily
# (API access requires Google Cloud project)
```

2. **Key Metrics**
- **Spam Rate**: Percentage of emails marked as spam
- **Target**: < 0.1%
- **Warning**: 0.2% - 0.3%
- **CRITICAL**: > 0.3%

3. **Set Up Alerts**
```typescript
// Example: Alert when spam rate exceeds threshold
if (spamRate > 0.002) { // 0.2%
  await sendAlert({
    to: 'alerts@yourdomain.com',
    subject: 'WARNING: Spam complaint rate elevated',
    message: `Current spam rate: ${(spamRate * 100).toFixed(3)}%`,
  });
}
```

### Root Causes of High Complaint Rates

| Cause | Frequency | Solution |
|-------|-----------|----------|
| Sending to purchased lists | ⭐⭐⭐⭐⭐ | Never buy email lists |
| No double opt-in | ⭐⭐⭐⭐ | Implement double opt-in |
| Too frequent emails | ⭐⭐⭐⭐ | Reduce frequency, add preferences |
| Irrelevant content | ⭐⭐⭐ | Improve targeting/segmentation |
| Difficult unsubscribe | ⭐⭐⭐ | Make unsubscribe easy (one-click) |
| Misleading subject lines | ⭐⭐ | Ensure subject matches content |
| Poor email design | ⭐⭐ | Improve design/mobile optimization |
| Sending to old lists | ⭐⭐⭐⭐⭐ | Implement sunset policies |

### Reducing Spam Complaints

#### 1. List Hygiene

**Remove Inactive Subscribers**:
```sql
-- Example: Remove subscribers inactive > 12 months
DELETE FROM email_subscriptions
WHERE last_engagement < NOW() - INTERVAL '12 months'
  AND created_at < NOW() - INTERVAL '12 months';
```

**Re-Permission Campaign**:
```
Subject: We miss you! Do you still want to hear from us?

Hi [Name],

We noticed you haven't opened our emails in a while. We only want to send 
emails to people who find them valuable.

[YES, KEEP ME SUBSCRIBED] [NO, UNSUBSCRIBE ME]

If we don't hear from you within 30 days, we'll automatically unsubscribe you.

Thanks,
[Your Team]
```

#### 2. Engagement-Based Sending

**Send to Engaged Users More Frequently**:
```typescript
// Example: Segment by engagement level
const segments = {
  highlyEngaged: { // Opened last 3 emails
    frequency: 'weekly',
    content: 'all campaigns',
  },
  moderatelyEngaged: { // Opened 1-2 of last 5 emails
    frequency: 'bi-weekly',
    content: 'curated campaigns',
  },
  lowEngagement: { // No opens in last 5 emails
    frequency: 'monthly',
    content: 'best-performing only',
  },
  inactive: { // No opens in 6 months
    frequency: 're-permission campaign only',
    content: 'win-back',
  },
};
```

#### 3. Preference Center

**Allow Granular Control**:
```typescript
// Example preference center options
interface EmailPreferences {
  // Frequency
  frequency: 'daily' | 'weekly' | 'bi-weekly' | 'monthly';
  
  // Content types
  productUpdates: boolean;
  educationalContent: boolean;
  promotions: boolean;
  newsletters: boolean;
  
  // Pause option (temporary)
  pausedUntil?: Date;
}
```

#### 4. Content Quality

**Best Practices**:
- ✅ Personalize content based on user behavior
- ✅ Segment by interests/preferences
- ✅ Test subject lines (avoid spam triggers)
- ✅ Provide clear value in every email
- ✅ Use consistent "From" name
- ❌ Don't use ALL CAPS in subject lines
- ❌ Don't use excessive punctuation (!!!)
- ❌ Don't use misleading subject lines

---

## <a name="content-optimization"></a>7. Content Optimization for Deliverability

### Spam Trigger Words to Avoid

**High-Risk Words** (Avoid in subject lines):
- Free, Winner, Prize, Congratulations
- Cash, Money, $$$, Earn money
- Click here, Act now, Limited time
- Guarantee, No obligation, Risk-free
- Urgent, Important, Alert

**Medium-Risk Words** (Use sparingly):
- Save, Discount, Sale, Offer
- Subscribe, Join, Sign up
- New, Now, Today

### HTML and CSS Best Practices

#### 1. HTML Structure

**✅ Good HTML**:
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Email Subject</title>
  <style>
    /* Inline critical CSS */
  </style>
</head>
<body>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
    <tr>
      <td>
        <!-- Email content -->
      </td>
    </tr>
  </table>
</body>
</html>
```

#### 2. CSS Best Practices

- ✅ Inline CSS for maximum compatibility
- ✅ Use tables for layout (email clients don't support modern CSS well)
- ✅ Test across email clients (Litmus, Email on Acid)
- ❌ Don't use JavaScript (blocked by most email clients)
- ❌ Don't rely on external stylesheets

#### 3. Image Best Practices

- ✅ Include alt text for all images
- ✅ Optimize image sizes (< 100 KB per image)
- ✅ Host images on CDN
- ✅ Use proper image dimensions
- ❌ Don't create image-only emails (60/40 text/image ratio)
- ❌ Don't embed large images inline

### Text-to-Image Ratio

**Recommended Ratio**: 60% text, 40% images

**Why?**: Spam filters flag image-heavy emails as potential spam.

```
Example email breakdown:
- Header text: 10%
- Body text: 50%
- Images: 30%
- Footer text: 10%
Total: 60% text, 30% images, 10% whitespace
```

### Link Best Practices

- ✅ Use HTTPS for all links
- ✅ Use descriptive link text (not "click here")
- ✅ Limit total links (< 20 per email)
- ✅ Include unsubscribe link prominently
- ❌ Don't use link shorteners (bit.ly, etc.) - triggers spam filters
- ❌ Don't use too many links (looks spammy)

### Mobile Optimization

**75%+ of emails are opened on mobile devices**

- ✅ Responsive design (adapts to screen size)
- ✅ Font size ≥ 14px for body text
- ✅ Touch-friendly buttons (minimum 44px × 44px)
- ✅ Single column layout for mobile
- ✅ Test on actual devices

---

## <a name="monitoring"></a>8. Monitoring and Maintenance

### Daily Monitoring Checklist

```bash
# Run daily (automate with cron)
./.cursor/tools/check-email-compliance.sh --domain yourdomain.com

# Manual checks:
□ Check Google Postmaster Tools
□ Review spam complaint rate (target: < 0.1%)
□ Check domain/IP reputation (target: High/Green)
□ Monitor bounce rates (target: < 5%)
□ Review authentication pass rates (target: 100%)
```

### Weekly Monitoring Checklist

```
□ Review email campaign performance
□ Analyze engagement rates by segment
□ Check for blacklist listings (MXToolbox, etc.)
□ Review DMARC aggregate reports
□ Monitor inbox placement rates
□ Audit unsubscribe processing time
```

### Monthly Monitoring Checklist

```
□ Comprehensive deliverability audit
□ Review and update email list segments
□ Analyze long-term trends (reputation, engagement)
□ Test email rendering across clients
□ Review and update content strategy
□ Audit compliance with latest regulations
```

### Key Metrics Dashboard

Create dashboard tracking:

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| Spam Complaint Rate | < 0.1% | 0.2% | > 0.3% |
| Hard Bounce Rate | < 2% | 3% | > 5% |
| Soft Bounce Rate | < 3% | 5% | > 10% |
| Domain Reputation | High | Medium | Low |
| IP Reputation | High | Medium | Low |
| SPF Pass Rate | 100% | 98% | < 95% |
| DKIM Pass Rate | 100% | 98% | < 95% |
| DMARC Pass Rate | 100% | 98% | < 95% |

---

## <a name="troubleshooting"></a>9. Troubleshooting Deliverability Issues

### Common Issues and Solutions

#### Issue #1: Emails Going to Spam

**Symptoms**:
- Low open rates
- Gmail Postmaster shows high spam rate
- Inbox placement < 80%

**Diagnosis Steps**:
1. Check authentication (SPF, DKIM, DMARC)
2. Review content for spam triggers
3. Check sender reputation
4. Analyze engagement rates

**Solutions**:
```bash
# 1. Verify authentication
./.cursor/tools/check-email-compliance.sh --domain yourdomain.com

# 2. Review spam triggers
# Use tools like mail-tester.com to test content

# 3. Clean email list
# Remove inactive subscribers (no engagement in 6+ months)

# 4. Implement re-engagement campaign
# "We miss you!" email to inactive subscribers
```

#### Issue #2: High Bounce Rate

**Symptoms**:
- Bounce rate > 5%
- Sender reputation declining
- Emails blocked by some ISPs

**Diagnosis Steps**:
1. Identify bounce types (hard vs. soft)
2. Check list quality
3. Review data collection methods

**Solutions**:
1. **Remove hard bounces immediately**
2. **Implement double opt-in** (prevents fake signups)
3. **Use email validation** at signup
4. **Regular list cleaning** (quarterly minimum)

#### Issue #3: Gmail/Yahoo Blocking Emails

**Symptoms**:
- Emails rejected with "550 5.7.1" error
- Gmail Postmaster shows authentication failures
- Domain reputation: Low

**Diagnosis Steps**:
1. Check if Gmail/Yahoo 2024 requirements met
2. Verify one-click unsubscribe implementation
3. Check spam complaint rate

**Solutions**:
```bash
# 1. Immediate: Stop sending to Gmail/Yahoo
# Fix compliance issues first!

# 2. Verify authentication
dig +short TXT yourdomain.com | grep spf
dig +short TXT _dmarc.yourdomain.com

# 3. Implement one-click unsubscribe
# Add List-Unsubscribe and List-Unsubscribe-Post headers

# 4. Monitor spam rate in Postmaster Tools
# Must be < 0.3%

# 5. Request review (if reputation damaged)
# Gmail: https://support.google.com/mail/contact/msgdelivery
# Yahoo: https://senders.yahooinc.com/contact
```

---

## <a name="emergency-response"></a>10. Emergency Response Procedures

### Spam Complaint Rate > 0.3% (CRITICAL)

**Impact**: Email blocking, spam folder placement

**Immediate Actions** (Within 1 hour):

```bash
# 1. STOP ALL EMAIL CAMPAIGNS IMMEDIATELY
# Pause in MailChimp, SendGrid, etc.

# 2. Investigate recent sends
# What changed? New list? New content? Higher frequency?

# 3. Check Google Postmaster Tools
# Identify which emails triggered complaints

# 4. Emergency list cleaning
# Remove complainers immediately
# Remove inactive subscribers (no engagement in 90 days)
```

**Recovery Plan** (1-2 weeks):

1. **Day 1-3**: Investigation and cleanup
   - Identify root cause
   - Clean email list aggressively
   - Fix unsubscribe process issues

2. **Day 4-7**: Limited re-engagement
   - Send only to highly engaged users (opened last 3 emails)
   - Best-performing content only
   - Reduced frequency

3. **Day 8-14**: Gradual recovery
   - Slowly expand to moderately engaged users
   - Monitor spam rate closely
   - Target: Get below 0.1%

### Domain/IP Reputation Drops to "Low"

**Impact**: Severe deliverability issues

**Immediate Actions**:

```bash
# 1. Check blacklist status
# https://mxtoolbox.com/blacklists.aspx

# 2. Request removal from blacklists
# Follow each blacklist's removal process

# 3. Audit recent campaigns
# Look for potential issues

# 4. Consider using subdomain
# Isolate damaged reputation
```

**Recovery Plan**:

1. **Fix root cause** (authentication, content, list quality)
2. **Implement IP warming** (if using new IP)
3. **Gradual volume increase** (similar to initial warming)
4. **Monitor daily** until reputation recovers

### Authentication Failures

**Impact**: Emails rejected

**Immediate Actions**:

```bash
# 1. Verify DNS records
dig +short TXT yourdomain.com | grep spf
dig +short TXT _dmarc.yourdomain.com

# 2. Check DKIM signing
# Send test email and verify DKIM-Signature header

# 3. Review DMARC reports
# Identify alignment issues
```

---

## Summary and Quick Reference

### Critical Requirements Checklist

```bash
# Run this check before every major campaign
./.cursor/tools/check-email-compliance.sh --domain yourdomain.com

# Must-have:
✓ SPF record configured
✓ DKIM signing enabled
✓ DMARC policy set (minimum p=none)
✓ List-Unsubscribe header in emails
✓ List-Unsubscribe-Post header in emails
✓ Unsubscribe processed < 2 seconds
✓ Spam complaint rate < 0.3%
✓ Domain reputation: High
✓ IP reputation: High
```

### Daily Operations

1. **Morning**: Check Google Postmaster Tools
2. **Before Campaign**: Verify compliance
3. **After Campaign**: Monitor engagement/complaints
4. **Evening**: Review metrics dashboard

### Key Resources

- **Google Postmaster Tools**: [https://postmaster.google.com](https://postmaster.google.com)
- **Microsoft SNDS**: [https://postmaster.live.com/snds](https://postmaster.live.com/snds)
- **MXToolbox**: [https://mxtoolbox.com](https://mxtoolbox.com)
- **Mail-Tester**: [https://mail-tester.com](https://mail-tester.com)

### Emergency Contacts

```
High spam complaint rate (> 0.2%):
→ Pause campaigns immediately
→ Run: ./.cursor/tools/check-email-compliance.sh
→ Contact: engineering-oncall@yourdomain.com

Domain blocked by Gmail/Yahoo:
→ Stop sending to affected ISP
→ Fix compliance issues
→ Submit sender review request

Authentication failures:
→ Verify DNS records
→ Contact email service provider
→ Review DMARC reports
```

---

**Document Status**: ✅ Production-Ready  
**Last Updated**: November 20, 2025  
**Next Review**: February 2026 (or when regulations change)

