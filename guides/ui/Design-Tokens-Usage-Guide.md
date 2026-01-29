# Design Tokens Usage Guide

**Purpose**: Complete guide for defining and using design tokens  
**Target**: v0.4.0 UI implementation  
**Status**: ✅ Production Ready  
**Last Updated**: 2024-12-07

---

## 📋 Table of Contents

1. [What Are Design Tokens?](#what-are-design-tokens)
2. [Token Categories](#token-categories)
3. [Defining Tokens](#defining-tokens)
4. [Using Tokens in Components](#using-tokens-in-components)
5. [Migration from Hard-Coded Values](#migration-from-hard-coded-values)
6. [Dark Mode Support](#dark-mode-support)
7. [Validation](#validation)

---

## What Are Design Tokens?

**Design tokens** are the single source of truth for visual design decisions. They replace hard-coded values with semantic names.

### Benefits

- ✅ **Consistency**: One place to change colors across entire app
- ✅ **Scalability**: Easy to rebrand or create themes
- ✅ **Maintainability**: Semantic names are self-documenting
- ✅ **Dark Mode**: Switch themes automatically
- ✅ **White-Labeling**: Different brands use same codebase

### Example

```tsx
// ❌ BEFORE: Hard-coded values
<button className="bg-blue-600 text-white border border-gray-300 rounded-md shadow-md">
  Save
</button>

// ✅ AFTER: Design tokens
<button className="bg-primary text-primary-foreground border border-border rounded-md shadow">
  Save
</button>
```

**Why better?**
- Change `--primary` color once, updates everywhere
- Dark mode handled automatically
- Accessible by default (proper contrast)

---

## Token Categories

### 1. Color Tokens

**Semantic colors** based on purpose, not hue:

| Token | Purpose | Example |
|-------|---------|---------|
| `primary` | Brand color, CTAs | Blue accent |
| `secondary` | Secondary actions | Gray background |
| `destructive` | Errors, delete actions | Red warning |
| `muted` | Subtle backgrounds | Light gray |
| `accent` | Highlights, hover states | Lighter blue |
| `background` | Page background | White |
| `foreground` | Primary text | Dark gray |
| `border` | Borders, dividers | Light gray |

### 2. Typography Tokens

| Token | Purpose | Size |
|-------|---------|------|
| `text-xs` | Captions, metadata | 12px |
| `text-sm` | Secondary text | 14px |
| `text-base` | Body text | 16px |
| `text-lg` | Subheadings | 18px |
| `text-xl` | Section titles | 20px |
| `text-2xl` | Page headings | 24px |
| `text-3xl` | Hero headings | 30px |
| `text-4xl` | Large hero | 36px |

### 3. Spacing Tokens

Based on 4px increment (Tailwind default):

| Token | Value | Usage |
|-------|-------|-------|
| `1` | 4px | Tight spacing |
| `2` | 8px | Compact spacing |
| `3` | 12px | Small spacing |
| `4` | 16px | Default spacing |
| `6` | 24px | Medium spacing |
| `8` | 32px | Large spacing |
| `12` | 48px | Extra large spacing |

### 4. Border Radius Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `rounded-sm` | 2px | Subtle rounding |
| `rounded-md` | 6px | Standard rounding |
| `rounded-lg` | 8px | Cards, containers |
| `rounded-full` | 9999px | Circles, pills |

### 5. Shadow Tokens

| Token | Usage |
|-------|-------|
| `shadow-sm` | Subtle elevation |
| `shadow` | Default cards |
| `shadow-md` | Raised elements |
| `shadow-lg` | Modals, popovers |
| `shadow-xl` | High elevation |

---

## Defining Tokens

### Step 1: CSS Variables (globals.css)

**File**: `app/globals.css`

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    /* Backgrounds */
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    
    /* Primary brand */
    --primary: 221.2 83.2% 53.3%;
    --primary-foreground: 210 40% 98%;
    
    /* Secondary */
    --secondary: 210 40% 96.1%;
    --secondary-foreground: 222.2 47.4% 11.2%;
    
    /* Muted */
    --muted: 210 40% 96.1%;
    --muted-foreground: 215.4 16.3% 46.9%;
    
    /* Accent */
    --accent: 210 40% 96.1%;
    --accent-foreground: 222.2 47.4% 11.2%;
    
    /* Destructive */
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    
    /* Card */
    --card: 0 0% 100%;
    --card-foreground: 222.2 84% 4.9%;
    
    /* Popover */
    --popover: 0 0% 100%;
    --popover-foreground: 222.2 84% 4.9%;
    
    /* Borders */
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 222.2 84% 4.9%;
    
    /* Radius */
    --radius: 0.5rem;
  }
}
```

### Step 2: Tailwind Config (tailwind.config.ts)

```typescript
import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./app/**/*.{ts,tsx}",
  ],
  theme: {
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

## Using Tokens in Components

### Colors

```tsx
// Backgrounds
<div className="bg-background">Page background</div>
<div className="bg-card">Card background</div>
<div className="bg-muted">Muted background</div>

// Text colors
<h1 className="text-foreground">Primary text</h1>
<p className="text-muted-foreground">Secondary text</p>

// Buttons
<button className="bg-primary text-primary-foreground">Primary</button>
<button className="bg-destructive text-destructive-foreground">Delete</button>

// Borders
<div className="border border-border">Bordered element</div>
```

### Typography

```tsx
// Headings
<h1 className="text-4xl font-bold">Page Title</h1>
<h2 className="text-2xl font-semibold">Section Title</h2>
<h3 className="text-xl font-medium">Subsection</h3>

// Body text
<p className="text-base">Regular paragraph</p>
<span className="text-sm text-muted-foreground">Helper text</span>
```

### Spacing

```tsx
// Padding
<div className="p-4">16px padding</div>
<div className="px-6 py-4">24px horizontal, 16px vertical</div>

// Margin
<div className="mt-8">32px top margin</div>
<div className="mb-6">24px bottom margin</div>

// Gap (flexbox/grid)
<div className="flex gap-4">16px gap</div>
<div className="grid gap-6">24px gap</div>

// Space-y (vertical spacing between children)
<div className="space-y-4">16px between each child</div>
```

---

## Migration from Hard-Coded Values

### Before → After Examples

**Colors**:
```tsx
// Before
<button className="bg-blue-600 text-white">

// After
<button className="bg-primary text-primary-foreground">
```

**Spacing**:
```tsx
// Before
<div className="p-[16px]">

// After
<div className="p-4">
```

**Border Radius**:
```tsx
// Before
<div className="rounded-[8px]">

// After
<div className="rounded-lg">
```

---

## Dark Mode Support

### Defining Dark Mode Colors

```css
@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    --primary: 221.2 83.2% 53.3%;
    /* ... light mode ... */
  }
  
  .dark {
    --background: 222.2 84% 4.9%;
    --foreground: 210 40% 98%;
    --primary: 217.2 91.2% 59.8%;
    /* ... dark mode ... */
  }
}
```

### Using in Components

```tsx
// Tokens automatically switch based on .dark class
<div className="bg-background text-foreground">
  Automatically light or dark based on theme
</div>

// No need for dark: prefix when using tokens!
```

---

## Validation

### Check Token Usage

```bash
# Run validation tool
./.cursor/tools/validate-design-tokens.sh

# Looks for:
# ❌ Hard-coded Tailwind colors (bg-blue-600)
# ❌ Arbitrary values ([16px])
# ✅ Semantic tokens (bg-primary)
```

### Manual Validation

```bash
# Search for hard-coded colors
grep -r "bg-blue-\|text-red-\|border-green-" app/components/

# Search for arbitrary values
grep -r "\[.*px\]\|\[.*rem\]" app/components/
```

---

**Related**:
- Rule: @043-design-tokens-standards.mdc
- Rule: @050-css-architecture.mdc
- Spec: docs/SPEC-v0.4.0-03-Component-Library.md
