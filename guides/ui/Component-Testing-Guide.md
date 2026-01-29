# Component Testing Guide - React Testing Library

**Purpose**: Practical patterns for testing React components  
**Target**: v0.4.0 component development  
**Status**: ✅ Production Ready  
**Last Updated**: 2024-12-07

---

## 📋 Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Setup](#setup)
3. [Testing Patterns by Component Type](#testing-patterns-by-component-type)
4. [Accessibility Testing](#accessibility-testing)
5. [Common Scenarios](#common-scenarios)
6. [Best Practices](#best-practices)

---

## Testing Philosophy

### The Guiding Principle

> "The more your tests resemble how users interact with your app, the more confidence they give you."

**This means**:
- ✅ Test user behavior, not implementation
- ✅ Use accessible queries (getByRole, getByLabelText)
- ✅ Interact like a user (click, type, navigate)
- ❌ Don't test internal state or props directly
- ❌ Don't query by className or test IDs (unless no other option)

---

## Setup

### Install Dependencies

```bash
cd app

npm install --save-dev \
  @testing-library/react \
  @testing-library/user-event \
  @testing-library/jest-dom \
  jest-axe
```

### Jest Configuration

**File**: `jest.unit.config.js`

```javascript
module.exports = {
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['<rootDir>/tests/setup/jest.unit.setup.ts'],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/$1',
  },
};
```

### Test Setup

**File**: `tests/setup/jest.unit.setup.ts`

```typescript
import '@testing-library/jest-dom';
import { toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);
```

---

## Testing Patterns by Component Type

### 1. Testing Buttons

```typescript
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Button } from '@/components/ui/button';

describe('Button', () => {
  it('should call onClick when clicked', async () => {
    const user = userEvent.setup();
    const onClick = jest.fn();
    
    render(<Button onClick={onClick}>Click me</Button>);
    
    await user.click(screen.getByRole('button'));
    expect(onClick).toHaveBeenCalledTimes(1);
  });
  
  it('should not call onClick when disabled', async () => {
    const user = userEvent.setup();
    const onClick = jest.fn();
    
    render(<Button onClick={onClick} disabled>Click me</Button>);
    
    await user.click(screen.getByRole('button'));
    expect(onClick).not.toHaveBeenCalled();
  });
  
  it('should show loading state', () => {
    render(
      <Button disabled>
        <LoaderIcon className="mr-2 h-4 w-4 animate-spin" />
        Loading...
      </Button>
    );
    
    expect(screen.getByRole('button')).toBeDisabled();
    expect(screen.getByText(/loading/i)).toBeInTheDocument();
  });
});
```

### 2. Testing Forms

```typescript
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { TestConfigForm } from '@/components/TestConfigForm';

describe('TestConfigForm', () => {
  it('should submit form with values', async () => {
    const user = userEvent.setup();
    const onSubmit = jest.fn();
    
    render(<TestConfigForm onSubmit={onSubmit} />);
    
    // Fill form
    await user.type(
      screen.getByLabelText(/test name/i), 
      'Morality Test'
    );
    
    await user.selectOptions(
      screen.getByLabelText(/framework/i),
      'morality'
    );
    
    // Submit
    await user.click(screen.getByRole('button', { name: /start test/i }));
    
    // Verify
    expect(onSubmit).toHaveBeenCalledWith({
      name: 'Morality Test',
      framework: 'morality',
    });
  });
  
  it('should show validation errors', async () => {
    const user = userEvent.setup();
    
    render(<TestConfigForm onSubmit={jest.fn()} />);
    
    // Submit empty form
    await user.click(screen.getByRole('button', { name: /start test/i }));
    
    // Check errors
    expect(await screen.findByText(/test name is required/i)).toBeInTheDocument();
  });
});
```

### 3. Testing Navigation Components

```typescript
import { render, screen } from '@testing-library/react';
import { NavLink } from '@/components/layout/NavLink';

describe('NavLink', () => {
  it('should highlight when active', () => {
    render(
      <NavLink 
        href="/dashboard" 
        icon={DashboardIcon}
        isActive={true}
        onClick={jest.fn()}
      >
        Dashboard
      </NavLink>
    );
    
    const link = screen.getByRole('link', { name: /dashboard/i });
    expect(link).toHaveClass('bg-primary');
    expect(link).toHaveClass('text-primary-foreground');
  });
  
  it('should call onClick when clicked', async () => {
    const user = userEvent.setup();
    const onClick = jest.fn();
    
    render(
      <NavLink 
        href="/dashboard"
        icon={DashboardIcon}
        isActive={false}
        onClick={onClick}
      >
        Dashboard
      </NavLink>
    );
    
    await user.click(screen.getByRole('link'));
    expect(onClick).toHaveBeenCalled();
  });
});
```

### 4. Testing Async Components

```typescript
import { render, screen, waitFor } from '@testing-library/react';
import { DashboardStats } from '@/components/dashboard/DashboardStats';

describe('DashboardStats', () => {
  it('should show loading state initially', () => {
    render(<DashboardStats userId="123" />);
    
    expect(screen.getByRole('status')).toBeInTheDocument();
    expect(screen.getByText(/loading/i)).toBeInTheDocument();
  });
  
  it('should display stats after loading', async () => {
    // Mock fetch
    global.fetch = jest.fn(() =>
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve({
          total: 10,
          completed: 8,
          inProgress: 2,
        }),
      })
    ) as jest.Mock;
    
    render(<DashboardStats userId="123" />);
    
    // Wait for data to load
    const totalStat = await screen.findByText('10');
    expect(totalStat).toBeInTheDocument();
    
    // Loading should be gone
    expect(screen.queryByRole('status')).not.toBeInTheDocument();
  });
  
  it('should show error state on failure', async () => {
    // Mock failed fetch
    global.fetch = jest.fn(() =>
      Promise.reject(new Error('Failed to fetch'))
    ) as jest.Mock;
    
    render(<DashboardStats userId="123" />);
    
    // Wait for error
    expect(await screen.findByRole('alert')).toBeInTheDocument();
    expect(screen.getByText(/failed to load/i)).toBeInTheDocument();
  });
});
```

---

## Accessibility Testing

### Using jest-axe

```typescript
import { render } from '@testing-library/react';
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

describe('AppShell Accessibility', () => {
  it('should have no accessibility violations', async () => {
    const { container } = render(
      <AppShell user={mockUser} currentPath="/dashboard">
        <div>Content</div>
      </AppShell>
    );
    
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });
});
```

### Keyboard Navigation Testing

```typescript
import userEvent from '@testing-library/user-event';

describe('Keyboard Navigation', () => {
  it('should navigate with Tab key', async () => {
    const user = userEvent.setup();
    
    render(<Navigation />);
    
    // Tab to first link
    await user.tab();
    expect(screen.getByRole('link', { name: /dashboard/i })).toHaveFocus();
    
    // Tab to next link
    await user.tab();
    expect(screen.getByRole('link', { name: /test/i })).toHaveFocus();
  });
  
  it('should activate button with Enter key', async () => {
    const user = userEvent.setup();
    const onClick = jest.fn();
    
    render(<Button onClick={onClick}>Save</Button>);
    
    // Tab to button
    await user.tab();
    
    // Press Enter
    await user.keyboard('{Enter}');
    expect(onClick).toHaveBeenCalled();
  });
});
```

---

## Best Practices

### 1. Use User-Event, Not fireEvent

```typescript
// ❌ AVOID: fireEvent (synchronous, unrealistic)
import { fireEvent } from '@testing-library/react';
fireEvent.click(button);

// ✅ PREFER: userEvent (async, realistic)
import userEvent from '@testing-library/user-event';
const user = userEvent.setup();
await user.click(button);
```

### 2. Query by Role, Not Test ID

```typescript
// ❌ LAST RESORT: Test IDs
screen.getByTestId('submit-button');

// ✅ BEST: Accessible roles
screen.getByRole('button', { name: /submit/i });
```

### 3. Wait for Async Changes

```typescript
// ❌ WRONG: Immediate assertion
expect(screen.getByText('Data loaded')).toBeInTheDocument();

// ✅ CORRECT: Wait for element
expect(await screen.findByText('Data loaded')).toBeInTheDocument();

// ✅ CORRECT: Wait for condition
await waitFor(() => {
  expect(screen.getByText('Data loaded')).toBeInTheDocument();
});
```

---

**Related**:
- Rule: @381-react-testing-library-patterns.mdc
- Rule: @380-comprehensive-testing-standards.mdc
- Spec: docs/SPEC-v0.4.0-07-Testing-Strategy.md

