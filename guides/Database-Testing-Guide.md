# VibeCoder Database Testing Guide

## Overview

This guide documents best practices for testing database operations in VibeCoder, including setup of test environments, creation of fixtures, and strategies for testing multi-tenant data access.

## Testing Environment Setup

### Configuration

1. **Separate Test Database**

   Create a dedicated test database configuration:

   ```bash
   # .env.test
   DATABASE_URL=postgresql://postgres:postgres@localhost:5432/vibecoder_test
   ```

2. **Test Client Setup**

   ```typescript
   // tests/helpers/db.ts
   import { PrismaClient } from "@prisma/client";

   // Create test client with test DB URL
   const prisma = new PrismaClient({
     datasources: {
       db: {
         url: process.env.DATABASE_URL,
       },
     },
   });

   export { prisma as testPrisma };
   ```

3. **Database Reset Functions**

   ```typescript
   // tests/helpers/db.ts

   // Setup function to clean database before tests
   export async function setupTestDatabase() {
     // Clean all tables
     await testPrisma.$transaction([
       testPrisma.$executeRaw`TRUNCATE TABLE "Task" CASCADE`,
       testPrisma.$executeRaw`TRUNCATE TABLE "Project" CASCADE`,
       testPrisma.$executeRaw`TRUNCATE TABLE "User" CASCADE`,
       testPrisma.$executeRaw`TRUNCATE TABLE "Organization" CASCADE`,
     ]);
   }

   // Teardown function
   export async function teardownTestDatabase() {
     await testPrisma.$disconnect();
   }
   ```

4. **Integration with Test Framework**

   ```typescript
   // jest.setup.js
   import { setupTestDatabase, teardownTestDatabase } from "./tests/helpers/db";

   // Global setup
   beforeAll(async () => {
     // Set test environment
     process.env.NODE_ENV = "test";

     // Reset database before all tests
     await setupTestDatabase();
   });

   // Reset between test suites
   beforeEach(async () => {
     // Reset test database before each test suite
     await setupTestDatabase();
   });

   // Global teardown
   afterAll(async () => {
     await teardownTestDatabase();
   });
   ```

## Test Data Generation

### Standardized Test Data Factories

Consistent test data generation is critical for reliable tests. Implement standardized test data factories to create test data with proper relationships:

