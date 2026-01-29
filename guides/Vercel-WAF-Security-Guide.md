# Vercel Security and WAF Configuration Guide

This guide provides detailed instructions for configuring security features and Web Application Firewall (WAF) protection for VibeCoder on Vercel.

## Table of Contents

1. [Web Application Firewall (WAF)](#web-application-firewall-waf)
2. [Security Headers](#security-headers)
3. [Rate Limiting](#rate-limiting)
4. [Bot Protection](#bot-protection)
5. [DDoS Protection](#ddos-protection)
6. [Monitoring and Alerts](#monitoring-and-alerts)
7. [Best Practices](#best-practices)

## Web Application Firewall (WAF)

Vercel provides Advanced Protection features that should be enabled for production deployments to protect against common web vulnerabilities.

### Enabling Vercel Advanced Protection

1. Go to Vercel dashboard > Project Settings > Security
2. Enable "Advanced Protection"
3. Configure the following settings:

#### Basic Protection

- **OWASP Top 10 Protection**: Enable protection against the OWASP Top 10 vulnerabilities
- **SQL Injection Protection**: Enable protection against SQL injection attacks
- **Cross-Site Scripting (XSS) Protection**: Enable protection against XSS attacks
- **Remote Code Execution Protection**: Enable protection against RCE attacks

#### Geographic Access Control

Limit access to your application based on geographic location:

1. Go to "Geographic Access Control" section
2. Choose either:
   - **Allow List**: Only allow access from specific countries
   - **Block List**: Block access from specific countries
3. Select countries based on your user base and threat intelligence

Example configuration:

```
Block List: North Korea, Russia, Iran (high attack sources)
```

#### IP Access Rules

Configure IP-based access rules:

1. Go to "IP Access Rules" section
2. Add specific IP addresses or CIDR ranges to block or allow
3. Consider blocking IP ranges known for malicious activity

Example configuration:

```
Block: 123.456.789.0/24 (known malicious range)
Allow: 98.765.432.1 (office IP for admin access)
```

## Security Headers

Configure security headers in your Next.js application to enhance security. Add the following to your `next.config.js`:

```javascript
// next.config.js
module.exports = {
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          {
            key: "X-Content-Type-Options",
            value: "nosniff",
          },
          {
            key: "X-Frame-Options",
            value: "DENY",
          },
          {
            key: "X-XSS-Protection",
            value: "1; mode=block",
          },
          {
            key: "Referrer-Policy",
            value: "strict-origin-when-cross-origin",
          },
          {
            key: "Content-Security-Policy",
            value: `
              default-src 'self';
              script-src 'self' 'unsafe-inline' 'unsafe-eval' https://js.stripe.com https://*.auth0.com https://cdn.auth0.com;
              style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;
              font-src 'self' https://fonts.gstatic.com data:;
              img-src 'self' data: https://*.auth0.com https://*.stripe.com;
              connect-src 'self' https://*.auth0.com https://api.stripe.com https://*.neon.tech;
              frame-src 'self' https://js.stripe.com https://*.auth0.com;
              object-src 'none';
              base-uri 'self';
              form-action 'self';
              frame-ancestors 'self';
              block-all-mixed-content;
            `
              .replace(/\s+/g, " ")
              .trim(),
          },
          {
            key: "Permissions-Policy",
            value: "camera=(), microphone=(), geolocation=()",
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

### Content Security Policy (CSP)

The CSP header above is configured for VibeCoder's specific needs:

- Allows scripts from Stripe and Auth0 domains
- Allows styles from Google Fonts
- Restricts image sources to trusted domains
- Prevents embedding your site in frames (clickjacking protection)
- Blocks mixed content (HTTP content on HTTPS pages)

Adjust the CSP as needed if you add new external resources or services.

## Rate Limiting

Implement rate limiting to protect against abuse and brute force attacks.

### Application-Level Rate Limiting

For critical endpoints, implement rate limiting in your Next.js API routes:

```typescript
// pages/api/_middleware.ts
import { NextRequest, NextResponse } from "next/server";
import { getToken } from "next-auth/jwt";

// Simple in-memory store (use Redis in production)
const ipRequestCounts = new Map<string, { count: number; timestamp: number }>();
const RATE_LIMIT_DURATION = 60; // 1 minute
const MAX_REQUESTS_PER_MINUTE = 60;

export async function middleware(request: NextRequest) {
  // Get client IP
  const ip = request.headers.get("x-forwarded-for") || "unknown";
  const now = Date.now();

  // Clean up old entries
  for (const [storedIp, data] of ipRequestCounts.entries()) {
    if (now - data.timestamp > RATE_LIMIT_DURATION * 1000) {
      ipRequestCounts.delete(storedIp);
    }
  }

  // Get current count for IP
  const current = ipRequestCounts.get(ip) || { count: 0, timestamp: now };

  // Increment count
  current.count += 1;
  current.timestamp = now;
  ipRequestCounts.set(ip, current);

  // Check if rate limit exceeded
  if (current.count > MAX_REQUESTS_PER_MINUTE) {
    return new NextResponse(JSON.stringify({ error: "Rate limit exceeded" }), {
      status: 429,
      headers: {
        "Content-Type": "application/json",
        "Retry-After": "60",
      },
    });
  }

  return NextResponse.next();
}

export const config = {
  matcher: "/api/:path*",
};
```

### Stricter Limits for Authentication Endpoints

Apply stricter rate limits for authentication endpoints to prevent brute force attacks:

```typescript
// pages/api/auth/_middleware.ts
import { NextRequest, NextResponse } from "next/server";

// Simple in-memory store (use Redis in production)
const ipRequestCounts = new Map<string, { count: number; timestamp: number }>();
const RATE_LIMIT_DURATION = 3600; // 1 hour
const MAX_REQUESTS_PER_HOUR = 10; // Stricter limit for auth endpoints

export async function middleware(request: NextRequest) {
  // Similar implementation as above but with stricter limits
  // ...
}

export const config = {
  matcher: "/api/auth/:path*",
};
```

## Bot Protection

Configure bot protection to prevent automated attacks while allowing legitimate bots.

### Vercel Bot Protection

1. Go to Vercel dashboard > Project Settings > Security > Bot Protection
2. Enable "Bot Protection"
3. Configure the following settings:
   - **Challenge Mode**: Select "JavaScript Challenge" for suspicious traffic
   - **Whitelist**: Add legitimate bot user agents (e.g., Google, Bing)
   - **Logging**: Enable logging for bot detection events

### CAPTCHA Implementation

For sensitive operations like login and registration, implement CAPTCHA:

1. Add Google reCAPTCHA or hCaptcha to your forms
2. Verify CAPTCHA tokens server-side before processing requests
3. Implement progressive CAPTCHA that only appears after suspicious activity

Example implementation:

```typescript
// pages/api/auth/login.ts
import { NextApiRequest, NextApiResponse } from "next";
import { verifyCaptcha } from "@/lib/captcha";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { email, password, captchaToken } = req.body;

  // Get login attempt count for this email/IP
  const ip = req.headers["x-forwarded-for"] || "unknown";
  const attemptKey = `login_attempts:${email}:${ip}`;
  const attempts = parseInt((await redis.get(attemptKey)) || "0");

  // Require CAPTCHA after 3 failed attempts
  if (attempts >= 3) {
    if (!captchaToken) {
      return res.status(400).json({
        error: "CAPTCHA required",
        requireCaptcha: true,
      });
    }

    const isValid = await verifyCaptcha(captchaToken);
    if (!isValid) {
      return res.status(400).json({ error: "Invalid CAPTCHA" });
    }
  }

  // Process login...

  // Increment attempt count on failure
  if (!success) {
    await redis.incr(attemptKey);
    await redis.expire(attemptKey, 3600); // 1 hour expiry
  } else {
    // Reset attempts on success
    await redis.del(attemptKey);
  }

  // Return response...
}
```

## DDoS Protection

Vercel provides built-in DDoS protection through their Edge Network. To maximize protection:

1. **Edge Functions**: Use Vercel Edge Functions for critical routes
2. **Caching**: Implement proper caching strategies
3. **Static Generation**: Use static generation where possible
4. **Circuit Breakers**: Implement circuit breakers for external API calls

### Circuit Breaker Implementation

```typescript
// lib/circuitBreaker.ts
import { CircuitBreaker } from "opossum";

export function createCircuitBreaker(fn, options = {}) {
  return new CircuitBreaker(fn, {
    timeout: 3000, // 3 seconds
    resetTimeout: 30000, // 30 seconds
    errorThresholdPercentage: 50,
    ...options,
  });
}

// Usage
const apiBreaker = createCircuitBreaker(callExternalApi);
apiBreaker.fallback(() => getFromCache()); // Fallback function
```

## Monitoring and Alerts

Set up comprehensive monitoring to detect and respond to security incidents.

### Security Event Logging

Implement logging for security-relevant events:

```typescript
// lib/securityLogger.ts
export function logSecurityEvent(event) {
  const securityLog = {
    timestamp: new Date().toISOString(),
    event: event.type,
    user: event.userId || "anonymous",
    ip: event.ip,
    userAgent: event.userAgent,
    details: event.details,
    severity: event.severity || "info",
  };

  // Log to monitoring system
  console.log(JSON.stringify(securityLog));

  // For high-severity events, send real-time alert
  if (event.severity === "high" || event.severity === "critical") {
    // Send alert via email, Slack, etc.
  }
}

// Usage
logSecurityEvent({
  type: "FAILED_LOGIN",
  userId: "user123",
  ip: "123.456.789.0",
  userAgent: "Mozilla/5.0...",
  details: "Failed login attempt",
  severity: "medium",
});
```

### Vercel Analytics and Logs

1. Enable Vercel Analytics for your project
2. Configure log forwarding to a central logging service
3. Set up alerts for security events
4. Regularly review logs for suspicious activity

## Best Practices

### Regular Security Audits

1. Run security audits on dependencies: `npm audit`
2. Scan for vulnerabilities in your code
3. Review security configurations quarterly
4. Test security controls with penetration testing

### Secret Management

1. Never commit secrets to version control
2. Use Vercel's environment variable management
3. Rotate secrets regularly
4. Use different secrets for different environments

### Principle of Least Privilege

1. Limit API access to only what's needed
2. Use role-based access control
3. Restrict database user permissions
4. Implement proper authentication and authorization

### Keep Dependencies Updated

1. Regularly update dependencies
2. Monitor for security advisories
3. Test thoroughly after updates
4. Have a process for emergency security patches

### Documentation and Response Plan

1. Document security configurations
2. Create an incident response plan
3. Train team members on security procedures
4. Conduct regular security drills

## References

- [Vercel Security Documentation](https://vercel.com/docs/concepts/security)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
- [Web Application Firewall (WAF)](https://www.cloudflare.com/learning/ddos/glossary/web-application-firewall-waf/)
