# Auth0 Testing Guide

> This guide provides comprehensive instructions for testing Auth0 integration in local, staging, and production environments, including automated tests and common debugging strategies.

## Table of Contents

1. [Local Testing](#local-testing)
2. [Testing Environments](#testing-environments)
3. [Automated Testing](#automated-testing)
4. [Debugging Authentication Issues](#debugging-authentication-issues)
5. [CI/CD Pipeline Integration](#cicd-pipeline-integration)
6. [Authentication Flow Validation](#authentication-flow-validation)
7. [Implementation Checklist and Timeline](#implementation-checklist-and-timeline)

## Local Testing

### Setting Up Local Test Environment

#### Step 1: Configure Auth0 Application for Local Testing

In your Auth0 Dashboard:

1. Add `http://localhost:3000/auth/callback` to Allowed Callback URLs
2. Add `http://localhost:3000` to Allowed Logout URLs and Allowed Web Origins
3. Configure your application to use Auth0 test credentials

#### Step 2: Create local environment variables

Create `.env.local` file:

```
AUTH0_SECRET=use-openssl-rand-hex-32-to-generate
AUTH0_BASE_URL=http://localhost:3000
AUTH0_ISSUER_BASE_URL=https://your-dev-tenant.us.auth0.com
AUTH0_CLIENT_ID=your-dev-client-id
AUTH0_CLIENT_SECRET=your-dev-client-secret
AUTH0_DOMAIN=your-dev-tenant.us.auth0.com
APP_BASE_URL=http://localhost:3000
```

#### Step 3: Set up test users

Create test users in Auth0 Dashboard:

1. Go to "User Management" → "Users"
2. Click "Create User"
3. Create users with different roles/permissions for testing various scenarios

### Using Auth0 Diagnostic Tools

We've created several diagnostic tools to help troubleshoot Auth0 issues:

#### 1. Environment Variables Test

Create a test page at `/pages/test-env.tsx` or `/app/test-env/page.tsx` to verify environment variables:

```tsx
// From our diagnostic tools
import TestEnvPage from "../../tools/auth0-diagnostics/test-env";
export default TestEnvPage;
```

#### 2. URL Construction Test

Create an API endpoint at `/pages/api/test-auth0-urls.ts` to test Auth0 URL construction:

```tsx
// From our diagnostic tools
import handler from "../../tools/auth0-diagnostics/test-auth0-urls";
export default handler;
```

#### 3. Discovery Endpoint Checker

Use our script to verify your Auth0 domain configuration:

```bash
# Run from project root
./tools/auth0-diagnostics/check-discovery-endpoint.sh your-dev-tenant.us.auth0.com
```

## Testing Environments

### Environment Isolation Strategy

For proper testing, maintain separate Auth0 tenants for each environment:

| Environment | Auth0 Tenant Example      | Purpose                                           |
| ----------- | ------------------------- | ------------------------------------------------- |
| Development | your-app-dev.us.auth0.com | Local development and unit testing                |
| Staging     | your-app-stg.us.auth0.com | Integration testing and pre-production validation |
| Production  | your-app.us.auth0.com     | Production deployment                             |

### Setting Up Test Users

For each environment, create a consistent set of test users:

1. **Basic User**: Regular user with minimal permissions
2. **Admin User**: User with administrative privileges
3. **Multi-Role User**: User with multiple roles for complex permission testing
4. **Test Organization User**: User belonging to a test organization (for multi-tenant testing)

### Creating Test Data Generators

Create utilities to generate consistent test data:

```typescript
// utils/auth-test-data.ts
export function generateTestUser(role: string = "user") {
  const userId = `test-${role}-${Date.now()}`;
  return {
    email: `${userId}@example.com`,
    password: "Test1234!",
    metadata: {
      role,
      testUser: true,
    },
  };
}

export async function createTestUserInAuth0(userData) {
  // Implementation to create user via Auth0 Management API
  // Only for development/staging environments
}
```

## Automated Testing

### Unit Testing Auth Components

Use Jest and React Testing Library to test Auth0 components:

```typescript
// __tests__/components/LoginButton.test.tsx
import { render, screen, fireEvent } from "@testing-library/react";
import LoginButton from "../../components/LoginButton";

describe("LoginButton", () => {
  it("renders correctly", () => {
    render(<LoginButton />);
    const button = screen.getByText(/log in/i);
    expect(button).toBeInTheDocument();
  });

  it("links to Auth0 login", () => {
    render(<LoginButton />);
    const button = screen.getByText(/log in/i);
    expect(button.closest("a")).toHaveAttribute("href", "/auth/login");
  });
});
```

### Integration Testing Auth Flows

For integration tests, use a mocked Auth0 client:

```typescript
// __tests__/mocks/auth0.ts
export const mockAuth0 = {
  getSession: jest.fn().mockResolvedValue({
    user: {
      sub: "auth0|123456",
      email: "test@example.com",
      name: "Test User",
      roles: ["user"],
    },
  }),
  handleAuth: jest.fn().mockReturnValue(() => {}),
  middleware: jest.fn().mockReturnValue({ status: 200 }),
};

// Ensure lib/auth0.ts is mocked in jest.config.js
// moduleNameMapper: {
//   '@/lib/auth0': '<rootDir>/__tests__/mocks/auth0.ts'
// }
```

### E2E Testing with Cypress

For end-to-end testing with Cypress:

```javascript
// cypress/e2e/auth.cy.js
describe("Authentication", () => {
  // Method 1: Use Auth0 test credentials for actual login flow
  it("allows user to log in and access protected page", () => {
    cy.visit("/");
    cy.get('[data-cy="login-button"]').click();

    // Fill out Auth0 login form
    cy.origin(Cypress.env("auth0_domain"), () => {
      cy.get('input[name="email"]').type(Cypress.env("auth0_username"));
      cy.get('input[name="password"]').type(Cypress.env("auth0_password"));
      cy.get('button[type="submit"]').click();
    });

    // Verify redirect back to app
    cy.url().should("include", "/dashboard");
    cy.get('[data-cy="user-profile"]').should("be.visible");
  });

  // Method 2: Mock Auth0 authentication for faster tests
  it("shows authenticated UI when logged in", () => {
    // Set auth cookie to simulate logged in state
    cy.setCookie("appSession", Cypress.env("test_session_token"));

    cy.visit("/dashboard");
    cy.get('[data-cy="user-profile"]').should("be.visible");
    cy.get('[data-cy="logout-button"]').should("be.visible");
  });
});
```

## Debugging Authentication Issues

### Common Auth0 Error Patterns

| Error                        | Likely Causes                             | Troubleshooting Steps                      |
| ---------------------------- | ----------------------------------------- | ------------------------------------------ |
| MIDDLEWARE_INVOCATION_FAILED | URL construction, env vars, route paths   | Check domain format, validate Auth0_DOMAIN |
| Invalid URL                  | Malformed URLs, missing protocol          | Ensure URLs have https:// prefix           |
| Missing state parameter      | Cookie issues, cross-domain problems      | Check SameSite cookie settings             |
| consent_required             | User hasn't accepted permissions          | Add prompt=consent to login URL            |
| invalid_grant                | Expired token, invalid refresh token      | Verify token configuration, check timeouts |
| unauthorized_client          | Application not allowed to use grant type | Check grant types in Auth0 Dashboard       |

### Vercel Log Analysis

When troubleshooting in Vercel:

1. Go to Vercel Dashboard → Your Project → Logs
2. Filter for "middleware" to see middleware execution logs
3. Look for Auth0 SDK error messages
4. Check for URL construction errors (`TypeError: Invalid URL`)
5. Verify environment variables are correctly set

### Browser Debugging

For client-side debugging:

1. Open browser devtools → Network tab
2. Filter for "auth" to see authentication requests
3. Look for 4xx or 5xx responses in callback requests
4. Check response body for detailed error messages
5. Verify cookies are being set properly (look in Application tab)

### Auth0 Logs

Auth0 provides detailed authentication logs:

1. Go to Auth0 Dashboard → Monitoring → Logs
2. Filter by user or application
3. Look for failed login attempts, errors during token exchange
4. Check IP addresses to verify requests are coming from expected sources

## CI/CD Pipeline Integration

### Testing Auth0 in CI Pipelines

For proper CI testing:

```yaml
# .github/workflows/auth0-tests.yml
name: Auth0 Integration Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v2

      - name: Setup Node.js
        uses: actions/setup-node@v2
        with:
          node-version: "18"

      - name: Install dependencies
        run: npm ci

      - name: Run Auth0 diagnostics
        run: |
          # Create test env file
          echo "AUTH0_SECRET=${{ secrets.AUTH0_SECRET_TEST }}" > .env.test
          echo "AUTH0_BASE_URL=http://localhost:3000" >> .env.test
          echo "AUTH0_ISSUER_BASE_URL=${{ secrets.AUTH0_ISSUER_BASE_URL_TEST }}" >> .env.test
          echo "AUTH0_CLIENT_ID=${{ secrets.AUTH0_CLIENT_ID_TEST }}" >> .env.test
          echo "AUTH0_CLIENT_SECRET=${{ secrets.AUTH0_CLIENT_SECRET_TEST }}" >> .env.test
          echo "AUTH0_DOMAIN=${{ secrets.AUTH0_DOMAIN_TEST }}" >> .env.test

          # Run URL validation test
          NODE_ENV=test node scripts/validate-auth0-urls.js

      - name: Run tests
        run: npm test
```

### Deployment Environment Validation

Before promoting to production:

1. Create a validation script that verifies:
   - Auth0 environment variables are set
   - Auth0 domain is reachable
   - Auth0 endpoints respond correctly
   - Callback URLs are correctly configured

```typescript
// scripts/validate-auth0-deployment.ts
async function validateAuth0Deployment() {
  // Check environment variables
  const requiredVars = [
    "AUTH0_SECRET",
    "AUTH0_BASE_URL",
    "AUTH0_ISSUER_BASE_URL",
    "AUTH0_CLIENT_ID",
    "AUTH0_CLIENT_SECRET",
    "AUTH0_DOMAIN",
  ];

  const missingVars = requiredVars.filter((v) => !process.env[v]);
  if (missingVars.length > 0) {
    console.error(
      "Missing required environment variables:",
      missingVars.join(", ")
    );
    process.exit(1);
  }

  // Check Auth0 domain
  try {
    const discoveryUrl = `${process.env.AUTH0_ISSUER_BASE_URL}/.well-known/openid-configuration`;
    const response = await fetch(discoveryUrl);

    if (!response.ok) {
      console.error(`Auth0 discovery endpoint error: ${response.status}`);
      process.exit(1);
    }

    console.log("Auth0 discovery endpoint accessible");
  } catch (error) {
    console.error("Failed to access Auth0 discovery endpoint:", error);
    process.exit(1);
  }

  console.log("Auth0 deployment validation successful");
}

validateAuth0Deployment();
```

## Authentication Flow Validation

### Login Flow Testing

To verify the complete login flow works:

1. **Initial State**: User is not logged in
2. **Action**: User clicks login button
3. **Expected**: User is redirected to Auth0 login page
4. **Action**: User enters credentials
5. **Expected**: User is redirected back to application
6. **Expected**: User session is created
7. **Expected**: Protected content is visible

### Logout Flow Testing

To verify logout works correctly:

1. **Initial State**: User is logged in
2. **Action**: User clicks logout button
3. **Expected**: User is redirected to Auth0 logout endpoint
4. **Expected**: User is redirected back to application
5. **Expected**: User session is destroyed
6. **Expected**: Protected content is no longer visible

### Token Refresh Testing

To verify token refresh works:

1. **Setup**: Configure short token expiration for testing
2. **Initial State**: User is logged in with valid tokens
3. **Action**: Wait for access token to expire
4. **Action**: Attempt to access protected resource
5. **Expected**: New access token is obtained using refresh token
6. **Expected**: Request succeeds without user interaction

## Implementation Checklist and Timeline

### Realistic Timeline

A complete Auth0 implementation typically requires:

| Phase     | Task                                     | Estimated Time |
| --------- | ---------------------------------------- | -------------- |
| 1         | Auth0 tenant setup and configuration     | 1 day          |
| 2         | Basic integration (login/logout)         | 1-2 days       |
| 3         | Advanced features (roles, organizations) | 2-3 days       |
| 4         | Testing and validation                   | 2-3 days       |
| 5         | Documentation and developer guidance     | 1 day          |
| **Total** |                                          | **7-10 days**  |

### Implementation Checklist

Use this checklist to track your Auth0 implementation:

```markdown
# Auth0 Implementation Checklist

## Initial Setup

- [ ] Create Auth0 tenant
- [ ] Create Auth0 application (Regular Web App)
- [ ] Configure application settings
- [ ] Set up test users

## Environment Configuration

- [ ] Generate AUTH0_SECRET using openssl
- [ ] Configure all required environment variables
- [ ] Set up environment variables in Vercel
- [ ] Configure callback URLs for all environments

## Code Implementation

- [ ] Create Auth0 client with robust error handling
- [ ] Set up Auth0 route handler at /auth/[...auth0].ts
- [ ] Configure middleware with fallbacks
- [ ] Implement login/logout UI
- [ ] Set up protected routes

## Testing

- [ ] Run local environment variable tests
- [ ] Test URL construction
- [ ] Verify discovery endpoint
- [ ] Test login flow
- [ ] Test logout flow
- [ ] Test session persistence
- [ ] Test error scenarios

## Deployment

- [ ] Deploy to staging environment
- [ ] Verify all Auth0 functionality in staging
- [ ] Run diagnostic tools in staging
- [ ] Deploy to production
- [ ] Verify all Auth0 functionality in production
```

### Common Pitfalls to Avoid

1. **Mismatched routes**: Using `/api/auth/` instead of `/auth/` in SDK 4.6.0+
2. **Missing regional domain suffix**: Using `tenant.auth0.com` instead of `tenant.us.auth0.com`
3. **Improper error handling**: Not handling URL construction errors
4. **Mixing SDK versions**: Mixing v3 and v4 documentation/examples
5. **Insufficient testing**: Not testing in production-like environments
6. **Browser compatibility issues**: Not testing in multiple browsers

## Next Steps

Now that you understand how to test and validate Auth0 integration, refer to our other guides:

1. [Auth0 Setup Guide](./01-Auth0-Setup-Guide.md)
2. [Environment-Specific Configuration](./02-Environment-Specific-Guides.md)
3. [Advanced Auth0 Integration](./03-Advanced-Auth0-Integration.md)