```typescript
// src/test/factories/DatabaseTestFactory.ts
import { PrismaClient } from "@prisma/client";
import { v4 as uuidv4 } from "uuid";

export class DatabaseTestFactory {
  private prisma: PrismaClient;

  constructor(prisma: PrismaClient) {
    this.prisma = prisma;
  }

  /**
   * Creates a complete user scenario with related entities
   */
  async createCompleteUserScenario(
    overrides: Partial<UserScenario> = {}
  ): Promise<UserScenario> {
    // Create the base organization
    const organization = await this.createOrganization(overrides.organization);

    // Create a subscription for the organization
    const subscription = await this.createSubscription({
      organizationId: organization.id,
      tier: overrides.subscriptionTier || "pro",
      ...(overrides.subscription || {}),
    });

    // Create users with different roles
    const users = await Promise.all([
      this.createUser({
        organizationId: organization.id,
        role: "admin",
        ...(overrides.adminUser || {}),
      }),
      this.createUser({
        organizationId: organization.id,
        role: "member",
        ...(overrides.memberUser || {}),
      }),
    ]);

    // Create some projects for the organization
    const projects = await Promise.all(
      Array(overrides.projectCount || 2)
        .fill(0)
        .map((_, i) =>
          this.createProject({
            organizationId: organization.id,
            name: `Test Project ${i + 1}`,
            ownerId: users[0].id,
            ...(overrides.projects?.[i] || {}),
          })
        )
    );

    return {
      organization,
      subscription,
      users,
      projects,
    };
  }

  /**
   * Creates a test organization
   */
  async createOrganization(
    overrides: Partial<Organization> = {}
  ): Promise<Organization> {
    return this.prisma.organization.create({
      data: {
        id: overrides.id || uuidv4(),
        name: overrides.name || `Test Organization ${Date.now()}`,
        createdAt: overrides.createdAt || new Date(),
        updatedAt: overrides.updatedAt || new Date(),
        ...overrides,
      },
    });
  }

  /**
   * Creates a test user
   */
  async createUser(
    overrides: Partial<User> & { organizationId: string; role?: string } = {
      organizationId: "",
    }
  ): Promise<User> {
    const { organizationId, role, ...userOverrides } = overrides;

    return this.prisma.user.create({
      data: {
        id: userOverrides.id || uuidv4(),
        email: userOverrides.email || `test-${Date.now()}@example.com`,
        name: userOverrides.name || `Test User ${Date.now()}`,
        role: role || "member",
        organization: {
          connect: { id: organizationId },
        },
        createdAt: userOverrides.createdAt || new Date(),
        updatedAt: userOverrides.updatedAt || new Date(),
        ...userOverrides,
      },
    });
  }

  /**
   * Creates a test subscription
   */
  async createSubscription(
    overrides: Partial<Subscription> & {
      organizationId: string;
      tier?: string;
    } = { organizationId: "" }
  ): Promise<Subscription> {
    const { organizationId, tier, ...subscriptionOverrides } = overrides;

    return this.prisma.subscription.create({
      data: {
        id: subscriptionOverrides.id || uuidv4(),
        tier: tier || "basic",
        status: subscriptionOverrides.status || "active",
        organization: {
          connect: { id: organizationId },
        },
        currentPeriodStart:
          subscriptionOverrides.currentPeriodStart || new Date(),
        currentPeriodEnd:
          subscriptionOverrides.currentPeriodEnd ||
          new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        createdAt: subscriptionOverrides.createdAt || new Date(),
        updatedAt: subscriptionOverrides.updatedAt || new Date(),
        ...subscriptionOverrides,
      },
    });
  }

  /**
   * Creates a test project
   */
  async createProject(
    overrides: Partial<Project> & {
      organizationId: string;
      ownerId: string;
    } = { organizationId: "", ownerId: "" }
  ): Promise<Project> {
    const { organizationId, ownerId, ...projectOverrides } = overrides;

    return this.prisma.project.create({
      data: {
        id: projectOverrides.id || uuidv4(),
        name: projectOverrides.name || `Test Project ${Date.now()}`,
        description: projectOverrides.description || "A test project",
        status: projectOverrides.status || "active",
        organization: {
          connect: { id: organizationId },
        },
        owner: {
          connect: { id: ownerId },
        },
        createdAt: projectOverrides.createdAt || new Date(),
        updatedAt: projectOverrides.updatedAt || new Date(),
        ...projectOverrides,
      },
    });
  }

  /**
   * Creates a complete scenario with realistic data relationships for testing
   */
  async createRealisticTestData(
    options: RealisticDataOptions = {}
  ): Promise<TestEnvironment> {
    const orgCount = options.organizationCount || 2;
    const organizations = [];
    const scenarios = [];

    // Create multiple organizations with different subscription tiers
    for (let i = 0; i < orgCount; i++) {
      const tier = i % 3 === 0 ? "enterprise" : i % 2 === 0 ? "pro" : "basic";

      // Create complete scenario for this organization
      const scenario = await this.createCompleteUserScenario({
        subscriptionTier: tier,
        projectCount: options.projectsPerOrg || 3,
        organization: {
          name: `Test Organization ${i + 1}`,
        },
      });

      organizations.push(scenario.organization);
      scenarios.push(scenario);
    }

    // Create some shared users that belong to multiple organizations
    if (options.createSharedUsers) {
      const sharedUsers = await Promise.all([
        this.createUser({
          name: "Shared Admin",
          email: "shared-admin@example.com",
          role: "admin",
          organizationId: organizations[0].id,
        }),
        this.createUser({
          name: "Shared Member",
          email: "shared-member@example.com",
          role: "member",
          organizationId: organizations[0].id,
        }),
      ]);

      // Add these users to other organizations
      for (let i = 1; i < organizations.length; i++) {
        await this.prisma.userOrganization.createMany({
          data: sharedUsers.map((user) => ({
            userId: user.id,
            organizationId: organizations[i].id,
            role: user.role,
          })),
        });
      }

      // Add shared users to all scenarios
      scenarios.forEach((scenario) => {
        scenario.users = [...scenario.users, ...sharedUsers];
      });
    }

    return {
      organizations,
      scenarios,
      // Add additional data for easier test access
      users: scenarios.flatMap((s) => s.users),
      projects: scenarios.flatMap((s) => s.projects),
      subscriptions: scenarios.map((s) => s.subscription),
    };
  }

  /**
   * Clean up all test data
   */
  async cleanup(): Promise<void> {
    // Delete in reverse order of dependencies
    await this.prisma.project.deleteMany();
    await this.prisma.userOrganization.deleteMany();
    await this.prisma.user.deleteMany();
    await this.prisma.subscription.deleteMany();
    await this.prisma.organization.deleteMany();
  }
}

// Types for the test factory
interface UserScenario {
  organization: Organization;
  subscription: Subscription;
  users: User[];
  projects: Project[];
}

interface RealisticDataOptions {
  organizationCount?: number;
  projectsPerOrg?: number;
  createSharedUsers?: boolean;
}

interface TestEnvironment {
  organizations: Organization[];
  scenarios: UserScenario[];
  users: User[];
  projects: Project[];
  subscriptions: Subscription[];
}

// These interfaces should match your Prisma schema
interface Organization {
  id: string;
  name: string;
  createdAt: Date;
  updatedAt: Date;
  [key: string]: any;
}

interface User {
  id: string;
  email: string;
  name: string;
  role: string;
  createdAt: Date;
  updatedAt: Date;
  [key: string]: any;
}

interface Subscription {
  id: string;
  tier: string;
  status: string;
  currentPeriodStart: Date;
  currentPeriodEnd: Date;
  createdAt: Date;
  updatedAt: Date;
  [key: string]: any;
}

interface Project {
  id: string;
  name: string;
  description: string;
  status: string;
  createdAt: Date;
  updatedAt: Date;
  [key: string]: any;
}
```

### Using Test Data Factories in Tests

Integrate the test data factories into your testing framework:

