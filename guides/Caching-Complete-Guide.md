# Caching - Complete Guide

**Purpose:** Comprehensive guide to implementing multi-layer caching strategies for optimal performance and scalability.

**Last Updated:** 2025-11-19

**Related Rules:** `064-caching-strategies.mdc`

---

## Table of Contents

1. [Caching Overview](#caching-overview)
2. [Browser Caching](#browser-caching)
3. [CDN/Edge Caching](#cdnedge-caching)
4. [Server-Side Caching](#server-side-caching)
5. [Database Query Caching](#database-query-caching)
6. [Cache Invalidation](#cache-invalidation)
7. [Best Practices](#best-practices)

---

## Caching Overview

### Why Caching Matters

**Performance Impact:**
- 10x faster response times
- 80%+ reduction in server load
- 90%+ reduction in database queries
- Improved user experience

**Cost Impact:**
- Lower infrastructure costs
- Reduced database load
- Fewer API calls to third parties
- Better resource utilization

### Caching Layers

```
┌─────────────────────────────────────┐
│   Browser Cache (Client-Side)      │  ← Fastest
├─────────────────────────────────────┤
│   CDN/Edge Cache (Vercel Edge)     │  ← Very Fast
├─────────────────────────────────────┤
│   Server Cache (Redis/Memory)      │  ← Fast
├─────────────────────────────────────┤
│   Database Query Cache              │  ← Faster than query
├─────────────────────────────────────┤
│   Database                          │  ← Slowest
└─────────────────────────────────────┘
```

### When to Cache

**ALWAYS Cache:**
- Static content (images, CSS, JS)
- Public APIs (non-user-specific)
- Rarely changing data (configuration, settings)

**SOMETIMES Cache:**
- User-specific data (with proper scoping)
- Frequently accessed data
- Computed results

**NEVER Cache:**
- Sensitive data (passwords, tokens)
- Real-time data (live updates)
- User sessions (or very short TTL)

---

## Browser Caching

### HTTP Cache Headers

**Cache-Control Header:**
```
Cache-Control: [directive], [directive], ...
```

**Common Directives:**
- `public` - Can be cached by browser and CDN
- `private` - Can only be cached by browser (user-specific)
- `no-cache` - Must revalidate before using cached version
- `no-store` - Never cache (sensitive data)
- `max-age=N` - Cache for N seconds
- `s-maxage=N` - CDN cache duration (overrides max-age)
- `stale-while-revalidate=N` - Serve stale while fetching fresh

### Next.js API Routes

**Static Content:**
```typescript
// app/api/config/route.ts
export async function GET() {
  const config = await getAppConfig();
  
  return new NextResponse(JSON.stringify(config), {
    headers: {
      'Content-Type': 'application/json',
      // Public, cache for 1 hour, revalidate in background for 1 day
      'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=86400',
    },
  });
}
```

**User-Specific Content:**
```typescript
// app/api/user/profile/route.ts
export async function GET() {
  const session = await getServerSession();
  const profile = await getUserProfile(session.user.id);
  
  return new NextResponse(JSON.stringify(profile), {
    headers: {
      'Content-Type': 'application/json',
      // Private, cache for 5 minutes
      'Cache-Control': 'private, max-age=300',
    },
  });
}
```

**Sensitive Data:**
```typescript
// app/api/auth/token/route.ts
export async function GET() {
  const token = await generateAuthToken();
  
  return new NextResponse(JSON.stringify({ token }), {
    headers: {
      'Content-Type': 'application/json',
      // Never cache sensitive data
      'Cache-Control': 'no-store, must-revalidate',
    },
  });
}
```

### Static Assets

**Next.js Automatic Caching:**
```typescript
// next.config.ts
const nextConfig = {
  // Static assets automatically get immutable cache headers
  // /_next/static/* → Cache-Control: public, max-age=31536000, immutable
};
```

**Custom Static Files:**
```typescript
// public/* files
// Add headers in next.config.ts
const nextConfig = {
  async headers() {
    return [
      {
        source: '/images/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
    ];
  },
};
```

---

## CDN/Edge Caching

### Vercel Edge Network

**Automatic Edge Caching:**
- Next.js static pages automatically cached
- ISR pages cached at edge
- API routes with `revalidate` cached

**Next.js ISR (Incremental Static Regeneration):**
```typescript
// app/blog/[slug]/page.tsx
export const revalidate = 3600; // Revalidate every hour

export async function generateStaticParams() {
  const posts = await getPosts();
  return posts.map((post) => ({ slug: post.slug }));
}

export default async function BlogPost({ params }: { params: { slug: string } }) {
  const post = await getPost(params.slug);
  return <Article post={post} />;
}
```

**API Route Caching:**
```typescript
// app/api/products/route.ts
export const runtime = 'edge'; // Deploy to edge
export const revalidate = 300; // Cache for 5 minutes

export async function GET() {
  const products = await getProducts();
  
  return new NextResponse(JSON.stringify(products), {
    headers: {
      'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600',
      'CDN-Cache-Control': 'max-age=300',
    },
  });
}
```

### Edge-Specific Headers

**Vercel-Specific:**
```typescript
headers: {
  // Standard cache
  'Cache-Control': 'public, s-maxage=300',
  
  // CDN-specific (Vercel)
  'CDN-Cache-Control': 'max-age=300',
  
  // Browser-specific
  'Vercel-CDN-Cache-Control': 'max-age=3600',
}
```

### Regional Edge Caching

**Next.js Config:**
```typescript
// next.config.ts
const nextConfig = {
  // Enable edge runtime for specific routes
  experimental: {
    runtime: 'experimental-edge',
  },
};
```

---

## Server-Side Caching

### In-Memory Cache (Development/Simple)

**Simple Memory Cache:**
```typescript
// lib/cache/memory-cache.ts
interface CacheEntry<T> {
  data: T;
  expiry: number;
}

class MemoryCache {
  private cache = new Map<string, CacheEntry<any>>();
  
  get<T>(key: string): T | null {
    const entry = this.cache.get(key);
    if (!entry) return null;
    
    if (Date.now() > entry.expiry) {
      this.cache.delete(key);
      return null;
    }
    
    return entry.data;
  }
  
  set<T>(key: string, data: T, ttlSeconds: number): void {
    this.cache.set(key, {
      data,
      expiry: Date.now() + (ttlSeconds * 1000),
    });
  }
  
  delete(key: string): void {
    this.cache.delete(key);
  }
  
  clear(): void {
    this.cache.clear();
  }
  
  // Cleanup expired entries periodically
  cleanup(): void {
    const now = Date.now();
    for (const [key, entry] of this.cache.entries()) {
      if (now > entry.expiry) {
        this.cache.delete(key);
      }
    }
  }
}

export const memoryCache = new MemoryCache();

// Cleanup every 5 minutes
if (typeof window === 'undefined') {
  setInterval(() => memoryCache.cleanup(), 5 * 60 * 1000);
}
```

**Usage:**
```typescript
export async function getOrganization(id: string) {
  const cacheKey = `org:${id}`;
  
  // Try cache first
  let org = memoryCache.get<Organization>(cacheKey);
  if (org) return org;
  
  // Cache miss - fetch from database
  org = await prisma.organization.findUnique({ where: { id } });
  
  if (org) {
    // Cache for 5 minutes
    memoryCache.set(cacheKey, org, 300);
  }
  
  return org;
}
```

### Redis Cache (Production)

**Setup Upstash Redis:**
```bash
npm install @upstash/redis
```

**Redis Cache Implementation:**
```typescript
// lib/cache/redis-cache.ts
import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
});

export async function getCached<T>(key: string): Promise<T | null> {
  try {
    const data = await redis.get<T>(key);
    return data;
  } catch (error) {
    console.error('Redis get error:', error);
    return null;
  }
}

export async function setCache<T>(
  key: string,
  data: T,
  ttlSeconds: number
): Promise<void> {
  try {
    await redis.setex(key, ttlSeconds, JSON.stringify(data));
  } catch (error) {
    console.error('Redis set error:', error);
  }
}

export async function invalidateCache(key: string): Promise<void> {
  try {
    await redis.del(key);
  } catch (error) {
    console.error('Redis delete error:', error);
  }
}

export async function invalidatePattern(pattern: string): Promise<void> {
  try {
    const keys = await redis.keys(pattern);
    if (keys.length > 0) {
      await redis.del(...keys);
    }
  } catch (error) {
    console.error('Redis pattern delete error:', error);
  }
}
```

**Cache Helper:**
```typescript
// lib/cache/cache-helper.ts
import { getCached, setCache } from './redis-cache';

export async function cachedQuery<T>(
  cacheKey: string,
  ttlSeconds: number,
  queryFn: () => Promise<T>
): Promise<T> {
  // Try cache first
  const cached = await getCached<T>(cacheKey);
  if (cached !== null) {
    console.log(`Cache HIT: ${cacheKey}`);
    return cached;
  }
  
  console.log(`Cache MISS: ${cacheKey}`);
  
  // Cache miss - execute query
  const result = await queryFn();
  
  // Cache result
  await setCache(cacheKey, result, ttlSeconds);
  
  return result;
}
```

**Usage:**
```typescript
import { cachedQuery } from '@/lib/cache/cache-helper';

export async function getOrganizationStats(orgId: string) {
  return cachedQuery(
    `org:${orgId}:stats`,
    300, // 5 minutes
    async () => {
      return prisma.organizationStats.findUnique({
        where: { organizationId: orgId },
        include: { metrics: true },
      });
    }
  );
}
```

---

## Database Query Caching

### Prisma with Redis Cache

**Cached Queries:**
```typescript
// lib/db/cached-queries.ts
import { cachedQuery } from '@/lib/cache/cache-helper';
import { prisma } from '@/lib/db';

export async function getCachedUser(userId: string) {
  return cachedQuery(
    `user:${userId}`,
    300, // 5 minutes
    () => prisma.user.findUnique({
      where: { id: userId },
      include: { organization: true },
    })
  );
}

export async function getCachedOrganization(orgId: string) {
  return cachedQuery(
    `org:${orgId}`,
    600, // 10 minutes
    () => prisma.organization.findUnique({
      where: { id: orgId },
      include: {
        users: true,
        settings: true,
      },
    })
  );
}

export async function getCachedAssessments(orgId: string) {
  return cachedQuery(
    `org:${orgId}:assessments`,
    180, // 3 minutes
    () => prisma.assessment.findMany({
      where: { organizationId: orgId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    })
  );
}
```

### Query Result Caching Pattern

**Generic Cache Wrapper:**
```typescript
// lib/db/query-cache.ts
import { getCached, setCache, invalidateCache } from '@/lib/cache/redis-cache';

export async function cachedFindUnique<T>(
  model: string,
  where: any,
  include?: any,
  ttl = 300
): Promise<T | null> {
  const cacheKey = `${model}:${JSON.stringify(where)}`;
  
  let result = await getCached<T>(cacheKey);
  if (result) return result;
  
  // @ts-ignore
  result = await prisma[model].findUnique({ where, include });
  
  if (result) {
    await setCache(cacheKey, result, ttl);
  }
  
  return result;
}

export async function cachedFindMany<T>(
  model: string,
  where: any,
  orderBy?: any,
  take?: number,
  ttl = 300
): Promise<T[]> {
  const cacheKey = `${model}:list:${JSON.stringify({ where, orderBy, take })}`;
  
  let results = await getCached<T[]>(cacheKey);
  if (results) return results;
  
  // @ts-ignore
  results = await prisma[model].findMany({ where, orderBy, take });
  
  await setCache(cacheKey, results, ttl);
  
  return results;
}
```

---

## Cache Invalidation

### Invalidation Strategies

**1. Time-Based (TTL):**
```typescript
// Cache expires after N seconds
await setCache(key, data, 300); // 5 minutes
```

**2. Event-Based:**
```typescript
// Invalidate on write operations
export async function updateOrganization(id: string, data: OrganizationUpdate) {
  const org = await prisma.organization.update({
    where: { id },
    data,
  });
  
  // Invalidate caches
  await invalidateCache(`org:${id}`);
  await invalidateCache(`org:${id}:stats`);
  await invalidatePattern(`org:${id}:*`);
  
  return org;
}
```

**3. Pattern-Based:**
```typescript
// Invalidate all related caches
export async function invalidateOrganizationCaches(orgId: string) {
  await invalidatePattern(`org:${orgId}:*`);
}
```

**4. Tag-Based (Advanced):**
```typescript
// Cache with tags
export async function setCacheWithTags<T>(
  key: string,
  data: T,
  ttl: number,
  tags: string[]
) {
  await setCache(key, data, ttl);
  
  // Store tags
  for (const tag of tags) {
    await redis.sadd(`tag:${tag}`, key);
    await redis.expire(`tag:${tag}`, ttl);
  }
}

// Invalidate by tag
export async function invalidateByTag(tag: string) {
  const keys = await redis.smembers(`tag:${tag}`);
  if (keys.length > 0) {
    await redis.del(...keys);
    await redis.del(`tag:${tag}`);
  }
}

// Usage
await setCacheWithTags(
  'org:abc123:stats',
  stats,
  300,
  ['org:abc123', 'stats']
);

// Invalidate all stats caches
await invalidateByTag('stats');
```

### Write-Through Cache

```typescript
export async function createAssessment(data: AssessmentInput) {
  // Write to database
  const assessment = await prisma.assessment.create({ data });
  
  // Update cache immediately
  const cacheKey = `assessment:${assessment.id}`;
  await setCache(cacheKey, assessment, 300);
  
  // Invalidate list cache
  await invalidateCache(`org:${data.organizationId}:assessments`);
  
  return assessment;
}
```

### Cache Stampede Prevention

**Problem:** Many requests hit expired cache simultaneously, all query database.

**Solution:** Lock-based approach
```typescript
// lib/cache/stampede-prevention.ts
const locks = new Map<string, Promise<any>>();

export async function cachedQueryWithLock<T>(
  cacheKey: string,
  ttl: number,
  queryFn: () => Promise<T>
): Promise<T> {
  // Check cache
  let cached = await getCached<T>(cacheKey);
  if (cached) return cached;
  
  // Check if another request is already fetching
  if (locks.has(cacheKey)) {
    return locks.get(cacheKey)!;
  }
  
  // Create lock
  const promise = (async () => {
    try {
      const result = await queryFn();
      await setCache(cacheKey, result, ttl);
      return result;
    } finally {
      locks.delete(cacheKey);
    }
  })();
  
  locks.set(cacheKey, promise);
  return promise;
}
```

---

## Best Practices

### Cache Key Naming Convention

**Pattern:**
```
{entity}:{id}:{scope}:{variant}
```

**Examples:**
```typescript
const keys = {
  user: (id: string) => `user:${id}`,
  userProfile: (id: string) => `user:${id}:profile`,
  orgStats: (orgId: string) => `org:${orgId}:stats`,
  orgAssessments: (orgId: string, status?: string) => 
    status ? `org:${orgId}:assessments:${status}` : `org:${orgId}:assessments`,
  globalConfig: () => 'global:config',
};
```

### TTL Guidelines

| Data Type | TTL | Reasoning |
|-----------|-----|-----------|
| Static content | 1 year | Immutable files |
| Public API | 5-60 min | Balance freshness/load |
| User profile | 5-15 min | Moderate change frequency |
| Settings/config | 10-60 min | Rarely changes |
| Dashboard stats | 1-5 min | Frequently viewed, expensive |
| Search results | 30-60 sec | Frequently changes |
| Real-time data | 0-10 sec | Near real-time |

### Cache Monitoring

**Track Cache Performance:**
```typescript
// lib/cache/monitoring.ts
export async function getCachedWithMetrics<T>(key: string): Promise<T | null> {
  const start = performance.now();
  const data = await getCached<T>(key);
  const duration = performance.now() - start;
  
  // Track metrics
  trackMetric('cache.get.duration', duration);
  trackMetric(data ? 'cache.hit' : 'cache.miss', 1);
  
  return data;
}
```

**Cache Hit Rate:**
```typescript
// Calculate cache effectiveness
const hitRate = (cacheHits / (cacheHits + cacheMisses)) * 100;
// Target: >80% hit rate
```

### Error Handling

**Graceful Degradation:**
```typescript
export async function getCachedData<T>(
  cacheKey: string,
  queryFn: () => Promise<T>
): Promise<T> {
  try {
    // Try cache first
    const cached = await getCached<T>(cacheKey);
    if (cached) return cached;
  } catch (error) {
    console.error('Cache get error:', error);
    // Continue to query
  }
  
  // Query database
  const result = await queryFn();
  
  try {
    // Try to cache result
    await setCache(cacheKey, result, 300);
  } catch (error) {
    console.error('Cache set error:', error);
    // Return result anyway
  }
  
  return result;
}
```

---

## Quick Reference

### Cache Headers Cheat Sheet

```typescript
// Static assets (1 year)
'Cache-Control': 'public, max-age=31536000, immutable'

// Public API (1 hour, stale-while-revalidate 1 day)
'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=86400'

// User-specific (5 minutes)
'Cache-Control': 'private, max-age=300'

// Sensitive data (never cache)
'Cache-Control': 'no-store, must-revalidate'

// Revalidate before use
'Cache-Control': 'no-cache, must-revalidate'
```

### Caching Decision Tree

```
Is data user-specific?
├─ NO → Is it static?
│       ├─ YES → Cache: 1 year (immutable)
│       └─ NO → Cache: 5-60 min (public, s-maxage)
└─ YES → Is it sensitive?
         ├─ YES → DON'T cache (no-store)
         └─ NO → Cache: 5-15 min (private, max-age)
```

---

**END OF GUIDE**

**Next Steps:**
1. Choose caching strategy for your use case
2. Implement browser/CDN caching first (biggest impact)
3. Add Redis for server-side caching
4. Implement cache invalidation
5. Monitor cache hit rates
6. Optimize TTLs based on data

