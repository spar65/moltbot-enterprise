# Performance Monitoring - Complete Guide

**Purpose:** Comprehensive guide to measuring, monitoring, and maintaining performance across development and production.

**Last Updated:** 2025-11-19

**Related Rules:** `060-performance-metrics.mdc`, `062-core-web-vitals.mdc`

---

## Table of Contents

1. [Monitoring Strategy](#monitoring-strategy)
2. [Development Tools](#development-tools)
3. [Production Monitoring](#production-monitoring)
4. [Performance Budgets](#performance-budgets)
5. [Alerting & Response](#alerting-response)
6. [Analysis & Optimization](#analysis-optimization)

---

## Monitoring Strategy

### Two Types of Monitoring

**1. Lab Testing (Synthetic):**
- Controlled environment
- Consistent conditions
- Run before deployment
- Lighthouse, WebPageTest

**2. Real User Monitoring (RUM):**
- Actual user experience
- Real-world conditions
- Production data
- web-vitals library

**Both Are Essential:**
- Lab = Development & CI/CD
- RUM = Production validation

---

## Development Tools

### 1. Lighthouse (Primary Tool)

**Local Lighthouse:**
```bash
# Use our automation tool
./.cursor/tools/run-lighthouse.sh

# Or manually
npx lighthouse http://localhost:3000 \
  --output=html \
  --output-path=./lighthouse-report.html \
  --view
```

**What Lighthouse Measures:**
- Performance score (0-100)
- Core Web Vitals (LCP, CLS, TBT)
- First Contentful Paint (FCP)
- Speed Index
- Time to Interactive (TTI)
- Total Blocking Time (TBT)

**Lighthouse CI in GitHub Actions:**
```yaml
# .github/workflows/lighthouse-ci.yml
name: Lighthouse CI

on: [pull_request]

jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build
        run: npm run build
      
      - name: Run Lighthouse CI
        uses: treosh/lighthouse-ci-action@v9
        with:
          urls: |
            http://localhost:3000/
            http://localhost:3000/dashboard
            http://localhost:3000/assessments
          budgetPath: ./lighthouse-budget.json
          temporaryPublicStorage: true
```

### 2. Chrome DevTools Performance Panel

**How to Profile:**
1. Open DevTools (F12)
2. Go to Performance tab
3. Click Record (Ctrl+E)
4. Interact with page
5. Stop recording
6. Analyze results

**What to Look For:**
- Long tasks (>50ms) - blocks main thread
- Layout shifts - CLS violations
- JavaScript execution time
- Network waterfall
- Rendering bottlenecks

**Performance Insights Panel:**
- Chrome DevTools → Performance Insights
- Easier to understand than Performance tab
- Highlights key issues automatically

### 3. React DevTools Profiler

**Profile React Renders:**
```typescript
import { Profiler, ProfilerOnRenderCallback } from 'react';

const onRenderCallback: ProfilerOnRenderCallback = (
  id,
  phase,
  actualDuration,
  baseDuration,
  startTime,
  commitTime
) => {
  console.log(`${id} (${phase}):`, {
    actualDuration, // Time spent rendering
    baseDuration, // Estimated time without memoization
    startTime,
    commitTime,
  });
};

export function App() {
  return (
    <Profiler id="App" onRender={onRenderCallback}>
      <Dashboard />
    </Profiler>
  );
}
```

**In React DevTools:**
1. Install React DevTools extension
2. Open Profiler tab
3. Click Record
4. Interact with app
5. Stop and analyze

**What to Look For:**
- Components that render frequently
- Long render times
- Unexpected re-renders
- Components that should be memoized

### 4. Bundle Analysis

**Analyze Bundle Size:**
```bash
# Install analyzer
npm install --save-dev @next/bundle-analyzer

# Add to next.config.ts
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});

module.exports = withBundleAnalyzer({
  // Next.js config
});

# Run analysis
ANALYZE=true npm run build
```

**What to Check:**
- Total bundle size
- Largest dependencies
- Duplicate dependencies
- Unused code

### 5. Network Tab Analysis

**Check:**
- Number of requests
- Total transfer size
- Compression (gzip/brotli)
- Cache headers
- Resource timing (TTFB, download time)
- Third-party resources

**Quick Checks:**
```
✅ < 50 requests (initial load)
✅ < 1MB total transfer (gzipped)
✅ TTFB < 600ms
✅ Images using WebP/AVIF
✅ Cache-Control headers present
```

---

## Production Monitoring

### 1. Real User Monitoring (RUM)

**Implement web-vitals:**
```typescript
// components/WebVitals.tsx
'use client';

import { useEffect } from 'react';
import { onCLS, onINP, onLCP, onFCP, onTTFB } from 'web-vitals';

export function WebVitals() {
  useEffect(() => {
    // Core Web Vitals
    onCLS(sendToAnalytics);
    onINP(sendToAnalytics);
    onLCP(sendToAnalytics);
    
    // Additional metrics
    onFCP(sendToAnalytics);
    onTTFB(sendToAnalytics);
  }, []);
  
  return null;
}

function sendToAnalytics(metric: any) {
  // Send to your analytics service
  const body = JSON.stringify({
    name: metric.name,
    value: metric.value,
    rating: metric.rating,
    delta: metric.delta,
    id: metric.id,
    navigationType: metric.navigationType,
  });
  
  const url = '/api/analytics/web-vitals';
  
  // Use sendBeacon for reliability
  if (navigator.sendBeacon) {
    navigator.sendBeacon(url, body);
  } else {
    fetch(url, {
      body,
      method: 'POST',
      keepalive: true,
      headers: { 'Content-Type': 'application/json' },
    }).catch(console.error);
  }
}
```

**Add to Layout:**
```typescript
// app/layout.tsx
import { WebVitals } from '@/components/WebVitals';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        {children}
        {process.env.NODE_ENV === 'production' && <WebVitals />}
      </body>
    </html>
  );
}
```

**Store Metrics:**
```typescript
// app/api/analytics/web-vitals/route.ts
import { prisma } from '@/lib/db';

export async function POST(request: Request) {
  try {
    const metric = await request.json();
    
    // Store in database
    await prisma.webVitalMetric.create({
      data: {
        name: metric.name,
        value: metric.value,
        rating: metric.rating,
        url: metric.url || '',
        userAgent: request.headers.get('user-agent') || '',
        timestamp: new Date(),
      },
    });
    
    // Check thresholds
    await checkThresholds(metric);
    
    return Response.json({ received: true });
  } catch (error) {
    console.error('Error storing metric:', error);
    return Response.json({ error: 'Failed to store metric' }, { status: 500 });
  }
}

async function checkThresholds(metric: any) {
  const thresholds = {
    LCP: 2500,  // 2.5s
    INP: 200,   // 200ms
    CLS: 0.1,   // 0.1
    FCP: 1800,  // 1.8s
    TTFB: 600,  // 600ms
  };
  
  const threshold = thresholds[metric.name as keyof typeof thresholds];
  
  if (threshold && metric.value > threshold) {
    // Send alert
    await sendAlert({
      metric: metric.name,
      value: metric.value,
      threshold,
      url: metric.url,
    });
  }
}
```

### 2. Vercel Analytics (Recommended)

**Enable Vercel Analytics:**
```bash
npm install @vercel/analytics
```

```typescript
// app/layout.tsx
import { Analytics } from '@vercel/analytics/react';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        {children}
        <Analytics />
      </body>
    </html>
  );
}
```

**Benefits:**
- Zero configuration
- Automatic Core Web Vitals tracking
- Real user data from all visitors
- Built-in dashboards
- Audience insights (device, location, browser)

### 3. Google Search Console

**Monitor SEO Impact:**
1. Add property in Search Console
2. Verify ownership
3. Check "Core Web Vitals" report
4. See "URLs needing attention"

**What You Get:**
- Real user Core Web Vitals data (CrUX)
- Mobile and desktop metrics
- Page-level issues
- Historical trends

### 4. Custom Performance API

**Track Custom Metrics:**
```typescript
// lib/performance-tracking.ts
export function trackPerformance(metricName: string, value: number) {
  // Create performance mark
  performance.mark(metricName);
  
  // Send to analytics
  fetch('/api/analytics/custom-metrics', {
    method: 'POST',
    body: JSON.stringify({ name: metricName, value }),
    keepalive: true,
  });
}

// Usage
export async function fetchData() {
  const start = performance.now();
  
  const data = await fetch('/api/data').then(res => res.json());
  
  const duration = performance.now() - start;
  trackPerformance('api-fetch-duration', duration);
  
  return data;
}
```

**Navigation Timing API:**
```typescript
// Track navigation performance
if (typeof window !== 'undefined') {
  window.addEventListener('load', () => {
    const perfData = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
    
    const metrics = {
      dns: perfData.domainLookupEnd - perfData.domainLookupStart,
      tcp: perfData.connectEnd - perfData.connectStart,
      ttfb: perfData.responseStart - perfData.requestStart,
      download: perfData.responseEnd - perfData.responseStart,
      domInteractive: perfData.domInteractive - perfData.fetchStart,
      domComplete: perfData.domComplete - perfData.fetchStart,
      loadComplete: perfData.loadEventEnd - perfData.fetchStart,
    };
    
    sendToAnalytics({ type: 'navigation-timing', metrics });
  });
}
```

---

## Performance Budgets

### Define Budgets

**Budget Types:**
1. **Timing Budgets** - LCP, INP, CLS targets
2. **Resource Budgets** - Max KB per resource type
3. **Quantity Budgets** - Max number of requests

**lighthouse-budget.json:**
```json
{
  "budgets": [
    {
      "path": "/*",
      "timings": [
        {
          "metric": "largest-contentful-paint",
          "budget": 2500,
          "tolerance": 500
        },
        {
          "metric": "interactive",
          "budget": 3500,
          "tolerance": 500
        },
        {
          "metric": "cumulative-layout-shift",
          "budget": 0.1,
          "tolerance": 0.05
        },
        {
          "metric": "first-contentful-paint",
          "budget": 1800,
          "tolerance": 200
        }
      ],
      "resourceSizes": [
        {
          "resourceType": "script",
          "budget": 300
        },
        {
          "resourceType": "stylesheet",
          "budget": 50
        },
        {
          "resourceType": "image",
          "budget": 500
        },
        {
          "resourceType": "font",
          "budget": 100
        },
        {
          "resourceType": "total",
          "budget": 1000
        }
      ],
      "resourceCounts": [
        {
          "resourceType": "script",
          "budget": 10
        },
        {
          "resourceType": "stylesheet",
          "budget": 5
        },
        {
          "resourceType": "third-party",
          "budget": 5
        }
      ]
    }
  ]
}
```

### Enforce Budgets

**In CI/CD:**
```yaml
# .github/workflows/performance-budget.yml
name: Performance Budget

on: [pull_request]

jobs:
  check-budget:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build
        run: npm run build
      
      - name: Check bundle size
        run: ./.cursor/tools/check-bundle-size.sh
      
      - name: Run Lighthouse
        uses: treosh/lighthouse-ci-action@v9
        with:
          urls: http://localhost:3000
          budgetPath: ./lighthouse-budget.json
          uploadArtifacts: true
      
      - name: Fail on budget violation
        if: failure()
        run: |
          echo "❌ Performance budget exceeded!"
          echo "Review the Lighthouse report for details."
          exit 1
```

**Bundle Size Tracking:**
```json
// package.json
{
  "scripts": {
    "check-bundle-size": "next build && ./.cursor/tools/check-bundle-size.sh"
  }
}
```

---

## Alerting & Response

### Set Up Alerts

**Slack Webhook Integration:**
```typescript
// lib/alerts.ts
export async function sendAlert(alert: {
  metric: string;
  value: number;
  threshold: number;
  url: string;
}) {
  const webhookUrl = process.env.SLACK_WEBHOOK_URL;
  if (!webhookUrl) return;
  
  const message = {
    text: `🚨 Performance Alert`,
    blocks: [
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*Performance Threshold Exceeded*\n\n` +
                `• Metric: *${alert.metric}*\n` +
                `• Value: *${alert.value}*\n` +
                `• Threshold: *${alert.threshold}*\n` +
                `• URL: ${alert.url}`,
        },
      },
    ],
  };
  
  await fetch(webhookUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(message),
  });
}
```

**Email Alerts:**
```typescript
// lib/email-alerts.ts
import { Resend } from 'resend';