```typescript
// src/test/setup.ts
import { PrismaClient } from "@prisma/client";
import { DatabaseTestFactory } from "./factories/DatabaseTestFactory";

// Global setup for tests
let prisma: PrismaClient;
let testFactory: DatabaseTestFactory;

beforeAll(async () => {
  // Initialize Prisma client for tests
  prisma = new PrismaClient({
    datasources: {
      db: {
        url: process.env.TEST_DATABASE_URL,
      },
    },
  });

  // Create test factory instance
  testFactory = new DatabaseTestFactory(prisma);
});

afterAll(async () => {
  // Clean up all test data
  await testFactory.cleanup();
  await prisma.$disconnect();
});

// Export for use in test files
export { prisma, testFactory };
```

Example usage in tests:

```typescript
// src/features/projects/project.test.ts
import { prisma, testFactory } from "../../test/setup";
import { ProjectService } from "./ProjectService";

describe("Project Service", () => {
  let projectService: ProjectService;
  let testData: TestEnvironment;

  beforeAll(async () => {
    projectService = new ProjectService(prisma);

    // Create test data once for all tests
    testData = await testFactory.createRealisticTestData({
      organizationCount: 2,
      projectsPerOrg: 3,
      createSharedUsers: true,
    });
  });

  test("should retrieve projects for organization", async () => {
    // Test against first organization
    const orgId = testData.organizations[0].id;
    const projects = await projectService.getProjectsByOrganization(orgId);

    expect(projects).toHaveLength(3);
    expect(projects[0].organizationId).toBe(orgId);
  });

  test("should retrieve project by ID with owner details", async () => {
    // Get first project from test data
    const project = testData.projects[0];
    const result = await projectService.getProjectWithOwner(project.id);

    expect(result).not.toBeNull();
    expect(result?.id).toBe(project.id);
    expect(result?.owner).toBeDefined();
    expect(result?.owner.id).toBe(project.ownerId);
  });

  test("should update project status", async () => {
    // Get project to update
    const project = testData.projects[1];

    // Update project status
    const updatedProject = await projectService.updateProjectStatus(
      project.id,
      "completed"
    );

    expect(updatedProject.status).toBe("completed");

    // Verify in database
    const dbProject = await prisma.project.findUnique({
      where: { id: project.id },
    });

    expect(dbProject?.status).toBe("completed");
  });
});
```

### Factory for Specific Test Scenarios

Create specialized factories for common test scenarios:

```typescript
// src/test/factories/PaymentTestFactory.ts
import { DatabaseTestFactory } from "./DatabaseTestFactory";
import { PrismaClient } from "@prisma/client";

export class PaymentTestFactory {
  private dbFactory: DatabaseTestFactory;
  private prisma: PrismaClient;

  constructor(prisma: PrismaClient) {
    this.prisma = prisma;
    this.dbFactory = new DatabaseTestFactory(prisma);
  }

  /**
   * Creates a subscription payment scenario
   */
  async createSubscriptionPaymentScenario(
    options: {
      subscriptionStatus?: string;
      paymentMethod?: string;
      hasInvoices?: boolean;
    } = {}
  ): Promise<PaymentScenario> {
    // Create base scenario
    const baseScenario = await this.dbFactory.createCompleteUserScenario({
      subscriptionTier: "pro",
    });

    // Create payment method
    const paymentMethod = await this.prisma.paymentMethod.create({
      data: {
        id: options.paymentMethod || "pm_test_card",
        type: "card",
        lastFour: "4242",
        expiryMonth: 12,
        expiryYear: 2030,
        user: {
          connect: { id: baseScenario.users[0].id },
        },
      },
    });

    // Create invoices if needed
    let invoices = [];
    if (options.hasInvoices) {
      invoices = await Promise.all([
        this.prisma.invoice.create({
          data: {
            id: `inv_${Date.now()}_1`,
            amount: 1000, // $10.00
            currency: "usd",
            status: "paid",
            subscription: {
              connect: { id: baseScenario.subscription.id },
            },
            paidAt: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000), // 30 days ago
          },
        }),
        this.prisma.invoice.create({
          data: {
            id: `inv_${Date.now()}_2`,
            amount: 1000, // $10.00
            currency: "usd",
            status: "paid",
            subscription: {
              connect: { id: baseScenario.subscription.id },
            },
            paidAt: new Date(), // Current date
          },
        }),
      ]);
    }

    return {
      ...baseScenario,
      paymentMethod,
      invoices,
    };
  }

  /**
   * Creates a failed payment scenario
   */
  async createFailedPaymentScenario(): Promise<PaymentScenario> {
    // Create base scenario with a past_due subscription
    const baseScenario = await this.dbFactory.createCompleteUserScenario({
      subscription: {
        status: "past_due",
      },
    });

    // Create payment method
    const paymentMethod = await this.prisma.paymentMethod.create({
      data: {
        id: "pm_test_card_declined",
        type: "card",
        lastFour: "0341",
        expiryMonth: 12,
        expiryYear: 2030,
        user: {
          connect: { id: baseScenario.users[0].id },
        },
      },
    });

    // Create failed invoice
    const invoice = await this.prisma.invoice.create({
      data: {
        id: `inv_failed_${Date.now()}`,
        amount: 1000, // $10.00
        currency: "usd",
        status: "failed",
        subscription: {
          connect: { id: baseScenario.subscription.id },
        },
        paidAt: null,
      },
    });

    // Create payment attempt
    const paymentAttempt = await this.prisma.paymentAttempt.create({
      data: {
        id: `pa_${Date.now()}`,
        status: "failed",
        errorCode: "card_declined",
        errorMessage: "Your card was declined",
        invoice: {
          connect: { id: invoice.id },
        },
        paymentMethod: {
          connect: { id: paymentMethod.id },
        },
      },
    });

    return {
      ...baseScenario,
      paymentMethod,
      invoices: [invoice],
      paymentAttempts: [paymentAttempt],
    };
  }
}

// Additional interfaces
interface PaymentScenario extends UserScenario {
  paymentMethod: any;
  invoices: any[];
  paymentAttempts?: any[];
}
```

