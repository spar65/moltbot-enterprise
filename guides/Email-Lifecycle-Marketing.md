# Email Lifecycle Marketing Guide

This guide outlines strategic approaches to email lifecycle marketing in the VibeCoder platform, focusing on customer journey alignment and engagement optimization throughout the customer lifecycle.

## Table of Contents

1. [Introduction](#introduction)
2. [Customer Lifecycle Mapping](#customer-lifecycle-mapping)
3. [Lifecycle Email Framework](#lifecycle-email-framework)
4. [Customer Journey Integration](#customer-journey-integration)
5. [Measurement & Optimization](#measurement--optimization)
6. [Implementation Guidelines](#implementation-guidelines)

## Introduction

Email lifecycle marketing refers to the strategic approach of delivering targeted, relevant emails to customers based on their position in the customer journey. By aligning email communication with specific lifecycle stages, businesses can provide more personalized experiences, increase engagement, and drive conversions at each stage of the customer relationship.

### Benefits of Lifecycle Marketing

- **Increased Relevance**: Deliver messages that match customer needs at each stage
- **Improved Engagement**: Higher open, click, and conversion rates through contextual relevance
- **Reduced Churn**: Identify and address at-risk customers before they disengage
- **Higher Customer Lifetime Value**: Nurture long-term relationships through consistent, valuable touchpoints
- **Better Resource Allocation**: Focus marketing efforts where they generate the most impact

## Customer Lifecycle Mapping

### Lifecycle Stage Definitions

Define clear customer lifecycle stages as the foundation for email marketing strategies:

```typescript
// Customer lifecycle stage definitions
export enum CustomerLifecycleStage {
  PROSPECT = "prospect",
  NEW_CUSTOMER = "new_customer",
  ACTIVE_CUSTOMER = "active_customer",
  AT_RISK = "at_risk",
  CHURNED = "churned",
  REACTIVATION = "reactivation",
}

// Lifecycle stage transition criteria
export interface StageTransitionCriteria {
  stage: CustomerLifecycleStage;
  entryCriteria: TransitionRule[];
  exitCriteria: TransitionRule[];
  typicalDuration: string;
  nextStages: CustomerLifecycleStage[];
}

// Definition of rules that determine stage transitions
export interface TransitionRule {
  field: string;
  operator:
    | "equals"
    | "notEquals"
    | "greaterThan"
    | "lessThan"
    | "contains"
    | "notContains"
    | "exists"
    | "notExists"
    | "withinLast"
    | "notWithinLast";
  value: any;
  unit?: "days" | "weeks" | "months";
  isRequired: boolean;
  weight: number;
}

// Example lifecycle stage definitions
export const DEFAULT_LIFECYCLE_STAGES: StageTransitionCriteria[] = [
  {
    stage: CustomerLifecycleStage.PROSPECT,
    entryCriteria: [
      {
        field: "email",
        operator: "exists",
        value: true,
        isRequired: true,
        weight: 100,
      },
    ],
    exitCriteria: [
      {
        field: "purchases.count",
        operator: "greaterThan",
        value: 0,
        isRequired: true,
        weight: 100,
      },
    ],
    typicalDuration: "30 days",
    nextStages: [
      CustomerLifecycleStage.NEW_CUSTOMER,
      CustomerLifecycleStage.CHURNED,
    ],
  },
  {
    stage: CustomerLifecycleStage.NEW_CUSTOMER,
    entryCriteria: [
      {
        field: "purchases.count",
        operator: "equals",
        value: 1,
        isRequired: true,
        weight: 100,
      },
      {
        field: "firstPurchaseDate",
        operator: "withinLast",
        value: 30,
        unit: "days",
        isRequired: true,
        weight: 100,
      },
    ],
    exitCriteria: [
      {
        field: "purchases.count",
        operator: "greaterThan",
        value: 1,
        isRequired: false,
        weight: 70,
      },
      {
        field: "firstPurchaseDate",
        operator: "notWithinLast",
        value: 30,
        unit: "days",
        isRequired: false,
        weight: 30,
      },
    ],
    typicalDuration: "30 days",
    nextStages: [
      CustomerLifecycleStage.ACTIVE_CUSTOMER,
      CustomerLifecycleStage.AT_RISK,
    ],
  },
  // Additional stages would be defined similarly
];
```

### Lifecycle Stage Assignment

```typescript
// Customer lifecycle stage assignment service
export class LifecycleStageManager {
  // Assign lifecycle stage to a customer based on their data
  static async determineCustomerStage(
    customerId: string
  ): Promise<LifecycleStageResult> {
    try {
      // Get customer data
      const customer = await db.customers.findUnique({
        where: { id: customerId },
        include: {
          purchases: true,
          events: true,
          subscriptions: true,
        },
      });

      if (!customer) {
        throw new Error(`Customer ${customerId} not found`);
      }

      // Get stage definitions
      const stageDefinitions = await this.getStageDefinitions(
        customer.organizationId
      );

      // Evaluate each stage for match
      const stageScores = stageDefinitions.map((stage) => ({
        stage: stage.stage,
        score: this.evaluateStageCriteria(stage, customer),
        matchDetails: this.getStageMatchDetails(stage, customer),
      }));

      // Select stage with highest score
      const assignedStage = this.selectHighestScoringStage(stageScores);

      // Determine if this is a stage transition
      const isTransition = await this.isStageTransition(
        customerId,
        assignedStage.stage
      );

      // Record stage assignment
      if (isTransition) {
        await this.recordStageTransition(customerId, assignedStage.stage);
      }

      return {
        customerId,
        previousStage: isTransition ? customer.lifecycleStage : null,
        assignedStage: assignedStage.stage,
        score: assignedStage.score,
        isTransition,
        matchDetails: assignedStage.matchDetails,
        evaluatedAt: new Date(),
      };
    } catch (error) {
      logger.error(
        `Failed to determine lifecycle stage for customer ${customerId}`,
        {
          customerId,
          error: error.message,
        }
      );

      throw error;
    }
  }
}
```

## Lifecycle Email Framework

### Lifecycle Triggers & Responses

Map key lifecycle events to specific email triggers:

| Lifecycle Stage | Trigger Event         | Email Response               | Goal                      |
| --------------- | --------------------- | ---------------------------- | ------------------------- |
| Prospect        | Initial signup        | Welcome series               | Build relationship        |
| Prospect        | Cart abandonment      | Abandonment reminder         | Recover potential sale    |
| New Customer    | First purchase        | Onboarding series            | Encourage product use     |
| New Customer    | Product delivered     | Setup guide                  | Reduce time to value      |
| Active Customer | Repeat purchase       | Cross-sell recommendation    | Increase basket size      |
| Active Customer | Feature usage         | Usage tips & best practices  | Increase product adoption |
| At Risk         | Engagement decline    | Re-engagement campaign       | Prevent churn             |
| At Risk         | Subscription near end | Renewal incentive            | Secure renewal            |
| Churned         | Subscription ended    | Win-back campaign            | Reactivate customer       |
| Reactivation    | Return after churn    | Welcome back + special offer | Rebuild relationship      |

### Content & Messaging Guidelines

Tailor messaging according to lifecycle stage:

| Lifecycle Stage | Tone                             | Content Focus                      | Call-to-Action              | Frequency            |
| --------------- | -------------------------------- | ---------------------------------- | --------------------------- | -------------------- |
| Prospect        | Helpful, Informative             | Value proposition, Problem-solving | Sign up, Learn more         | Higher (2-3x/week)   |
| New Customer    | Supportive, Educational          | Onboarding, Getting started        | Complete setup, Try feature | Higher (1-2x/week)   |
| Active Customer | Conversational, Collaborative    | Advanced usage, Community          | Upgrade, Connect            | Moderate (1x/week)   |
| At Risk         | Concerned, Value-focused         | Benefits, Success stories          | Renew, Reengage             | Moderate (1x/week)   |
| Churned         | Understanding, Incentive-focused | What's new, Improvements           | Come back, Special offer    | Lower (2x/month)     |
| Reactivation    | Appreciative, Welcoming          | Reintroduction, Updates            | Explore new features        | Building up (weekly) |

### Implementation Framework

```typescript
// Lifecycle email campaign manager
export class LifecycleEmailManager {
  // Create a lifecycle email campaign
  static async createLifecycleCampaign(
    campaign: LifecycleCampaignConfig
  ): Promise<LifecycleCampaignResult> {
    try {
      // Validate campaign configuration
      this.validateCampaignConfig(campaign);

      // Create campaign record
      const createdCampaign = await db.lifecycleCampaigns.create({
        data: {
          name: campaign.name,
          description: campaign.description,
          lifecycleStage: campaign.lifecycleStage,
          triggerEvent: campaign.triggerEvent,
          status: "draft",
          organizationId: campaign.organizationId,
          createdBy: campaign.createdBy,
        },
      });

      // Create email templates for this campaign
      const emailTemplates = await Promise.all(
        campaign.emails.map((email, index) =>
          this.createEmailTemplate(email, createdCampaign.id, index)
        )
      );

      // Create automation workflow for this campaign
      const workflow = await this.createCampaignWorkflow(
        createdCampaign.id,
        campaign,
        emailTemplates.map((template) => template.id)
      );

      return {
        campaignId: createdCampaign.id,
        name: createdCampaign.name,
        status: "draft",
        workflowId: workflow.id,
        emailTemplateIds: emailTemplates.map((template) => template.id),
        message: `Lifecycle campaign "${campaign.name}" created successfully`,
      };
    } catch (error) {
      logger.error(`Failed to create lifecycle campaign`, {
        lifecycleStage: campaign.lifecycleStage,
        triggerEvent: campaign.triggerEvent,
        error: error.message,
      });

      throw error;
    }
  }

  // Create a workflow for a lifecycle campaign
  private static async createCampaignWorkflow(
    campaignId: string,
    campaign: LifecycleCampaignConfig,
    emailTemplateIds: string[]
  ): Promise<AutomationWorkflow> {
    // Create workflow steps based on email sequence
    const steps = [];

    // Create entry trigger step
    steps.push({
      name: `${campaign.name} - Trigger`,
      type: "trigger",
      position: 0,
      config: {
        triggerType: "event",
        eventName: campaign.triggerEvent,
        filters: [
          {
            field: "customer.lifecycleStage",
            operator: "equals",
            value: campaign.lifecycleStage,
          },
          ...(campaign.additionalTriggerConditions || []),
        ],
      },
    });

    // Create steps for each email
    campaign.emails.forEach((email, index) => {
      // Add delay step if specified
      if (email.delay && email.delay.value > 0) {
        steps.push({
          name: `Delay before ${email.name}`,
          type: "delay",
          position: steps.length,
          config: {
            delayType: "fixed",
            delayValue: email.delay.value,
            delayUnit: email.delay.unit,
          },
        });
      }

      // Add email step
      steps.push({
        name: email.name,
        type: "email",
        position: steps.length,
        config: {
          emailTemplateId: emailTemplateIds[index],
          subject: email.subject,
          preheader: email.preheader,
          fromName: email.fromName || campaign.defaultFromName,
          fromEmail: email.fromEmail || campaign.defaultFromEmail,
          sendTimeOptimization: email.sendTimeOptimization || false,
        },
      });

      // Add goal/conversion tracking if specified
      if (email.conversionGoal) {
        steps.push({
          name: `Track conversion for ${email.name}`,
          type: "goalTracking",
          position: steps.length,
          config: {
            goalType: email.conversionGoal.type,
            eventName: email.conversionGoal.eventName,
            urlPath: email.conversionGoal.urlPath,
            valueField: email.conversionGoal.valueField,
          },
        });
      }
    });

    // Create the workflow with all steps
    const workflow = await db.automationWorkflows.create({
      data: {
        name: `${campaign.name} Workflow`,
        description: campaign.description,
        status: "draft",
        lifecycleCampaignId: campaignId,
        steps: {
          create: steps,
        },
      },
    });

    return workflow;
  }
}
```

## Customer Journey Integration

### Journey Mapping

Document the customer journey stages and align email communications accordingly:

```typescript
// Customer journey stage definitions
export enum CustomerJourneyStage {
  AWARENESS = "awareness",
  CONSIDERATION = "consideration",
  DECISION = "decision",
  ONBOARDING = "onboarding",
  ADOPTION = "adoption",
  RETENTION = "retention",
  EXPANSION = "expansion",
  ADVOCACY = "advocacy",
}

// Journey mapping configuration
export interface JourneyStageMapping {
  journeyStage: CustomerJourneyStage;
  lifecycleStages: CustomerLifecycleStage[];
  keyEvents: string[];
  emailGoals: string[];
  recommendedContentTypes: string[];
  kpis: string[];
}

// Example journey mapping
export const DEFAULT_JOURNEY_MAPPING: JourneyStageMapping[] = [
  {
    journeyStage: CustomerJourneyStage.AWARENESS,
    lifecycleStages: [CustomerLifecycleStage.PROSPECT],
    keyEvents: [
      "first_visit",
      "blog_view",
      "resource_download",
      "newsletter_signup",
    ],
    emailGoals: [
      "Education about problem",
      "Value proposition introduction",
      "Trust building",
    ],
    recommendedContentTypes: [
      "Blog content",
      "Industry reports",
      "Educational resources",
    ],
    kpis: [
      "Email open rate",
      "Resource download rate",
      "Website visit frequency",
    ],
  },
  {
    journeyStage: CustomerJourneyStage.CONSIDERATION,
    lifecycleStages: [CustomerLifecycleStage.PROSPECT],
    keyEvents: [
      "product_page_view",
      "pricing_page_view",
      "feature_comparison",
      "free_trial_signup",
    ],
    emailGoals: [
      "Product differentiation",
      "Feature showcasing",
      "Social proof",
      "Objection handling",
    ],
    recommendedContentTypes: [
      "Product demos",
      "Case studies",
      "Feature highlights",
      "Comparison guides",
    ],
    kpis: ["Demo request rate", "Case study engagement", "Trial signup rate"],
  },
  // Additional journey stages would be defined similarly
];
```

### Customer Experience Mapping

```typescript
// Customer experience mapping service
export class CustomerExperienceMapper {
  // Map customer to their current journey stage
  static async mapCustomerJourney(
    customerId: string
  ): Promise<CustomerJourneyResult> {
    try {
      // Get customer data
      const customer = await db.customers.findUnique({
        where: { id: customerId },
        include: {
          events: {
            orderBy: { timestamp: "desc" },
            take: 100,
          },
          purchases: true,
        },
      });

      if (!customer) {
        throw new Error(`Customer ${customerId} not found`);
      }

      // Get journey mapping configuration
      const journeyMapping = await this.getJourneyMapping(
        customer.organizationId
      );

      // Calculate journey stage scores based on customer data and events
      const stageScores = journeyMapping.map((journeyStage) => ({
        stage: journeyStage.journeyStage,
        score: this.calculateJourneyStageScore(journeyStage, customer),
        matchedEvents: this.findMatchingEvents(
          journeyStage.keyEvents,
          customer.events
        ),
      }));

      // Select primary and secondary journey stages
      const primaryStage = this.selectHighestScoringStage(stageScores);
      const secondaryStage = this.selectSecondHighestScoringStage(stageScores);

      // Get content recommendations for these stages
      const contentRecommendations = this.getContentRecommendations(
        [primaryStage.stage, secondaryStage.stage],
        journeyMapping
      );

      // Record journey mapping result
      await this.recordJourneyMapping(
        customerId,
        primaryStage.stage,
        secondaryStage.stage
      );

      return {
        customerId,
        primaryJourneyStage: primaryStage.stage,
        primaryStageScore: primaryStage.score,
        secondaryJourneyStage: secondaryStage.stage,
        secondaryStageScore: secondaryStage.score,
        lifecycleStage: customer.lifecycleStage,
        matchedEvents: primaryStage.matchedEvents,
        contentRecommendations,
        mappedAt: new Date(),
      };
    } catch (error) {
      logger.error(`Failed to map customer journey for ${customerId}`, {
        customerId,
        error: error.message,
      });

      throw error;
    }
  }
}
```

### Lifecycle-Journey Alignment Matrix

| Lifecycle Stage | Journey Stage(s)         | Email Focus                      | Key Email Types                                         |
| --------------- | ------------------------ | -------------------------------- | ------------------------------------------------------- |
| Prospect        | Awareness, Consideration | Education, Differentiation       | Welcome Series, Educational Content, Feature Highlights |
| New Customer    | Decision, Onboarding     | Validation, Setup Success        | Purchase Confirmation, Setup Guides, Quick Wins         |
| Active Customer | Adoption, Retention      | Value Maximization, Relationship | Feature Tips, Use Case Examples, Milestone Celebration  |
| At Risk         | Retention                | Value Reminders, Incentives      | Usage Summaries, Special Offers, Renewal Reminders      |
| Churned         | Awareness (reset)        | Re-education, Improvement        | What's New, Feature Updates, Win-back Offers            |
| Reactivation    | Onboarding, Adoption     | Re-orientation, Quick Value      | Welcome Back, New Feature Highlights                    |

## Measurement & Optimization

### Lifecycle Email KPIs

Track these key performance indicators for lifecycle email programs:

| Lifecycle Stage | Primary KPIs                                        | Secondary KPIs                                  | Business Impact Metrics                           |
| --------------- | --------------------------------------------------- | ----------------------------------------------- | ------------------------------------------------- |
| Prospect        | Subscription rate, Lead quality score               | Open rate, Click rate                           | Lead-to-customer conversion rate, Cost per lead   |
| New Customer    | Onboarding completion rate, First value achievement | Time to first value, Support ticket rate        | First 30-day retention, Initial expansion revenue |
| Active Customer | Engagement index, Feature adoption rate             | Active days per month, Session frequency        | Retention rate, Net revenue retention             |
| At Risk         | Recovery rate, Engagement reactivation              | Response rate to offers, Support usage          | Saved revenue, Churn reduction                    |
| Churned         | Win-back rate                                       | Open rate from churned, Click rate from churned | Reacquisition revenue, Reacquisition cost         |
| Reactivation    | Retention after reactivation                        | Re-engagement depth                             | Second lifetime value, Referral rate              |

### Measurement Implementation

```typescript
// Lifecycle email analytics service
export class LifecycleEmailAnalytics {
  // Generate lifecycle email program performance report
  static async generatePerformanceReport(
    organizationId: string,
    dateRange: DateRange
  ): Promise<LifecyclePerformanceReport> {
    try {
      // Get all lifecycle campaigns for organization
      const campaigns = await db.lifecycleCampaigns.findMany({
        where: { organizationId },
        include: {
          emailTemplates: true,
          automationWorkflow: {
            include: { steps: true },
          },
        },
      });

      // Get performance metrics for each campaign
      const campaignMetrics = await Promise.all(
        campaigns.map((campaign) =>
          this.getCampaignPerformance(campaign.id, dateRange)
        )
      );

      // Group metrics by lifecycle stage
      const stageMetrics = this.groupMetricsByLifecycleStage(campaignMetrics);

      // Calculate overall program metrics
      const overallMetrics = this.calculateOverallMetrics(stageMetrics);

      // Generate lifecycle journey insights
      const journeyInsights = await this.generateJourneyInsights(
        organizationId,
        stageMetrics,
        dateRange
      );

      // Identify optimization opportunities
      const optimizationOpportunities = this.identifyOptimizationOpportunities(
        stageMetrics,
        overallMetrics
      );

      return {
        organizationId,
        dateRange,
        overallMetrics,
        stageMetrics,
        journeyInsights,
        optimizationOpportunities,
        generatedAt: new Date(),
      };
    } catch (error) {
      logger.error(`Failed to generate lifecycle performance report`, {
        organizationId,
        error: error.message,
      });

      throw error;
    }
  }

  // Get performance metrics for a single campaign
  private static async getCampaignPerformance(
    campaignId: string,
    dateRange: DateRange
  ): Promise<CampaignPerformance> {
    // Get campaign details
    const campaign = await db.lifecycleCampaigns.findUnique({
      where: { id: campaignId },
      include: {
        emailTemplates: true,
        automationWorkflow: true,
      },
    });

    // Get email metrics
    const emailMetrics = await Promise.all(
      campaign.emailTemplates.map((template) =>
        this.getEmailMetrics(template.id, dateRange)
      )
    );

    // Get conversion metrics
    const conversionMetrics = await this.getConversionMetrics(
      campaign.automationWorkflow.id,
      dateRange
    );

    // Calculate campaign performance metrics
    return {
      campaignId,
      name: campaign.name,
      lifecycleStage: campaign.lifecycleStage,
      triggerEvent: campaign.triggerEvent,
      recipients: emailMetrics.reduce((sum, m) => sum + m.sent, 0),
      opens: emailMetrics.reduce((sum, m) => sum + m.opens, 0),
      clicks: emailMetrics.reduce((sum, m) => sum + m.clicks, 0),
      conversions: conversionMetrics.conversions,
      conversionValue: conversionMetrics.conversionValue,
      openRate: this.calculateOpenRate(emailMetrics),
      clickRate: this.calculateClickRate(emailMetrics),
      conversionRate: this.calculateConversionRate(
        emailMetrics,
        conversionMetrics
      ),
      emailMetrics,
    };
  }
}
```

## Implementation Guidelines

### Implementation Roadmap

Follow this structured approach to implement effective lifecycle email marketing:

1. **Foundation Phase (Month 1-2)**

   - Define lifecycle stages and transition rules
   - Map customer journey stages to lifecycle stages
   - Set up basic welcome and onboarding email sequences
   - Establish baseline measurement framework

2. **Expansion Phase (Month 3-4)**

   - Implement full customer lifecycle email programs
   - Create dynamic content personalization
   - Set up automated trigger-based emails for key events
   - Deploy A/B testing framework for continuous optimization

3. **Optimization Phase (Month 5-6)**
   - Refine segmentation based on behavioral data
   - Implement advanced personalization logic
   - Optimize send times and frequency
   - Develop predictive models for at-risk identification

### Best Practices for Lifecycle Email Programs

1. **Data-Driven Approach**

   - Use behavioral data to trigger emails, not just time-based sequences
   - Track customer engagement patterns to refine lifecycle stage definitions
   - Leverage predictive analytics to anticipate customer needs

2. **Content Relevance**

   - Match content specifically to lifecycle stage needs
   - Personalize beyond basic fields (name, company) to behaviors and preferences
   - Test different content approaches for each lifecycle stage

3. **Timing Optimization**

   - Implement send-time optimization for each recipient
   - Adjust frequency based on engagement levels
   - Create appropriate spacing between messages in sequences

4. **Continuous Improvement**
   - A/B test all major lifecycle email campaigns
   - Regularly review and update lifecycle stage definitions
   - Compare performance across lifecycle stages to allocate resources

### Technical Architecture

```typescript
// Lifecycle email program architecture
export class LifecycleEmailArchitecture {
  // Initialize lifecycle email system components
  static async initializeLifecycleSystem(
    organizationId: string
  ): Promise<SystemInitializationResult> {
    try {
      // Initialize lifecycle stage definitions
      await this.initializeLifecycleStages(organizationId);

      // Initialize journey mapping
      await this.initializeJourneyMapping(organizationId);

      // Create basic lifecycle email templates
      await this.createBaseEmailTemplates(organizationId);

      // Set up analytics tracking
      await this.setupAnalyticsTracking(organizationId);

      // Create initial automation workflows
      await this.createBaseAutomationWorkflows(organizationId);

      // Set up scheduled processes
      await this.setupScheduledProcesses(organizationId);

      return {
        organizationId,
        status: "success",
        components: {
          lifecycleStages: true,
          journeyMapping: true,
          emailTemplates: true,
          analyticsTracking: true,
          automationWorkflows: true,
          scheduledProcesses: true,
        },
        message: "Lifecycle email system initialized successfully",
        createdAt: new Date(),
      };
    } catch (error) {
      logger.error(`Failed to initialize lifecycle email system`, {
        organizationId,
        error: error.message,
      });

      throw error;
    }
  }

  // Create base automation workflows
  private static async createBaseAutomationWorkflows(
    organizationId: string
  ): Promise<void> {
    // Create welcome series workflow
    await LifecycleEmailManager.createLifecycleCampaign({
      name: "Welcome Series",
      description: "Introduction series for new subscribers",
      lifecycleStage: CustomerLifecycleStage.PROSPECT,
      triggerEvent: "email_subscription",
      organizationId,
      defaultFromName: "Customer Success Team",
      defaultFromEmail: "success@company.com",
      emails: [
        {
          name: "Welcome Email",
          subject: "Welcome to {company_name}",
          preheader: "We're excited to have you join us",
          content: TEMPLATE_WELCOME_EMAIL,
          delay: { value: 0, unit: "hours" },
          sendTimeOptimization: false,
        },
        {
          name: "Value Proposition",
          subject: "How {company_name} helps you succeed",
          preheader: "Discover how our solution addresses your challenges",
          content: TEMPLATE_VALUE_PROP_EMAIL,
          delay: { value: 2, unit: "days" },
          sendTimeOptimization: true,
          conversionGoal: {
            type: "pageView",
            urlPath: "/product",
          },
        },
        {
          name: "Customer Stories",
          subject: "See how others succeeded with {company_name}",
          preheader: "Real results from customers like you",
          content: TEMPLATE_CASE_STUDIES_EMAIL,
          delay: { value: 5, unit: "days" },
          sendTimeOptimization: true,
          conversionGoal: {
            type: "event",
            eventName: "request_demo",
          },
        },
      ],
      createdBy: "system",
    });

    // Create onboarding series workflow
    await LifecycleEmailManager.createLifecycleCampaign({
      name: "New Customer Onboarding",
      description: "Onboarding series for new customers",
      lifecycleStage: CustomerLifecycleStage.NEW_CUSTOMER,
      triggerEvent: "first_purchase",
      organizationId,
      defaultFromName: "Customer Success Team",
      defaultFromEmail: "success@company.com",
      emails: [
        {
          name: "Purchase Confirmation",
          subject: "Your {company_name} purchase confirmation",
          preheader: "Thank you for your purchase",
          content: TEMPLATE_PURCHASE_CONFIRMATION,
          delay: { value: 0, unit: "hours" },
          sendTimeOptimization: false,
        },
        {
          name: "Getting Started Guide",
          subject: "Getting started with {product_name}",
          preheader: "Easy steps to get up and running quickly",
          content: TEMPLATE_GETTING_STARTED,
          delay: { value: 1, unit: "days" },
          sendTimeOptimization: true,
          conversionGoal: {
            type: "event",
            eventName: "product_first_use",
          },
        },
        {
          name: "First Success Tips",
          subject: "Tips for your first success with {product_name}",
          preheader: "Achieve your first win quickly",
          content: TEMPLATE_FIRST_SUCCESS,
          delay: { value: 3, unit: "days" },
          sendTimeOptimization: true,
          conversionGoal: {
            type: "event",
            eventName: "feature_used",
          },
        },
      ],
      createdBy: "system",
    });

    // Additional base workflows would be created similarly
  }
}
```

## Resources

- [MailChimp Marketing API Documentation](https://mailchimp.com/developer/marketing/api/)
- [Customer Lifecycle Mapping Guide](https://www.hubspot.com/customer-lifecycle-marketing)
- [Email Automation Best Practices](https://mailchimp.com/resources/email-automation-best-practices/)
- [Journey-based Email Marketing](https://www.mckinsey.com/capabilities/growth-marketing-and-sales/our-insights/the-value-of-getting-personalization-right-or-wrong-is-multiplying)
- [Measuring Email Marketing Success](https://www.litmus.com/blog/email-marketing-kpis-metrics/)
