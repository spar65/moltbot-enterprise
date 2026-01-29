# VibeCoder Database Query Optimization Guide

## Overview

This guide documents best practices for optimizing database queries in VibeCoder to ensure efficient database operations, minimize response times, and maintain performance as the application scales.

## Table of Contents

1. [Indexing Strategy](#indexing-strategy)
2. [Query Plan Analysis](#query-plan-analysis)
3. [Performance Optimization Techniques](#performance-optimization-techniques)
4. [Complex Query Patterns](#complex-query-patterns)
5. [Common Anti-Patterns](#common-anti-patterns)
6. [Monitoring Query Performance](#monitoring-query-performance)
7. [Scaling Strategies](#scaling-strategies)

## Indexing Strategy

Proper indexing is critical for database performance. The following guidelines should be followed when creating and maintaining indexes.

### Primary Key and Foreign Key Indexes

- Every table should have a primary key
- Foreign keys should be indexed to improve join performance
- Composite foreign keys should have corresponding composite indexes

```sql
-- Example: Create index on foreign key
CREATE INDEX idx_projects_organization_id ON projects(organization_id);

-- Example: Composite index for junction table
CREATE INDEX idx_user_organizations_composite
  ON user_organizations(organization_id, user_id);
```

### Multi-Column Indexes

Create multi-column indexes based on common query patterns:

```sql
-- Order matters: place the most selective column first
CREATE INDEX idx_agents_org_status_type
  ON agents(organization_id, status, agent_type);

-- Index for sorting within a filtered subset
CREATE INDEX idx_projects_org_created_at
  ON projects(organization_id, created_at DESC);
```

### Text Search Indexes

For columns that are frequently searched with LIKE or text search operations:

```sql
-- GIN index for full text search
CREATE INDEX idx_projects_name_trgm
  ON projects USING GIN (name gin_trgm_ops);

-- B-tree index for exact or prefix matching
CREATE INDEX idx_users_email
  ON users(email);
```

### Index Maintenance

Monitor and maintain indexes for optimal performance:

- Regularly analyze tables to update statistics
- Remove unused indexes that add overhead to write operations
- Consider partial indexes for specific query patterns

```sql
-- Partial index for active projects only
CREATE INDEX idx_active_projects
  ON projects(name) WHERE status = 'active';

-- Analyze tables to update statistics
ANALYZE projects;
```

## Query Plan Analysis

Understanding query execution plans is essential for optimizing performance.

### Using EXPLAIN

Always use EXPLAIN ANALYZE to understand how queries are executed:

```sql
-- Basic query plan
EXPLAIN SELECT * FROM projects WHERE organization_id = '123';

-- Query plan with execution statistics
EXPLAIN ANALYZE SELECT *
FROM projects p
JOIN agents a ON p.id = a.project_id
WHERE p.organization_id = '123' AND p.status = 'active';
```

### Interpreting Query Plans

Key components to look for in query plans:

1. **Scan Types**

   - Sequential scan: Full table scan (potentially slow for large tables)
   - Index scan: Using an index to find rows
   - Index-only scan: Most efficient as data comes directly from index

2. **Join Types**

   - Nested loop: Good for small tables or highly selective joins
   - Hash join: Better for larger datasets with good hash distribution
   - Merge join: Efficient for pre-sorted data

3. **Cost Estimates**
   - Startup cost: Cost before first row is returned
   - Total cost: Estimated total cost of the operation

Example query plan analysis:

```
Nested Loop  (cost=0.00..16.97 rows=32 width=295)
  ->  Index Scan using projects_pkey on projects p  (cost=0.00..8.27 rows=1 width=155)
        Index Cond: (id = '123')
  ->  Seq Scan on agents a  (cost=0.00..8.32 rows=32 width=140)
        Filter: (project_id = '123')
```

Issues to identify:

- Sequential scans on large tables
- High filter costs (missing indexes)
- Inefficient join methods for the data size

## Performance Optimization Techniques

### Query Structure Optimization

1. **Select Only Necessary Columns**

   ```typescript
   // GOOD: Select only needed fields
   const users = await prisma.user.findMany({
     select: {
       id: true,
       name: true,
       email: true,
       // Only select fields you need
     },
   });

   // AVOID: Selecting everything when only specific fields are needed
   const users = await prisma.user.findMany();
   ```

2. **Use Appropriate WHERE Clauses**

   ```typescript
   // GOOD: Specific filtering conditions
   const activeProjects = await prisma.project.findMany({
     where: {
       organizationId,
       status: "active",
       updatedAt: {
         gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000), // Last 30 days
       },
     },
   });

   // AVOID: Over-fetching and filtering in application code
   const allProjects = await prisma.project.findMany({
     where: { organizationId },
   });
   const activeProjects = allProjects.filter(
     (p) =>
       p.status === "active" &&
       new Date(p.updatedAt) >= new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
   );
   ```

3. **Optimize JOINs**

   ```typescript
   // GOOD: Specific includes with select
   const project = await prisma.project.findUnique({
     where: { id: projectId },
     include: {
       tasks: {
         select: {
           id: true,
           title: true,
           status: true,
         },
         where: {
           status: "in_progress",
         },
       },
     },
   });

   // AVOID: Including everything from joined tables
   const project = await prisma.project.findUnique({
     where: { id: projectId },
     include: {
       tasks: true,
       creator: true,
       organization: true,
     },
   });
   ```

4. **Sort Efficiently**

   ```typescript
   // GOOD: Sort on indexed columns
   const users = await prisma.user.findMany({
     where: { organizationId },
     orderBy: {
       email: "asc", // email has an index
     },
   });

   // AVOID: Sorting on non-indexed columns or in application code
   const users = await prisma.user.findMany({
     where: { organizationId },
   });
   const sortedUsers = users.sort((a, b) => a.lastLoginDate - b.lastLoginDate);
   ```

### Optimizing Aggregate Functions

1. **Pre-filter data before aggregation**

```sql
-- Bad: Filtering after aggregation
SELECT agent_type, COUNT(*)
FROM agents
GROUP BY agent_type
HAVING COUNT(*) > 10;

-- Good: Filtering before aggregation when possible
SELECT agent_type, COUNT(*)
FROM agents
WHERE created_at > '2023-01-01'
GROUP BY agent_type
HAVING COUNT(*) > 10;
```

2. **Use window functions for complex analytics**

```sql
-- Efficient ranking and analytics with window functions
SELECT
  p.name,
  p.created_at,
  COUNT(a.id) as agent_count,
  RANK() OVER (PARTITION BY p.organization_id ORDER BY COUNT(a.id) DESC) as rank
FROM projects p
LEFT JOIN agents a ON p.id = a.project_id
WHERE p.organization_id = '123'
GROUP BY p.id, p.name, p.created_at;
```

### Transaction Optimization

1. **Keep transactions short and focused**
2. **Batch operations when processing large datasets**
3. **Use appropriate isolation levels**

```sql
-- Example of batched processing
DO $$
DECLARE
  batch_size INT := 1000;
  total_rows INT;
  processed_rows INT := 0;
BEGIN
  SELECT COUNT(*) INTO total_rows FROM large_table WHERE needs_update = true;

  WHILE processed_rows < total_rows LOOP
    -- Process batch
    UPDATE large_table
    SET processed = true
    WHERE id IN (
      SELECT id FROM large_table
      WHERE needs_update = true AND processed = false
      LIMIT batch_size
    );

    processed_rows := processed_rows + batch_size;
    COMMIT;
  END LOOP;
END $$;
```

## Complex Query Patterns

Complex queries spanning multiple repositories and entities require special attention to maintain performance and readability. This section covers patterns for handling advanced query scenarios.

### Query Composition Utility

Create a dedicated utility for composing complex queries:

```typescript
// src/lib/queryComposer.ts
export class QueryComposer {
  /**
   * Creates an optimized query for fetching users with their subscriptions
   */
  static createUserWithSubscriptionQuery(
    organizationId: string,
    filters: UserFilters
  ) {
    return prisma.user.findMany({
      where: {
        organizationId,
        ...filters,
        subscription: {
          status: "active",
          tier: { in: filters.allowedTiers },
        },
      },
      include: {
        subscription: {
          include: { tier: true },
        },
        settings: true,
      },
      orderBy: {
        createdAt: "desc",
      },
    });
  }

  /**
   * Creates an optimized analytics query for revenue reporting
   */
  static createRevenueAnalyticsQuery(
    organizationId: string,
    dateRange: DateRange
  ) {
    return prisma.$queryRaw`
      SELECT 
        DATE_TRUNC('month', s.created_at) as month,
        st.name as tier_name,
        COUNT(*) as subscription_count,
        SUM(st.price) as revenue
      FROM subscriptions s
      JOIN subscription_tiers st ON s.tier_id = st.id
      WHERE s.organization_id = ${organizationId}
        AND s.created_at BETWEEN ${dateRange.start} AND ${dateRange.end}
      GROUP BY month, st.name
      ORDER BY month DESC
    `;
  }

  /**
   * Creates a query for dashboard metrics with multiple entity types
   */
  static createDashboardMetricsQuery(organizationId: string) {
    return prisma.$transaction(async (tx) => {
      // User statistics
      const userStats = await tx.user.aggregate({
        where: { organizationId },
        _count: { id: true },
        _max: { createdAt: true },
      });

      // Subscription statistics
      const subscriptionStats = await tx.subscription.groupBy({
        by: ["status"],
        where: { organizationId },
        _count: { id: true },
      });

      // Project statistics
      const projectStats = await tx.project.aggregate({
        where: { organizationId },
        _count: { id: true },
        _max: { updatedAt: true },
      });

      return {
        userCount: userStats._count.id,
        lastUserCreated: userStats._max.createdAt,
        subscriptions: subscriptionStats.reduce((acc, curr) => {
          acc[curr.status] = curr._count.id;
          return acc;
        }, {}),
        projectCount: projectStats._count.id,
        lastProjectUpdate: projectStats._max.updatedAt,
      };
    });
  }
}
```

### Cross-Entity Query Patterns

When queries need to span multiple entities that don't have direct relationships:

```typescript
// Example: Finding users with specific activity patterns
export async function findPowerUsers(organizationId: string): Promise<User[]> {
  // First, identify user IDs with high activity
  const activeUserIds = await prisma.$queryRaw<Array<{ userId: string }>>`
    SELECT user_id as "userId"
    FROM user_activities
    WHERE organization_id = ${organizationId}
    GROUP BY user_id
    HAVING COUNT(*) > 100 AND MAX(created_at) > NOW() - INTERVAL '7 days'
  `;

  // Then fetch the full user records with their subscription info
  return await prisma.user.findMany({
    where: {
      id: { in: activeUserIds.map((u) => u.userId) },
      organizationId,
    },
    include: {
      subscription: true,
      profile: true,
    },
  });
}
```

### Repository Query Composition

Implement a pattern for combining queries from multiple repositories:

```typescript
// src/repositories/AnalyticsRepository.ts
export class AnalyticsRepository {
  constructor(
    private userRepository: UserRepository,
    private subscriptionRepository: SubscriptionRepository,
    private projectRepository: ProjectRepository
  ) {}

  async getOrganizationOverview(
    organizationId: string
  ): Promise<OrganizationOverview> {
    // Execute queries in parallel for better performance
    const [userStats, subscriptionStats, projectStats] = await Promise.all([
      this.userRepository.getUserStatistics(organizationId),
      this.subscriptionRepository.getSubscriptionStatistics(organizationId),
      this.projectRepository.getProjectStatistics(organizationId),
    ]);

    return {
      users: userStats,
      subscriptions: subscriptionStats,
      projects: projectStats,
      overallHealth: this.calculateOrganizationHealth(
        userStats,
        subscriptionStats,
        projectStats
      ),
    };
  }

  private calculateOrganizationHealth(
    userStats: UserStatistics,
    subscriptionStats: SubscriptionStatistics,
    projectStats: ProjectStatistics
  ): HealthScore {
    // Complex business logic to determine organization health
    // ...
  }
}
```

### View Models for Complex Data

Create dedicated view models for complex query results:

```typescript
// src/models/views/UserActivityViewModel.ts
export interface UserActivityViewModel {
  userId: string;
  name: string;
  email: string;
  activityCount: number;
  lastActivityDate: Date;
  topProjects: Array<{
    projectId: string;
    projectName: string;
    activityCount: number;
  }>;
  subscriptionTier: string;
  subscriptionStatus: string;
}

// src/repositories/UserActivityRepository.ts
export class UserActivityRepository {
  async getUserActivitySummary(
    userId: string,
    organizationId: string
  ): Promise<UserActivityViewModel> {
    // Fetch base user data
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        subscription: {
          include: { tier: true },
        },
      },
    });

    if (!user) {
      throw new Error(`User not found: ${userId}`);
    }

    // Fetch activity statistics
    const activityStats = await prisma.$queryRaw<{
      count: number;
      lastActivity: Date;
    }>`
      SELECT 
        COUNT(*) as count,
        MAX(created_at) as "lastActivity"
      FROM user_activities
      WHERE user_id = ${userId} AND organization_id = ${organizationId}
    `;

    // Fetch top projects by activity
    const topProjects = await prisma.$queryRaw<
      Array<{ projectId: string; projectName: string; count: number }>
    >`
      SELECT 
        p.id as "projectId",
        p.name as "projectName",
        COUNT(ua.id) as count
      FROM user_activities ua
      JOIN projects p ON ua.project_id = p.id
      WHERE ua.user_id = ${userId} AND ua.organization_id = ${organizationId}
      GROUP BY p.id, p.name
      ORDER BY count DESC
      LIMIT 5
    `;

    // Construct and return the view model
    return {
      userId: user.id,
      name: user.name,
      email: user.email,
      activityCount: Number(activityStats.count),
      lastActivityDate: activityStats.lastActivity,
      topProjects: topProjects,
      subscriptionTier: user.subscription?.tier?.name || "None",
      subscriptionStatus: user.subscription?.status || "None",
    };
  }
}
```

### Paginated Aggregate Queries

Implement efficient pagination for aggregate queries:

```typescript
// src/repositories/ReportRepository.ts
export class ReportRepository {
  async getSubscriptionReport(
    organizationId: string,
    pagination: { page: number; pageSize: number }
  ): Promise<PaginatedResult<SubscriptionReportItem>> {
    const { page, pageSize } = pagination;
    const offset = page * pageSize;

    // Get paginated results
    const items = await prisma.$queryRaw<SubscriptionReportItem[]>`
      SELECT 
        s.id,
        u.name as user_name,
        u.email as user_email,
        st.name as tier_name,
        s.status,
        s.current_period_end as renewal_date,
        s.price as amount,
        s.created_at as subscription_date
      FROM subscriptions s
      JOIN users u ON s.user_id = u.id
      JOIN subscription_tiers st ON s.tier_id = st.id
      WHERE s.organization_id = ${organizationId}
      ORDER BY s.created_at DESC
      LIMIT ${pageSize} OFFSET ${offset}
    `;

    // Get total count for pagination
    const countResult = await prisma.$queryRaw<[{ count: number }]>`
      SELECT COUNT(*) as count
      FROM subscriptions s
      WHERE s.organization_id = ${organizationId}
    `;

    const totalCount = Number(countResult[0].count);

    return {
      items,
      pagination: {
        page,
        pageSize,
        totalCount,
        totalPages: Math.ceil(totalCount / pageSize),
      },
    };
  }
}
```

### Key-Value Store Pattern for Complex Filters

Implement a key-value store pattern for handling complex filtering:

```typescript
// src/services/SearchService.ts
export class SearchService {
  async searchProjects(
    organizationId: string,
    filters: Record<string, any>
  ): Promise<Project[]> {
    // Start with base query
    let query = prisma.project.findMany({
      where: { organizationId },
    });

    // Apply dynamic filters
    if (filters) {
      query = this.applyProjectFilters(query, filters);
    }

    return await query;
  }

  private applyProjectFilters(query: any, filters: Record<string, any>): any {
    const whereClause: any = query.where || {};

    // Apply text search
    if (filters.searchText) {
      whereClause.OR = [
        { name: { contains: filters.searchText, mode: "insensitive" } },
        { description: { contains: filters.searchText, mode: "insensitive" } },
      ];
    }

    // Apply status filter
    if (filters.status) {
      whereClause.status = filters.status;
    }

    // Apply date range filter
    if (filters.dateFrom || filters.dateTo) {
      whereClause.createdAt = {};

      if (filters.dateFrom) {
        whereClause.createdAt.gte = new Date(filters.dateFrom);
      }

      if (filters.dateTo) {
        whereClause.createdAt.lte = new Date(filters.dateTo);
      }
    }

    // Apply tag filters
    if (filters.tags && filters.tags.length > 0) {
      whereClause.tags = {
        hasEvery: filters.tags,
      };
    }

    // Apply ownership filter
    if (filters.ownerId) {
      whereClause.ownerId = filters.ownerId;
    }

    return {
      ...query,
      where: whereClause,
    };
  }
}
```

### Performance Considerations for Complex Queries

When implementing complex queries, consider these performance optimizations:

1. **Break Down Complex Queries**

   - Use transactions to maintain atomicity
   - Split into multiple simpler queries when appropriate
   - Consider data denormalization for reporting

2. **Use Database Features Effectively**

   - Common Table Expressions (CTEs) for readability
   - Window functions for analytics
   - Materialized views for expensive calculations

3. **Caching Complex Query Results**
   - Cache results with appropriate TTL
   - Implement cache invalidation strategies
   - Consider using Redis for shared caching

```typescript
// Example: Using Redis to cache complex query results
export class CachedReportRepository {
  constructor(
    private redis: Redis,
    private reportRepository: ReportRepository
  ) {}

  async getSubscriptionReport(
    organizationId: string,
    pagination: { page: number; pageSize: number }
  ): Promise<PaginatedResult<SubscriptionReportItem>> {
    const cacheKey = `subscription_report:${organizationId}:${pagination.page}:${pagination.pageSize}`;

    // Try to get from cache
    const cached = await this.redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }

    // If not in cache, fetch from database
    const report = await this.reportRepository.getSubscriptionReport(
      organizationId,
      pagination
    );

    // Cache the result (expire after 15 minutes)
    await this.redis.set(cacheKey, JSON.stringify(report), "EX", 900);

    return report;
  }

  // Method to invalidate cache when data changes
  async invalidateReportCache(organizationId: string): Promise<void> {
    const pattern = `subscription_report:${organizationId}:*`;
    const keys = await this.redis.keys(pattern);

    if (keys.length > 0) {
      await this.redis.del(...keys);
    }
  }
}
```

## Common Anti-Patterns

### N+1 Query Problem

The N+1 query problem occurs when you execute 1 query to retrieve a list of N items, then execute N additional queries to retrieve related data for each item.

```typescript
// Bad: N+1 query problem
const projects = await db.query(
  "SELECT * FROM projects WHERE organization_id = $1",
  [orgId]
);

// Then for each project, a separate query (N additional queries)
for (const project of projects) {
  const agents = await db.query("SELECT * FROM agents WHERE project_id = $1", [
    project.id,
  ]);
  project.agents = agents;
}

// Good: Single join query
const results = await db.query(
  `
  SELECT p.*, a.id as agent_id, a.name as agent_name, a.status as agent_status
  FROM projects p
  LEFT JOIN agents a ON p.id = a.project_id
  WHERE p.organization_id = $1
`,
  [orgId]
);

// Then group in application code
const projects = [];
const projectMap = new Map();

for (const row of results) {
  if (!projectMap.has(row.id)) {
    const project = {
      id: row.id,
      name: row.name,
      // ...other project fields
      agents: [],
    };
    projectMap.set(row.id, project);
    projects.push(project);
  }

  if (row.agent_id) {
    projectMap.get(row.id).agents.push({
      id: row.agent_id,
      name: row.agent_name,
      status: row.agent_status,
    });
  }
}
```

### Over-Indexing and Under-Indexing

- **Over-indexing**: Too many indexes that slow down write operations
- **Under-indexing**: Missing indexes on frequently queried columns

```sql
-- Check index usage to identify unused indexes
SELECT
  schemaname, relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
FROM
  pg_stat_user_indexes
ORDER BY
  idx_scan ASC;
```

### Inefficient Joins

Poor join conditions can lead to excessive data processing:

```sql
-- Bad: Cartesian product (missing join condition)
SELECT * FROM projects, agents;

-- Bad: Join on non-indexed column
SELECT * FROM projects p
JOIN agents a ON p.name = a.project_name;

-- Good: Join on indexed columns
SELECT * FROM projects p
JOIN agents a ON p.id = a.project_id;
```

### Large IN Clauses

Very large IN clauses can cause performance issues:

```sql
-- Bad: Very large IN clause
SELECT * FROM agents WHERE id IN (1, 2, 3, ..., 10000);

-- Good: Use temporary table or JOIN
CREATE TEMPORARY TABLE tmp_agent_ids (id INT);
INSERT INTO tmp_agent_ids VALUES (1), (2), (3), ..., (10000);

SELECT a.* FROM agents a
JOIN tmp_agent_ids t ON a.id = t.id;
```

## Monitoring Query Performance

### Slow Query Tracking

Implement a system to track and analyze slow queries:

```typescript
// Query performance tracking utility
export class QueryPerformanceTracker {
  static trackQuery(query: string, duration: number, endpoint: string) {
    // Log slow queries
    if (duration > 100) {
      logger.warn("Slow query detected", {
        query: query.substring(0, 200),
        duration,
        endpoint,
        timestamp: new Date().toISOString(),
      });
    }

    // Collect metrics
    metrics.histogram("database.query.duration", duration, {
      endpoint,
      query_type: getQueryType(query),
    });
  }
}
```

### Database Performance Metrics

Key metrics to monitor:

1. **Query execution time**

   - Average, P95, P99 response times
   - Counts of queries exceeding thresholds

2. **Resource utilization**

   - Connection pool usage
   - CPU and memory usage
   - Disk I/O operations

3. **Lock and wait statistics**
   - Lock wait times
   - Deadlock counts
   - Transaction duration

### Performance Testing

Regularly test query performance under load:

1. **Establish performance baselines**
2. **Create realistic test datasets**
3. **Simulate concurrent users**
4. **Measure impact of schema changes**

## Scaling Strategies

### Read Replicas

Implement read replicas for scaling read operations:

```typescript
// Read/write splitting example
class DatabaseService {
  private writePool: Pool; // Primary database
  private readPool: Pool; // Read replicas

  async query(
    sql: string,
    params: any[],
    options?: { writeOperation?: boolean }
  ) {
    const pool = options?.writeOperation ? this.writePool : this.readPool;
    const start = performance.now();

    try {
      return await pool.query(sql, params);
    } finally {
      const duration = performance.now() - start;
      QueryPerformanceTracker.trackQuery(sql, duration);
    }
  }
}
```

### Query Result Caching

Implement caching for frequently accessed, relatively static data:

```typescript
// Query result caching implementation
export class QueryCache {
  private cache = new Map<string, CacheEntry>();

  async get<T>(
    key: string,
    fetcher: () => Promise<T>,
    ttl: number = 300
  ): Promise<T> {
    const cached = this.cache.get(key);

    if (cached && cached.expires > Date.now()) {
      return cached.data;
    }

    const data = await fetcher();
    this.cache.set(key, {
      data,
      expires: Date.now() + ttl * 1000,
    });

    return data;
  }
}
```

### Partitioning Strategies

For very large tables, consider these partitioning strategies:

1. **Range partitioning**: By date ranges or ID ranges
2. **List partitioning**: By discrete values like status or type
3. **Hash partitioning**: For even distribution with no clear partition key

```sql
-- Example: Range partitioning by date
CREATE TABLE events (
  id UUID PRIMARY KEY,
  event_time TIMESTAMP NOT NULL,
  event_type VARCHAR(50) NOT NULL,
  organization_id UUID NOT NULL,
  payload JSONB
) PARTITION BY RANGE (event_time);

-- Create partitions
CREATE TABLE events_2023_q1 PARTITION OF events
  FOR VALUES FROM ('2023-01-01') TO ('2023-04-01');

CREATE TABLE events_2023_q2 PARTITION OF events
  FOR VALUES FROM ('2023-04-01') TO ('2023-07-01');
```

### Horizontal Scaling

For extreme scale, implement database sharding:

1. **Shard by organization ID**: Isolate tenant data
2. **Implement a shard router**: Direct queries to appropriate database
3. **Handle cross-shard queries**: Aggregate results when necessary

## Conclusion

Database query optimization is an ongoing process. As the application evolves and data grows, continue to monitor performance, analyze query patterns, and refine your optimization strategy. Regular performance testing and query analysis will help maintain a responsive and efficient application.

Follow these best practices to ensure your database queries are efficient, properly indexed, and designed for scale. When implementing new features, consider query performance from the start rather than optimizing after problems arise.