### Benefits of Standardized Test Data Factories

Using standardized test data factories provides several benefits:

1. **Consistent Test Data**: All tests use the same patterns for creating test data
2. **Reduced Duplication**: Factory methods can be reused across test files
3. **Relationship Management**: Proper relationships between entities are maintained
4. **Test Isolation**: Each test can create its own isolated data
5. **Realistic Scenarios**: Tests can simulate real-world data patterns
6. **Easy Cleanup**: Centralized cleanup reduces test side effects

By implementing these test data factories, you can significantly improve the quality and maintainability of your database tests.

## Test Data Management

### Fixture Creation

1. **Factory Functions**

   Create factories to generate test data:

   ```typescript
   // tests/factories/organization.ts
   import { Organization } from "@prisma/client";
   import { testPrisma } from "../helpers/db";

   type OrganizationCreateProps = Partial<
     Omit<Organization, "id" | "createdAt" | "updatedAt">
   >;

   export async function createOrganization(
     props: OrganizationCreateProps = {}
   ): Promise<Organization> {
     return await testPrisma.organization.create({
       data: {
         name: props.name || `Test Org ${Date.now()}`,
         domain: props.domain || `testorg-${Date.now()}.example.com`,
         logoUrl: props.logoUrl || null,
         settings: props.settings || {},
         ...props,
       },
     });
   }

   // tests/factories/user.ts
   import { User } from "@prisma/client";
   import { testPrisma } from "../helpers/db";
   import { createOrganization } from "./organization";

   type UserCreateProps = Partial<Omit<User, "id" | "createdAt" | "updatedAt">>;

   export async function createUser(
     props: UserCreateProps = {}
   ): Promise<User> {
     // Create organization if not provided
     const organizationId =
       props.organizationId || (await createOrganization()).id;

     return await testPrisma.user.create({
       data: {
         name: props.name || `Test User ${Date.now()}`,
         email: props.email || `user-${Date.now()}@example.com`,
         auth0Id: props.auth0Id || `auth0|${Date.now()}`,
         role: props.role || "USER",
         organizationId,
         ...props,
       },
     });
   }
   ```

2. **Seed Data Script**

   Create reusable seed data for tests:

   ```typescript
   // tests/seed/index.ts
   import { testPrisma } from "../helpers/db";
   import { createOrganization } from "../factories/organization";
   import { createUser } from "../factories/user";

   export async function seedTestData() {
     // Create organizations
     const org1 = await createOrganization({ name: "Test Org 1" });
     const org2 = await createOrganization({ name: "Test Org 2" });

     // Create users in each organization
     const user1 = await createUser({
       name: "User One",
       email: "user1@example.com",
       organizationId: org1.id,
       role: "ADMIN",
     });

     const user2 = await createUser({
       name: "User Two",
       email: "user2@example.com",
       organizationId: org1.id,
     });

     const user3 = await createUser({
       name: "User Three",
       email: "user3@example.com",
       organizationId: org2.id,
       role: "ADMIN",
     });

     // Create projects
     const project1 = await testPrisma.project.create({
       data: {
         name: "Project One",
         description: "Test project 1",
         organizationId: org1.id,
         createdById: user1.id,
       },
     });

     const project2 = await testPrisma.project.create({
       data: {
         name: "Project Two",
         description: "Test project 2",
         organizationId: org2.id,
         createdById: user3.id,
       },
     });

     // Create tasks
     await testPrisma.task.createMany({
       data: [
         {
           title: "Task 1",
           description: "Test task 1",
           status: "TODO",
           projectId: project1.id,
           organizationId: org1.id,
           createdById: user1.id,
           assignedToId: user2.id,
         },
         {
           title: "Task 2",
           description: "Test task 2",
           status: "IN_PROGRESS",
           projectId: project1.id,
           organizationId: org1.id,
           createdById: user1.id,
           assignedToId: user1.id,
         },
         {
           title: "Task 3",
           description: "Test task 3",
           status: "TODO",
           projectId: project2.id,
           organizationId: org2.id,
           createdById: user3.id,
           assignedToId: user3.id,
         },
       ],
     });

     return {
       organizations: { org1, org2 },
       users: { user1, user2, user3 },
       projects: { project1, project2 },
     };
   }
   ```

## Repository Testing

### Testing Repository Methods

