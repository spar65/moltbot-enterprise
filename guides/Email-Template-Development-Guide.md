# Email Template Development Guide

This guide provides standards and best practices for developing email templates in the VibeCoder platform, covering template structure, design requirements, testing procedures, and maintenance workflows.

## Table of Contents

1. [Template Architecture](#template-architecture)
2. [Responsive Design Standards](#responsive-design-standards)
3. [Accessibility Requirements](#accessibility-requirements)
4. [Content Best Practices](#content-best-practices)
5. [Testing Procedures](#testing-procedures)
6. [Template Maintenance](#template-maintenance)
7. [Implementation Examples](#implementation-examples)

## Template Architecture

### Base Template Structure

All email templates should follow this basic HTML structure:

```html
<!DOCTYPE html>
<html
  lang="en"
  xmlns:v="urn:schemas-microsoft-com:vml"
  xmlns:o="urn:schemas-microsoft-com:office:office"
>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="x-apple-disable-message-reformatting" />
    <meta
      name="format-detection"
      content="telephone=no, date=no, address=no, email=no"
    />
    <meta name="color-scheme" content="light" />
    <meta name="supported-color-schemes" content="light" />
    <title>{Email Title}</title>
    <!--[if mso]>
      <noscript>
        <xml>
          <o:OfficeDocumentSettings>
            <o:PixelsPerInch>96</o:PixelsPerInch>
          </o:OfficeDocumentSettings>
        </xml>
      </noscript>
    <![endif]-->
    <style>
      /* Base styles */
      body {
        margin: 0;
        padding: 0;
        width: 100% !important;
        font-family: Arial, sans-serif;
        color: #333333;
        -webkit-text-size-adjust: 100%;
        -ms-text-size-adjust: 100%;
      }

      /* Responsive styles */
      @media screen and (max-width: 600px) {
        .email-container {
          width: 100% !important;
        }
        .fluid {
          max-width: 100% !important;
          height: auto !important;
          margin-left: auto !important;
          margin-right: auto !important;
        }
        .stack-column,
        .stack-column-center {
          display: block !important;
          width: 100% !important;
          max-width: 100% !important;
          direction: ltr !important;
        }
        .stack-column-center {
          text-align: center !important;
        }
      }
    </style>
  </head>
  <body>
    <!-- Preheader text -->
    <div style="display: none; max-height: 0px; overflow: hidden;">
      {Preheader text - keep under 90 characters}
    </div>

    <!-- Email container -->
    <table
      role="presentation"
      cellspacing="0"
      cellpadding="0"
      border="0"
      align="center"
      width="600"
      style="margin: 0 auto;"
      class="email-container"
    >
      <!-- Header -->
      <tr>
        <td style="padding: 20px 0; text-align: center">
          <img
            src="{Logo URL}"
            width="200"
            height="50"
            alt="VibeCoder"
            style="height: auto; background: #ffffff; font-family: sans-serif; font-size: 15px; line-height: 15px; color: #555555;"
          />
        </td>
      </tr>

      <!-- Content area -->
      <tr>
        <td style="padding: 20px; background-color: #ffffff;">
          <!-- Content goes here -->
        </td>
      </tr>

      <!-- Footer -->
      <tr>
        <td
          style="padding: 20px; background-color: #f8f8f8; text-align: center; font-family: sans-serif; font-size: 12px; line-height: 18px; color: #666666;"
        >
          <p>© {Current Year} VibeCoder, Inc. All rights reserved.</p>
          <p>{Physical Address for CAN-SPAM compliance}</p>
          <p>
            <a
              href="{Unsubscribe URL}"
              style="color: #666666; text-decoration: underline;"
              >Unsubscribe</a
            >
            |
            <a
              href="{Preferences URL}"
              style="color: #666666; text-decoration: underline;"
              >Update Preferences</a
            >
            |
            <a
              href="{Privacy Policy URL}"
              style="color: #666666; text-decoration: underline;"
              >Privacy Policy</a
            >
          </p>
        </td>
      </tr>
    </table>
  </body>
</html>
```

### Component-Based Architecture

Templates should be built using a component-based approach:

1. **Header Component**

   - Logo and branding
   - Navigation (if needed)
   - Consistent across all templates

2. **Content Components**

   - Hero section
   - Text blocks
   - Button components
   - Image components
   - Feature blocks
   - Dividers and spacers

3. **Footer Component**
   - Legal information
   - Unsubscribe links
   - Social media links
   - Contact information

### Templating System

```typescript
// Email template renderer with components
export class EmailTemplateRenderer {
  // Component registry
  private components: Record<string, EmailComponent> = {};

  constructor() {
    // Register default components
    this.registerComponent("header", new HeaderComponent());
    this.registerComponent("footer", new FooterComponent());
    this.registerComponent("button", new ButtonComponent());
    this.registerComponent("textBlock", new TextBlockComponent());
    this.registerComponent("imageBlock", new ImageBlockComponent());
    this.registerComponent("spacer", new SpacerComponent());
    this.registerComponent("divider", new DividerComponent());
  }

  // Register a new component
  registerComponent(name: string, component: EmailComponent): void {
    this.components[name] = component;
  }

  // Render a template with data
  async renderTemplate(
    templateName: string,
    data: TemplateData
  ): Promise<string> {
    // Load template
    const template = await this.loadTemplate(templateName);

    // Process components
    let renderedTemplate = template;

    // Replace component tags with rendered components
    const componentRegex = /\{\{component:([^}]+)\}\}/g;
    renderedTemplate = renderedTemplate.replace(
      componentRegex,
      (match, componentString) => {
        const [componentName, ...paramsArray] = componentString.split(":");
        const params = paramsArray.join(":");

        // Get component
        const component = this.components[componentName];
        if (!component) {
          return `<!-- Component ${componentName} not found -->`;
        }

        // Parse parameters
        const componentParams = this.parseComponentParams(params, data);

        // Render component
        return component.render(componentParams, data);
      }
    );

    // Replace simple variables
    const variableRegex = /\{\{([^}]+)\}\}/g;
    renderedTemplate = renderedTemplate.replace(
      variableRegex,
      (match, variable) => {
        return this.getVariableValue(variable, data) || match;
      }
    );

    return renderedTemplate;
  }

  // Parse component parameters
  private parseComponentParams(
    paramsString: string,
    data: TemplateData
  ): Record<string, any> {
    const params: Record<string, any> = {};

    if (!paramsString) {
      return params;
    }

    const paramPairs = paramsString.split("|");

    for (const pair of paramPairs) {
      const [key, value] = pair.split("=");

      if (key && value) {
        // Check if value is a variable reference
        if (value.startsWith("$")) {
          const varName = value.substring(1);
          params[key] = this.getVariableValue(varName, data);
        } else {
          params[key] = value;
        }
      }
    }

    return params;
  }

  // Get variable value from data
  private getVariableValue(path: string, data: TemplateData): any {
    const parts = path.split(".");
    let value: any = data;

    for (const part of parts) {
      if (value === undefined || value === null) {
        return null;
      }

      value = value[part];
    }

    return value;
  }
}

// Component interface
interface EmailComponent {
  render(params: Record<string, any>, data: TemplateData): string;
}

// Button component example
class ButtonComponent implements EmailComponent {
  render(params: Record<string, any>, data: TemplateData): string {
    const url = params.url || "#";
    const text = params.text || "Click Here";
    const backgroundColor = params.backgroundColor || "#007bff";
    const textColor = params.textColor || "#ffffff";
    const width = params.width || "auto";

    return `
      <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" style="margin: auto;">
        <tr>
          <td style="border-radius: 4px; background: ${backgroundColor}; text-align: center;" class="button-td">
            <a href="${url}" style="background: ${backgroundColor}; border: 15px solid ${backgroundColor}; font-family: sans-serif; font-size: 14px; line-height: 1.1; text-align: center; text-decoration: none; display: block; border-radius: 4px; font-weight: bold;" class="button-a">
              <span style="color:${textColor};">${text}</span>
            </a>
          </td>
        </tr>
      </table>
    `;
  }
}
```

## Responsive Design Standards

### Breakpoints

- **Desktop**: 600px and above
- **Mobile**: Below 600px

### Responsive Design Requirements

1. **Fluid Layouts**

   - Single-column layout for mobile
   - Maximum width of 600px for desktop
   - Fluid images that scale with screen size

2. **Email Client Support**

   - Outlook (Windows): 2007, 2010, 2013, 2016, 2019
   - Apple Mail (iOS, macOS)
   - Gmail (Web, iOS, Android)
   - Outlook (iOS, Android)
   - Samsung Mail
   - Yahoo Mail

3. **Testing Requirements**
   - Test on all major email clients
   - Test on mobile and desktop devices
   - Verify responsive behavior

### Responsive HTML Examples

**Responsive Images**:

```html
<img
  src="image.jpg"
  width="600"
  alt="Description"
  style="width: 100%; max-width: 600px; height: auto;"
/>
```

**Responsive Two-Column Layout**:

```html
<table
  role="presentation"
  border="0"
  cellpadding="0"
  cellspacing="0"
  width="100%"
>
  <tr>
    <!-- First column -->
    <td valign="top" width="50%" class="stack-column">
      <table
        role="presentation"
        border="0"
        cellpadding="0"
        cellspacing="0"
        width="100%"
      >
        <tr>
          <td style="padding: 10px;">
            <img
              src="image1.jpg"
              width="280"
              alt="Image 1"
              style="width: 100%; max-width: 280px; height: auto;"
            />
          </td>
        </tr>
      </table>
    </td>
    <!-- Second column -->
    <td valign="top" width="50%" class="stack-column">
      <table
        role="presentation"
        border="0"
        cellpadding="0"
        cellspacing="0"
        width="100%"
      >
        <tr>
          <td style="padding: 10px;">
            <img
              src="image2.jpg"
              width="280"
              alt="Image 2"
              style="width: 100%; max-width: 280px; height: auto;"
            />
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
```

## Accessibility Requirements

### WCAG Compliance

Email templates should follow the Web Content Accessibility Guidelines (WCAG) 2.1 Level AA:

1. **Text Alternatives**

   - Provide alt text for all images
   - Use descriptive alt text for functional images
   - Empty alt attributes for decorative images

2. **Color Contrast**

   - Text and background color must have sufficient contrast ratio
   - Minimum 4.5:1 for normal text
   - Minimum 3:1 for large text (18pt or 14pt bold)

3. **Text Readability**

   - Minimum font size of 14px for body text
   - Line height of at least 1.5 for paragraph text
   - Sufficient spacing between paragraphs

4. **Structural Elements**
   - Logical reading order
   - Semantic HTML structure
   - Descriptive link text (avoid "click here")

### Accessibility Implementation

```html
<!-- Accessible image with alt text -->
<img
  src="feature-image.jpg"
  width="600"
  height="300"
  alt="A person using the VibeCoder dashboard to create an automation workflow"
  style="width: 100%; max-width: 600px; height: auto;"
/>

<!-- Decorative image with empty alt -->
<img
  src="divider.png"
  width="600"
  height="20"
  alt=""
  role="presentation"
  style="width: 100%; max-width: 600px; height: auto;"
/>

<!-- Accessible button with clear purpose -->
<a
  href="https://app.vibecoder.com/signup"
  style="background: #007bff; color: #ffffff; padding: 12px 20px; text-decoration: none; border-radius: 4px; display: inline-block; font-weight: bold; text-align: center;"
  >Start your free trial</a
>

<!-- Accessible link text -->
<a
  href="https://docs.vibecoder.com/getting-started"
  style="color: #007bff; text-decoration: underline;"
  >Read our getting started guide</a
>
```

### Accessibility Testing Checklist

- [ ] All images have appropriate alt text
- [ ] Color contrast ratios meet WCAG 2.1 AA standards
- [ ] Text is readable at different zoom levels
- [ ] Links have descriptive text
- [ ] Email can be navigated using keyboard only
- [ ] Reading order is logical when using screen readers
- [ ] All content is visible with images disabled

## Content Best Practices

### Subject Line Standards

1. **Length**: 50 characters or less for optimal display
2. **Personalization**: Include personalization when relevant
3. **Value Proposition**: Clearly communicate the value
4. **Urgency**: Use urgency appropriately, avoid false urgency
5. **Spam Triggers**: Avoid spam trigger words and excessive punctuation

### Preheader Text

1. **Length**: 85-100 characters maximum
2. **Purpose**: Complement the subject line and provide additional context
3. **Value**: Include a compelling reason to open the email
4. **Call to Action**: Consider including a call to action

### Copy Guidelines

1. **Tone**: Friendly, professional, and consistent with brand voice
2. **Length**: Keep paragraphs short (3-4 sentences maximum)
3. **Structure**: Use headings, bullet points, and short paragraphs
4. **Call to Action**: Clear, action-oriented language
5. **Personalization**: Use personalization tokens appropriately

### Example Content Structure

```
Subject: Your weekly VibeCoder report is ready

Preheader: See how your automations performed and discover 3 optimization opportunities

---

HEADER: Weekly Performance Report

GREETING: Hi {{firstName}},

INTRO PARAGRAPH: Your VibeCoder automations processed {{processingCount}} events this week, a {{percentChange}}% increase from last week. Here's a summary of your performance and some opportunities we've identified.

SECTION HEADING: Performance Highlights

BULLET POINTS:
• {{feature1}} automation achieved {{performance1}}% efficiency
• {{feature2}} saved approximately {{timeSaved}} hours this week
• {{feature3}} conversion rate increased by {{conversionIncrease}}%

SECTION HEADING: Optimization Opportunities

OPPORTUNITY 1: [Description of first opportunity with clear benefit]

OPPORTUNITY 2: [Description of second opportunity with clear benefit]

OPPORTUNITY 3: [Description of third opportunity with clear benefit]

CTA BUTTON: View Full Report

CLOSING: If you have any questions, our support team is ready to help.

SIGNATURE: The VibeCoder Team
```

## Testing Procedures

### Comprehensive Testing Framework

```typescript
// Email Testing Automation implementation
export class EmailTestingAutomation {
  static async runComprehensiveTests(templateId: string): Promise<TestResults> {
    const results = await Promise.all([
      this.testEmailClientRendering(templateId),
      this.testAccessibility(templateId),
      this.testSpamScore(templateId),
      this.testLinkValidation(templateId),
      this.testPersonalizationData(templateId),
    ]);

    return this.compileTestResults(results);
  }

  // Test rendering across email clients
  private static async testEmailClientRendering(
    templateId: string
  ): Promise<ClientRenderingResults> {
    const template = await emailTemplateService.getTemplate(templateId);

    // Create test data with sample values
    const testData = this.createTestData();

    // Render template with test data
    const renderedEmail = await emailTemplateService.renderTemplate(
      template,
      testData
    );

    // Submit to email testing service (e.g., Litmus, Email on Acid)
    const testResults = await emailTestingService.testRendering(renderedEmail);

    // Process and categorize results
    return {
      passed: testResults.passedClients,
      failed: testResults.failedClients,
      issues: testResults.renderingIssues,
      screenshots: testResults.screenshots,
    };
  }

  // Test accessibility compliance
  private static async testAccessibility(
    templateId: string
  ): Promise<AccessibilityResults> {
    const template = await emailTemplateService.getTemplate(templateId);
    const testData = this.createTestData();
    const renderedEmail = await emailTemplateService.renderTemplate(
      template,
      testData
    );

    // Run accessibility tests
    const accessibilityIssues = await emailTestingService.testAccessibility(
      renderedEmail
    );

    return {
      passed: accessibilityIssues.length === 0,
      issues: accessibilityIssues,
      recommendations:
        this.generateAccessibilityRecommendations(accessibilityIssues),
    };
  }

  // Test spam score
  private static async testSpamScore(
    templateId: string
  ): Promise<SpamTestResults> {
    const template = await emailTemplateService.getTemplate(templateId);
    const testData = this.createTestData();
    const renderedEmail = await emailTemplateService.renderTemplate(
      template,
      testData
    );

    // Run spam tests
    const spamResults = await emailTestingService.testSpamScore(renderedEmail);

    return {
      score: spamResults.score,
      passed: spamResults.score < 5, // Under 5 is typically considered good
      issues: spamResults.issues,
      recommendations: spamResults.recommendations,
    };
  }

  // Test all links in the email
  private static async testLinkValidation(
    templateId: string
  ): Promise<LinkValidationResults> {
    const template = await emailTemplateService.getTemplate(templateId);
    const testData = this.createTestData();
    const renderedEmail = await emailTemplateService.renderTemplate(
      template,
      testData
    );

    // Extract and test all links
    const links = this.extractLinks(renderedEmail);
    const validationResults = await Promise.all(
      links.map((link) => this.validateLink(link))
    );

    // Identify broken or problematic links
    const brokenLinks = validationResults
      .filter((result) => !result.valid)
      .map((result) => result.link);

    return {
      passed: brokenLinks.length === 0,
      totalLinks: links.length,
      brokenLinks,
    };
  }

  // Test personalization data
  private static async testPersonalizationData(
    templateId: string
  ): Promise<PersonalizationTestResults> {
    const template = await emailTemplateService.getTemplate(templateId);

    // Extract all personalization variables
    const variables = this.extractPersonalizationVariables(template.content);

    // Check for required data fields
    const requiredFields = ["firstName", "email", "unsubscribeUrl"];
    const missingRequiredFields = requiredFields.filter(
      (field) => !variables.includes(field)
    );

    // Test with empty/null values
    const nullTestData = this.createNullTestData(variables);
    const nullValueRendering = await emailTemplateService.renderTemplate(
      template,
      nullTestData
    );

    // Check for rendering errors or missing fallbacks
    const renderingIssues = this.checkForRenderingIssues(nullValueRendering);

    return {
      passed:
        missingRequiredFields.length === 0 && renderingIssues.length === 0,
      requiredFields,
      missingRequiredFields,
      allVariables: variables,
      renderingIssues,
    };
  }

  static async validateCampaignBeforeSend(
    campaignId: string
  ): Promise<ValidationResult> {
    const campaign = await emailCampaignService.getCampaign(campaignId);

    // Comprehensive pre-send validation
    const validations = await Promise.all([
      // 1. Template rendering test
      this.runComprehensiveTests(campaign.templateId),

      // 2. List validation
      this.validateAudienceList(campaign.listId),

      // 3. Compliance checks
      this.validateCompliance(campaign),

      // 4. Content quality checks
      this.validateContentQuality(campaign),

      // 5. Sending configuration
      this.validateSendingConfig(campaign),
    ]);

    // Determine if campaign is ready to send
    const allPassed = validations.every((v) => v.passed);
    const issues = validations.flatMap((v) => v.issues || []);

    return {
      ready: allPassed,
      issues,
      recommendations: this.generateRecommendations(issues),
    };
  }
}
```

### Manual Testing Checklist

Create a manual testing checklist for each template:

1. **Visual Inspection**

   - Consistent branding elements
   - Proper spacing and alignment
   - Readable font sizes and colors
   - Mobile responsiveness

2. **Functional Testing**

   - All links work correctly
   - Images load properly
   - Buttons are clickable and properly sized
   - Unsubscribe link functions correctly

3. **Personalization Testing**

   - Personalization tokens render correctly
   - Fallbacks for missing personalization data
   - Conditional content displays correctly

4. **Cross-Client Testing**
   - Renders correctly in major email clients
   - Mobile-friendly design works on various devices
   - Text-only version is readable

## Template Maintenance

### Version Control

Templates should be versioned to track changes and allow rollback if needed:

```typescript
// Template version control
interface TemplateVersion {
  id: string;
  templateId: string;
  version: string; // Semantic versioning
  content: string;
  metadata: {
    createdBy: string;
    createdAt: Date;
    description: string;
    changes: string[];
  };
}

// Template repository with versioning
class TemplateRepository {
  // Create a new template version
  async createTemplateVersion(
    templateId: string,
    content: string,
    metadata: {
      createdBy: string;
      description: string;
      changes: string[];
    }
  ): Promise<TemplateVersion> {
    // Get latest version
    const latestVersion = await this.getLatestVersion(templateId);

    // Calculate new version number
    const newVersion = this.calculateNewVersion(
      latestVersion?.version || "0.0.0",
      metadata.changes
    );

    // Create new version
    const templateVersion: TemplateVersion = {
      id: uuidv4(),
      templateId,
      version: newVersion,
      content,
      metadata: {
        ...metadata,
        createdAt: new Date(),
      },
    };

    // Save to database
    await db.templateVersions.create({
      data: templateVersion,
    });

    return templateVersion;
  }

  // Calculate new version based on changes
  private calculateNewVersion(
    currentVersion: string,
    changes: string[]
  ): string {
    const [major, minor, patch] = currentVersion.split(".").map(Number);

    // Major version bump for breaking changes
    if (changes.some((change) => change.toLowerCase().includes("breaking"))) {
      return `${major + 1}.0.0`;
    }

    // Minor version bump for new features
    if (changes.some((change) => change.toLowerCase().includes("feature"))) {
      return `${major}.${minor + 1}.0`;
    }

    // Patch version bump for fixes
    return `${major}.${minor}.${patch + 1}`;
  }
}
```

### Template Update Workflow

1. **Template Request**

   - Identify need for new template or update
   - Document requirements and changes

2. **Design and Development**

   - Design template or changes
   - Implement in HTML/CSS
   - Add to versioning system

3. **Testing**

   - Run automated tests
   - Perform manual testing
   - Fix issues and retest

4. **Approval**

   - Get stakeholder approval
   - Document final version

5. **Deployment**
   - Deploy to production
   - Update documentation
   - Communicate changes to users

### Template Audit Process

Conduct regular audits of email templates:

1. **Quarterly Reviews**

   - Review all templates for consistency
   - Check for outdated designs or content
   - Verify compliance with current standards

2. **Performance Analysis**

   - Analyze template performance metrics
   - Identify low-performing templates
   - Recommend improvements

3. **Compliance Check**
   - Verify compliance with email regulations
   - Check accessibility standards
   - Update as needed

## Implementation Examples

### Example: Welcome Email Template

```html
<!DOCTYPE html>
<html
  lang="en"
  xmlns:v="urn:schemas-microsoft-com:vml"
  xmlns:o="urn:schemas-microsoft-com:office:office"
>
  <head>
    <!-- Standard meta tags and styles omitted for brevity -->
  </head>
  <body>
    <!-- Preheader text -->
    <div style="display: none; max-height: 0px; overflow: hidden;">
      Welcome to VibeCoder! Get started with these 3 simple steps to set up your
      account.
    </div>

    <!-- Email container -->
    <table
      role="presentation"
      cellspacing="0"
      cellpadding="0"
      border="0"
      align="center"
      width="600"
      style="margin: 0 auto;"
      class="email-container"
    >
      <!-- Header -->
      <tr>
        <td style="padding: 20px 0; text-align: center">
          <img
            src="https://vibecoder.com/emails/logo.png"
            width="200"
            height="50"
            alt="VibeCoder"
            style="height: auto;"
          />
        </td>
      </tr>

      <!-- Hero section -->
      <tr>
        <td
          style="background-color: #007bff; text-align: center; padding: 40px 20px; color: #ffffff;"
        >
          <h1
            style="margin: 0; font-family: sans-serif; font-size: 28px; line-height: 36px; color: #ffffff; font-weight: bold;"
          >
            Welcome to VibeCoder!
          </h1>
          <p
            style="margin: 20px 0 0 0; font-family: sans-serif; font-size: 16px; line-height: 24px; color: #ffffff;"
          >
            We're excited to help you build amazing automations.
          </p>
        </td>
      </tr>

      <!-- Intro copy -->
      <tr>
        <td
          style="padding: 40px 20px; background-color: #ffffff; text-align: center;"
        >
          <h2
            style="margin: 0 0 20px 0; font-family: sans-serif; font-size: 22px; line-height: 28px; color: #333333; font-weight: bold;"
          >
            Getting Started is Easy
          </h2>
          <p
            style="margin: 0; font-family: sans-serif; font-size: 16px; line-height: 24px; color: #333333;"
          >
            Follow these steps to set up your account and create your first
            automation.
          </p>
        </td>
      </tr>

      <!-- Step 1 -->
      <tr>
        <td style="padding: 0 20px 30px 20px; background-color: #ffffff;">
          <table
            role="presentation"
            cellspacing="0"
            cellpadding="0"
            border="0"
            width="100%"
          >
            <tr>
              <td
                style="padding: 20px; border: 1px solid #dddddd; border-radius: 4px;"
              >
                <h3
                  style="margin: 0 0 10px 0; font-family: sans-serif; font-size: 18px; line-height: 24px; color: #333333; font-weight: bold;"
                >
                  1. Complete Your Profile
                </h3>
                <p
                  style="margin: 0 0 10px 0; font-family: sans-serif; font-size: 16px; line-height: 24px; color: #333333;"
                >
                  Add your information and preferences to personalize your
                  experience.
                </p>
                <table
                  role="presentation"
                  cellspacing="0"
                  cellpadding="0"
                  border="0"
                  align="center"
                  style="margin: auto;"
                >
                  <tr>
                    <td
                      style="border-radius: 4px; background: #007bff; text-align: center;"
                    >
                      <a
                        href="{{profileUrl}}"
                        style="background: #007bff; border: 15px solid #007bff; font-family: sans-serif; font-size: 14px; line-height: 1.1; text-align: center; text-decoration: none; display: block; border-radius: 4px; font-weight: bold;"
                      >
                        <span style="color:#ffffff;">Complete Profile</span>
                      </a>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </td>
      </tr>

      <!-- Steps 2 and 3 would follow the same pattern -->

      <!-- Help section -->
      <tr>
        <td
          style="padding: 20px; background-color: #f8f8f8; text-align: center;"
        >
          <h2
            style="margin: 0 0 10px 0; font-family: sans-serif; font-size: 18px; line-height: 24px; color: #333333; font-weight: bold;"
          >
            Need Help?
          </h2>
          <p
            style="margin: 0 0 10px 0; font-family: sans-serif; font-size: 16px; line-height: 24px; color: #333333;"
          >
            Our support team is ready to assist you with any questions.
          </p>
          <table
            role="presentation"
            cellspacing="0"
            cellpadding="0"
            border="0"
            align="center"
            style="margin: auto;"
          >
            <tr>
              <td
                style="border-radius: 4px; background: #ffffff; text-align: center; border: 1px solid #007bff;"
              >
                <a
                  href="{{supportUrl}}"
                  style="background: #ffffff; border: 15px solid #ffffff; font-family: sans-serif; font-size: 14px; line-height: 1.1; text-align: center; text-decoration: none; display: block; border-radius: 4px; font-weight: bold;"
                >
                  <span style="color:#007bff;">Contact Support</span>
                </a>
              </td>
            </tr>
          </table>
        </td>
      </tr>

      <!-- Footer -->
      <tr>
        <td
          style="padding: 20px; background-color: #f8f8f8; text-align: center; font-family: sans-serif; font-size: 12px; line-height: 18px; color: #666666;"
        >
          <p>© 2025 VibeCoder, Inc. All rights reserved.</p>
          <p>123 Main St, Suite 100, San Francisco, CA 94105</p>
          <p>
            <a
              href="{{unsubscribeUrl}}"
              style="color: #666666; text-decoration: underline;"
              >Unsubscribe</a
            >
            |
            <a
              href="{{preferencesUrl}}"
              style="color: #666666; text-decoration: underline;"
              >Update Preferences</a
            >
            |
            <a
              href="{{privacyUrl}}"
              style="color: #666666; text-decoration: underline;"
              >Privacy Policy</a
            >
          </p>
        </td>
      </tr>
    </table>
  </body>
</html>
```

### Example: Using the Component System

```typescript
// Using the component system to build an email
const welcomeEmail = {
  subject: "Welcome to VibeCoder!",
  preheader: "Get started with these 3 simple steps to set up your account.",
  components: [
    {
      type: "header",
      params: {
        logoUrl: "https://vibecoder.com/emails/logo.png",
        logoAlt: "VibeCoder",
      },
    },
    {
      type: "hero",
      params: {
        title: "Welcome to VibeCoder!",
        subtitle: "We're excited to help you build amazing automations.",
        backgroundColor: "#007bff",
        textColor: "#ffffff",
      },
    },
    {
      type: "textBlock",
      params: {
        heading: "Getting Started is Easy",
        content:
          "Follow these steps to set up your account and create your first automation.",
        alignment: "center",
      },
    },
    {
      type: "featureBlock",
      params: {
        icon: "profile",
        title: "1. Complete Your Profile",
        description:
          "Add your information and preferences to personalize your experience.",
        buttonText: "Complete Profile",
        buttonUrl: "{{profileUrl}}",
      },
    },
    {
      type: "featureBlock",
      params: {
        icon: "integration",
        title: "2. Connect Your Services",
        description:
          "Integrate with your favorite tools to automate your workflow.",
        buttonText: "Add Integrations",
        buttonUrl: "{{integrationsUrl}}",
      },
    },
    {
      type: "featureBlock",
      params: {
        icon: "automation",
        title: "3. Create Your First Automation",
        description:
          "Build a simple automation to see how easy it is to use VibeCoder.",
        buttonText: "Start Building",
        buttonUrl: "{{automationUrl}}",
      },
    },
    {
      type: "helpBlock",
      params: {
        title: "Need Help?",
        content: "Our support team is ready to assist you with any questions.",
        buttonText: "Contact Support",
        buttonUrl: "{{supportUrl}}",
      },
    },
    {
      type: "footer",
      params: {
        companyName: "VibeCoder, Inc.",
        year: "2025",
        address: "123 Main St, Suite 100, San Francisco, CA 94105",
        unsubscribeUrl: "{{unsubscribeUrl}}",
        preferencesUrl: "{{preferencesUrl}}",
        privacyUrl: "{{privacyUrl}}",
      },
    },
  ],
};

// Render the email using the component system
const renderedEmail = await emailRenderer.renderFromComponents(
  welcomeEmail.components,
  userData
);

// Send the email
await emailSender.send({
  to: userData.email,
  subject: welcomeEmail.subject,
  preheader: welcomeEmail.preheader,
  html: renderedEmail,
  from: "welcome@vibecoder.com",
});
```
