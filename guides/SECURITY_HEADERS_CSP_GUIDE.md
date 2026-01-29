# Security Headers and CSP Implementation Guide

This guide provides practical implementation strategies for configuring security headers and Content Security Policy (CSP) in applications with Auth0 integration. It complements the `310-security-headers.mdc` rule with concrete examples and implementation patterns.

## Introduction

Security headers and Content Security Policy are critical for protecting web applications against common attacks such as XSS, clickjacking, and information leakage. When implementing Auth0 authentication, special consideration is needed to ensure security headers don't break authentication flows.

## Table of Contents

1. [Core Security Headers](#core-security-headers)
2. [Content Security Policy Basics](#content-security-policy-basics)
3. [Auth0-Compatible CSP Configuration](#auth0-compatible-csp-configuration)
4. [Implementing in Next.js](#implementing-in-nextjs)
5. [Implementing in Express](#implementing-in-express)
6. [Testing Security Headers](#testing-security-headers)
7. [Environment-Specific Configurations](#environment-specific-configurations)
8. [Common Issues and Solutions](#common-issues-and-solutions)

## Core Security Headers

### Essential Security Headers

```typescript
const securityHeaders = [
  // Prevent browsers from interpreting files as a different MIME type
  {
    key: "X-Content-Type-Options",
    value: "nosniff",
  },

  // Prevents page from being framed (clickjacking protection)
  {
    key: "X-Frame-Options",
    value: "DENY",
  },

  // Enable browser XSS filtering
  {
    key: "X-XSS-Protection",
    value: "1; mode=block",
  },

  // Controls how much referrer information is included with requests
  {
    key: "Referrer-Policy",
    value: "strict-origin-when-cross-origin",
  },

  // HTTPS enforcement
  {
    key: "Strict-Transport-Security",
    value: "max-age=63072000; includeSubDomains; preload",
  },

  // Control browser features and APIs
  {
    key: "Permissions-Policy",
    value: "camera=(), microphone=(), geolocation=(), interest-cohort=()",
  },
];
```

### Security Header Descriptions

| Header                    | Purpose                    | Recommended Value                              |
| ------------------------- | -------------------------- | ---------------------------------------------- |
| X-Content-Type-Options    | Prevents MIME sniffing     | `nosniff`                                      |
| X-Frame-Options           | Prevents clickjacking      | `DENY` or `SAMEORIGIN`                         |
| X-XSS-Protection          | Enables browser XSS filter | `1; mode=block`                                |
| Referrer-Policy           | Controls referrer info     | `strict-origin-when-cross-origin`              |
| Strict-Transport-Security | Enforces HTTPS             | `max-age=63072000; includeSubDomains; preload` |
| Permissions-Policy        | Controls browser features  | Various based on needs                         |
| Content-Security-Policy   | Controls resource loading  | Complex (see below)                            |

## Content Security Policy Basics

### CSP Directives Overview

```
Content-Security-Policy: <directive> <source list>; <directive> <source list>; ...
```

Common directives:

- `default-src`: Default fallback for other directives
- `script-src`: Controls JavaScript sources
- `style-src`: Controls CSS sources
- `img-src`: Controls image sources
- `connect-src`: Controls fetch, XHR, WebSocket connections
- `frame-src`: Controls iframes
- `font-src`: Controls font loading
- `form-action`: Controls form submission targets
- `base-uri`: Controls `<base>` element
- `frame-ancestors`: Controls who can embed your site

### Basic CSP Example

```
Content-Security-Policy: default-src 'self';
                         script-src 'self' https://trusted-cdn.com;
                         style-src 'self' https://trusted-cdn.com;
                         img-src 'self' data: https://trusted-cdn.com;
                         connect-src 'self' https://api.example.com;
```

## Auth0-Compatible CSP Configuration

Auth0 requires specific domains to be allowed in your CSP for authentication to work properly.

### Required Domains for Auth0

| Auth0 Feature  | CSP Directive | Required Domains                             |
| -------------- | ------------- | -------------------------------------------- |
| Authentication | connect-src   | `https://*.auth0.com`                        |
| Login widget   | script-src    | `https://*.auth0.com`                        |
| Login widget   | style-src     | `https://*.auth0.com`                        |
| Login widget   | img-src       | `https://*.auth0.com https://s.gravatar.com` |
| Login popup    | frame-src     | `https://*.auth0.com`                        |
| User avatar    | img-src       | `https://s.gravatar.com`                     |

### Sample Auth0-Compatible CSP

```
Content-Security-Policy: default-src 'self';
  script-src 'self' https://*.auth0.com;
  style-src 'self' https://*.auth0.com;
  img-src 'self' data: https://*.auth0.com https://s.gravatar.com;
  connect-src 'self' https://*.auth0.com;
  frame-src 'self' https://*.auth0.com;
  font-src 'self';
  object-src 'none';
  base-uri 'self';
  form-action 'self';
  frame-ancestors 'none';
  block-all-mixed-content;
  upgrade-insecure-requests;
```

## Implementing in Next.js

### Next.js Security Headers Configuration

```javascript
// next.config.js
module.exports = {
  async headers() {
    return [
      {
        // Apply these headers to all routes
        source: "/:path*",
        headers: [
          {
            key: "X-DNS-Prefetch-Control",
            value: "on",
          },
          {
            key: "X-XSS-Protection",
            value: "1; mode=block",
          },
          {
            key: "X-Frame-Options",
            value: "DENY",
          },
          {
            key: "X-Content-Type-Options",
            value: "nosniff",
          },
          {
            key: "Referrer-Policy",
            value: "strict-origin-when-cross-origin",
          },
          {
            key: "Permissions-Policy",
            value:
              "camera=(), microphone=(), geolocation=(), interest-cohort=()",
          },
          {
            key: "Strict-Transport-Security",
            value: "max-age=63072000; includeSubDomains; preload",
          },
        ],
      },
    ];
  },
};
```

### Next.js Auth0-Compatible CSP

```javascript
// next.config.js
module.exports = {
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          // Other security headers...
          {
            key: "Content-Security-Policy",
            value: `
              default-src 'self';
              script-src 'self' https://*.auth0.com;
              style-src 'self' https://*.auth0.com 'unsafe-inline';
              img-src 'self' data: https://*.auth0.com https://s.gravatar.com;
              font-src 'self';
              connect-src 'self' https://*.auth0.com;
              frame-src 'self' https://*.auth0.com;
              object-src 'none';
              base-uri 'self';
              form-action 'self';
              frame-ancestors 'none';
              block-all-mixed-content;
              upgrade-insecure-requests;
            `
              .replace(/\s{2,}/g, " ")
              .trim(),
          },
        ],
      },
    ];
  },
};
```

## Implementing in Express

### Express with Helmet.js

```javascript
// app.js
const express = require("express");
const helmet = require("helmet");
const app = express();

// Basic Helmet setup
app.use(helmet());

// Custom CSP for Auth0 compatibility
app.use(
  helmet.contentSecurityPolicy({
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "*.auth0.com"],
      styleSrc: ["'self'", "*.auth0.com", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "*.auth0.com", "s.gravatar.com"],
      connectSrc: ["'self'", "*.auth0.com"],
      frameSrc: ["'self'", "*.auth0.com"],
      objectSrc: ["'none'"],
      baseUri: ["'self'"],
      formAction: ["'self'"],
      frameAncestors: ["'none'"],
    },
    reportOnly: false,
  })
);

// Routes and other middleware
// ...

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

## Testing Security Headers

### Online Tools

- [Security Headers](https://securityheaders.com)
- [CSP Evaluator](https://csp-evaluator.withgoogle.com/)
- [SSL Labs](https://www.ssllabs.com/ssltest/)

### Local Testing with Chrome DevTools

1. Open Chrome DevTools (F12)
2. Go to the Network tab
3. Click on any request to your application
4. View the "Headers" tab
5. Look for security headers in the response headers section

### Automated Testing

```javascript
// Using Jest and Supertest
describe("Security Headers", () => {
  it("returns correct security headers", async () => {
    const res = await request(app).get("/");

    expect(res.headers["x-content-type-options"]).toBe("nosniff");
    expect(res.headers["x-frame-options"]).toBe("DENY");
    expect(res.headers["x-xss-protection"]).toBe("1; mode=block");
    expect(res.headers["referrer-policy"]).toBe(
      "strict-origin-when-cross-origin"
    );
    expect(res.headers["strict-transport-security"]).toContain("max-age=");
    expect(res.headers["content-security-policy"]).toBeDefined();
  });

  it("CSP allows Auth0 domains", async () => {
    const res = await request(app).get("/");

    const csp = res.headers["content-security-policy"];
    expect(csp).toContain("*.auth0.com");
  });
});
```

## Environment-Specific Configurations

### Development vs. Production

For development environments, you may need to relax some CSP rules:

```javascript
// Development CSP
const devCsp = `
  default-src 'self';
  script-src 'self' 'unsafe-eval' https://*.auth0.com;
  style-src 'self' 'unsafe-inline' https://*.auth0.com;
  img-src 'self' data: https://*.auth0.com https://s.gravatar.com;
  connect-src 'self' https://*.auth0.com;
  frame-src 'self' https://*.auth0.com;
`;

// Production CSP
const prodCsp = `
  default-src 'self';
  script-src 'self' https://*.auth0.com;
  style-src 'self' https://*.auth0.com 'unsafe-inline';
  img-src 'self' data: https://*.auth0.com https://s.gravatar.com;
  connect-src 'self' https://*.auth0.com;
  frame-src 'self' https://*.auth0.com;
  object-src 'none';
  base-uri 'self';
  form-action 'self';
  frame-ancestors 'none';
  block-all-mixed-content;
  upgrade-insecure-requests;
`;

// Choose based on environment
const csp = process.env.NODE_ENV === "production" ? prodCsp : devCsp;
```

### CSP Reporting

For monitoring CSP violations:

```javascript
// Add reporting directive to CSP
const cspWithReporting = `${csp}; report-uri https://your-reporting-endpoint.com/csp-reports`;
```

## Common Issues and Solutions

### Issue: Auth0 Login Popup Blocked

**Symptoms:** Auth0 popup login doesn't appear, or CSP errors in console.

**Solution:** Add Auth0 domains to `frame-src` directive:

```
frame-src 'self' https://*.auth0.com;
```

### Issue: Auth0 API Calls Failing

**Symptoms:** Authentication works but token validation or user info fails.

**Solution:** Add Auth0 domains to `connect-src` directive:

```
connect-src 'self' https://*.auth0.com;
```

### Issue: Auth0 Lock Script Loading Fails

**Symptoms:** Auth0 Lock UI doesn't load, script errors in console.

**Solution:** Add Auth0 domains to `script-src` directive:

```
script-src 'self' https://*.auth0.com;
```

### Issue: Inline Styles Breaking Auth0 UI

**Symptoms:** Auth0 login widget appears unstyled or broken.

**Solution:** Either allow unsafe-inline for styles or use nonces:

```
style-src 'self' https://*.auth0.com 'unsafe-inline';
```

### Issue: CSP Blocks Auth0 Redirect

**Symptoms:** After login, redirect fails with CSP errors.

**Solution:** Ensure your application domain is in `form-action`:

```
form-action 'self';
```

## Conclusion

Implementing security headers and CSP is essential for protecting your application, but requires special configuration when using Auth0 or other authentication providers. Always test thoroughly after implementing security headers to ensure authentication flows continue to work properly.

For a complete reference of security best practices, refer to the `310-security-headers.mdc` rule in the project guidelines.

## Resources

- [Auth0 Documentation: Security](https://auth0.com/docs/security)
- [Content Security Policy Reference](https://content-security-policy.com/)
- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)
- [MDN: Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
- [Helmet.js Documentation](https://helmetjs.github.io/)
