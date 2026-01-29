# Admin Testing Guide: From 15 Failures to 0

## Overview

This guide documents the systematic approach to fixing failing admin tests in the VibeCoder project. It's based on the successful resolution of the Admin Dashboard test suite, which went from 15 failing tests to 0.

## Quick Diagnosis Checklist

When facing failing admin tests, check these common issues first:

1. **Mock Conflicts** - Are there conflicting mocks between `jest.setup.js` and your test?
2. **Text Mismatches** - Does your test text exactly match the component (including punctuation)?
3. **DOM Structure** - Are you querying elements based on the actual DOM structure?
4. **Authentication** - Are AdminGuard and AdminContext properly mocked?
5. **Non-existent Features** - Are you testing functionality that doesn't exist?

## The Mock Setup Architecture

### Global Mocks (jest.setup.js)

```javascript
// Key mocks that should be in jest.setup.js:

// 1. Next.js Router Mock
jest.mock("next/router", () => ({
  useRouter: jest.fn(() => ({
    pathname: "/",
    query: {},
    asPath: "/",
    push: jest.fn(),
    replace: jest.fn(),
    back: jest.fn(),
  })),
}));

// 2. Auth0 Mock
jest.mock("@auth0/nextjs-auth0", () => ({
  useUser: jest.fn(() => ({
    user: undefined,
    error: undefined,
    isLoading: false,
  })),
  UserProvider: ({ children }) => children,
  withPageAuthRequired: (Component) => Component,
}));

// 3. AdminContext Mock
jest.mock("./src/contexts/AdminContext", () => ({
  AdminProvider: ({ children }) => children,
  useAdmin: jest.fn(() => ({
    isAdmin: true,
    permissions: ["*"],
    hasPermission: jest.fn(() => true),
    isLoading: false,
  })),
}));

// 4. AdminGuard Mock
jest.mock("./src/components/AdminGuard", () => ({
  AdminGuard: ({ children }) => children,
  AdminOnly: ({ children }) => children,
}));
```

### Test Utilities (admin-test-utils.tsx)

The `renderWithAdminProviders` function is your primary tool:

```typescript
export function renderWithAdminProviders(
  ui: React.ReactElement,
  {
    user = mockAdminUser,
    isAdmin = true,
    mockRouter = createMockRouter(),
    initialFetchResponse = { ok: true, json: async () => ({}) },
    ...renderOptions
  }: AdminRenderOptions = {}
) {
  // Override global mocks with test-specific values
  const { useRouter } = require("next/router");
  const { useUser } = require("@auth0/nextjs-auth0");

  (useRouter as jest.Mock).mockReturnValue(mockRouter);
  (useUser as jest.Mock).mockReturnValue({
    user,
    isLoading: false,
    error: null,
    checkSession: jest.fn(),
  });

  // ... rest of implementation
}
```

## Common Failure Patterns and Solutions

### 1. "Checking permissions..." Forever

**Symptom:** Tests show "Checking permissions..." instead of actual content.

**Cause:** AdminGuard is waiting for permission checks that never complete.

**Solution:** Ensure AdminContext mock returns `isLoading: false`:

```javascript
jest.mock("./src/contexts/AdminContext", () => ({
  useAdmin: jest.fn(() => ({
    isAdmin: true,
    isLoading: false, // Critical!
  })),
}));
```

### 2. Text Not Found

**Symptom:** `Unable to find an element with the text: Welcome, admin@example.com`

**Cause:** Text doesn't match exactly what's in the component.

**Solution:** Check the actual component for exact text:

```typescript
// Component might have:
<h2>Welcome to the VibeCoder Admin Dashboard, {user.name}</h2>;

// Test should match exactly:
expect(
  screen.getByText(/Welcome to the VibeCoder Admin Dashboard, Test Admin/i)
).toBeInTheDocument();
```

### 3. Navigation Tests Failing

**Symptom:** `expect(mockRouter.push).toHaveBeenCalledWith('/admin/users')` fails.