1. **Basic CRUD Operations**

   ```typescript
   // tests/repositories/UserRepository.test.ts
   import { UserRepository } from "../../src/repositories/UserRepository";
   import { testPrisma } from "../helpers/db";
   import { createOrganization } from "../factories/organization";

   describe("UserRepository", () => {
     let userRepository: UserRepository;
     let organizationId: string;

     beforeAll(async () => {
       userRepository = new UserRepository(testPrisma);
       const organization = await createOrganization();
       organizationId = organization.id;
     });

     beforeEach(async () => {
       // Clean users before each test
       await testPrisma.user.deleteMany({
         where: { organizationId },
       });
     });

     test("should create a user", async () => {
       const user = await userRepository.create({
         name: "New User",
         email: "new@example.com",
         organizationId,
       });

       expect(user).toBeDefined();
       expect(user.id).toBeDefined();
       expect(user.name).toBe("New User");
       expect(user.email).toBe("new@example.com");
       expect(user.organizationId).toBe(organizationId);
     });

     test("should find a user by id", async () => {
       // Create test user
       const created = await testPrisma.user.create({
         data: {
           name: "Find Me",
           email: "find@example.com",
           organizationId,
         },
       });

       // Find the user
       const found = await userRepository.findById(created.id, organizationId);

       expect(found).toBeDefined();
       expect(found!.id).toBe(created.id);
     });

     test("should update a user", async () => {
       // Create test user
       const created = await testPrisma.user.create({
         data: {
           name: "Original Name",
           email: "original@example.com",
           organizationId,
         },
       });

       // Update the user
       const updated = await userRepository.update(created.id, organizationId, {
         name: "Updated Name",
       });

       expect(updated.name).toBe("Updated Name");
       expect(updated.email).toBe("original@example.com");
     });

     test("should delete a user", async () => {
       // Create test user
       const created = await testPrisma.user.create({
         data: {
           name: "Delete Me",
           email: "delete@example.com",
           organizationId,
         },
       });

       // Delete the user
       await userRepository.delete(created.id, organizationId);

       // Try to find the deleted user
       const found = await testPrisma.user.findUnique({
         where: { id: created.id },
       });

       expect(found).toBeNull();
     });
   });
   ```

2. **Query Methods**

   ```typescript
   // tests/repositories/ProjectRepository.test.ts
   import { ProjectRepository } from "../../src/repositories/ProjectRepository";
   import { testPrisma } from "../helpers/db";
   import { seedTestData } from "../seed";

   describe("ProjectRepository", () => {
     let projectRepository: ProjectRepository;
     let testData: any;

     beforeAll(async () => {
       projectRepository = new ProjectRepository(testPrisma);
     });

     beforeEach(async () => {
       // Seed test data
       testData = await seedTestData();
     });

     test("should find projects by organization", async () => {
       const { org1, org2 } = testData.organizations;

       // Find projects for org1
       const org1Projects = await projectRepository.findAll(org1.id);

       expect(org1Projects).toHaveLength(1);
       expect(org1Projects[0].name).toBe("Project One");

       // Find projects for org2
       const org2Projects = await projectRepository.findAll(org2.id);

       expect(org2Projects).toHaveLength(1);
       expect(org2Projects[0].name).toBe("Project Two");
     });

     test("should find projects with tasks", async () => {
       const { org1 } = testData.organizations;

       // Find projects with tasks
       const projects = await projectRepository.findAllWithTasks(org1.id);

       expect(projects).toHaveLength(1);
       expect(projects[0].tasks).toBeDefined();
       expect(projects[0].tasks).toHaveLength(2);
     });

     test("should count projects by status", async () => {
       const { org1 } = testData.organizations;

       // Set different statuses
       await testPrisma.project.update({
         where: { id: testData.projects.project1.id },
         data: { status: "ACTIVE" },
       });

       // Create another project
       await testPrisma.project.create({
         data: {
           name: "Project Three",
           status: "ARCHIVED",
           organizationId: org1.id,
           createdById: testData.users.user1.id,
         },
       });

       // Get counts
       const counts = await projectRepository.countByStatus(org1.id);

       expect(counts).toEqual({
         ACTIVE: 1,
         ARCHIVED: 1,
       });
     });
   });
   ```

## Multi-Tenant Testing

### Testing Tenant Isolation

