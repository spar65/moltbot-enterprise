# Auth0 Setup Guide

> This guide provides step-by-step instructions for setting up an Auth0 tenant and application for use with Next.js applications.

## Table of Contents

1. [Creating an Auth0 Tenant](#creating-an-auth0-tenant)
2. [Creating an Application](#creating-an-application)
3. [Configuring Application Settings](#configuring-application-settings)
4. [Setting Up Test Users](#setting-up-test-users)
5. [API Configuration (Optional)](#api-configuration-optional)
6. [Security Recommendations](#security-recommendations)

## Creating an Auth0 Tenant

### Step 1: Sign up for Auth0

1. Go to [Auth0's website](https://auth0.com/) and click "Sign Up"
2. Provide your email, password, and company name
3. Choose your region (this is important - your region affects your tenant's domain)
4. Accept the terms and create your account

### Step 2: Create a new tenant (if needed)

1. After login, click on your profile picture in the top right
2. Select "Create tenant"
3. Provide a tenant name (this will be part of your Auth0 domain)
4. Choose your region (US, EU, AU, etc.) - **This is critical**
5. Select a tenant type (Development, Production)

![Auth0 Create Tenant Screenshot](https://auth0.com/docs/media/articles/dashboard/new-tenant.png)

> **IMPORTANT**: Your tenant region determines your domain's suffix (e.g., `.us.auth0.com`, `.eu.auth0.com`). Make note of this for your environment variables.

## Creating an Application

### Step 1: Create a new application

1. In the Auth0 Dashboard, navigate to "Applications" → "Applications"
2. Click "Create Application"
3. Enter a name for your application (e.g., "Next.js Web App")
4. **Important**: Select "Regular Web Application" (not Single Page App)
5. Click "Create"

![Create Application Screenshot](https://auth0.com/docs/media/articles/dashboard/new-app.png)

### Step 2: Note your application credentials

After creating the application, you'll be taken to its settings page. Take note of:

- **Domain**: This will be in the format `your-tenant.{region}.auth0.com`
- **Client ID**: A unique identifier for your application
- **Client Secret**: A secret key used to authenticate

These will be used in your environment variables.

## Configuring Application Settings

### Step 1: Configure Allowed URLs

Under the "Application URIs" section, configure the following:

```
# Application Login URI:
https://your-domain.com/auth/login

# Allowed Callback URLs:
http://localhost:3000/auth/callback,
https://your-staging-domain.com/auth/callback,
https://your-production-domain.com/auth/callback

# Allowed Logout URLs:
http://localhost:3000,
https://your-staging-domain.com,
https://your-production-domain.com

# Allowed Web Origins:
http://localhost:3000,
https://your-staging-domain.com,
https://your-production-domain.com
```

> **CRITICAL NOTE FOR SDK 4.6.0**: Use `/auth/` paths, not `/api/auth/` paths

### Step 2: Configure Advanced Settings

1. Scroll down to "Advanced Settings"
2. Under the "OAuth" tab:
   - Set "JsonWebToken Signature Algorithm" to "RS256"
   - Ensure "OIDC Conformant" is enabled
3. Under the "Grant Types" tab, ensure the following are enabled:
   - Authorization Code
   - Refresh Token
   - Client Credentials

### Step 3: Save changes

Don't forget to scroll to the bottom of the page and click "Save Changes"

## Setting Up Test Users

### Step 1: Create a test user

1. Navigate to "User Management" → "Users"
2. Click "Create User"
3. Fill in the email, password, and connection (usually "Username-Password-Authentication")
4. Click "Create"

### Step 2: Verify the test user

1. Click on the newly created user
2. If needed, click "Confirm" to verify their email
3. You can also assign roles or metadata if needed

## API Configuration (Optional)

If your application needs to access APIs:

### Step 1: Create an API

1. Navigate to "Applications" → "APIs"
2. Click "Create API"
3. Provide a name, identifier (audience), and signing algorithm (RS256)
4. Click "Create"

### Step 2: Configure permissions

1. Go to the "Permissions" tab of your API
2. Add permissions (scopes) that your application will request
3. These will be used in your authorization parameters

## Security Recommendations

1. **Use separate tenants** for development, staging, and production
2. **Rotate client secrets** periodically
3. **Enable MFA** for your Auth0 dashboard account
4. **Use strict logout URLs** to prevent redirect attacks
5. **Configure brute force protection** in Auth0 Authentication → Attack Protection
6. **Set up email verification** to ensure users verify their accounts
7. **Configure CORS** to only allow requests from your domains

## Next Steps

Now that you've set up your Auth0 tenant and application, you can configure your Next.js application to use Auth0 for authentication. Refer to our other guides:

1. [Auth0 Integration Guide](./Auth0-Integration-Guide.md)
2. [Environment-Specific Configuration](./02-Environment-Specific-Guides.md)
3. [Advanced Auth0 Integration](./03-Advanced-Auth0-Integration.md)
4. [Auth0 Testing Guide](./04-Auth0-Testing-Guide.md)
