# VibeCoder API Design Guide

## API Design Principles

VibeCoder APIs follow these core principles:

1. **RESTful Design**: Resources as nouns, HTTP methods as verbs
2. **Consistency**: Predictable patterns across all endpoints
3. **Security First**: Authentication and authorization by default
4. **Performance**: Optimized for minimal latency
5. **Developer Experience**: Clear documentation and intuitive behavior

## API Structure

### Base URL

- Development: `http://localhost:3000/api`
- Production: `https://app.vibecoder.com/api`

### Versioning

- Version in URL path: `/api/v1/resource`
- Current version: v1

### Resource Naming

- Use plural nouns for collections: `/api/v1/users`
- Use specific resource identifiers: `/api/v1/users/123`
- Use sub-resources for relationships: `/api/v1/users/123/projects`
- Use kebab-case for multi-word resources: `/api/v1/user-preferences`

## Request Format

### HTTP Methods

- **GET**: Read resources
- **POST**: Create resources
- **PUT**: Replace resources
- **PATCH**: Update resources
- **DELETE**: Remove resources

### Headers

- `Content-Type: application/json` for request bodies
- `Authorization: Bearer {token}` for authenticated requests
- `Accept-Language: en-US` for localization

### Query Parameters

- Use for filtering: `?status=active`
- Use for pagination: `?page=2&limit=10`
- Use for sorting: `?sort=createdAt&order=desc`
- Use for field selection: `?fields=id,name,email`

### Request Body

```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "role": "user"
}
```

## Response Format

### Success Response

```json
{
  "data": {
    "id": "123",
    "name": "John Doe",
    "email": "john@example.com",
    "createdAt": "2023-06-01T12:00:00Z"
  },
  "meta": {
    "requestId": "req_123456"
  }
}
```

### Collection Response

```json
{
  "data": [
    {
      "id": "123",
      "name": "John Doe"
    },
    {
      "id": "124",
      "name": "Jane Smith"
    }
  ],
  "pagination": {
    "total": 50,
    "page": 1,
    "limit": 10,
    "hasMore": true
  },
  "meta": {
    "requestId": "req_123456"
  }
}
```

### Error Response

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Email is required",
    "details": [
      {
        "field": "email",
        "message": "Email is required"
      }
    ]
  },
  "meta": {
    "requestId": "req_123456"
  }
}
```

## Status Codes

- **200 OK**: Successful request
- **201 Created**: Resource created successfully
- **204 No Content**: Successful request with no response body
- **400 Bad Request**: Invalid request format
- **401 Unauthorized**: Missing or invalid authentication
- **403 Forbidden**: Valid authentication but insufficient permissions
- **404 Not Found**: Resource not found
- **409 Conflict**: Request conflicts with current state
- **422 Unprocessable Entity**: Validation errors
- **429 Too Many Requests**: Rate limit exceeded
- **500 Internal Server Error**: Server-side error

## Authentication

### Auth0 Integration

- Protected endpoints require valid JWT
- JWT validation using Auth0 middleware
- Roles and permissions from Auth0 claims

### Authorization

- Use middleware for role-based access control
- Check permissions for specific operations
- Document required permissions for each endpoint

## API Implementation

### Next.js API Routes

```typescript
// pages/api/users/[id].ts
import { NextApiRequest, NextApiResponse } from "next";
import { withApiAuthRequired, getSession } from "@auth0/nextjs-auth0";
import { getUserById } from "@/lib/db/users";
import { ApiResponse, User } from "@/types";

async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse<User>>
) {
  const { id } = req.query;
  const session = await getSession(req, res);

  try {
    const user = await getUserById(id as string);

    if (!user) {
      return res.status(404).json({
        error: {
          code: "USER_NOT_FOUND",
          message: "User not found",
        },
        meta: { requestId: req.headers["x-request-id"] as string },
      });
    }

    return res.status(200).json({
      data: user,
      meta: { requestId: req.headers["x-request-id"] as string },
    });
  } catch (error) {
    console.error("Error fetching user:", error);
    return res.status(500).json({
      error: {
        code: "INTERNAL_SERVER_ERROR",
        message: "An unexpected error occurred",
      },
      meta: { requestId: req.headers["x-request-id"] as string },
    });
  }
}

export default withApiAuthRequired(handler);
```

### API Middleware

```typescript
// middleware/withValidation.ts
import { NextApiRequest, NextApiResponse } from "next";
import { z } from "zod";
import { ApiResponse } from "@/types";

