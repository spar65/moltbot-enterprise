# MailChimp Integration Guide

This guide provides comprehensive documentation for integrating MailChimp with the VibeCoder platform, focusing on API setup, user synchronization, campaign management, and advanced features.

## Table of Contents

1. [API Setup and Authentication](#api-setup-and-authentication)
2. [User Data Synchronization](#user-data-synchronization)
3. [List and Segment Management](#list-and-segment-management)
4. [Campaign Creation and Management](#campaign-creation-and-management)
5. [Automation Workflows](#automation-workflows)
6. [Event Tracking and Analytics](#event-tracking-and-analytics)
7. [Advanced Segmentation Strategies](#advanced-segmentation-strategies)

## API Setup and Authentication

### MailChimp API Keys

1. **Creating API Keys**

   - Log in to your MailChimp account
   - Navigate to Account → Extras → API keys
   - Generate a new API key with appropriate permissions

2. **API Key Security**

   - Store API keys in environment variables or secure secret management
   - Never hardcode API keys in application code
   - Implement key rotation procedures

3. **Server Configuration**

   ```typescript
   // Configuration for MailChimp API
   interface MailChimpConfig {
     apiKey: string; // Your MailChimp API key
     serverPrefix: string; // The server prefix (e.g., "us1", "us2")
     defaultListId: string; // Your primary audience list ID
   }

   // Environment variable names
   const MAILCHIMP_API_KEY = process.env.MAILCHIMP_API_KEY;
   const MAILCHIMP_SERVER_PREFIX = process.env.MAILCHIMP_SERVER_PREFIX;
   const MAILCHIMP_LIST_ID = process.env.MAILCHIMP_LIST_ID;
   ```

### API Client Setup

```typescript
import { MailchimpMarketingApi } from "@mailchimp/mailchimp_marketing";

export class MailChimpClient {
  private client: MailchimpMarketingApi;

  constructor(apiKey: string, serverPrefix: string) {
    this.client = new MailchimpMarketingApi();
    this.client.setConfig({
      apiKey: apiKey,
      server: serverPrefix,
    });
  }

  // Test API connectivity
  async ping(): Promise<boolean> {
    try {
      const response = await this.client.ping.get();
      return response.health_status === "Everything's Chimpy!";
    } catch (error) {
      console.error("MailChimp API connection failed:", error);
      return false;
    }
  }
}
```

## User Data Synchronization

### User Data Mapping

```typescript
// Map VibeCoder user data to MailChimp fields
function mapUserToMailChimp(user: User): MailChimpMemberData {
  return {
    email_address: user.email,
    status: user.marketingConsent ? "subscribed" : "unsubscribed",
    merge_fields: {
      FNAME: user.firstName || "",
      LNAME: user.lastName || "",
      COMPANY: user.company || "",
      PLAN: user.subscriptionTier || "free",
    },
    tags: generateUserTags(user),
    language: user.language || "en",
    vip: user.subscriptionTier === "enterprise",
    location: user.location
      ? {
          latitude: user.location.latitude,
          longitude: user.location.longitude,
          country_code: user.location.countryCode,
        }
      : undefined,
    marketing_permissions: mapMarketingPermissions(user),
  };
}

// Generate relevant tags for user segmentation
function generateUserTags(user: User): string[] {
  const tags: string[] = [];

  if (user.subscriptionTier) tags.push(`plan:${user.subscriptionTier}`);
  if (user.userRole) tags.push(`role:${user.userRole}`);
  if (user.signupSource) tags.push(`source:${user.signupSource}`);
  if (user.lastLogin) {
    const daysSinceLogin = Math.floor(
      (Date.now() - user.lastLogin.getTime()) / (1000 * 3600 * 24)
    );
    if (daysSinceLogin < 7) tags.push("active:7days");
    else if (daysSinceLogin < 30) tags.push("active:30days");
    else tags.push("inactive");
  }

  return tags;
}
```

### Synchronization Process

```typescript
export class UserSynchronizer {
  private mailchimpClient: MailChimpClient;
  private listId: string;

  constructor(mailchimpClient: MailChimpClient, listId: string) {
    this.mailchimpClient = mailchimpClient;
    this.listId = listId;
  }

  // Sync a single user to MailChimp
  async syncUser(user: User): Promise<SyncResult> {
    try {
      // Convert email to MD5 hash for MailChimp's subscriber hash
      const subscriberHash = md5(user.email.toLowerCase());

      // Map user data to MailChimp format
      const memberData = mapUserToMailChimp(user);

      // Upsert the member in MailChimp
      const result = await this.mailchimpClient.client.lists.setListMember(
        this.listId,
        subscriberHash,
        memberData
      );

      // Log successful sync
      logger.info(`User ${user.id} synced to MailChimp`, {
        userId: user.id,
        email: user.email,
        status: memberData.status,
      });

      return { success: true, data: result };
    } catch (error) {
      // Log and handle error
      logger.error(`Failed to sync user ${user.id} to MailChimp`, {
        userId: user.id,
        email: user.email,
        error: error.message,
      });

      return { success: false, error };
    }
  }

  // Batch sync multiple users
  async batchSyncUsers(users: User[]): Promise<BatchSyncResult> {
    const operations = users.map((user) => ({
      method: "PUT",
      path: `/lists/${this.listId}/members/${md5(user.email.toLowerCase())}`,
      body: JSON.stringify(mapUserToMailChimp(user)),
    }));

    try {
      const response = await this.mailchimpClient.client.batches.start({
        operations,
      });

      // Log batch operation started
      logger.info(`Batch sync of ${users.length} users started`, {
        batchId: response.id,
        userCount: users.length,
      });

      return {
        success: true,
        batchId: response.id,
        userCount: users.length,
      };
    } catch (error) {
      logger.error(`Batch sync failed`, {
        userCount: users.length,
        error: error.message,
      });

      return {
        success: false,
        error,
        userCount: users.length,
      };
    }
  }
}
```

## List and Segment Management

### List Structure

MailChimp lists (audiences) should follow these guidelines:

1. **Primary List**: Maintain one main list for all VibeCoder users
2. **Segments**: Use segments to target specific user groups
3. **Groups**: Use groups for interest categories and preferences
4. **Tags**: Use tags for dynamic properties and user attributes

### Segment Management

```typescript
export class SegmentManager {
  private mailchimpClient: MailChimpClient;
  private listId: string;

  constructor(mailchimpClient: MailChimpClient, listId: string) {
    this.mailchimpClient = mailchimpClient;
    this.listId = listId;
  }

  // Create a new segment based on criteria
  async createSegment(
    name: string,
    conditions: SegmentCondition[]
  ): Promise<Segment> {
    try {
      const result = await this.mailchimpClient.client.lists.createSegment(
        this.listId,
        {
          name,
          static_segment: [],
          options: {
            match: "all", // or "any" for OR logic
            conditions,
          },
        }
      );

      return result;
    } catch (error) {
      logger.error(`Failed to create segment ${name}`, {
        error: error.message,
      });
      throw error;
    }
  }

  // Update an existing segment
  async updateSegment(
    segmentId: string,
    name: string,
    conditions: SegmentCondition[]
  ): Promise<Segment> {
    try {
      const result = await this.mailchimpClient.client.lists.updateSegment(
        this.listId,
        segmentId,
        {
          name,
          options: {
            match: "all",
            conditions,
          },
        }
      );

      return result;
    } catch (error) {
      logger.error(`Failed to update segment ${segmentId}`, {
        error: error.message,
      });
      throw error;
    }
  }
}
```

## Campaign Creation and Management

### Campaign Creation

```typescript
export class CampaignManager {
  private mailchimpClient: MailChimpClient;

  constructor(mailchimpClient: MailChimpClient) {
    this.mailchimpClient = mailchimpClient;
  }

  // Create a new regular campaign
  async createCampaign(campaign: CampaignData): Promise<Campaign> {
    try {
      const result = await this.mailchimpClient.client.campaigns.create({
        type: "regular",
        recipients: {
          list_id: campaign.listId,
          segment_opts: campaign.segmentId
            ? {
                saved_segment_id: campaign.segmentId,
              }
            : undefined,
        },
        settings: {
          subject_line: campaign.subject,
          preview_text: campaign.previewText,
          title: campaign.title,
          from_name: campaign.fromName,
          reply_to: campaign.replyTo,
          to_name: "*|FNAME|*", // MailChimp merge tag for first name
          auto_footer: true,
          inline_css: true,
        },
        tracking: {
          opens: true,
          html_clicks: true,
          text_clicks: true,
          goal_tracking: true,
          ecomm360: true,
          google_analytics: campaign.utmParameters,
        },
      });

      // Set campaign content
      if (campaign.htmlContent) {
        await this.mailchimpClient.client.campaigns.setContent(result.id, {
          html: campaign.htmlContent,
        });
      }

      return result;
    } catch (error) {
      logger.error(`Failed to create campaign ${campaign.title}`, {
        error: error.message,
      });
      throw error;
    }
  }

  // Send a test email for a campaign
  async sendTest(campaignId: string, emails: string[]): Promise<void> {
    try {
      await this.mailchimpClient.client.campaigns.sendTestEmail(campaignId, {
        test_emails: emails,
        send_type: "html",
      });
    } catch (error) {
      logger.error(`Failed to send test for campaign ${campaignId}`, {
        error: error.message,
      });
      throw error;
    }
  }

  // Schedule a campaign for sending
  async scheduleCampaign(
    campaignId: string,
    scheduledTime: Date
  ): Promise<void> {
    try {
      await this.mailchimpClient.client.campaigns.schedule(campaignId, {
        schedule_time: scheduledTime.toISOString(),
      });
    } catch (error) {
      logger.error(`Failed to schedule campaign ${campaignId}`, {
        error: error.message,
      });
      throw error;
    }
  }
}
```

## Automation Workflows

### Automation Creation

```typescript
export class AutomationManager {
  private mailchimpClient: MailChimpClient;

  constructor(mailchimpClient: MailChimpClient) {
    this.mailchimpClient = mailchimpClient;
  }

  // Create a new automation workflow
  async createAutomation(automation: AutomationData): Promise<Automation> {
    try {
      const result = await this.mailchimpClient.client.automations.create({
        recipients: {
          list_id: automation.listId,
          segment_opts: automation.segmentId
            ? {
                saved_segment_id: automation.segmentId,
              }
            : undefined,
        },
        trigger_settings: {
          workflow_type: automation.triggerType,
          workflow_title: automation.title,
        },
        settings: {
          from_name: automation.fromName,
          reply_to: automation.replyTo,
          use_conversation: true,
          to_name: "*|FNAME|*",
        },
      });

      return result;
    } catch (error) {
      logger.error(`Failed to create automation ${automation.title}`, {
        error: error.message,
      });
      throw error;
    }
  }

  // Add an email to an automation workflow
  async addAutomationEmail(
    automationId: string,
    emailData: AutomationEmailData
  ): Promise<AutomationEmail> {
    try {
      const result =
        await this.mailchimpClient.client.automations.addWorkflowEmail(
          automationId,
          {
            delay: {
              amount: emailData.delayAmount,
              type: emailData.delayType,
            },
            subject_line: emailData.subject,
            preview_text: emailData.previewText,
            title: emailData.title,
          }
        );

      // Set email content
      if (emailData.htmlContent) {
        await this.mailchimpClient.client.automations.updateWorkflowEmail(
          automationId,
          result.id,
          {
            content_type: "html",
            html: emailData.htmlContent,
          }
        );
      }

      return result;
    } catch (error) {
      logger.error(`Failed to add email to automation ${automationId}`, {
        error: error.message,
      });
      throw error;
    }
  }
}
```

## Event Tracking and Analytics

### Event Tracking

```typescript
export class EventTracker {
  private mailchimpClient: MailChimpClient;
  private storeId: string;

  constructor(mailchimpClient: MailChimpClient, storeId: string) {
    this.mailchimpClient = mailchimpClient;
    this.storeId = storeId;
  }

  // Track a product viewed event
  async trackProductView(user: User, productId: string): Promise<void> {
    try {
      await this.mailchimpClient.client.ecommerce.addProductActivity(
        this.storeId,
        {
          emails: [{ email: user.email }],
          products: [
            {
              id: productId,
              product_viewed: true,
            },
          ],
        }
      );
    } catch (error) {
      logger.error(`Failed to track product view for user ${user.id}`, {
        userId: user.id,
        productId,
        error: error.message,
      });
    }
  }

  // Track a cart addition event
  async trackCartAddition(
    user: User,
    productId: string,
    quantity: number
  ): Promise<void> {
    try {
      await this.mailchimpClient.client.ecommerce.addProductActivity(
        this.storeId,
        {
          emails: [{ email: user.email }],
          products: [
            {
              id: productId,
              cart_quantity: quantity,
            },
          ],
        }
      );
    } catch (error) {
      logger.error(`Failed to track cart addition for user ${user.id}`, {
        userId: user.id,
        productId,
        quantity,
        error: error.message,
      });
    }
  }

  // Track a purchase event
  async trackPurchase(
    user: User,
    orderId: string,
    products: ProductPurchase[]
  ): Promise<void> {
    try {
      await this.mailchimpClient.client.ecommerce.addOrder(this.storeId, {
        id: orderId,
        customer: {
          id: user.id,
          email_address: user.email,
          first_name: user.firstName,
          last_name: user.lastName,
          opt_in_status: user.marketingConsent,
        },
        currency_code: "USD",
        order_total: products.reduce((sum, p) => sum + p.price * p.quantity, 0),
        lines: products.map((p) => ({
          id: `${orderId}_${p.id}`,
          product_id: p.id,
          product_title: p.name,
          price: p.price,
          quantity: p.quantity,
        })),
      });
    } catch (error) {
      logger.error(`Failed to track purchase for user ${user.id}`, {
        userId: user.id,
        orderId,
        error: error.message,
      });
    }
  }
}
```

## Advanced Segmentation Strategies

Advanced segmentation allows for precise targeting of users based on their behavior, attributes, and engagement levels.

```typescript
// Advanced segmentation implementation
export class AdvancedSegmentation {
  static createDynamicSegments(userData: UserData[]): SegmentConfig[] {
    return [
      {
        name: "High-Value Active Users",
        conditions: {
          subscriptionTier: ["pro", "enterprise"],
          lastActive: { within: "7 days" },
          engagementScore: { greaterThan: 70 },
        },
      },
      {
        name: "Trial Users Near Expiration",
        conditions: {
          subscriptionStatus: "trial",
          trialDaysRemaining: { lessThan: 3 },
          hasUsedCoreFeature: false,
        },
      },
      {
        name: "Feature-Specific Users",
        conditions: {
          hasUsedFeature: ["reporting", "analytics"],
          subscriptionTier: "basic",
          accountAge: { greaterThan: "30 days" },
        },
      },
    ];
  }

  // Create segments based on user activity
  static createEngagementSegments(): SegmentCondition[] {
    return [
      // Highly engaged users
      {
        name: "Highly Engaged Users",
        conditions: [
          {
            condition_type: "CampaignActivity",
            op: "greater",
            field: "opens",
            value: 3,
          },
          {
            condition_type: "CampaignActivity",
            op: "greater",
            field: "clicks",
            value: 1,
          },
        ],
      },

      // Unengaged users
      {
        name: "Unengaged Users",
        conditions: [
          {
            condition_type: "CampaignActivity",
            op: "is",
            field: "opens",
            value: 0,
          },
          {
            condition_type: "DateMerge",
            op: "greater",
            field: "MEMBER_RATING",
            value: 30, // Days since last engagement
          },
        ],
      },

      // Product interest segments
      {
        name: "Analytics Interest",
        conditions: [
          {
            condition_type: "EmailActivity",
            op: "contains",
            field: "Click",
            value: "analytics", // Clicked links containing "analytics"
          },
        ],
      },
    ];
  }
}
```

## Best Practices

### General Best Practices

1. **Rate Limiting**

   - Implement proper rate limiting to avoid MailChimp API limits
   - Use exponential backoff for retries
   - Batch operations for efficiency

2. **Error Handling**

   - Implement proper error logging and monitoring
   - Create alerts for critical failures
   - Implement retry logic for transient failures

3. **Synchronization**
   - Use batch operations for bulk updates
   - Implement idempotent operations
   - Create audit logs for synchronization activities

### Security Considerations

1. **API Key Security**

   - Rotate API keys regularly
   - Use proper access controls
   - Monitor API usage for suspicious activity

2. **Data Protection**

   - Only synchronize necessary data
   - Implement proper data retention policies
   - Follow GDPR and other privacy regulations

3. **Consent Management**
   - Track and honor marketing preferences
   - Maintain audit trails of consent changes
   - Implement double opt-in for new subscriptions

## Troubleshooting

Common issues and solutions:

1. **API Connection Issues**

   - Verify API key and server prefix
   - Check network connectivity
   - Verify firewall and security settings

2. **Synchronization Failures**

   - Check for invalid email formats
   - Verify list and segment IDs
   - Check for merge field mapping issues

3. **Campaign Sending Issues**
   - Verify campaign content and settings
   - Check for compliance issues
   - Verify segment conditions

## Resources

- [MailChimp API Documentation](https://mailchimp.com/developer/marketing/api/root/)
- [MailChimp Marketing API Reference](https://mailchimp.com/developer/marketing/api/root/)
- [MailChimp API Error Codes](https://mailchimp.com/developer/marketing/guides/error-glossary/)
