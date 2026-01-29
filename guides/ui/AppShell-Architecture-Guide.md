# AppShell Architecture - Complete Implementation Guide

**Purpose**: Step-by-step guide for implementing the AppShell layout system  
**Target**: v0.4.0 Week 1 Development  
**Status**: ✅ Production Ready  
**Last Updated**: 2024-12-07

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Implementation Steps](#implementation-steps)
3. [Component Specifications](#component-specifications)
4. [Responsive Behavior](#responsive-behavior)
5. [State Management](#state-management)
6. [Testing Guide](#testing-guide)
7. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### What is AppShell?

AppShell is the **root layout wrapper** for all authenticated pages in v0.4.0. It provides:

- ✅ **TopBanner** - Fixed header with branding, user menu, admin button
- ✅ **Sidebar** - Collapsible navigation (drawer on mobile)
- ✅ **Main Content Area** - Page-specific content
- ✅ **Footer** - Consistent footer across pages

### Visual Structure

```
┌───────────────────────────────────────────────────────────┐
│ TopBanner (z-50)                                          │
│  [Logo] CompSI                              [User] [Admin]│
├───────────┬───────────────────────────────────────────────┤
│ Sidebar   │ Main Content Area                             │
│ (z-40)    │                                               │
│           │  ┌─────────────────────────────────┐          │
│ Dashboard │  │                                 │          │
│ Run Test  │  │  Page-Specific Content          │          │
│ History   │  │  (children)                     │          │
│ Settings  │  │                                 │          │
│           │  └─────────────────────────────────┘          │
│           │                                               │
├───────────┴───────────────────────────────────────────────┤
│ Footer                                                    │
└───────────────────────────────────────────────────────────┘
```

### File Structure

```
app/
├── (app)/                           # Authenticated routes use AppShell
│   ├── layout.tsx                  # AppShell wrapper
│   ├── dashboard/page.tsx          # Wrapped by AppShell
│   ├── test/page.tsx               # Wrapped by AppShell
│   └── ...
├── components/
│   └── layout/
│       ├── AppShell.tsx            # Main wrapper component
│       ├── TopBanner.tsx           # Header component
│       ├── Sidebar.tsx             # Navigation component
│       ├── Footer.tsx              # Footer component
│       ├── NavLink.tsx             # Navigation item component
│       └── UserMenu.tsx            # User dropdown menu
└── ...
```

---

## Implementation Steps

### Step 1: Create Layout Components Directory

```bash
mkdir -p app/components/layout
```

### Step 2: Implement AppShell Component

**File**: `app/components/layout/AppShell.tsx`

```tsx
'use client';

import { useState } from 'react';
import { TopBanner } from './TopBanner';
import { Sidebar } from './Sidebar';
import { Footer } from './Footer';

interface User {
  id: string;
  name: string;
  email: string;
  role: 'USER' | 'ADMIN';
}

interface AppShellProps {
  user: User;
  currentPath: string;
  children: React.ReactNode;
}

export function AppShell({ user, currentPath, children }: AppShellProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  
  return (
    <div className="min-h-screen bg-gray-50">
      {/* TopBanner - Fixed header */}
      <TopBanner 
        user={user} 
        onMenuToggle={() => setSidebarOpen(!sidebarOpen)} 
      />
      
      {/* Sidebar - Collapsible navigation */}
      <Sidebar 
        currentPath={currentPath}
        isOpen={sidebarOpen}
        onClose={() => setSidebarOpen(false)}
      />
      
      {/* Main Content */}
      <main className="pt-16 md:pl-64 min-h-screen">
        <div className="container mx-auto px-4 md:px-6 lg:px-8 py-6 md:py-8">
          {children}
        </div>
      </main>
      
      {/* Footer */}
      <Footer />
    </div>
  );
}
```

### Step 3: Implement TopBanner Component

**File**: `app/components/layout/TopBanner.tsx`

```tsx
'use client';

import Link from 'next/link';
import { MenuIcon } from 'lucide-react';
import { UserMenu } from './UserMenu';
import { Button } from '@/components/ui/button';

interface User {
  id: string;
  name: string;
  email: string;
  role: 'USER' | 'ADMIN';
}

interface TopBannerProps {
  user: User;
  onMenuToggle: () => void;
}

export function TopBanner({ user, onMenuToggle }: TopBannerProps) {
  return (
    <header className="fixed top-0 left-0 right-0 h-16 bg-white border-b border-gray-200 z-50">
      <div className="flex items-center justify-between h-full px-4">
        {/* Mobile hamburger menu */}
        <button
          onClick={onMenuToggle}
          className="md:hidden p-2 rounded-md hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-primary"
          aria-label="Toggle navigation menu"
        >
          <MenuIcon className="h-6 w-6" />
        </button>
        
        {/* Logo and brand */}
        <Link 
          href="/dashboard" 
          className="flex items-center gap-2 hover:opacity-80 transition-opacity"
        >
          <div className="h-8 w-8 bg-primary rounded-md flex items-center justify-center">
            <span className="text-primary-foreground font-bold text-lg">C</span>
          </div>
          <span className="hidden md:block text-xl font-semibold text-gray-900">
            CompSI
          </span>
        </Link>
        
        {/* Right section: Admin button + User menu */}
        <div className="flex items-center gap-3">
          {user.role === 'ADMIN' && (
            <Button 
              asChild 
              variant="default"
              size="sm"
              className="hidden sm:inline-flex"
            >
              <Link href="/admin">Admin</Link>
            </Button>
          )}
          
          <UserMenu user={user} />
        </div>
      </div>
    </header>
  );
}
```

### Step 4: Implement Sidebar Component

**File**: `app/components/layout/Sidebar.tsx`

```tsx
'use client';

import { useEffect, useRef } from 'react';
import { NavLink } from './NavLink';
import { LayoutDashboard, Play, History, Settings } from 'lucide-react';
import { cn } from '@/lib/utils';

interface SidebarProps {
  currentPath: string;
  isOpen: boolean;
  onClose: () => void;
}

export function Sidebar({ currentPath, isOpen, onClose }: SidebarProps) {
  const sidebarRef = useRef<HTMLElement>(null);
  
  const navItems = [
    { label: 'Dashboard', href: '/dashboard', icon: LayoutDashboard },
    { label: 'Run Test', href: '/test', icon: Play },
    { label: 'Test History', href: '/history', icon: History },
    { label: 'Settings', href: '/settings', icon: Settings },
  ];
  
  // Focus trap for mobile drawer
  useEffect(() => {
    if (isOpen) {
      const firstFocusable = sidebarRef.current?.querySelector<HTMLElement>(
        'a, button'
      );
      firstFocusable?.focus();
    }
  }, [isOpen]);
  
  // Close on Escape key
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };
    
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [isOpen, onClose]);
  
  return (
    <>
      {/* Mobile overlay */}
      {isOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-40 md:hidden"
          onClick={onClose}
          aria-hidden="true"
        />
      )}
      
      {/* Sidebar */}
      <aside
        ref={sidebarRef}
        className={cn(
          "fixed left-0 top-16 bottom-0 w-64 bg-white border-r border-gray-200 z-40",
          "transform transition-transform duration-200 ease-in-out",
          // Mobile: slide from left
          "md:translate-x-0",
          isOpen ? "translate-x-0" : "-translate-x-full"
        )}
        role="navigation"
        aria-label="Primary navigation"
      >
        <nav className="p-4 space-y-2">
          {navItems.map((item) => (
            <NavLink
              key={item.href}
              href={item.href}
              icon={item.icon}
              isActive={currentPath === item.href}
              onClick={onClose}
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
      </aside>
    </>
  );
}
```

### Step 5: Implement NavLink Component

**File**: `app/components/layout/NavLink.tsx`

```tsx
'use client';

import Link from 'next/link';
import { LucideIcon } from 'lucide-react';
import { cn } from '@/lib/utils';

interface NavLinkProps {
  href: string;
  icon: LucideIcon;
  children: React.ReactNode;
  isActive: boolean;
  onClick?: () => void;
}

export function NavLink({ href, icon: Icon, children, isActive, onClick }: NavLinkProps) {
  return (
    <Link
      href={href}
      onClick={onClick}
      className={cn(
        "flex items-center gap-3 px-4 py-3 rounded-lg",
        "transition-colors duration-200",
        "focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2",
        isActive 
          ? "bg-primary text-primary-foreground font-medium shadow-sm" 
          : "text-gray-700 hover:bg-gray-100 hover:text-gray-900"
      )}
    >
      <Icon className="h-5 w-5 flex-shrink-0" />
      <span>{children}</span>
    </Link>
  );
}
```

### Step 6: Implement UserMenu Component

**File**: `app/components/layout/UserMenu.tsx`

```tsx
'use client';

import { signOut } from 'next-auth/react';
import { User, Settings, LogOut } from 'lucide-react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';

interface UserMenuProps {
  user: {
    id: string;
    name: string;
    email: string;
    role: 'USER' | 'ADMIN';
  };
}

export function UserMenu({ user }: UserMenuProps) {
  const initials = user.name
    .split(' ')
    .map(n => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);
  
  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="focus:outline-none focus:ring-2 focus:ring-primary rounded-full">
        <Avatar>
          <AvatarFallback className="bg-primary text-primary-foreground">
            {initials}
          </AvatarFallback>
        </Avatar>
      </DropdownMenuTrigger>
      
      <DropdownMenuContent align="end" className="w-56">
        <DropdownMenuLabel>
          <div className="flex flex-col space-y-1">
            <p className="text-sm font-medium">{user.name}</p>
            <p className="text-xs text-muted-foreground">{user.email}</p>
          </div>
        </DropdownMenuLabel>
        
        <DropdownMenuSeparator />
        
        <DropdownMenuItem asChild>
          <Link href="/settings" className="flex items-center cursor-pointer">
            <Settings className="mr-2 h-4 w-4" />
            <span>Settings</span>
          </Link>
        </DropdownMenuItem>
        
        {user.role === 'ADMIN' && (
          <DropdownMenuItem asChild className="md:hidden">
            <Link href="/admin" className="flex items-center cursor-pointer">
              <User className="mr-2 h-4 w-4" />
              <span>Admin</span>
            </Link>
          </DropdownMenuItem>
        )}
        
        <DropdownMenuSeparator />
        
        <DropdownMenuItem
          onClick={() => signOut({ callbackUrl: '/login' })}
          className="cursor-pointer text-destructive focus:text-destructive"
        >
          <LogOut className="mr-2 h-4 w-4" />
          <span>Log out</span>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
```

### Step 7: Implement Footer Component

**File**: `app/components/layout/Footer.tsx`

```tsx
import Link from 'next/link';

export function Footer() {
  const currentYear = new Date().getFullYear();
  
  return (
    <footer className="border-t border-gray-200 bg-gray-50 py-8 md:pl-64">
      <div className="container mx-auto px-4 md:px-6">
        <div className="flex flex-col md:flex-row justify-between items-center gap-4">
          <p className="text-sm text-gray-600">
            © {currentYear} CompSI • AI Ethics Assessment Platform
          </p>
          
          <div className="flex gap-6">
            <Link 
              href="/privacy" 
              className="text-sm text-gray-600 hover:text-gray-900 transition-colors"
            >
              Privacy
            </Link>
            <Link 
              href="/terms" 
              className="text-sm text-gray-600 hover:text-gray-900 transition-colors"
            >
              Terms
            </Link>
            <Link 
              href="/contact" 
              className="text-sm text-gray-600 hover:text-gray-900 transition-colors"
            >
              Contact
            </Link>
          </div>
        </div>
      </div>
    </footer>
  );
}
```

### Step 8: Wire Up in Layout

**File**: `app/(app)/layout.tsx`

```tsx
import { redirect } from 'next/navigation';
import { headers } from 'next/headers';
import { auth } from '@/lib/auth';
import { AppShell } from '@/components/layout/AppShell';

export default async function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  // Get session
  const session = await auth();
  
  // Guard: Require authentication
  if (!session?.user) {
    redirect('/login');
  }
  
  // Get current pathname
  const headersList = headers();
  const pathname = headersList.get('x-invoke-path') || '/dashboard';
  
  // Render with AppShell
  return (
    <AppShell 
      user={{
        id: session.user.id!,
        name: session.user.name || '',
        email: session.user.email || '',
        role: (session.user.role as 'USER' | 'ADMIN') || 'USER',
      }}
      currentPath={pathname}
    >
      {children}
    </AppShell>
  );
}
```

---

## Responsive Behavior

### Desktop (≥768px)

- ✅ Sidebar always visible (256px width)
- ✅ Main content has left padding (pl-64)
- ✅ Hamburger menu hidden
- ✅ Full brand name visible in TopBanner

### Tablet (640-767px)

- ✅ Sidebar becomes drawer (opens on hamburger click)
- ✅ Main content full width
- ✅ Hamburger menu visible
- ✅ Brand name may be shortened

### Mobile (<640px)

- ✅ Sidebar is drawer with overlay
- ✅ Main content full width
- ✅ Hamburger menu visible
- ✅ Compact TopBanner (logo only)
- ✅ Admin button in UserMenu dropdown

---

## State Management

### Sidebar State

```tsx
// AppShell manages sidebar open/close state
const [sidebarOpen, setSidebarOpen] = useState(false);

// TopBanner toggles sidebar
<TopBanner onMenuToggle={() => setSidebarOpen(!sidebarOpen)} />

// Sidebar receives state and close handler
<Sidebar 
  isOpen={sidebarOpen}
  onClose={() => setSidebarOpen(false)}
/>

// Clicking nav item closes mobile sidebar
<NavLink onClick={onClose}>Dashboard</NavLink>

// Clicking overlay closes sidebar
<div onClick={onClose} />

// Escape key closes sidebar
useEffect(() => {
  const handleEscape = (e: KeyboardEvent) => {
    if (e.key === 'Escape' && isOpen) onClose();
  };
  window.addEventListener('keydown', handleEscape);
  return () => window.removeEventListener('keydown', handleEscape);
}, [isOpen, onClose]);
```

---

## Testing Guide

### Unit Tests for AppShell

**File**: `app/__tests__/unit/components/layout/AppShell.test.tsx`

```tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { AppShell } from '@/components/layout/AppShell';

const mockUser = {
  id: '123',
  name: 'Test User',
  email: 'test@example.com',
  role: 'USER' as const,
};

describe('AppShell', () => {
  it('should render all layout components', () => {
    render(
      <AppShell user={mockUser} currentPath="/dashboard">
        <div>Page Content</div>
      </AppShell>
    );
    
    expect(screen.getByRole('banner')).toBeInTheDocument();
    expect(screen.getByRole('navigation')).toBeInTheDocument();
    expect(screen.getByRole('main')).toBeInTheDocument();
    expect(screen.getByRole('contentinfo')).toBeInTheDocument();
    expect(screen.getByText('Page Content')).toBeInTheDocument();
  });
  
  it('should show admin button for admin users', () => {
    const adminUser = { ...mockUser, role: 'ADMIN' as const };
    
    render(
      <AppShell user={adminUser} currentPath="/dashboard">
        <div>Content</div>
      </AppShell>
    );
    
    expect(screen.getByRole('link', { name: /admin/i })).toBeInTheDocument();
  });
  
  it('should toggle mobile sidebar', async () => {
    const user = userEvent.setup();
    
    render(
      <AppShell user={mockUser} currentPath="/dashboard">
        <div>Content</div>
      </AppShell>
    );
    
    const menuButton = screen.getByRole('button', { name: /toggle navigation/i });
    const nav = screen.getByRole('navigation');
    
    // Initially closed
    expect(nav).toHaveClass('-translate-x-full');
    
    // Open sidebar
    await user.click(menuButton);
    expect(nav).toHaveClass('translate-x-0');
    
    // Close sidebar
    await user.click(menuButton);
    expect(nav).toHaveClass('-translate-x-full');
  });
});
```

---

## Troubleshooting

### Issue: Sidebar not responsive

**Symptom**: Sidebar always visible, even on mobile

**Solution**: Check Tailwind classes
```tsx
// Should have both base and responsive classes
className="translate-x-0 md:translate-x-0"  // ❌ Wrong
className="-translate-x-full md:translate-x-0" // ✅ Correct
```

### Issue: Content hidden behind sidebar

**Symptom**: Main content overlaps with sidebar

**Solution**: Add padding to main element
```tsx
<main className="pt-16 md:pl-64">  {/* pl-64 = 256px sidebar width */}
```

### Issue: Z-index conflicts

**Symptom**: Modals appear behind TopBanner

**Solution**: Use correct z-index hierarchy
```tsx
TopBanner: z-50
Sidebar:   z-40
Modals:    z-50 (same as TopBanner)
Overlay:   z-40 (same as Sidebar)
```

---

## Performance Optimization

### Lazy Load UserMenu

```tsx
import dynamic from 'next/dynamic';

const UserMenu = dynamic(() => import('./UserMenu'), {
  loading: () => (
    <div className="h-10 w-10 rounded-full bg-gray-200 animate-pulse" />
  ),
});
```

### Prefetch Navigation Links

```tsx
import { useRouter } from 'next/navigation';

export function NavLink({ href, ...props }) {
  const router = useRouter();
  
  return (
    <Link
      href={href}
      onMouseEnter={() => router.prefetch(href)}
      {...props}
    />
  );
}
```

---

**Related**:
- Rule: @041-app-shell-layout-standards.mdc
- Rule: @044-responsive-design-patterns.mdc
- Spec: docs/SPEC-v0.4.0-01-Layout-Architecture.md

