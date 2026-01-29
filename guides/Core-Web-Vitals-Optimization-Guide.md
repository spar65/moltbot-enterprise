# Core Web Vitals Optimization - Complete Guide

**Purpose:** Comprehensive guide to optimizing Core Web Vitals (LCP, INP, CLS) for excellent user experience and SEO performance.

**Last Updated:** 2025-11-19

**Related Rules:** `062-core-web-vitals.mdc`

---

## Table of Contents

1. [Understanding Core Web Vitals](#understanding-core-web-vitals)
2. [LCP - Largest Contentful Paint](#lcp-largest-contentful-paint)
3. [INP - Interaction to Next Paint](#inp-interaction-to-next-paint)
4. [CLS - Cumulative Layout Shift](#cls-cumulative-layout-shift)
5. [Measurement & Monitoring](#measurement-monitoring)
6. [Common Issues & Solutions](#common-issues-solutions)
7. [Performance Budgets](#performance-budgets)

---

## Understanding Core Web Vitals

### What Are Core Web Vitals?

Core Web Vitals are Google's standardized metrics for measuring user experience. They are:
- **Critical for SEO** - Direct ranking factor
- **User-focused** - Measure actual user experience
- **Actionable** - Clear targets and optimization paths

### The Three Core Metrics

| Metric | Measures | Target | Impact |
|--------|----------|--------|--------|
| **LCP** | Loading performance | <2.5s | How fast content appears |
| **INP** | Interactivity | <200ms | How responsive to interactions |
| **CLS** | Visual stability | <0.1 | How stable the layout is |

### Why They Matter

**SEO Impact:**
- Pages with good Core Web Vitals rank higher in Google search
- Part of "Page Experience" signals
- Mobile and desktop rankings affected

**User Experience:**
- Fast LCP = Users see content quickly
- Good INP = Responsive, smooth interactions
- Low CLS = Stable, predictable interface

**Business Impact:**
- Amazon: 100ms delay = 1% revenue loss
- Pinterest: 40% reduction in wait time = 15% increase in traffic
- Vodafone: 31% improvement in LCP = 8% increase in sales

---

## LCP - Largest Contentful Paint

### What is LCP?

**Definition:** Time until the largest content element becomes visible in the viewport.

**Target:** <2.5 seconds (good), <4s (needs improvement), >4s (poor)

**Common LCP Elements:**
- Hero images
- Large heading text blocks
- Video thumbnails
- Background images with text

### Measuring LCP

**In Browser DevTools:**
```javascript
// Chrome DevTools Performance tab
// Or use this code:
new PerformanceObserver((list) => {
  const entries = list.getEntries();
  const lastEntry = entries[entries.length - 1];
  console.log('LCP:', lastEntry.renderTime || lastEntry.loadTime);
}).observe({ entryTypes: ['largest-contentful-paint'] });
```

**With Lighthouse:**
```bash
./.cursor/tools/run-lighthouse.sh
# Look for "Largest Contentful Paint" metric
```

### LCP Optimization Strategies

#### 1. Optimize Server Response Time (TTFB)

**Target:** <600ms

**Solutions:**
- Use CDN (Vercel Edge Network)
- Enable HTTP/2
- Use SSR/SSG for fast initial response
- Optimize database queries
- Add server-side caching

```typescript
// app/page.tsx
// SSR for fast TTFB
export default async function Page() {
  const data = await getCachedData(); // Use caching!
  return <Content data={data} />;
}
```

#### 2. Optimize Resource Loading

**Preload Critical Resources:**
```typescript
// app/layout.tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <head>
        {/* Preload hero image */}
        <link rel="preload" href="/hero.webp" as="image" />
        
        {/* Preload critical font */}
        <link
          rel="preload"
          href="/fonts/inter.woff2"
          as="font"
          type="font/woff2"
          crossOrigin="anonymous"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
```

**Prioritize Above-the-Fold Images:**
```typescript
import Image from 'next/image';

export function Hero() {
  return (
    <Image
      src="/hero.jpg"
      alt="Hero"
      width={1200}
      height={600}
      priority // ✅ Loads immediately
      quality={90}
    />
  );
}
```

#### 3. Optimize Images

**Use Next.js Image Component:**
```typescript
// ✅ Automatic optimization
import Image from 'next/image';

<Image
  src="/product.jpg"
  alt="Product"
  width={800}
  height={600}
  priority={isAboveFold}
  quality={85} // Good balance
/>
```

**Image Format Priority:**
1. **AVIF** - Best compression (30-50% smaller than JPEG)
2. **WebP** - Great compression (25-35% smaller)
3. **JPEG/PNG** - Fallback

**Responsive Images:**
```typescript
<Image
  src="/hero.jpg"
  alt="Hero"
  fill
  sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
  priority
/>
```

#### 4. Eliminate Render-Blocking Resources

**Inline Critical CSS:**
```typescript
// app/layout.tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <head>
        <style dangerouslySetInnerHTML={{
          __html: `
            /* Critical CSS only - above the fold styles */
            body { margin: 0; font-family: system-ui; }
            .hero { min-height: 400px; }
          `
        }} />
      </head>
      <body>
        {children}
        {/* Non-critical CSS loads after */}
      </body>
    </html>
  );
}
```

**Defer Non-Critical JavaScript:**
```typescript
import Script from 'next/script';

<Script
  src="/analytics.js"
  strategy="afterInteractive" // Doesn't block LCP
/>
```

#### 5. Use CDN for Static Assets

**Vercel automatically provides:**
- Edge caching
- Image optimization
- Automatic compression

```typescript
// next.config.ts
const nextConfig = {
  images: {
    domains: ['cdn.example.com'],
    formats: ['image/avif', 'image/webp'],
  },
};
```

### LCP Checklist

- [ ] Server response time < 600ms (check TTFB)
- [ ] Hero image uses Next.js Image with `priority`
- [ ] Critical resources preloaded
- [ ] Images optimized (WebP/AVIF)
- [ ] No render-blocking JavaScript above fold
- [ ] Critical CSS inlined
- [ ] Using CDN (Vercel Edge)
- [ ] HTTP/2 enabled
- [ ] Fonts optimized (see font-optimization rule)

### Common LCP Issues

**Issue 1: Large Unoptimized Images**
```typescript
// ❌ BAD: 5MB JPG
<img src="/hero.jpg" alt="Hero" />

// ✅ GOOD: Next.js Image
<Image src="/hero.jpg" alt="Hero" width={1200} height={600} priority />
```

**Issue 2: Slow Server Response**
```typescript
// ❌ BAD: Slow uncached query
export default async function Page() {
  const data = await prisma.item.findMany(); // No caching!
  return <List data={data} />;
}

// ✅ GOOD: Cached with ISR
export const revalidate = 300; // 5 minutes
export default async function Page() {
  const data = await getCachedData();
  return <List data={data} />;
}
```

**Issue 3: Render-Blocking Resources**
```typescript
// ❌ BAD: Blocking script in head
<head>
  <script src="/large-library.js"></script>
</head>

// ✅ GOOD: Async loading
<Script src="/large-library.js" strategy="afterInteractive" />
```

---

## INP - Interaction to Next Paint

### What is INP?

**Definition:** Measures responsiveness to user interactions (click, tap, keyboard).

**Target:** <200ms (good), <500ms (needs improvement), >500ms (poor)

**Replaces:** First Input Delay (FID) - More comprehensive metric

### Measuring INP

**Web Vitals Library:**
```typescript
import { onINP } from 'web-vitals';

onINP((metric) => {
  console.log('INP:', metric.value);
  // Send to analytics
  sendToAnalytics(metric);
});
```

### INP Optimization Strategies

#### 1. Optimize Event Handlers

**Keep Event Handlers Light:**
```typescript
// ❌ BAD: Heavy work in event handler
const handleClick = () => {
  const result = performExpensiveCalculation(); // Blocks UI!
  updateState(result);
};

// ✅ GOOD: Defer heavy work
const handleClick = () => {
  startTransition(() => {
    const result = performExpensiveCalculation();
    updateState(result);
  });
};
```

**Debounce Frequent Events:**
```typescript
import { debounce } from 'lodash';

const handleSearch = debounce((query: string) => {
  performSearch(query);
}, 300); // Only search after 300ms of no typing
```

**Throttle Scroll/Resize:**
```typescript
import { throttle } from 'lodash';

const handleScroll = throttle(() => {
  updateScrollPosition();
}, 100); // Max once per 100ms
```

#### 2. Use React Optimization Hooks

**React.memo:**
```typescript
const ExpensiveComponent = memo(function ExpensiveComponent({ data }: Props) {
  return <ComplexVisualization data={data} />;
});
```

**useMemo:**
```typescript
const sortedData = useMemo(() => {
  return data.sort((a, b) => a.value - b.value);
}, [data]);
```

**useCallback:**
```typescript
const handleItemClick = useCallback((id: string) => {
  updateItem(id);
}, []);
```

#### 3. Break Up Long Tasks

**Yield to Main Thread:**
```typescript
async function processLargeDataset(items: Item[]) {
  const batchSize = 50;
  
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    processBatch(batch);
    
    // Yield to main thread
    await new Promise(resolve => setTimeout(resolve, 0));
  }
}
```

**Use Web Workers:**
```typescript
// worker.ts
self.addEventListener('message', (event) => {
  const result = expensiveCalculation(event.data);
  self.postMessage(result);
});

// component.tsx
const worker = new Worker(new URL('./worker.ts', import.meta.url));
worker.postMessage(data);
worker.addEventListener('message', (e) => {
  setResult(e.data);
});
```

#### 4. Use useTransition for Non-Urgent Updates

```typescript
'use client';

import { useState, useTransition } from 'react';

export function SearchResults() {
  const [query, setQuery] = useState('');
  const [isPending, startTransition] = useTransition();
  
  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setQuery(value); // Urgent - update input immediately
    
    // Non-urgent - filter results
    startTransition(() => {
      filterResults(value);
    });
  };
  
  return (
    <>
      <input value={query} onChange={handleChange} />
      {isPending && <Spinner />}
      <Results />
    </>
  );
}
```

### INP Checklist

- [ ] Event handlers are lightweight
- [ ] Debouncing/throttling for frequent events
- [ ] React.memo for expensive components
- [ ] useMemo for expensive computations
- [ ] useCallback for stable function references
- [ ] Long tasks broken into chunks
- [ ] CPU-intensive work in Web Workers
- [ ] useTransition for non-urgent updates
- [ ] No unnecessary re-renders

### Common INP Issues

**Issue 1: Expensive Event Handlers**
```typescript
// ❌ BAD: Blocks for 500ms
const handleClick = () => {
  const data = expensiveCalculation(); // 500ms!
  setState(data);
};

// ✅ GOOD: Non-blocking
const handleClick = () => {
  startTransition(() => {
    const data = expensiveCalculation();
    setState(data);
  });
};
```

**Issue 2: Unnecessary Re-renders**
```typescript
// ❌ BAD: Re-renders everything
export function List({ items }: { items: Item[] }) {
  return items.map(item => <ItemCard item={item} />);
}

// ✅ GOOD: Memoized items
const MemoizedItem = memo(ItemCard);
export function List({ items }: { items: Item[] }) {
  return items.map(item => <MemoizedItem key={item.id} item={item} />);
}
```

---

## CLS - Cumulative Layout Shift

### What is CLS?

**Definition:** Measures visual stability - unexpected layout shifts.

**Target:** <0.1 (good), <0.25 (needs improvement), >0.25 (poor)

**Common Causes:**
- Images without dimensions
- Ads/embeds without reserved space
- Dynamic content insertion
- Web fonts causing FOUT/FOIT

### Measuring CLS

**Web Vitals Library:**
```typescript
import { onCLS } from 'web-vitals';

onCLS((metric) => {
  console.log('CLS:', metric.value);
  sendToAnalytics(metric);
});
```

### CLS Optimization Strategies

#### 1. Always Specify Image Dimensions

```typescript
// ❌ BAD: No dimensions = layout shift
<img src="/product.jpg" alt="Product" />

// ✅ GOOD: Explicit dimensions
<Image
  src="/product.jpg"
  alt="Product"
  width={400}
  height={300}
/>
```

#### 2. Reserve Space for Dynamic Content

```typescript
// ✅ GOOD: Fixed height container
export function DynamicContent() {
  return (
    <div className="min-h-[200px]">
      <Suspense fallback={<Skeleton />}>
        <AsyncContent />
      </Suspense>
    </div>
  );
}
```

#### 3. Optimize Font Loading

**Use next/font:**
```typescript
import { Inter } from 'next/font/google';

const inter = Inter({
  subsets: ['latin'],
  display: 'swap', // Prevents layout shift
});
```

#### 4. Use CSS aspect-ratio

```typescript
// ✅ Maintains aspect ratio during load
<div className="aspect-video">
  <Image src="/video-thumbnail.jpg" fill alt="Video" />
</div>
```

#### 5. Avoid Inserting Content Above Existing Content

```typescript
// ❌ BAD: Pushes content down
<div>
  {newBanner && <Banner />}
  <ExistingContent />
</div>

// ✅ GOOD: Fixed position or append to bottom
<div className="relative">
  {newBanner && <Banner className="fixed top-0" />}
  <ExistingContent />
</div>
```

### CLS Checklist

- [ ] All images have width/height
- [ ] Fonts use `display: swap`
- [ ] Critical fonts preloaded
- [ ] Reserved space for ads/embeds
- [ ] Dynamic content has min-height
- [ ] No content inserted above existing content
- [ ] CSS aspect-ratio for responsive media
- [ ] Skeleton loaders with fixed dimensions

### Common CLS Issues

**Issue 1: Images Without Dimensions**
```typescript
// ❌ Causes CLS
<img src="/product.jpg" />

// ✅ Prevents CLS
<Image src="/product.jpg" width={400} height={300} alt="Product" />
```

**Issue 2: Font Loading**
```typescript
// ❌ Causes CLS
<link href="https://fonts.googleapis.com/css2?family=Inter" rel="stylesheet" />

// ✅ Prevents CLS
import { Inter } from 'next/font/google';
const inter = Inter({ display: 'swap' });
```

**Issue 3: Dynamic Content**
```typescript
// ❌ Causes CLS
<div>
  {loading ? null : <Content />}
</div>

// ✅ Prevents CLS
<div className="min-h-[300px]">
  {loading ? <Skeleton /> : <Content />}
</div>
```

---

## Measurement & Monitoring

### Development Tools

**1. Lighthouse (Local):**
```bash
./.cursor/tools/run-lighthouse.sh
```

**2. Chrome DevTools:**
- Performance tab → Record → Analyze
- Look for "Experience" section
- Check Core Web Vitals

**3. Web Vitals Extension:**
- Install Chrome extension "Web Vitals"
- Shows real-time metrics

### Production Monitoring

**1. Real User Monitoring (RUM):**
```typescript
// app/layout.tsx
import { WebVitals } from '@/components/WebVitals';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        {children}
        <WebVitals />
      </body>
    </html>
  );
}
```

```typescript
// components/WebVitals.tsx
'use client';

import { useEffect } from 'react';
import { onCLS, onINP, onLCP } from 'web-vitals';

export function WebVitals() {
  useEffect(() => {
    onCLS(sendToAnalytics);
    onINP(sendToAnalytics);
    onLCP(sendToAnalytics);
  }, []);
  
  return null;
}

function sendToAnalytics(metric: any) {
  const body = JSON.stringify(metric);
  const url = '/api/analytics/web-vitals';
  
  if (navigator.sendBeacon) {
    navigator.sendBeacon(url, body);
  } else {
    fetch(url, { body, method: 'POST', keepalive: true });
  }
}
```

**2. Google Search Console:**
- Check "Core Web Vitals" report
- See real user data
- Identify problematic pages

**3. Vercel Analytics:**
- Automatic Core Web Vitals tracking
- No code changes needed

### Setting Alerts

```typescript
// api/analytics/web-vitals/route.ts
export async function POST(request: Request) {
  const metric = await request.json();
  
  // Check thresholds
  if (metric.name === 'LCP' && metric.value > 2500) {
    await sendAlert(`LCP threshold exceeded: ${metric.value}ms`);
  }
  
  if (metric.name === 'INP' && metric.value > 200) {
    await sendAlert(`INP threshold exceeded: ${metric.value}ms`);
  }
  
  if (metric.name === 'CLS' && metric.value > 0.1) {
    await sendAlert(`CLS threshold exceeded: ${metric.value}`);
  }
  
  // Store metric
  await storeMetric(metric);
  
  return Response.json({ received: true });
}
```

---

## Performance Budgets

### Setting Budgets

```json
// lighthouse-budget.json
{
  "budgets": [{
    "path": "/*",
    "timings": [
      {
        "metric": "largest-contentful-paint",
        "budget": 2500
      },
      {
        "metric": "interactive",
        "budget": 3500
      },
      {
        "metric": "cumulative-layout-shift",
        "budget": 0.1
      }
    ],
    "resourceSizes": [
      {
        "resourceType": "script",
        "budget": 300
      },
      {
        "resourceType": "image",
        "budget": 500
      },
      {
        "resourceType": "total",
        "budget": 1000
      }
    ]
  }]
}
```

### Enforcing Budgets in CI/CD

```yaml
# .github/workflows/performance.yml
name: Performance Check

on: [pull_request]

jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Lighthouse
        uses: treosh/lighthouse-ci-action@v9
        with:
          urls: |
            https://staging.example.com/
            https://staging.example.com/products
          budgetPath: ./lighthouse-budget.json
          uploadArtifacts: true
```

---

## Quick Reference

### Core Web Vitals Targets

| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| LCP | <2.5s | 2.5s-4s | >4s |
| INP | <200ms | 200ms-500ms | >500ms |
| CLS | <0.1 | 0.1-0.25 | >0.25 |

### Priority Optimizations

**High Priority (Do First):**
1. ✅ Optimize images with Next.js Image
2. ✅ Enable ISR/SSG for static content
3. ✅ Use next/font for font optimization
4. ✅ Add resource hints (preconnect, preload)
5. ✅ Set image dimensions to prevent CLS

**Medium Priority:**
6. ⚠️ Implement caching strategy
7. ⚠️ Optimize event handlers
8. ⚠️ Add React.memo for expensive components
9. ⚠️ Use virtual scrolling for long lists
10. ⚠️ Implement RUM monitoring

**Low Priority (Nice to Have):**
11. 📌 Move heavy work to Web Workers
12. 📌 Implement service worker
13. 📌 Advanced code splitting
14. 📌 Implement HTTP/3

---

**END OF GUIDE**

**Next Steps:**
1. Run Lighthouse audit: `./.cursor/tools/run-lighthouse.sh`
2. Identify worst-performing pages
3. Apply optimizations from this guide
4. Measure improvements
5. Set up continuous monitoring

