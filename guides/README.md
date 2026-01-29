# Implementation Guides

This directory contains detailed implementation guides for various aspects of the project.

## Authentication Guides

### Auth0 Implementation

- [**Auth0 Quick Reference Card**](AUTH0_QUICK_REFERENCE.md) - Concise reference with key patterns and common errors
- [**Current Auth0 Implementation**](AUTH0_CURRENT_IMPLEMENTATION.md) - Details of the current Auth0 setup in this project
- [**Auth0 v4.6.0+ Implementation Guide**](AUTH0_V4_IMPLEMENTATION_GUIDE.md) - Comprehensive guide for implementing Auth0 v4.6.0+ in Next.js
- [**Auth0 Do's and Don'ts**](AUTH0_DOS_AND_DONTS.md) - Clear guidelines to prevent common Auth0 mistakes
- [**Auth0 Version Documentation Template**](AUTH0_VERSION_TEMPLATE.md) - Template for documenting Auth0 version details in your project
- [**Auth0 Manual Testing Procedure**](../README-Auth0-Manual-Testing.md) - Detailed steps for testing Auth0 implementation

## Why These Guides Exist

These guides were created to prevent common implementation issues, particularly around Auth0 integration where mixing different version patterns can cause critical authentication failures.

The key points are:

1. **Auth0 v3 and v4+ are completely different** in their implementation approaches
2. **Documentation must be version-specific** to prevent confusion
3. **Implementation patterns must be consistent** throughout the codebase
4. **Testing procedures must be thorough** to catch authentication issues early

## How to Use These Guides

1. **Determine your Auth0 version** before starting implementation
2. **Follow the version-specific guide** completely
3. **Document your implementation** using the version template
4. **Test thoroughly** following the testing procedure

## Contributing to Guides

When adding new guides or updating existing ones:

1. Clearly indicate version information where applicable
2. Include practical code examples
3. Highlight common pitfalls and solutions
4. Add to this index for discoverability

## Other Implementation Guides

This directory will expand to include guides for other critical implementation patterns:

- **Stripe Integration**
  - [Stripe Integration Guide](Stripe-Integration-Guide.md) - Comprehensive guide for implementing Stripe payments
  - [Stripe Webhook Guide](Stripe-Webhook-Guide.md) - Setting up and handling Stripe webhooks
  - [Stripe Fraud Prevention Guide](Stripe-Fraud-Prevention-Guide.md) - Security best practices for Stripe
  - [Stripe Production Setup](stripe-production-setup.md) - Moving from test to production
  - [Stripe Deployment Checklist](Stripe-Deployment-Checklist.md) - Complete checklist for deploying Stripe
  - [Subscription Tiers](subscriptions/subscription-tiers.md) - Overview of subscription tiers
  - [Subscription Implementation](subscriptions/subscription-access-implementation.md) - Implementing subscription-based access controls
- Database Access Patterns (coming soon)
- API Security Best Practices (coming soon)
- Frontend State Management (coming soon)