export function withValidation<T>(
  schema: z.Schema<T>,
  handler: (
    req: NextApiRequest,
    res: NextApiResponse,
    validData: T
  ) => Promise<void>
) {
  return async (
    req: NextApiRequest,
    res: NextApiResponse<ApiResponse<any>>
  ) => {
    try {
      const validData = schema.parse(req.body);
      return handler(req, res, validData);
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(422).json({
          error: {
            code: "VALIDATION_ERROR",
            message: "Validation failed",
            details: error.errors.map((err) => ({
              field: err.path.join("."),
              message: err.message,
            })),
          },
          meta: { requestId: req.headers["x-request-id"] as string },
        });
      }

      return res.status(500).json({
        error: {
          code: "INTERNAL_SERVER_ERROR",
          message: "An unexpected error occurred",
        },
        meta: { requestId: req.headers["x-request-id"] as string },
      });
    }
  };
}
```

## Client-Side API Interaction

### API Client

```typescript
// lib/api/client.ts
import { ApiResponse } from "@/types";

export class ApiError extends Error {
  status: number;
  code: string;
  details?: Array<{ field: string; message: string }>;

  constructor(
    message: string,
    status: number,
    code: string,
    details?: Array<{ field: string; message: string }>
  ) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
    this.name = "ApiError";
  }
}

async function apiRequest<T>(
  url: string,
  options: RequestInit = {}
): Promise<T> {
  const response = await fetch(url, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...options.headers,
    },
  });

  const data: ApiResponse<T> = await response.json();

  if (!response.ok) {
    const error = data.error!;
    throw new ApiError(
      error.message,
      response.status,
      error.code,
      error.details
    );
  }

  return data.data as T;
}

export const api = {
  get: <T>(url: string, options?: RequestInit) =>
    apiRequest<T>(url, { method: "GET", ...options }),

  post: <T>(url: string, body: any, options?: RequestInit) =>
    apiRequest<T>(url, {
      method: "POST",
      body: JSON.stringify(body),
      ...options,
    }),

  put: <T>(url: string, body: any, options?: RequestInit) =>
    apiRequest<T>(url, {
      method: "PUT",
      body: JSON.stringify(body),
      ...options,
    }),

  patch: <T>(url: string, body: any, options?: RequestInit) =>
    apiRequest<T>(url, {
      method: "PATCH",
      body: JSON.stringify(body),
      ...options,
    }),

  delete: <T>(url: string, options?: RequestInit) =>
    apiRequest<T>(url, { method: "DELETE", ...options }),
};
```

### React Query Integration

```typescript
// hooks/useUsers.ts
import { useQuery, useMutation, useQueryClient } from "react-query";
import { api } from "@/lib/api/client";
import { User } from "@/types";

export function useUsers() {
  const queryClient = useQueryClient();

  const getUsers = useQuery<User[]>("users", () => api.get("/api/users"));

  const getUserById = (id: string) =>
    useQuery<User>(["users", id], () => api.get(`/api/users/${id}`));

  const createUser = useMutation(
    (newUser: Omit<User, "id">) => api.post<User>("/api/users", newUser),
    {
      onSuccess: () => {
        queryClient.invalidateQueries("users");
      },
    }
  );

  const updateUser = useMutation(
    ({ id, data }: { id: string; data: Partial<User> }) =>
      api.patch<User>(`/api/users/${id}`, data),
    {
      onSuccess: (data) => {
        queryClient.invalidateQueries("users");
        queryClient.invalidateQueries(["users", data.id]);
      },
    }
  );

  const deleteUser = useMutation(
    (id: string) => api.delete(`/api/users/${id}`),
    {
      onSuccess: () => {
        queryClient.invalidateQueries("users");
      },
    }
  );

  return {
    getUsers,
    getUserById,
    createUser,
    updateUser,
    deleteUser,
  };
}
```

## API Documentation

### JSDoc Comments

```typescript
/**
 * Get user by ID
 *
 * @route GET /api/users/:id
 * @param {string} id - User ID
 * @returns {User} User object
 * @throws {404} User not found
 * @throws {500} Internal server error
 * @auth Required
 */
export async function getUserById(id: string): Promise<User | null> {
  // Implementation
}
```

### Swagger/OpenAPI

- Generate OpenAPI specifications from JSDoc comments
- Provide interactive API documentation
- Include example requests and responses
- Document authentication requirements

## Rate Limiting

### Implementation

- Use Redis for rate limit tracking
- Implement token bucket algorithm
- Set different limits based on endpoint sensitivity
- Return appropriate headers with rate limit information

## Monitoring and Logging

### Request Logging

- Log all API requests with metadata
- Include performance metrics
- Track error rates
- Monitor usage patterns

### Performance Monitoring

- Track response times
- Monitor database query performance
- Set up alerts for slow endpoints
- Implement distributed tracing

## Testing

### Unit Testing

- Test individual API handlers
- Mock database and external services
- Test validation and error handling

### Integration Testing

- Test complete API flows
- Verify authentication and authorization
- Test with realistic data
- Validate response formats

### Load Testing

- Test API performance under load
- Identify bottlenecks
- Verify rate limiting behavior
- Measure resource utilization