const resend = new Resend(process.env.RESEND_API_KEY);

export async function sendEmailAlert(alert: PerformanceAlert) {
  await resend.emails.send({
    from: 'alerts@example.com',
    to: ['team@example.com'],
    subject: `Performance Alert: ${alert.metric} exceeded`,
    html: `
      <h2>Performance Alert</h2>
      <p>The ${alert.metric} metric has exceeded the threshold.</p>
      <ul>
        <li><strong>Current Value:</strong> ${alert.value}</li>
        <li><strong>Threshold:</strong> ${alert.threshold}</li>
        <li><strong>URL:</strong> ${alert.url}</li>
      </ul>
    `,
  });
}
```

### Alert Thresholds

**Recommended Thresholds:**
```typescript
const ALERT_THRESHOLDS = {
  // Critical alerts
  LCP: {
    warning: 2500,  // 2.5s
    critical: 4000, // 4s
  },
  INP: {
    warning: 200,   // 200ms
    critical: 500,  // 500ms
  },
  CLS: {
    warning: 0.1,
    critical: 0.25,
  },
  
  // Warning alerts
  FCP: {
    warning: 1800,  // 1.8s
    critical: 3000, // 3s
  },
  TTFB: {
    warning: 600,   // 600ms
    critical: 1000, // 1s
  },
};
```

### Response Procedures

**When Alert Fires:**
1. **Assess Impact**
   - How many users affected?
   - Which pages/routes?
   - Mobile or desktop?

2. **Investigate**
   - Check recent deployments
   - Review error logs
   - Analyze performance traces

3. **Triage**
   - Critical: Immediate fix/rollback
   - Warning: Schedule fix within 24h
   - Info: Add to backlog

4. **Fix & Verify**
   - Implement fix
   - Test locally
   - Deploy to staging
   - Verify metrics improved

---

## Analysis & Optimization

### Performance Dashboard

**Create Dashboard:**
```typescript
// app/admin/performance/page.tsx
import { prisma } from '@/lib/db';

