# Frontend Performance - Complete Guide

**Purpose:** Master guide covering all aspects of frontend performance optimization, from initial load to runtime performance.

**Last Updated:** 2025-11-19

**Related Rules:** `060-performance-metrics.mdc`, `061-code-splitting.mdc`, `062-core-web-vitals.mdc`, `062-rendering-strategies.mdc`, `063-client-performance.mdc`, `064-caching-strategies.mdc`, `064-font-optimization.mdc`, `065-third-party-script-management.mdc`, `066-network-optimization.mdc`, `067-runtime-optimization.mdc`

---

## Table of Contents

1. [Performance Overview](#performance-overview)
2. [Loading Performance](#loading-performance)
3. [Rendering Performance](#rendering-performance)
4. [Runtime Performance](#runtime-performance)
5. [Asset Optimization](#asset-optimization)
6. [Network Performance](#network-performance)
7. [Performance Checklist](#performance-checklist)

---

## Performance Overview

### The Complete Performance Picture

**Three Performance Phases:**
1. **Loading** - How fast the page loads (LCP, TTFB, FCP)
2. **Interactivity** - How responsive interactions are (INP, TBT)
3. **Visual Stability** - How stable the layout is (CLS)

**Performance Budget:**
```
Target Performance Score: 90+/100 (Lighthouse)
- Loading: LCP < 2.5s
- Interactivity: INP < 200ms
- Visual Stability: CLS < 0.1
- Bundle Size: < 300KB (gzipped)
- Requests: < 50 (initial load)
```

### Performance ROI

**Business Impact:**
- **100ms faster** = 1% increase in conversions (Amazon)
- **0.1s improvement** = 8% increase in sales (Vodafone)
- **40% faster** = 15% increase in traffic (Pinterest)

**SEO Impact:**
- Core Web Vitals are Google ranking factors
- Better performance = higher search rankings
- Mobile performance especially critical

---

## Loading Performance

### Critical Metrics

**LCP (Largest Contentful Paint)** - Target: <2.5s
**FCP (First Contentful Paint)** - Target: <1.8s
**TTFB (Time to First Byte)** - Target: <600ms

### 1. Optimize Server Response (TTFB)

**Use Static Generation (SSG):**
```typescript
// app/page.tsx - Static by default
export default async function HomePage() {
  const data = await getStaticData();
  return <HomeContent data={data} />;
}
```

**Incremental Static Regeneration (ISR):**
```typescript
// app/blog/[slug]/page.tsx
export const revalidate = 3600; // Regenerate every hour

export async function generateStaticParams() {
  const posts = await getPosts();
  return posts.map((post) => ({ slug: post.slug }));
}

export default async function BlogPost({ params }: { params: { slug: string } }) {
  const post = await getPost(params.slug);
  return <Article post={post} />;
}
```

**Edge Runtime for API Routes:**
```typescript
// app/api/data/route.ts
export const runtime = 'edge';
export const revalidate = 300;

export async function GET() {
  const data = await fetchData();
  return Response.json(data);
}
```

### 2. Optimize Critical Path

**Preconnect to Critical Origins:**
```typescript
// app/layout.tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <head>
        <link rel="preconnect" href={process.env.NEXT_PUBLIC_API_URL} />
        <link rel="preconnect" href="https://cdn.example.com" />
      </head>
      <body>{children}</body>
    </html>
  );
}
```

**Preload Critical Resources:**
```typescript
<head>
  {/* Critical font */}
  <link
    rel="preload"
    href="/fonts/inter.woff2"
    as="font"
    type="font/woff2"
    crossOrigin="anonymous"
  />
  
  {/* Hero image */}
  <link rel="preload" href="/hero.webp" as="image" />
</head>
```

### 3. Image Optimization

**Use Next.js Image Component:**
```typescript
import Image from 'next/image';

// Hero image (above fold) - priority load
<Image
  src="/hero.jpg"
  alt="Hero"
  width={1200}
  height={600}
  priority
  quality={90}
/>

// Product images (below fold) - lazy load
<Image
  src="/product.jpg"
  alt="Product"
  width={400}
  height={300}
  quality={85}
/>
```

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

### 4. Font Optimization

**Use next/font:**
```typescript
// app/layout.tsx
import { Inter } from 'next/font/google';

const inter = Inter({
  subsets: ['latin'],
  display: 'swap', // Prevents FOIT
  weight: ['400', '600'], // Only needed weights
});

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={inter.className}>
      <body>{children}</body>
    </html>
  );
}
```

### 5. Code Splitting

**Automatic Route-Based Splitting:**
```
// Next.js automatically splits by route
app/
├── page.tsx           → bundle-1.js
├── dashboard/
│   └── page.tsx       → bundle-2.js
└── settings/
    └── page.tsx       → bundle-3.js
```

**Manual Component Splitting:**
```typescript
import dynamic from 'next/dynamic';

// Lazy load heavy component
const HeavyChart = dynamic(() => import('@/components/HeavyChart'), {
  loading: () => <ChartSkeleton />,
  ssr: false, // Client-side only if needed
});

export function Dashboard() {
  return (
    <div>
      <QuickStats /> {/* Loads immediately */}
      <HeavyChart /> {/* Loads on demand */}
    </div>
  );
}
```

---

## Rendering Performance

### React Server Components (Default)

**Server Components for Data Fetching:**
```typescript
// app/dashboard/page.tsx - Server Component
export default async function Dashboard() {
  // Direct database access - no API call needed
  const data = await prisma.dashboard.findMany();
  
  return (
    <div>
      <h1>Dashboard</h1>
      <ServerDataDisplay data={data} />
    </div>
  );
}
```

**Client Components for Interactivity:**
```typescript
// components/InteractiveChart.tsx
'use client';

import { useState } from 'react';

export function InteractiveChart({ data }: { data: ChartData }) {
  const [filter, setFilter] = useState('all');
  
  return (
    <div>
      <select value={filter} onChange={(e) => setFilter(e.target.value)}>
        <option value="all">All</option>
        <option value="active">Active</option>
      </select>
      <Chart data={filterData(data, filter)} />
    </div>
  );
}
```

### Streaming with Suspense

**Progressive Rendering:**
```typescript
import { Suspense } from 'react';

export default function Dashboard() {
  return (
    <div>
      <Header /> {/* Renders immediately */}
      
      {/* Slow components stream in parallel */}
      <Suspense fallback={<ChartSkeleton />}>
        <SlowChart />
      </Suspense>
      
      <Suspense fallback={<TableSkeleton />}>
        <SlowTable />
      </Suspense>
    </div>
  );
}
```

---

## Runtime Performance

### 1. React Optimization

**React.memo - Prevent Unnecessary Renders:**
```typescript
import { memo } from 'react';

const ExpensiveComponent = memo(function ExpensiveComponent({ data }: Props) {
  return <ComplexVisualization data={data} />;
});
```

**useMemo - Memoize Expensive Computations:**
```typescript
const sortedData = useMemo(() => {
  return data.sort((a, b) => a.value - b.value);
}, [data]);
```

**useCallback - Stable Function References:**
```typescript
const handleClick = useCallback((id: string) => {
  updateItem(id);
}, []);
```

### 2. Virtual Scrolling

**For Large Lists (100+ items):**
```typescript
import { FixedSizeList } from 'react-window';

export function LargeList({ items }: { items: Item[] }) {
  return (
    <FixedSizeList
      height={600}
      itemCount={items.length}
      itemSize={80}
      width="100%"
    >
      {({ index, style }) => (
        <div style={style}>
          <ItemCard item={items[index]} />
        </div>
      )}
    </FixedSizeList>
  );
}
```

### 3. Event Handler Optimization

**Debounce Input Events:**
```typescript
import { debounce } from 'lodash';

const debouncedSearch = useCallback(
  debounce((query: string) => performSearch(query), 300),
  []
);
```

**Throttle Scroll Events:**
```typescript
import { throttle } from 'lodash';

const throttledScroll = useCallback(
  throttle(() => handleScroll(), 100),
  []
);
```

### 4. Web Workers for Heavy Computation

**Offload CPU-Intensive Tasks:**
```typescript
// worker.ts
self.addEventListener('message', (event) => {
  const result = expensiveCalculation(event.data);
  self.postMessage(result);
});

// component.tsx
const worker = new Worker(new URL('./worker.ts', import.meta.url));
worker.postMessage(data);
worker.addEventListener('message', (e) => setResult(e.data));
```

---

## Asset Optimization

### 1. Images

**Formats Priority:**
1. AVIF (best compression)
2. WebP (great compression)
3. JPEG/PNG (fallback)

**Next.js Image Config:**
```typescript
// next.config.ts
const nextConfig = {
  images: {
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
  },
};
```

### 2. JavaScript

**Bundle Size Targets:**
- Main bundle: < 200KB (gzipped)
- Total JavaScript: < 300KB (gzipped)

**Code Splitting:**
```typescript
// Automatic by route (Next.js)
// Manual with dynamic()
const Heavy = dynamic(() => import('./Heavy'));
```

**Tree Shaking:**
```typescript
// ✅ GOOD: Named imports (tree-shakeable)
import { Button } from '@/components/Button';

// ❌ BAD: Default imports entire module
import * as Components from '@/components';
```

### 3. CSS

**Critical CSS Inlining:**
```typescript
// Inline critical above-fold CSS
<style dangerouslySetInnerHTML={{
  __html: `
    body { margin: 0; font-family: system-ui; }
    .hero { min-height: 400px; }
  `
}} />
```

**CSS Modules (Automatic):**
```typescript
// styles.module.css automatically code-split
import styles from './styles.module.css';
```

### 4. Fonts

**Only Load Needed Weights:**
```typescript
const inter = Inter({
  subsets: ['latin'],
  weight: ['400', '600'], // Only 2 weights
  display: 'swap',
});
```

---

## Network Performance

### 1. HTTP/2 & Compression

**Automatic on Vercel:**
- HTTP/2 multiplexing
- Brotli compression
- Automatic optimization

### 2. Caching Strategy

**Static Assets (1 year):**
```typescript
// Automatic for /_next/static/*
'Cache-Control': 'public, max-age=31536000, immutable'
```

**API Responses (5-60 min):**
```typescript
export async function GET() {
  const data = await fetchData();
  
  return new NextResponse(JSON.stringify(data), {
    headers: {
      'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600',
    },
  });
}
```

### 3. Request Optimization

**Parallel Data Fetching:**
```typescript
// ✅ GOOD: Parallel
const [user, posts, stats] = await Promise.all([
  fetchUser(),
  fetchPosts(),
  fetchStats(),
]);

// ❌ BAD: Sequential (waterfall)
const user = await fetchUser();
const posts = await fetchPosts();
const stats = await fetchStats();
```

### 4. Third-Party Scripts

**Defer Non-Critical Scripts:**
```typescript
import Script from 'next/script';

// Analytics - after interactive
<Script
  src="https://analytics.example.com/script.js"
  strategy="afterInteractive"
/>

// Chat widget - lazy load
<Script
  src="https://chat.example.com/widget.js"
  strategy="lazyOnload"
/>
```

---

## Performance Checklist

### Initial Load (LCP < 2.5s)

- [ ] Use SSG/ISR for static content
- [ ] Optimize server response time (TTFB < 600ms)
- [ ] Preconnect to critical origins
- [ ] Preload critical resources (fonts, hero images)
- [ ] Use Next.js Image with `priority` for hero
- [ ] Optimize images (WebP/AVIF)
- [ ] Inline critical CSS
- [ ] Defer non-critical JavaScript
- [ ] Enable HTTP/2 and compression
- [ ] Set up CDN caching

**Quick Wins (< 1 hour):**
1. Add `priority` to hero image
2. Use next/font for fonts
3. Add preconnect headers
4. Enable ISR for static pages

### Interactivity (INP < 200ms)

- [ ] Use React.memo for expensive components
- [ ] Add useMemo for expensive computations
- [ ] Use useCallback for stable function references
- [ ] Debounce/throttle frequent events
- [ ] Use virtual scrolling for long lists (100+ items)
- [ ] Move heavy work to Web Workers
- [ ] Use useTransition for non-urgent updates
- [ ] Code split heavy components

**Quick Wins (< 1 hour):**
1. Add React.memo to slow components
2. Debounce search inputs
3. Use virtual scrolling for long lists

### Visual Stability (CLS < 0.1)

- [ ] Set image dimensions (width/height)
- [ ] Use aspect-ratio for responsive media
- [ ] Reserve space for dynamic content (min-height)
- [ ] Use `display: swap` for fonts
- [ ] Preload critical fonts
- [ ] Avoid inserting content above existing content
- [ ] Use skeleton loaders with fixed dimensions

**Quick Wins (< 30 min):**
1. Add width/height to all images
2. Use next/font (automatic CLS prevention)
3. Add min-height to dynamic sections

### Bundle Size (< 300KB)

- [ ] Analyze bundle with `@next/bundle-analyzer`
- [ ] Use dynamic imports for heavy components
- [ ] Tree-shake unused code (named imports)
- [ ] Remove unused dependencies
- [ ] Use lighter alternatives (e.g., date-fns instead of moment)
- [ ] Defer loading third-party scripts

**Quick Wins (< 1 hour):**
1. Run bundle analyzer
2. Dynamic import heavy libraries
3. Replace large dependencies

### Monitoring

- [ ] Set up web-vitals RUM
- [ ] Configure Vercel Analytics
- [ ] Add Lighthouse CI to GitHub Actions
- [ ] Create performance dashboard
- [ ] Set up performance alerts
- [ ] Define performance budgets
- [ ] Schedule weekly reviews

**Quick Wins (< 2 hours):**
1. Add web-vitals component
2. Enable Vercel Analytics
3. Add Lighthouse CI

---

## Performance Budget Template

```json
{
  "budgets": [{
    "path": "/*",
    "timings": [
      { "metric": "largest-contentful-paint", "budget": 2500 },
      { "metric": "interactive", "budget": 3500 },
      { "metric": "cumulative-layout-shift", "budget": 0.1 },
      { "metric": "first-contentful-paint", "budget": 1800 },
      { "metric": "speed-index", "budget": 3000 }
    ],
    "resourceSizes": [
      { "resourceType": "script", "budget": 300 },
      { "resourceType": "stylesheet", "budget": 50 },
      { "resourceType": "image", "budget": 500 },
      { "resourceType": "font", "budget": 100 },
      { "resourceType": "total", "budget": 1000 }
    ],
    "resourceCounts": [
      { "resourceType": "script", "budget": 10 },
      { "resourceType": "stylesheet", "budget": 5 },
      { "resourceType": "third-party", "budget": 5 }
    ]
  }]
}
```

---

## Quick Start Guide

### Day 1: Critical Optimizations (2-4 hours)

1. **Images** (1 hour)
   - Convert all images to Next.js Image component
   - Add `priority` to hero images
   - Ensure all images have width/height

2. **Fonts** (30 min)
   - Switch to next/font
   - Use `display: 'swap'`
   - Preload critical fonts

3. **Resource Hints** (30 min)
   - Add preconnect to API domain
   - Preload critical resources

4. **Measurement** (1 hour)
   - Set up web-vitals RUM
   - Run Lighthouse audit
   - Document baseline metrics

### Week 1: Major Improvements (8-12 hours)

1. **Rendering Strategy** (2-3 hours)
   - Convert to SSG/ISR where possible
   - Implement streaming with Suspense
   - Optimize API routes with edge runtime

2. **Code Splitting** (2-3 hours)
   - Dynamic import heavy components
   - Analyze and reduce bundle size
   - Remove unused dependencies

3. **Caching** (2-3 hours)
   - Implement CDN caching
   - Add Redis for server-side caching
   - Set up cache invalidation

4. **Monitoring** (2-3 hours)
   - Create performance dashboard
   - Set up alerts
   - Configure Lighthouse CI

### Month 1: Advanced Optimizations (20-30 hours)

1. **React Optimization** (5-8 hours)
   - Add React.memo strategically
   - Implement useMemo/useCallback
   - Profile with React DevTools

2. **Advanced Caching** (5-8 hours)
   - Multi-layer caching strategy
   - Cache warming
   - Advanced invalidation patterns

3. **Third-Party Optimization** (3-5 hours)
   - Audit third-party scripts
   - Implement facades for heavy widgets
   - Defer non-critical scripts

4. **Testing & Refinement** (7-9 hours)
   - Comprehensive Lighthouse audits
   - Performance budget enforcement
   - A/B test optimizations

---

## Performance ROI Calculator

**Estimated Time Savings:**
- **Images:** 2 hours work → 30% LCP improvement
- **Fonts:** 1 hour work → 15% CLS improvement
- **Code Splitting:** 3 hours work → 40% bundle size reduction
- **Caching:** 4 hours work → 10x response time improvement
- **React Optimization:** 5 hours work → 50% INP improvement

**Business Impact Estimate:**
- 1s faster load = 7% increase in conversions
- 100ms faster = 1% increase in revenue
- 0.1 CLS improvement = 5-10% SEO improvement

---

**END OF MASTER GUIDE**

**Next Steps:**
1. Run baseline Lighthouse audit: `./.cursor/tools/run-lighthouse.sh`
2. Follow Day 1 Quick Start Guide
3. Measure improvements
4. Continue with Week 1 improvements
5. Set up continuous monitoring

**Related Guides:**
- `Core-Web-Vitals-Optimization-Guide.md` - Detailed Core Web Vitals
- `Performance-Monitoring-Complete-Guide.md` - Monitoring & alerting
- `Caching-Complete-Guide.md` - Multi-layer caching
- `Rendering-Strategies-Guide.md` - SSR, SSG, ISR patterns