1. **Cross-Tenant Access Tests**

   ```typescript
   // tests/multi-tenant/isolation.test.ts
   import { testPrisma } from "../helpers/db";
   import { seedTestData } from "../seed";
   import { UserRepository } from "../../src/repositories/UserRepository";
   import { ProjectRepository } from "../../src/repositories/ProjectRepository";
   import { TaskRepository } from "../../src/repositories/TaskRepository";

   describe("Multi-Tenant Isolation", () => {
     let testData: any;
     let userRepo: UserRepository;
     let projectRepo: ProjectRepository;
     let taskRepo: TaskRepository;

     beforeEach(async () => {
       testData = await seedTestData();

       userRepo = new UserRepository(testPrisma);
       projectRepo = new ProjectRepository(testPrisma);
       taskRepo = new TaskRepository(testPrisma);
     });

     test("users cannot access data from another organization", async () => {
       const { org1, org2 } = testData.organizations;

       // User from org1 trying to access org2 user
       const org2User = testData.users.user3;
       const userFromOrg1 = await userRepo.findById(org2User.id, org1.id);

       expect(userFromOrg1).toBeNull();
     });

     test("projects are isolated between organizations", async () => {
       const { org1, org2 } = testData.organizations;
       const { project2 } = testData.projects;

       // Try to get org2's project from org1
       const projectFromOrg1 = await projectRepo.findById(project2.id, org1.id);

       expect(projectFromOrg1).toBeNull();

       // Try to get all projects from org1
       const org1Projects = await projectRepo.findAll(org1.id);

       // Should only return org1's projects
       expect(org1Projects.map((p) => p.id)).not.toContain(project2.id);
     });

     test("tasks are isolated between organizations", async () => {
       const { org1, org2 } = testData.organizations;

       // Get all tasks for org1
       const org1Tasks = await taskRepo.findAll(org1.id);

       // Get all tasks for org2
       const org2Tasks = await taskRepo.findAll(org2.id);

       // Verify correct isolation
       expect(org1Tasks).toHaveLength(2);
       expect(org2Tasks).toHaveLength(1);

       // Check no tasks are shared
       const org1TaskIds = org1Tasks.map((t) => t.id);
       const org2TaskIds = org2Tasks.map((t) => t.id);

       expect(org1TaskIds.some((id) => org2TaskIds.includes(id))).toBe(false);
     });
   });
   ```

2. **Organization Context Tests**

   ```typescript
   // tests/multi-tenant/context.test.ts
   import { testPrisma } from "../helpers/db";
   import { seedTestData } from "../seed";
   import { tenantContext } from "../../src/lib/prisma";
   import { UserRepository } from "../../src/repositories/UserRepository";

   describe("Tenant Context", () => {
     let testData: any;
     let userRepo: UserRepository;

     beforeEach(async () => {
       testData = await seedTestData();
       userRepo = new UserRepository(testPrisma);
     });

     test("tenant context middleware enforces isolation", async () => {
       const { org1, org2 } = testData.organizations;

       // Set tenant context to org1
       const org1Users = await tenantContext.run(
         { organizationId: org1.id },
         async () => {
           // This should only return org1 users
           return await testPrisma.user.findMany();
         }
       );

       // Set tenant context to org2
       const org2Users = await tenantContext.run(
         { organizationId: org2.id },
         async () => {
           // This should only return org2 users
           return await testPrisma.user.findMany();
         }
       );

       // Verify isolation
       expect(org1Users.length).toBe(2);
       expect(org2Users.length).toBe(1);

       const org1Emails = org1Users.map((u) => u.email);
       expect(org1Emails).toContain("user1@example.com");
       expect(org1Emails).toContain("user2@example.com");
       expect(org1Emails).not.toContain("user3@example.com");

       const org2Emails = org2Users.map((u) => u.email);
       expect(org2Emails).toContain("user3@example.com");
       expect(org2Emails).not.toContain("user1@example.com");
     });

     test("create operations enforce organization ID", async () => {
       const { org1 } = testData.organizations;

       // Set tenant context to org1
       const user = await tenantContext.run(
         { organizationId: org1.id },
         async () => {
           // Create without explicit organizationId
           return await testPrisma.user.create({
             data: {
               name: "Context Test User",
               email: "context@example.com",
             },
           });
         }
       );

       // Verify organization was set correctly
       expect(user.organizationId).toBe(org1.id);
     });
   });
   ```

## Transaction Testing

### Testing Atomic Operations

1. **Transaction Success Tests**

   ```typescript
   // tests/transactions/atomic.test.ts
   import { testPrisma } from "../helpers/db";
   import { createOrganization } from "../factories/organization";
   import { ProjectRepository } from "../../src/repositories/ProjectRepository";

   describe("Transaction Tests", () => {
     let projectRepo: ProjectRepository;
     let organizationId: string;

     beforeAll(async () => {
       projectRepo = new ProjectRepository(testPrisma);
       const organization = await createOrganization();
       organizationId = organization.id;
     });

     test("createProjectWithTasks succeeds as atomic operation", async () => {
       const result = await projectRepo.createProjectWithTasks(
         {
           name: "Transaction Project",
           description: "Testing transactions",
           organizationId,
         },
         [
           { title: "Task 1", status: "TODO", organizationId },
           { title: "Task 2", status: "TODO", organizationId },
         ]
       );

       // Verify project was created
       expect(result.project).toBeDefined();
       expect(result.project.name).toBe("Transaction Project");

       // Verify tasks were created
       expect(result.tasks).toHaveLength(2);
       expect(result.tasks[0].projectId).toBe(result.project.id);
       expect(result.tasks[1].projectId).toBe(result.project.id);
     });

     test("transaction rollback on error", async () => {
       // Count projects before
       const beforeCount = await testPrisma.project.count({
         where: { organizationId },
       });

       // Try to create with invalid data to trigger error
       try {
         await projectRepo.createProjectWithTasks(
           {
             name: "Will Fail",
             description: "Testing rollback",
             organizationId,
           },
           [
             // Invalid - missing required fields
             { title: "Task 1" } as any,
           ]
         );

         fail("Should have thrown an error");
       } catch (error) {
         // Expected error
       }

       // Count projects after
       const afterCount = await testPrisma.project.count({
         where: { organizationId },
       });

       // Verify no project was created
       expect(afterCount).toBe(beforeCount);
     });
   });
   ```