**Cause:** Component uses regular `<a>` tags, not `router.push()`.

**Solution:** Either:

- Remove the test if navigation is handled by browser
- Test that links have correct `href` attributes:

```typescript
const tile = screen.getByText("User Management").closest("div");
const link = tile?.querySelector("a");
expect(link).toHaveAttribute("href", "/admin/users");
```

### 4. Cannot Find Links

**Symptom:** `.closest('a')` returns null.

**Cause:** Links are nested inside other elements.

**Solution:** Navigate the DOM correctly:

```typescript
// Instead of:
const link = screen.getByText("User Management").closest("a");

// Do:
const tile = screen.getByText("User Management").closest("div");
const link = tile?.querySelector("a");
```

### 5. Mock Conflicts

**Symptom:** Weird errors about functions not being mocks.

**Cause:** Test is trying to mock something already mocked globally.

**Solution:** Don't re-mock, just override return values:

```typescript
// BAD:
jest.mock("@auth0/nextjs-auth0"); // Already mocked globally!

// GOOD:
beforeEach(() => {
  const { useUser } = require("@auth0/nextjs-auth0");
  (useUser as jest.Mock).mockReturnValue({
    user: customUser,
    isLoading: false,
  });
});
```

## Step-by-Step Debugging Process

1. **Run the specific test suite:**

   ```bash
   npm test tests/admin/dashboard.test.tsx
   ```

2. **Check the rendered output:**

   ```typescript
   const { debug } = renderWithAdminProviders(<AdminDashboard />);
   debug(); // Shows what's actually rendered
   ```

3. **Verify mocks are working:**

   ```typescript
   console.log(useUser()); // Should show your mocked user
   console.log(useAdmin()); // Should show isAdmin: true
   ```

4. **Check exact text in component:**

   - Open the actual component file
   - Copy the exact text including punctuation
   - Update your test to match

5. **Understand the DOM structure:**
   - Use browser DevTools on the running app
   - Note how elements are nested
   - Update selectors accordingly

## Best Practices

### DO:

- ✅ Use `renderWithAdminProviders` for all admin tests
- ✅ Clear mocks in `beforeEach`
- ✅ Match text exactly as it appears in components
- ✅ Test actual behavior, not imagined behavior
- ✅ Use the mock data from `admin-test-utils`

### DON'T:

- ❌ Create new mocks for already-mocked modules
- ❌ Assume component structure without checking
- ❌ Test functionality that doesn't exist
- ❌ Forget about punctuation in text matching
- ❌ Use `jest.doMock` when global mocks exist

## Applying to Other Test Suites

When fixing other admin test suites:

1. **Start with the test utility:**

   ```typescript
   import { renderWithAdminProviders } from "../utils/admin-test-utils";
   ```

2. **Check component text:**

   - Open the component file
   - Note all text, including punctuation
   - Update tests to match exactly

3. **Verify navigation patterns:**

   - Check if using `<Link>` or `<a>` tags
   - Adjust tests accordingly

4. **Remove non-existent tests:**
   - If testing a feature that doesn't exist, remove the test
   - Don't test what you wish was there

## Performance Tips

- Run single test files during debugging: `npm test path/to/test.tsx`
- Use `.only` to run specific tests: `it.only('should work', ...)`
- Keep `console.log` statements until all tests pass
- Use `--watch` mode for rapid iteration

## Success Metrics

You'll know you've succeeded when:

- All tests show green checkmarks
- No console errors or warnings
- Coverage shows 100% for the tested component
- Tests run in under 30 seconds

## Troubleshooting Resources

- Check `jest.setup.js` for global mock configuration
- Review `tests/utils/admin-test-utils.tsx` for available utilities
- Look at working tests (like the fixed dashboard test) as examples
- Use `debug()` liberally to understand what's being rendered

Remember: Most test failures are due to mismatches between what the test expects and what the component actually does. Always verify against the real component!
