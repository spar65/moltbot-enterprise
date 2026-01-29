# Email Marketing Compliance Guide

This guide provides comprehensive information on email marketing compliance requirements, focusing on consent management, regulatory requirements, and data protection practices for the VibeCoder platform.

## Table of Contents

1. [Regulatory Overview](#regulatory-overview)
2. [Consent Collection and Management](#consent-collection-and-management)
3. [Unsubscribe Handling](#unsubscribe-handling)
4. [Privacy Policy Requirements](#privacy-policy-requirements)
5. [Data Retention and Protection](#data-retention-and-protection)
6. [Data Subject Requests](#data-subject-requests)
7. [Documentation and Record Keeping](#documentation-and-record-keeping)
8. [Implementation Guidelines](#implementation-guidelines)

## Regulatory Overview

### GDPR (European Union)

The General Data Protection Regulation applies to all organizations processing personal data of EU citizens:

1. **Key Requirements**

   - Lawful basis for processing (consent, legitimate interest, etc.)
   - Purpose limitation (specific, explicit, and legitimate purposes)
   - Data minimization (adequate, relevant, and limited)
   - Storage limitation (kept no longer than necessary)
   - Integrity and confidentiality (security)
   - Accountability (demonstrate compliance)

2. **Email Marketing Implications**
   - Explicit consent required for marketing communications
   - Clear and comprehensive privacy notices
   - Easy unsubscribe mechanisms
   - Data subject rights (access, erasure, portability)

### CAN-SPAM (United States)

The Controlling the Assault of Non-Solicited Pornography and Marketing Act sets requirements for commercial emails:

1. **Key Requirements**

   - Don't use false or misleading header information
   - Don't use deceptive subject lines
   - Identify the message as an advertisement
   - Tell recipients where you're located
   - Tell recipients how to opt out
   - Honor opt-out requests promptly
   - Monitor what others do on your behalf

2. **Email Marketing Implications**
   - Include physical postal address in all emails
   - Provide clear and conspicuous unsubscribe mechanism
   - Process opt-out requests within 10 business days
   - Clear identification of marketing content

### CASL (Canada)

Canada's Anti-Spam Legislation imposes strict requirements on commercial electronic messages:

1. **Key Requirements**

   - Express or implied consent required
   - Identify sender and provide contact information
   - Provide unsubscribe mechanism
   - Keep records of consent

2. **Email Marketing Implications**
   - Express consent must be documented
   - Implied consent has time limitations
   - Include name, address, and contact information
   - Unsubscribe mechanism must remain active for 60 days

### PECR (UK)

Privacy and Electronic Communications Regulations complement GDPR in the UK:

1. **Key Requirements**
   - Consent required for marketing emails to individuals
   - Corporate email marketing doesn't require consent but must provide opt-out
   - Clear identification of sender
   - Valid address for opt-out requests

## Consent Collection and Management

### Consent Collection Implementation

```typescript
// Data Privacy and GDPR Compliance implementation
export class ConsentManagement {
  static async recordConsent(
    userId: string,
    consentData: ConsentData
  ): Promise<void> {
    // Validate consent data
    if (!consentData.source) {
      throw new Error("Consent source is required");
    }

    if (!consentData.timestamp) {
      consentData.timestamp = new Date();
    }

    // Create consent record with all required information
    await db.consentRecords.create({
      data: {
        userId,
        consentType: "marketing_email",
        consented: consentData.consented,
        source: consentData.source,
        ipAddress: consentData.ipAddress,
        userAgent: consentData.userAgent,
        timestamp: consentData.timestamp,
        version: consentData.version || "1.0",
        additionalData: consentData.additionalData,
      },
    });

    // Update user's marketing preferences
    await db.users.update({
      where: { id: userId },
      data: {
        marketingConsent: consentData.consented,
        marketingConsentUpdatedAt: consentData.timestamp,
      },
    });

    // Sync with MailChimp if consent is given
    if (consentData.consented) {
      try {
        const user = await db.users.findUnique({
          where: { id: userId },
        });

        if (user) {
          await mailchimpClient.syncUser({
            email: user.email,
            hasConsented: true,
            consentTimestamp: consentData.timestamp,
            consentSource: consentData.source,
          });
        }
      } catch (error) {
        logger.error("Failed to sync consent to MailChimp", {
          userId,
          error: error.message,
        });
      }
    }
  }

  static async handleDataSubjectRequest(
    userId: string,
    requestType: "access" | "delete" | "portability"
  ): Promise<void> {
    const user = await db.users.findUnique({
      where: { id: userId },
      include: {
        consentRecords: true,
      },
    });

    if (!user) {
      throw new Error("User not found");
    }

    switch (requestType) {
      case "access":
        // Provide all user data including consent records
        return this.prepareUserDataAccess(user);

      case "delete":
        // Delete user data from both database and MailChimp
        await this.deleteUserData(user);
        break;

      case "portability":
        // Prepare portable format of user data
        return this.preparePortableUserData(user);
    }
  }

  private static async deleteUserData(user: User): Promise<void> {
    // Delete from MailChimp
    try {
      const subscriberHash = md5(user.email.toLowerCase());
      await mailchimpClient.client.lists.deleteListMember(
        process.env.MAILCHIMP_LIST_ID,
        subscriberHash
      );
    } catch (error) {
      logger.error("Failed to delete user from MailChimp", {
        userId: user.id,
        email: user.email,
        error: error.message,
      });
    }

    // Delete from database (or anonymize)
    await db.consentRecords.deleteMany({
      where: { userId: user.id },
    });

    // Anonymize user instead of deleting
    await db.users.update({
      where: { id: user.id },
      data: {
        email: `deleted_${uuidv4()}@example.com`,
        firstName: "Deleted",
        lastName: "User",
        marketingConsent: false,
        deleted: true,
        deletedAt: new Date(),
      },
    });
  }
}
```

### Consent Form Requirements

All consent forms should include:

1. **Clear Language**

   - Use plain, simple language
   - Avoid legal jargon
   - Clearly state what the user is consenting to

2. **Explicit Action**

   - Require affirmative action (e.g., checking an unchecked box)
   - No pre-ticked boxes (prohibited under GDPR)
   - Clear call to action

3. **Comprehensive Information**

   - What communications they will receive
   - Approximate frequency
   - Type of content
   - How to withdraw consent

4. **Privacy Policy Link**
   - Clear link to privacy policy
   - Summary of key points

**Example Consent Form HTML:**

```html
<div class="consent-form">
  <h3>Marketing Communications</h3>

  <p>
    We'd like to keep you informed about our latest features, tips, and offers.
  </p>

  <div class="consent-checkbox">
    <input
      type="checkbox"
      id="marketing-consent"
      name="marketing-consent"
      value="true"
      required
    />
    <label for="marketing-consent">
      Yes, I'd like to receive marketing emails from VibeCoder (approximately
      1-2 per month). I understand I can unsubscribe at any time.
    </label>
  </div>

  <p class="consent-info">
    By checking this box, you consent to receive marketing communications from
    VibeCoder. We'll use your data to send personalized offers and updates. For
    more information, read our <a href="/privacy-policy">Privacy Policy</a>.
  </p>
</div>
```

## Unsubscribe Handling

### Requirements

1. **Clear Mechanism**

   - Visible and easy-to-find unsubscribe link
   - Simple, one-step process (no login required)
   - Available in every email

2. **Prompt Processing**

   - Process within timeframes required by law (e.g., 10 days for CAN-SPAM)
   - Immediate confirmation of unsubscribe request
   - No further marketing emails after unsubscribe

3. **Preference Center Option**
   - Allow frequency or content type preferences
   - Provide category-specific unsubscribe options
   - Clear explanations of each option

### Implementation

```typescript
// Unsubscribe handling
export class UnsubscribeManager {
  // Process unsubscribe request
  static async processUnsubscribe(
    email: string,
    source: string = "email_link"
  ): Promise<UnsubscribeResult> {
    try {
      // Find user by email
      const user = await db.users.findUnique({
        where: { email: email.toLowerCase() },
      });

      if (!user) {
        return { success: false, message: "User not found" };
      }

      // Update user preferences in database
      await db.users.update({
        where: { id: user.id },
        data: {
          marketingConsent: false,
          marketingConsentUpdatedAt: new Date(),
        },
      });

      // Record unsubscribe action
      await ConsentManagement.recordConsent(user.id, {
        consented: false,
        source: source,
        timestamp: new Date(),
        ipAddress: null, // May not have this for all unsubscribe sources
        version: "1.0",
      });

      // Update MailChimp
      try {
        const subscriberHash = md5(email.toLowerCase());
        await mailchimpClient.client.lists.updateListMember(
          process.env.MAILCHIMP_LIST_ID,
          subscriberHash,
          {
            status: "unsubscribed",
          }
        );
      } catch (mailchimpError) {
        logger.error("Failed to update unsubscribe status in MailChimp", {
          userId: user.id,
          email,
          error: mailchimpError.message,
        });
        // Continue processing - don't fail the unsubscribe because of MailChimp error
      }

      return {
        success: true,
        message: "Successfully unsubscribed from marketing emails",
      };
    } catch (error) {
      logger.error("Unsubscribe processing failed", {
        email,
        error: error.message,
      });

      return {
        success: false,
        message: "An error occurred while processing your request",
      };
    }
  }

  // Process preference updates
  static async updatePreferences(
    email: string,
    preferences: EmailPreferences
  ): Promise<UnsubscribeResult> {
    try {
      // Similar implementation to processUnsubscribe but with more granular options
      // Update specific preferences rather than a global unsubscribe

      return {
        success: true,
        message: "Your email preferences have been updated",
      };
    } catch (error) {
      logger.error("Preference update failed", {
        email,
        error: error.message,
      });

      return {
        success: false,
        message: "An error occurred while updating your preferences",
      };
    }
  }
}
```

## Privacy Policy Requirements

### Essential Privacy Policy Components

1. **Personal Data Collection**

   - What data is collected
   - How it's collected (forms, website, third parties)
   - Legal basis for collection

2. **Use of Data**

   - Marketing purposes
   - Service improvement
   - Analytics and statistics
   - Personalization

3. **Data Sharing**

   - Third-party service providers (e.g., MailChimp)
   - Legal requirements
   - Business transfers
   - With user consent

4. **Data Subject Rights**

   - Right to access
   - Right to rectification
   - Right to erasure
   - Right to restrict processing
   - Right to data portability
   - Right to object

5. **Security Measures**

   - How data is protected
   - Data breach notification procedures

6. **Retention Periods**

   - How long data is kept
   - Criteria for determining retention periods

7. **Updates to Privacy Policy**
   - How changes will be communicated
   - Version history

### Privacy Policy Implementation Checklist

- [ ] Legal review of privacy policy
- [ ] Easy-to-find link in website footer
- [ ] Link in all signup forms
- [ ] Link in all marketing emails
- [ ] Regular review and updates
- [ ] Version control and change history
- [ ] Notification system for material changes

## Data Retention and Protection

### Data Retention Policy

1. **Marketing Data**

   - Active customers: Retain while relationship exists
   - Inactive customers: Review after 24 months of inactivity
   - Unsubscribed users: Retain only necessary data, anonymize rest
   - Consent records: Retain for 7 years for legal compliance

2. **Technical Implementation**

```typescript
// Data retention implementation
export class DataRetentionManager {
  // Schedule regular data retention job
  static scheduleDataRetentionJob(): void {
    // Run weekly data retention check
    cron.schedule("0 0 * * 0", async () => {
      await this.processDataRetention();
    });
  }

  // Process data retention rules
  static async processDataRetention(): Promise<void> {
    try {
      // Find inactive users (no login or interaction for 24+ months)
      const inactiveDate = new Date();
      inactiveDate.setMonth(inactiveDate.getMonth() - 24);

      const inactiveUsers = await db.users.findMany({
        where: {
          AND: [
            { lastLogin: { lt: inactiveDate } },
            { lastActivity: { lt: inactiveDate } },
            { deleted: false },
          ],
        },
      });

      // For each inactive user, anonymize or delete
      for (const user of inactiveUsers) {
        await this.anonymizeUserData(user.id);
      }

      // Log results
      logger.info(`Data retention job completed`, {
        processedCount: inactiveUsers.length,
      });
    } catch (error) {
      logger.error("Data retention job failed", {
        error: error.message,
      });
    }
  }

  // Anonymize user data
  static async anonymizeUserData(userId: string): Promise<void> {
    // Anonymize user but keep consent records
    await db.users.update({
      where: { id: userId },
      data: {
        email: `anonymized_${uuidv4()}@example.com`,
        firstName: "Anonymized",
        lastName: "User",
        phone: null,
        address: null,
        anonymized: true,
        anonymizedAt: new Date(),
      },
    });

    // Remove from MailChimp
    try {
      const user = await db.users.findUnique({
        where: { id: userId },
        select: { email: true },
      });

      if (user) {
        const subscriberHash = md5(user.email.toLowerCase());
        await mailchimpClient.client.lists.deleteListMember(
          process.env.MAILCHIMP_LIST_ID,
          subscriberHash
        );
      }
    } catch (error) {
      logger.error("Failed to remove anonymized user from MailChimp", {
        userId,
        error: error.message,
      });
    }
  }
}
```

### Data Protection Measures

1. **Technical Measures**

   - Encryption in transit (TLS for all connections)
   - Encryption at rest for sensitive data
   - Access controls and authentication
   - Regular security assessments

2. **Organizational Measures**
   - Staff training on data protection
   - Data protection policies
   - Access control policies
   - Regular compliance reviews

## Data Subject Requests

### Handling Data Subject Requests

```typescript
export class DataSubjectRequestHandler {
  // Process a data access request
  static async processAccessRequest(userId: string): Promise<UserDataExport> {
    // Collect all user data
    const user = await db.users.findUnique({
      where: { id: userId },
      include: {
        consentRecords: true,
        marketingPreferences: true,
        loginHistory: true,
      },
    });

    if (!user) {
      throw new Error("User not found");
    }

    // Get MailChimp data
    let mailchimpData = null;
    try {
      const subscriberHash = md5(user.email.toLowerCase());
      mailchimpData = await mailchimpClient.client.lists.getListMember(
        process.env.MAILCHIMP_LIST_ID,
        subscriberHash
      );
    } catch (error) {
      logger.warn("Could not retrieve MailChimp data for user", {
        userId,
        error: error.message,
      });
    }

    // Format data for export
    return {
      userData: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        createdAt: user.createdAt,
        marketingConsent: user.marketingConsent,
        marketingConsentUpdatedAt: user.marketingConsentUpdatedAt,
      },
      consentHistory: user.consentRecords.map((record) => ({
        type: record.consentType,
        consented: record.consented,
        timestamp: record.timestamp,
        source: record.source,
      })),
      marketingPreferences: user.marketingPreferences,
      mailchimpData: mailchimpData,
    };
  }

  // Process data portability request
  static async processPortabilityRequest(userId: string): Promise<string> {
    const userData = await this.processAccessRequest(userId);

    // Convert to portable format (JSON)
    return JSON.stringify(userData, null, 2);
  }

  // Process erasure request
  static async processErasureRequest(userId: string): Promise<void> {
    // Get user
    const user = await db.users.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new Error("User not found");
    }

    // Delete from MailChimp
    try {
      const subscriberHash = md5(user.email.toLowerCase());
      await mailchimpClient.client.lists.deleteListMember(
        process.env.MAILCHIMP_LIST_ID,
        subscriberHash
      );
    } catch (error) {
      logger.error("Failed to delete user from MailChimp during erasure", {
        userId,
        error: error.message,
      });
    }

    // Anonymize in database
    await db.users.update({
      where: { id: userId },
      data: {
        email: `deleted_${uuidv4()}@example.com`,
        firstName: "Deleted",
        lastName: "User",
        phone: null,
        address: null,
        marketingConsent: false,
        deleted: true,
        deletedAt: new Date(),
      },
    });

    // Delete non-essential data
    await db.marketingPreferences.deleteMany({
      where: { userId },
    });

    // Keep consent records for legal compliance
    // but disconnect from user identity
  }
}
```

## Documentation and Record Keeping

### Required Records

1. **Consent Records**

   - When consent was obtained
   - How consent was obtained
   - What information was provided
   - Who gave consent
   - How they gave consent

2. **Processing Records**

   - What data is processed
   - Purpose of processing
   - Categories of recipients
   - Transfer to third countries
   - Retention periods
   - Security measures

3. **Data Subject Request Records**
   - Type of request
   - Date of request
   - Decision made
   - Date of response
   - Any exemptions applied

### Record Implementation

```typescript
// Consent record schema
interface ConsentRecord {
  id: string;
  userId: string;
  consentType: string; // e.g., "marketing_email", "cookie", etc.
  consented: boolean;
  source: string; // e.g., "signup_form", "preferences_page", "email_link"
  ipAddress: string | null;
  userAgent: string | null;
  timestamp: Date;
  version: string; // Version of consent form/privacy policy
  additionalData: Record<string, any> | null;
}

// Data subject request record schema
interface DataSubjectRequestRecord {
  id: string;
  userId: string;
  requestType:
    | "access"
    | "rectify"
    | "erase"
    | "restrict"
    | "portability"
    | "object";
  requestDate: Date;
  completionDate: Date | null;
  status: "pending" | "completed" | "denied";
  denialReason: string | null;
  handledBy: string | null; // User ID of staff member who handled request
  notes: string | null;
}

// Processing activity record schema
interface ProcessingActivityRecord {
  id: string;
  activityName: string;
  description: string;
  legalBasis: string;
  dataCategories: string[];
  dataSubjects: string[];
  recipients: string[];
  retentionPeriod: string;
  securityMeasures: string[];
  thirdCountryTransfers: boolean;
  safeguards: string | null;
  createdAt: Date;
  updatedAt: Date;
}
```

## Implementation Guidelines

### Compliance Checklist

1. **Initial Setup**

   - [ ] Privacy policy created and reviewed by legal
   - [ ] Consent collection mechanism implemented
   - [ ] Unsubscribe mechanism implemented
   - [ ] Data subject request handling process
   - [ ] Record keeping system

2. **MailChimp Configuration**

   - [ ] GDPR fields enabled
   - [ ] Consent tracking fields added
   - [ ] Double opt-in enabled where required
   - [ ] Unsubscribe footer configured
   - [ ] Custom merge fields for compliance data

3. **Technical Implementation**

   - [ ] API integration with proper security
   - [ ] Consent storage and tracking
   - [ ] Data retention processes
   - [ ] Export and erasure capabilities
   - [ ] Audit logging for compliance actions

4. **Regular Maintenance**
   - [ ] Quarterly privacy policy review
   - [ ] Monthly unsubscribe process testing
   - [ ] Regular consent record audits
   - [ ] Staff training on compliance
   - [ ] Review of MailChimp settings and compliance

### Implementation Timeline

| Phase             | Tasks                                             | Timeline   |
| ----------------- | ------------------------------------------------- | ---------- |
| 1. Preparation    | Research requirements, legal consultation         | Week 1-2   |
| 2. Documentation  | Privacy policy, consent language, record formats  | Week 3-4   |
| 3. Implementation | Consent forms, unsubscribe, data subject requests | Week 5-8   |
| 4. Integration    | MailChimp setup, API integration, testing         | Week 9-10  |
| 5. Verification   | Compliance testing, audit, fixes                  | Week 11-12 |
| 6. Launch         | Production deployment with monitoring             | Week 13    |
| 7. Maintenance    | Regular reviews and updates                       | Ongoing    |

## Resources

- [ICO GDPR Guidance](https://ico.org.uk/for-organisations/guide-to-data-protection/guide-to-the-general-data-protection-regulation-gdpr/)
- [FTC CAN-SPAM Compliance Guide](https://www.ftc.gov/tips-advice/business-center/guidance/can-spam-act-compliance-guide-business)
- [CASL Guidance](https://www.priv.gc.ca/en/privacy-topics/privacy-laws-in-canada/the-personal-information-protection-and-electronic-documents-act-pipeda/r_o_p/canadas-anti-spam-legislation/)
- [MailChimp GDPR Guide](https://mailchimp.com/help/about-the-general-data-protection-regulation/)
- [MailChimp API Reference](https://mailchimp.com/developer/marketing/api/)