2. **Concurrent Transaction Tests**

   ```typescript
   // tests/transactions/concurrent.test.ts
   import { testPrisma } from "../helpers/db";
   import { createUser } from "../factories/user";
   import { UserRepository } from "../../src/repositories/UserRepository";

   describe("Concurrent Transaction Tests", () => {
     let userRepo: UserRepository;

     beforeAll(() => {
       userRepo = new UserRepository(testPrisma);
     });

     test("concurrent updates handle conflicts", async () => {
       // Create test user with credit balance
       const user = await createUser();
       await testPrisma.userCredit.create({
         data: {
           userId: user.id,
           organizationId: user.organizationId,
           balance: 100,
         },
       });

       // Simulate concurrent transactions
       const promises = [
         userRepo.deductCredits(user.id, user.organizationId, 30),
         userRepo.deductCredits(user.id, user.organizationId, 50),
       ];

       // Wait for both to complete
       await Promise.all(promises);

       // Check final balance
       const userCredit = await testPrisma.userCredit.findFirst({
         where: {
           userId: user.id,
           organizationId: user.organizationId,
         },
       });

       // Should be atomic, so balance should be 20
       expect(userCredit?.balance).toBe(20);
     });
   });
   ```

## Testing Database Hooks and Middleware

### Middleware Testing

1. **Soft Delete Middleware**

   ```typescript
   // tests/middleware/soft-delete.test.ts
   import { testPrisma } from "../helpers/db";
   import { createProject } from "../factories/project";

   describe("Soft Delete Middleware", () => {
     test("delete operation marks record as deleted", async () => {
       // Create test project
       const project = await createProject();

       // Delete the project
       await testPrisma.project.delete({
         where: { id: project.id },
       });

       // Check raw data in database
       const result = await testPrisma.$queryRaw`
         SELECT * FROM "Project" WHERE id = ${project.id}
       `;

       // Should still exist but have deletedAt timestamp
       expect(result).toHaveLength(1);
       expect(result[0].deletedAt).not.toBeNull();
     });

     test("find operations exclude deleted records", async () => {
       // Create two projects
       const project1 = await createProject({ name: "Active Project" });
       const project2 = await createProject({ name: "Deleted Project" });

       // Delete one project
       await testPrisma.project.delete({
         where: { id: project2.id },
       });

       // Find all projects
       const projects = await testPrisma.project.findMany({
         where: { organizationId: project1.organizationId },
       });

       // Should only return non-deleted project
       expect(projects).toHaveLength(1);
       expect(projects[0].id).toBe(project1.id);
     });

     test("explicitly include deleted records", async () => {
       // Create project
       const project = await createProject();

       // Delete the project
       await testPrisma.project.delete({
         where: { id: project.id },
       });

       // Find with deleted
       const result = await testPrisma.project.findMany({
         where: {
           id: project.id,
           deletedAt: { not: null }, // Explicitly look for deleted
         },
       });

       // Should find the deleted project
       expect(result).toHaveLength(1);
     });
   });
   ```

2. **Tenant Middleware**

   ```typescript
   // tests/middleware/tenant.test.ts
   import { testPrisma } from "../helpers/db";
   import { seedTestData } from "../seed";
   import { tenantContext } from "../../src/lib/prisma";

   describe("Tenant Middleware", () => {
     let testData: any;

     beforeEach(async () => {
       testData = await seedTestData();
     });

     test("creates with organization ID", async () => {
       const { org1 } = testData.organizations;

       // Run in tenant context
       const project = await tenantContext.run(
         { organizationId: org1.id },
         async () => {
           return await testPrisma.project.create({
             data: {
               name: "Middleware Test Project",
               createdById: testData.users.user1.id,
               // Note: no organizationId specified
             },
           });
         }
       );

       // Should have organization ID set
       expect(project.organizationId).toBe(org1.id);
     });

     test("filters queries by organization", async () => {
       const { org1, org2 } = testData.organizations;

       // Run in org1 context
       const org1Projects = await tenantContext.run(
         { organizationId: org1.id },
         async () => {
           return await testPrisma.project.findMany();
         }
       );

       // Run in org2 context
       const org2Projects = await tenantContext.run(
         { organizationId: org2.id },
         async () => {
           return await testPrisma.project.findMany();
         }
       );

       // Should filter correctly
       expect(org1Projects.length).toBe(1);
       expect(org1Projects[0].name).toBe("Project One");

       expect(org2Projects.length).toBe(1);
       expect(org2Projects[0].name).toBe("Project Two");
     });

     test("protects against organization spoofing", async () => {
       const { org1, org2 } = testData.organizations;

       // Try to create with wrong organization
       const project = await tenantContext.run(
         { organizationId: org1.id },
         async () => {
           return await testPrisma.project.create({
             data: {
               name: "Spoofing Test",
               createdById: testData.users.user1.id,
               organizationId: org2.id, // Try to specify different org
             },
           });
         }
       );

       // Should override with context organization
       expect(project.organizationId).toBe(org1.id);
     });
   });
   ```

## Performance Testing

### Database Query Performance

