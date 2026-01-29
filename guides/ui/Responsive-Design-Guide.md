# Responsive Design Guide - Mobile-First Patterns

**Purpose**: Complete guide for building responsive, mobile-first UIs  
**Target**: v0.4.0 UI development  
**Status**: ✅ Production Ready  
**Last Updated**: 2024-12-07

---

## 📋 Table of Contents

1. [Mobile-First Philosophy](#mobile-first-philosophy)
2. [Breakpoint Strategy](#breakpoint-strategy)
3. [Layout Patterns](#layout-patterns)
4. [Component Patterns](#component-patterns)
5. [Testing Responsive Designs](#testing-responsive-designs)
6. [Common Pitfalls](#common-pitfalls)
7. [Performance Optimization](#performance-optimization)

---

## Mobile-First Philosophy

### Why Mobile-First?

**Statistics**:
- 📱 60%+ of web traffic is mobile
- 📱 Google uses mobile-first indexing
- 📱 Mobile users convert better when UX is good
- 📱 Easier to scale UP than scale DOWN

### The Approach

**Mobile-First means**:
1. Design for smallest screen FIRST
2. Add complexity as screen size increases
3. Use Tailwind classes WITHOUT prefix for mobile
4. Add responsive prefixes (`md:`, `lg:`) for larger screens

```tsx
// ✅ CORRECT: Mobile-first (base = mobile, md: = tablet+)
<div className="flex-col md:flex-row">
  {/* Mobile: stack vertically
      Tablet+: horizontal layout */}
</div>

// ❌ WRONG: Desktop-first (requires overrides)
<div className="flex-row md:flex-col">
  {/* Backwards thinking! */}
</div>
```

---

## Breakpoint Strategy

### Tailwind Breakpoints

| Breakpoint | Min Width | Typical Device | Primary Use |
|------------|-----------|----------------|-------------|
| *(none)* | 0px | Mobile phones | Base styles |
| `sm:` | 640px | Large phones | Minor tweaks |
| `md:` | 768px | Tablets | Major layout shifts |
| `lg:` | 1024px | Desktops | Enhanced layouts |
| `xl:` | 1280px | Large desktops | Max-width constraints |
| `2xl:` | 1536px | Ultra-wide | Rare adjustments |

### v0.4.0 Breakpoint Usage

For v0.4.0, focus on **3 breakpoints**:

1. **Mobile** (default, no prefix) - 0-767px
2. **Tablet** (`md:`) - 768-1023px
3. **Desktop** (`lg:+`) - 1024px+

**Example**:
```tsx
<div className="
  grid 
  grid-cols-1          /* Mobile: 1 column */
  md:grid-cols-2       /* Tablet: 2 columns */
  lg:grid-cols-3       /* Desktop: 3 columns */
  gap-4                /* Mobile: 16px gap */
  md:gap-6             /* Tablet: 24px gap */
">
  {/* Content */}
</div>
```

---

## Layout Patterns

### Pattern 1: Stacked → Horizontal

**Use Case**: Sidebar + content, form fields side-by-side

```tsx
// Mobile: Stacked vertically
// Desktop: Side-by-side
<div className="flex flex-col md:flex-row gap-4">
  <aside className="w-full md:w-64">Sidebar</aside>
  <main className="flex-1">Content</main>
</div>
```

### Pattern 2: Single Column → Multi-Column Grid

**Use Case**: Dashboard stats, product cards, image galleries

```tsx
// Mobile: 1 column
// Tablet: 2 columns
// Desktop: 4 columns
<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
  <StatCard title="Total" value={10} />
  <StatCard title="Active" value={5} />
  <StatCard title="Pending" value={3} />
  <StatCard title="Complete" value={2} />
</div>
```

### Pattern 3: Full Width → Constrained Width

**Use Case**: Page content, reading content

```tsx
// Mobile: Full width
// Desktop: Max 1280px, centered
<div className="w-full max-w-7xl mx-auto px-4 md:px-6 lg:px-8">
  {/* Content never too wide for reading */}
</div>
```

### Pattern 4: Hidden → Visible

**Use Case**: Desktop-only features, mobile-only menus

```tsx
// Show on desktop, hide on mobile
<div className="hidden md:block">
  Desktop only navigation
</div>

// Show on mobile, hide on desktop
<div className="block md:hidden">
  Mobile hamburger menu
</div>
```

### Pattern 5: Drawer → Fixed Sidebar

**Use Case**: AppShell sidebar navigation

```tsx
// Mobile: Overlay drawer (slides in from left)
// Desktop: Fixed sidebar (always visible)
<aside className={cn(
  "fixed left-0 top-16 bottom-0 w-64 bg-white border-r z-40",
  "transition-transform duration-200",
  // Mobile behavior
  isOpen ? "translate-x-0" : "-translate-x-full",
  // Desktop behavior (always visible)
  "md:translate-x-0"
)}>
  {/* Navigation */}
</aside>

// Corresponding main content padding
<main className="pt-16 md:pl-64">
  {/* No padding on mobile, 256px padding on desktop */}
</main>
```

---

## Component Patterns

### Responsive Buttons

```tsx
// Full width on mobile, auto width on desktop
<Button className="w-full md:w-auto">
  Save Changes
</Button>

// Stack vertically on mobile, horizontal on desktop
<div className="flex flex-col md:flex-row gap-3">
  <Button variant="outline" className="w-full md:w-auto">Cancel</Button>
  <Button className="w-full md:w-auto">Save</Button>
</div>
```

### Responsive Cards

```tsx
export function StatCard({ title, value, icon: Icon }) {
  return (
    <div className="
      bg-card 
      rounded-lg 
      border 
      border-border 
      p-4 md:p-6           /* Smaller padding on mobile */
      shadow-sm
    ">
      <div className="flex items-center justify-between mb-2">
        <p className="text-sm md:text-base text-muted-foreground">{title}</p>
        <Icon className="h-5 w-5 md:h-6 md:w-6 text-primary" />
      </div>
      <p className="text-2xl md:text-3xl font-bold text-foreground">{value}</p>
    </div>
  );
}
```

### Responsive Forms

```tsx
export function TestConfigForm() {
  return (
    <form className="space-y-4 md:space-y-6">
      {/* Single column on mobile, two columns on desktop */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-6">
        <div>
          <Label>Test Name</Label>
          <Input className="w-full" />
        </div>
        
        <div>
          <Label>Framework</Label>
          <Select className="w-full" />
        </div>
      </div>
      
      {/* Full width field */}
      <div>
        <Label>Description</Label>
        <Textarea className="w-full" rows={3} />
      </div>
      
      {/* Stack buttons on mobile, row on desktop */}
      <div className="flex flex-col md:flex-row gap-3 md:justify-end">
        <Button variant="outline" className="w-full md:w-auto">
          Cancel
        </Button>
        <Button type="submit" className="w-full md:w-auto">
          Start Test
        </Button>
      </div>
    </form>
  );
}
```

### Responsive Tables

```tsx
export function TestHistoryTable({ tests }) {
  return (
    <>
      {/* Desktop: Full table */}
      <div className="hidden md:block overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead>
            <tr>
              <th>Test Name</th>
              <th>Date</th>
              <th>Score</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {tests.map(test => (
              <tr key={test.id}>
                <td className="px-6 py-4">{test.name}</td>
                <td className="px-6 py-4">{test.date}</td>
                <td className="px-6 py-4">{test.score}</td>
                <td className="px-6 py-4">{test.status}</td>
                <td className="px-6 py-4">
                  <Button size="sm">View</Button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      
      {/* Mobile: Card list */}
      <div className="block md:hidden space-y-4">
        {tests.map(test => (
          <Card key={test.id}>
            <CardHeader>
              <CardTitle className="text-lg">{test.name}</CardTitle>
              <CardDescription>{test.date}</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Score:</span>
                <span className="font-medium">{test.score}</span>
              </div>
              <div className="flex justify-between text-sm mt-1">
                <span className="text-muted-foreground">Status:</span>
                <Badge>{test.status}</Badge>
              </div>
            </CardContent>
            <CardFooter>
              <Button size="sm" className="w-full">View Details</Button>
            </CardFooter>
          </Card>
        ))}
      </div>
    </>
  );
}
```

---

## Testing Responsive Designs

### Chrome DevTools

```bash
# 1. Open DevTools (F12 or Cmd+Option+I)
# 2. Click device toolbar icon (Cmd+Shift+M)
# 3. Test these viewports:

Mobile:
- iPhone SE (375x667)
- iPhone 12 Pro (390x844)
- iPhone 14 Pro Max (430x932)

Tablet:
- iPad (768x1024)
- iPad Pro (1024x1366)

Desktop:
- 1280x720 (standard)
- 1920x1080 (Full HD)
```

### Manual Testing Checklist

```markdown
## Mobile (375px)
- [ ] All content visible (no horizontal scroll)
- [ ] Text readable (minimum 16px body text)
- [ ] Touch targets adequate (44x44px minimum)
- [ ] Buttons full-width where appropriate
- [ ] Forms easy to complete with thumbs
- [ ] Hamburger menu opens sidebar
- [ ] Images load appropriately sized

## Tablet (768px)
- [ ] Sidebar becomes visible
- [ ] Two-column grids where appropriate
- [ ] Content not too narrow or too wide
- [ ] Touch and mouse both work

## Desktop (1024px+)
- [ ] Content max-width prevents lines too long
- [ ] Multi-column grids (3-4 columns)
- [ ] Hover states work
- [ ] Keyboard navigation smooth
- [ ] All features accessible
```

### Automated Responsive Tests

```typescript
import { render } from '@testing-library/react';

describe('Responsive Layout', () => {
  it('should adapt to mobile viewport', () => {
    global.innerWidth = 375;
    
    const { container } = render(<AppShell {...props} />);
    
    const sidebar = container.querySelector('[role="navigation"]');
    expect(sidebar).toHaveClass('-translate-x-full');
  });
  
  it('should adapt to desktop viewport', () => {
    global.innerWidth = 1024;
    
    const { container } = render(<AppShell {...props} />);
    
    const sidebar = container.querySelector('[role="navigation"]');
    expect(sidebar).toHaveClass('md:translate-x-0');
  });
});
```

---

## Common Pitfalls

### ❌ Pitfall 1: Forgetting Mobile Padding

```tsx
// ❌ WRONG: No mobile padding (content touches edges)
<div className="lg:px-8">

// ✅ CORRECT: Padding on all sizes
<div className="px-4 md:px-6 lg:px-8">
```

### ❌ Pitfall 2: Fixed Widths

```tsx
// ❌ WRONG: Fixed width breaks mobile
<div className="w-[600px]">

// ✅ CORRECT: Max-width with 100% mobile
<div className="w-full max-w-2xl">
```

### ❌ Pitfall 3: Touch Targets Too Small

```tsx
// ❌ WRONG: 32x32px touch target (too small)
<button className="p-2">
  <XIcon className="h-4 w-4" />
</button>

// ✅ CORRECT: 44x44px minimum
<button className="min-h-[44px] min-w-[44px] p-3">
  <XIcon className="h-5 w-5" />
</button>
```

### ❌ Pitfall 4: Forgetting Landscape Mobile

```tsx
// Mobile landscape is wide but short
// Account for shorter viewport height

<div className="h-screen">  {/* ❌ May be too tall */}
<div className="min-h-screen">  {/* ✅ Better */}
```

---

## Performance Optimization

### Responsive Images

```tsx
import Image from 'next/image';

// ✅ CORRECT: Responsive images with Next.js
<Image
  src="/dashboard-screenshot.png"
  alt="Dashboard view"
  width={1200}
  height={800}
  sizes="(max-width: 768px) 100vw, 800px"
  className="w-full h-auto rounded-lg"
/>
```

### Conditional Rendering

```tsx
'use client';

import { useMediaQuery } from '@/hooks/useMediaQuery';

export function ResponsiveLayout() {
  const isDesktop = useMediaQuery('(min-width: 768px)');
  
  return (
    <>
      {isDesktop ? (
        <DesktopTable data={data} />
      ) : (
        <MobileCardList data={data} />
      )}
    </>
  );
}

// Custom hook
function useMediaQuery(query: string) {
  const [matches, setMatches] = useState(false);
  
  useEffect(() => {
    const media = window.matchMedia(query);
    setMatches(media.matches);
    
    const listener = (e: MediaQueryListEvent) => setMatches(e.matches);
    media.addEventListener('change', listener);
    return () => media.removeEventListener('change', listener);
  }, [query]);
  
  return matches;
}
```

---

## Quick Reference

### Common Responsive Patterns

```tsx
// Container width
<div className="container mx-auto px-4 md:px-6 lg:px-8">

// Grid columns
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">

// Flexbox direction
<div className="flex flex-col md:flex-row gap-4">

// Text size
<h1 className="text-2xl md:text-3xl lg:text-4xl">

// Padding/spacing
<div className="p-4 md:p-6 lg:p-8">
<div className="space-y-4 md:space-y-6">

// Hide/show
<div className="hidden md:block">Desktop only</div>
<div className="block md:hidden">Mobile only</div>

// Button width
<Button className="w-full md:w-auto">

// Max width
<div className="w-full max-w-4xl mx-auto">
```

---

**Related**:
- Rule: @044-responsive-design-patterns.mdc
- Rule: @041-app-shell-layout-standards.mdc
- Rule: @054-accessibility-requirements.mdc
- Spec: docs/SPEC-v0.4.0-01-Layout-Architecture.md

