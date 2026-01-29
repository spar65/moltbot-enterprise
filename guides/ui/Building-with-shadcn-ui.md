# Building with shadcn/ui - Complete Guide

**Purpose**: Comprehensive guide for using shadcn/ui in v0.4.0  
**Target**: Developers implementing v0.4.0 UI components  
**Status**: ✅ Production Ready  
**Last Updated**: 2024-12-07

---

## 📋 Table of Contents

1. [What is shadcn/ui?](#what-is-shadcnui)
2. [Installation](#installation)
3. [Adding Components](#adding-components)
4. [Customizing Theme](#customizing-theme)
5. [Common Patterns](#common-patterns)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

---

## What is shadcn/ui?

**shadcn/ui** is NOT a component library. It's a collection of **reusable components** that you copy into your project and own.

### Key Differences from Traditional Libraries

| Aspect | Traditional Library | shadcn/ui |
|--------|---------------------|-----------|
| **Installation** | npm package | Copy components |
| **Ownership** | External dependency | You own the code |
| **Customization** | Limited by props | Full control |
| **Updates** | Breaking changes | You decide when to update |
| **Bundle Size** | Entire library | Only what you use |

### Why shadcn/ui for v0.4.0?

- ✅ Built on Radix UI (accessibility-first)
- ✅ Tailwind CSS styling (design token integration)
- ✅ TypeScript support (type-safe)
- ✅ Highly customizable (full code ownership)
- ✅ WCAG AA compliant out of the box
- ✅ Copy what you need, leave what you don't

---

## Installation

### Step 1: Initialize shadcn/ui

```bash
cd app

# Initialize shadcn/ui (interactive)
npx shadcn@latest init

# Answer prompts:
# - TypeScript? Yes
# - Style: New York (or Default)
# - Base color: Slate (or Zinc)
# - CSS variables: Yes
# - Tailwind prefix: (none)
# - Components directory: @/components
# - Utils directory: @/lib/utils
# - React Server Components: Yes
```

This creates:
```
app/
├── components/
│   └── ui/              # shadcn/ui components go here
├── lib/
│   └── utils.ts         # cn() utility function
├── tailwind.config.ts   # Updated with shadcn config
└── app/globals.css      # Updated with CSS variables
```

### Step 2: Verify Setup

```bash
# Check that files were created
ls -la app/components/ui/
ls -la app/lib/utils.ts

# Check tailwind.config.ts was updated
cat app/tailwind.config.ts | grep shadcn
```

---

## Adding Components

### Basic Component Installation

```bash
# Add individual components
npx shadcn@latest add button
npx shadcn@latest add card
npx shadcn@latest add input
npx shadcn@latest add select
npx shadcn@latest add dialog

# Add multiple components at once
npx shadcn@latest add button card input select dialog
```

### Components Needed for v0.4.0

```bash
# Core UI components
npx shadcn@latest add button
npx shadcn@latest add card
npx shadcn@latest add badge
npx shadcn@latest add avatar
npx shadcn@latest add separator

# Form components
npx shadcn@latest add input
npx shadcn@latest add label
npx shadcn@latest add textarea
npx shadcn@latest add select
npx shadcn@latest add checkbox
npx shadcn@latest add radio-group

# Navigation components
npx shadcn@latest add dropdown-menu
npx shadcn@latest add navigation-menu

# Feedback components
npx shadcn@latest add alert
npx shadcn@latest add toast
npx shadcn@latest add progress

# Layout components
npx shadcn@latest add tabs
npx shadcn@latest add dialog
npx shadcn@latest add sheet
```

---

## Customizing Theme

### Design Tokens (CSS Variables)

**File**: `app/globals.css`

```css
@layer base {
  :root {
    /* Background and foreground */
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    
    /* Primary brand color */
    --primary: 221.2 83.2% 53.3%;  /* Blue */
    --primary-foreground: 210 40% 98%;
    
    /* Secondary color */
    --secondary: 210 40% 96.1%;
    --secondary-foreground: 222.2 47.4% 11.2%;
    
    /* Accent color */
    --accent: 210 40% 96.1%;
    --accent-foreground: 222.2 47.4% 11.2%;
    
    /* Destructive (errors, delete actions) */
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    
    /* Muted (subtle backgrounds, disabled states) */
    --muted: 210 40% 96.1%;
    --muted-foreground: 215.4 16.3% 46.9%;
    
    /* Card and popover backgrounds */
    --card: 0 0% 100%;
    --card-foreground: 222.2 84% 4.9%;
    
    --popover: 0 0% 100%;
    --popover-foreground: 222.2 84% 4.9%;
    
    /* Borders and inputs */
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 222.2 84% 4.9%;
    
    /* Border radius */
    --radius: 0.5rem;
  }
}
```

### Tailwind Config Integration

**File**: `tailwind.config.ts`

```typescript
import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: ["class"],
  content: [
    "./pages/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./app/**/*.{ts,tsx}",
  ],
  theme: {
    container: {
      center: true,
      padding: "2rem",
      screens: {
        "2xl": "1400px",
      },
    },
    extend: {
      colors: {
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};

export default config;
```

---

## Common Patterns

### 1. Using Button Component

```tsx
import { Button } from "@/components/ui/button";

export function Example() {
  return (
    <div className="space-y-4">
      {/* Default primary button */}
      <Button>Click me</Button>
      
      {/* Variants */}
      <Button variant="secondary">Secondary</Button>
      <Button variant="destructive">Delete</Button>
      <Button variant="outline">Outline</Button>
      <Button variant="ghost">Ghost</Button>
      <Button variant="link">Link</Button>
      
      {/* Sizes */}
      <Button size="sm">Small</Button>
      <Button size="default">Default</Button>
      <Button size="lg">Large</Button>
      <Button size="icon"><PlusIcon /></Button>
      
      {/* With icon */}
      <Button>
        <PlusIcon className="mr-2 h-4 w-4" />
        Add Item
      </Button>
      
      {/* Loading state */}
      <Button disabled>
        <LoaderIcon className="mr-2 h-4 w-4 animate-spin" />
        Loading...
      </Button>
    </div>
  );
}
```

### 2. Using Card Component

```tsx
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  CardFooter,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";

export function StatCard({ title, value, description }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        <CardDescription>{description}</CardDescription>
      </CardHeader>
      <CardContent>
        <p className="text-4xl font-bold">{value}</p>
      </CardContent>
      <CardFooter>
        <Button variant="outline" size="sm">View Details</Button>
      </CardFooter>
    </Card>
  );
}
```

### 3. Using Form Components

```tsx
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from "@/components/ui/select";
import { Button } from "@/components/ui/button";

export function TestConfigForm({ onSubmit }) {
  return (
    <form onSubmit={onSubmit} className="space-y-6">
      <div className="space-y-2">
        <Label htmlFor="testName">Test Name</Label>
        <Input 
          id="testName" 
          placeholder="Enter test name"
          required
        />
      </div>
      
      <div className="space-y-2">
        <Label htmlFor="framework">Framework</Label>
        <Select name="framework" required>
          <SelectTrigger>
            <SelectValue placeholder="Select framework" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="morality">Morality</SelectItem>
            <SelectItem value="virtue">Virtue</SelectItem>
            <SelectItem value="ethics">Ethics</SelectItem>
          </SelectContent>
        </Select>
      </div>
      
      <div className="flex justify-end gap-3">
        <Button type="button" variant="outline">Cancel</Button>
        <Button type="submit">Start Test</Button>
      </div>
    </form>
  );
}
```

### 4. Using Dialog/Modal

```tsx
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";

export function DeleteConfirmDialog({ onConfirm }) {
  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button variant="destructive">Delete Test</Button>
      </DialogTrigger>
      
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Are you sure?</DialogTitle>
          <DialogDescription>
            This action cannot be undone. This will permanently delete the test
            and all associated results.
          </DialogDescription>
        </DialogHeader>
        
        <DialogFooter>
          <Button variant="outline">Cancel</Button>
          <Button variant="destructive" onClick={onConfirm}>
            Delete
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
```

---

## Best Practices

### 1. Always Use the `cn()` Utility

```tsx
import { cn } from "@/lib/utils";

// ✅ CORRECT: Merge classes safely
<Button className={cn("w-full", variant === 'large' && "py-4")}>
  Click me
</Button>

// ❌ WRONG: String concatenation (doesn't handle conflicts)
<Button className={"w-full " + (variant === 'large' ? "py-4" : "")}>
```

### 2. Extend Components, Don't Modify

```tsx
// ✅ CORRECT: Create wrapper component
import { Button as BaseButton } from "@/components/ui/button";

export function LoadingButton({ loading, children, ...props }) {
  return (
    <BaseButton disabled={loading} {...props}>
      {loading && <LoaderIcon className="mr-2 h-4 w-4 animate-spin" />}
      {children}
    </BaseButton>
  );
}

// ❌ WRONG: Modifying ui/button.tsx directly
// Don't edit files in components/ui/ directly!
```

### 3. Use Composition Over Customization

```tsx
// ✅ CORRECT: Compose multiple components
<Card>
  <CardHeader>
    <CardTitle>Dashboard Stats</CardTitle>
  </CardHeader>
  <CardContent>
    <div className="grid grid-cols-4 gap-4">
      <StatCard title="Total" value={10} />
      <StatCard title="Completed" value={8} />
    </div>
  </CardContent>
</Card>

// ❌ WRONG: Creating custom card from scratch
// Reuse shadcn/ui cards instead!
```

---

## Troubleshooting

### Issue: Component not found

```bash
# Error: Cannot find module '@/components/ui/button'

# Solution: Add the component
npx shadcn@latest add button
```

### Issue: Styles not applied

```bash
# Check Tailwind config includes component path
cat tailwind.config.ts | grep "components"

# Should see:
# content: ["./components/**/*.{ts,tsx}"]
```

### Issue: Dark mode not working

```tsx
// Ensure dark mode provider is set up
// app/layout.tsx
import { ThemeProvider } from "next-themes";

export default function RootLayout({ children }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
```

---

## Quick Reference

### Most Used Components for v0.4.0

| Component | Use Case | Command |
|-----------|----------|---------|
| **Button** | Actions, CTAs | `npx shadcn@latest add button` |
| **Card** | Content containers | `npx shadcn@latest add card` |
| **Input** | Text fields | `npx shadcn@latest add input` |
| **Select** | Dropdowns | `npx shadcn@latest add select` |
| **Dialog** | Modals, confirmations | `npx shadcn@latest add dialog` |
| **Badge** | Status indicators | `npx shadcn@latest add badge` |
| **Avatar** | User profiles | `npx shadcn@latest add avatar` |
| **Dropdown Menu** | User menu, actions | `npx shadcn@latest add dropdown-menu` |

---

**Related**:
- Rule: @200-shadcn-ui-strictness.mdc
- Rule: @043-design-tokens-standards.mdc
- Spec: docs/SPEC-v0.4.0-03-Component-Library.md