export default async function PerformanceDashboard() {
  // Get metrics from last 7 days
  const metrics = await prisma.webVitalMetric.findMany({
    where: {
      timestamp: {
        gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
      },
    },
    orderBy: {
      timestamp: 'desc',
    },
  });
  
  // Calculate percentiles
  const p75 = calculatePercentile(metrics, 75);
  const p90 = calculatePercentile(metrics, 90);
  const p95 = calculatePercentile(metrics, 95);
  
  return (
    <div>
      <h1>Performance Dashboard</h1>
      
      <MetricsGrid>
        <MetricCard metric="LCP" p75={p75.LCP} p95={p95.LCP} />
        <MetricCard metric="INP" p75={p75.INP} p95={p95.INP} />
        <MetricCard metric="CLS" p75={p75.CLS} p95={p95.CLS} />
      </MetricsGrid>
      
      <PerformanceChart data={metrics} />
      
      <WorstPerformingPages metrics={metrics} />
    </div>
  );
}
```

### Weekly Performance Review

**Checklist:**
- [ ] Review Core Web Vitals trends
- [ ] Identify regressing pages
- [ ] Check bundle size growth
- [ ] Review third-party impact
- [ ] Update performance budgets if needed
- [ ] Plan optimization work

### Quarterly Performance Audit

**Comprehensive Review:**
1. Run full Lighthouse audit on all pages
2. Analyze RUM data trends
3. Review and update budgets
4. Benchmark against competitors
5. Identify technical debt
6. Plan major optimizations

---

## Quick Reference

### Essential Monitoring Tools

| Tool | Use Case | Frequency |
|------|----------|-----------|
| Lighthouse | Development, CI/CD | Every PR |
| Chrome DevTools | Development debugging | As needed |
| React DevTools | Component profiling | As needed |
| web-vitals (RUM) | Production monitoring | Continuous |
| Vercel Analytics | Overall production health | Daily review |
| Google Search Console | SEO/CrUX data | Weekly review |

### Key Metrics to Track

| Metric | Target | Alert At |
|--------|--------|----------|
| LCP | <2.5s | >4s |
| INP | <200ms | >500ms |
| CLS | <0.1 | >0.25 |
| FCP | <1.8s | >3s |
| TTFB | <600ms | >1s |
| Bundle Size | <300KB JS | >500KB |

### Monitoring Checklist

**Daily:**
- [ ] Check production dashboards
- [ ] Review any alerts

**Weekly:**
- [ ] Review Core Web Vitals trends
- [ ] Check for regressions
- [ ] Review worst-performing pages

**Monthly:**
- [ ] Full Lighthouse audit
- [ ] Update performance budgets
- [ ] Review third-party impact

**Quarterly:**
- [ ] Comprehensive performance audit
- [ ] Benchmark competitors
- [ ] Plan major optimizations

---

**END OF GUIDE**

**Next Steps:**
1. Set up RUM with web-vitals: `components/WebVitals.tsx`
2. Create performance dashboard
3. Configure alerts
4. Set up CI/CD performance checks
5. Schedule regular reviews