1. **Query Execution Time**

   ```typescript
   // tests/performance/query-performance.test.ts
   import { testPrisma } from "../helpers/db";
   import { createOrganization } from "../factories/organization";
   import { ProjectRepository } from "../../src/repositories/ProjectRepository";

   describe("Query Performance", () => {
     let projectRepo: ProjectRepository;
     let organizationId: string;

     beforeAll(async () => {
       projectRepo = new ProjectRepository(testPrisma);
       const organization = await createOrganization();
       organizationId = organization.id;

       // Create test data - many projects
       const projects = Array(100)
         .fill(0)
         .map((_, i) => ({
           name: `Performance Project ${i}`,
           organizationId,
           createdById: "test-user-id",
         }));

       await testPrisma.project.createMany({
         data: projects,
       });
     });

     test("findAll query should complete in under 100ms", async () => {
       const start = Date.now();

       await projectRepo.findAll(organizationId);

       const duration = Date.now() - start;
       expect(duration).toBeLessThan(100);
     });

     test("paginated query should be faster than non-paginated", async () => {
       // Non-paginated
       const startNonPaginated = Date.now();
       await projectRepo.findAll(organizationId);
       const durationNonPaginated = Date.now() - startNonPaginated;

       // Paginated
       const startPaginated = Date.now();
       await projectRepo.findAll(organizationId, { skip: 0, take: 10 });
       const durationPaginated = Date.now() - startPaginated;

       expect(durationPaginated).toBeLessThan(durationNonPaginated);
     });

     test("filtered query should use index", async () => {
       // This test requires analyzing query plans
       // We can approximate by measuring execution time
       const start = Date.now();

       await projectRepo.findByStatus(organizationId, "ACTIVE");

       const duration = Date.now() - start;
       expect(duration).toBeLessThan(50);
     });
   });
   ```

2. **Connection Pool Testing**

   ```typescript
   // tests/performance/connection-pool.test.ts
   import { testPrisma } from "../helpers/db";
   import { createOrganization } from "../factories/organization";

   describe("Connection Pool", () => {
     test("handles concurrent queries efficiently", async () => {
       const organization = await createOrganization();

       // Create 20 concurrent queries
       const queries = Array(20)
         .fill(0)
         .map((_, i) =>
           testPrisma.user.create({
             data: {
               name: `Pool Test User ${i}`,
               email: `pool-test-${i}@example.com`,
               organizationId: organization.id,
             },
           })
         );

       // Measure time to complete all
       const start = Date.now();
       await Promise.all(queries);
       const duration = Date.now() - start;

       // Depends on connection pool settings, but should be relatively fast
       expect(duration).toBeLessThan(1000);
     });
   });
   ```

## Integration Testing

### API Route Database Integration

1. **API Route with Database**

   ```typescript
   // tests/integration/api-routes.test.ts
   import { createMocks } from "node-mocks-http";
   import { seedTestData } from "../seed";
   import { tenantContext } from "../../src/lib/prisma";
   import usersHandler from "../../src/pages/api/users";
   import projectsHandler from "../../src/pages/api/projects";

   describe("API Routes Database Integration", () => {
     let testData: any;

     beforeEach(async () => {
       testData = await seedTestData();
     });

     test("GET /api/users returns users from correct organization", async () => {
       const { org1 } = testData.organizations;

       // Mock request with organization context
       const { req, res } = createMocks({
         method: "GET",
         headers: {
           "x-organization-id": org1.id,
         },
       });

       // Call API handler
       await usersHandler(req, res);

       // Check response
       expect(res._getStatusCode()).toBe(200);

       const data = JSON.parse(res._getData());
       expect(data.length).toBe(2); // org1 has 2 users

       const emails = data.map((u: any) => u.email);
       expect(emails).toContain("user1@example.com");
       expect(emails).toContain("user2@example.com");
     });

     test("POST /api/projects creates project in correct organization", async () => {
       const { org1 } = testData.organizations;
       const { user1 } = testData.users;

       // Mock request with organization context
       const { req, res } = createMocks({
         method: "POST",
         headers: {
           "x-organization-id": org1.id,
         },
         body: {
           name: "API Test Project",
           description: "Created via API test",
         },
       });

       // Set auth context
       req.auth = { userId: user1.id };

       // Call API handler
       await projectsHandler(req, res);

       // Check response
       expect(res._getStatusCode()).toBe(201);

       const project = JSON.parse(res._getData());
       expect(project.name).toBe("API Test Project");
       expect(project.organizationId).toBe(org1.id);
     });
   });
   ```

## Best Practices

1. **Isolate Test Database**

   - Always use a separate database for testing
   - Reset database state before tests

2. **Use Repository Pattern**

   - Test repository methods directly
   - Mock repositories in service/controller tests

3. **Test Multi-Tenant Isolation**

   - Explicitly test data isolation between tenants
   - Verify tenant middleware works correctly

4. **Test Transactions**

   - Verify atomic operations succeed or fail completely
   - Test rollbacks on error conditions

5. **Test Performance**

   - Measure query execution time
   - Verify indexes are effective
   - Test with realistic data volumes

6. **Integration Testing**
   - Test API routes with real database access
   - Verify correct tenant context propagation

By following these testing practices, you can ensure your database code is reliable, maintains proper tenant isolation, and performs efficiently under various conditions.
