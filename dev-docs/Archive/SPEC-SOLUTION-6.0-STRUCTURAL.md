# SPEC-SOLUTION 6.0: Structural Improvements

**Document ID**: SPEC-SOLUTION-6.0  
**Addresses**: SPEC-ISSUES-6.0  
**Category**: Architecture & Structure  
**Priority**: P2 (Important)  
**Date Created**: 2026-01-28  
**Status**: Draft

---

## Executive Summary

This document provides strategies and implementation plans for addressing structural and architectural challenges in the Moltbot codebase.

---

## Solution Registry

### Solution 6.1: Source Directory Reorganization

**Addresses**: Issue 6.1 - Source Directory Organization  
**Priority**: P2  
**Effort**: High (phased over multiple sprints)

#### Target Structure

```
src/
├── core/                    # Core abstractions and utilities
│   ├── config/             # Configuration (merged from config/)
│   ├── errors/             # Error types and handling
│   ├── logging/            # Logging infrastructure
│   ├── security/           # Security utilities
│   ├── validation/         # Validation utilities
│   └── utils/              # Shared utilities
│
├── channels/               # All messaging channels
│   ├── shared/             # Shared channel utilities
│   │   ├── command-gating.ts
│   │   ├── allowlist.ts
│   │   ├── sender-identity.ts
│   │   └── message-types.ts
│   ├── whatsapp/           # (renamed from web/)
│   ├── telegram/
│   ├── discord/
│   ├── slack/
│   ├── signal/
│   ├── imessage/
│   └── line/
│
├── agents/                 # AI agent runtime (refactored)
│   ├── core/               # Core agent abstractions
│   ├── tools/              # Tool implementations
│   │   ├── exec/           # Command execution (from bash-tools)
│   │   ├── browser/        # Browser automation
│   │   ├── file/           # File operations
│   │   └── search/         # Search tools
│   ├── sandbox/            # Sandbox configuration
│   ├── sessions/           # Session management
│   └── memory/             # Memory/vector store
│
├── gateway/                # Gateway server (refactored)
│   ├── server/             # HTTP/WS server
│   ├── protocol/           # Protocol definitions
│   ├── methods/            # RPC methods
│   ├── middleware/         # Middleware (cors, rate-limit, auth)
│   └── coordination/       # Cross-module coordination
│
├── cli/                    # CLI implementation
│   ├── commands/           # (merged from commands/)
│   ├── validation/         # CLI argument validation
│   └── output/             # Output formatting
│
├── hooks/                  # Event hooks and webhooks
│   ├── gmail/
│   ├── cron/
│   └── webhooks/
│
├── infra/                  # Infrastructure utilities
│   ├── process/            # Process management
│   ├── daemon/             # Daemon/service management
│   ├── networking/         # SSH, tunnels, Tailscale
│   └── platform/           # Platform-specific (macos/, etc.)
│
└── media/                  # Media processing
    ├── processing/
    └── understanding/
```

#### Migration Strategy

##### Phase 1: Non-Breaking Moves (Sprint 1)
- Create new directory structure
- Add barrel exports (index.ts) at new locations
- Update internal imports

##### Phase 2: Gradual Migration (Sprint 2-4)
- Move files to new locations one module at a time
- Update imports across codebase
- Maintain backward compatibility exports

##### Phase 3: Cleanup (Sprint 5)
- Remove old directories
- Remove backward compatibility exports
- Update documentation

#### Implementation

```typescript
// src/channels/index.ts - Barrel export for channels

// Re-export from legacy locations for backward compatibility
export * from './whatsapp';
export * from './telegram';
export * from './discord';
export * from './slack';
export * from './signal';
export * from './imessage';
export * from './line';

// Shared utilities
export * from './shared';
```

```typescript
// Migration script helper
// scripts/migrate-imports.ts

import * as ts from 'typescript';
import * as fs from 'fs';
import * as path from 'path';

const IMPORT_MAPPINGS: Record<string, string> = {
  '../web/': '../channels/whatsapp/',
  '../../web/': '../../channels/whatsapp/',
  '../config/': '../core/config/',
  '../../config/': '../../core/config/',
};

function migrateImports(filePath: string): void {
  let content = fs.readFileSync(filePath, 'utf-8');
  let modified = false;
  
  for (const [oldPath, newPath] of Object.entries(IMPORT_MAPPINGS)) {
    if (content.includes(oldPath)) {
      content = content.replace(new RegExp(escapeRegex(oldPath), 'g'), newPath);
      modified = true;
    }
  }
  
  if (modified) {
    fs.writeFileSync(filePath, content);
    console.log(`Updated imports in ${filePath}`);
  }
}

function escapeRegex(string: string): string {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
```

---

### Solution 6.2: Module Dependency Management

**Addresses**: Issue 6.2 - Module Coupling Analysis  
**Priority**: P2  
**Effort**: Medium (ongoing)

#### Dependency Rules

```typescript
// .dependency-rules.ts (for tooling)

const DEPENDENCY_RULES = {
  // Core can't depend on anything except itself
  'src/core/': {
    allow: ['src/core/'],
    deny: ['src/channels/', 'src/agents/', 'src/gateway/', 'src/cli/'],
  },
  
  // Channels can depend on core and shared channel utilities
  'src/channels/': {
    allow: ['src/core/', 'src/channels/shared/'],
    deny: ['src/agents/', 'src/gateway/', 'src/cli/'],
  },
  
  // Agents can depend on core
  'src/agents/': {
    allow: ['src/core/', 'src/agents/'],
    deny: ['src/channels/', 'src/gateway/', 'src/cli/'],
  },
  
  // Gateway can depend on core, channels, agents
  'src/gateway/': {
    allow: ['src/core/', 'src/channels/', 'src/agents/'],
    deny: ['src/cli/'],
  },
  
  // CLI can depend on everything
  'src/cli/': {
    allow: ['*'],
    deny: [],
  },
};
```

#### ESLint Plugin for Dependency Enforcement

```javascript
// eslint-rules/enforce-module-boundaries.js

module.exports = {
  meta: {
    type: 'problem',
    docs: {
      description: 'Enforce module dependency boundaries',
    },
  },
  create(context) {
    const filename = context.getFilename();
    
    return {
      ImportDeclaration(node) {
        const importPath = node.source.value;
        
        // Check if import violates dependency rules
        const violation = checkDependencyViolation(filename, importPath);
        if (violation) {
          context.report({
            node,
            message: `Module boundary violation: ${violation}`,
          });
        }
      },
    };
  },
};
```

#### Dependency Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      DEPENDENCY HIERARCHY                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────┐                                                  │
│  │   CLI     │ ← Top level, can use all                        │
│  └─────┬─────┘                                                  │
│        │                                                        │
│        ▼                                                        │
│  ┌───────────┐                                                  │
│  │  Gateway  │ ← Coordinates channels + agents                 │
│  └─────┬─────┘                                                  │
│        │                                                        │
│   ┌────┴────┐                                                   │
│   ▼         ▼                                                   │
│ ┌───────┐ ┌───────┐                                            │
│ │Channels│ │Agents │ ← Domain-specific                         │
│ └───┬───┘ └───┬───┘                                            │
│     │         │                                                 │
│     └────┬────┘                                                 │
│          ▼                                                      │
│    ┌───────────┐                                                │
│    │   Core    │ ← Shared utilities, no domain logic           │
│    └───────────┘                                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Solution 6.3: Test Organization Improvement

**Addresses**: Issue 6.3 - Test File Organization  
**Priority**: P3  
**Effort**: Low (conventions only)

#### Test Naming Conventions

```typescript
// Current (too verbose):
// sandbox-agent-config.agent-specific-sandbox-config.includes-session-status-default-sandbox-allowlist.test.ts

// Recommended:
// sandbox-config.test.ts (for unit tests)
// sandbox-config.integration.test.ts (for integration tests)
// sandbox-config.e2e.test.ts (for e2e tests)
```

#### Test Organization Rules

1. **Unit tests**: Colocated with source (`*.test.ts`)
2. **Integration tests**: Colocated with source (`*.integration.test.ts`)
3. **E2E tests**: Separate directory (`tests/e2e/`)
4. **Test fixtures**: `__fixtures__/` directory
5. **Test utilities**: `__utils__/` directory

```
src/agents/
├── exec.ts
├── exec.test.ts                    # Unit tests
├── exec.integration.test.ts        # Integration tests
├── __fixtures__/
│   └── sample-commands.json
└── __utils__/
    └── mock-executor.ts

tests/
├── e2e/
│   ├── agent-execution.e2e.test.ts
│   └── gateway-flow.e2e.test.ts
└── helpers/
    └── test-setup.ts
```

---

### Solution 6.4: Channel Architecture Standardization

**Addresses**: Issue 6.4 - Channel Architecture Inconsistency  
**Priority**: P2  
**Effort**: Medium (1-2 sprints)

#### Standard Channel Interface

```typescript
// src/channels/shared/channel-interface.ts

export interface ChannelConfig {
  name: string;
  displayName: string;
  icon?: string;
  supportsMedia: boolean;
  supportsReactions: boolean;
  supportsThreads: boolean;
  maxMessageLength: number;
}

export interface ChannelConnection {
  status: 'connected' | 'disconnected' | 'connecting' | 'error';
  lastError?: string;
  connectedAt?: Date;
}

export interface Channel {
  readonly config: ChannelConfig;
  readonly connection: ChannelConnection;
  
  // Lifecycle
  connect(): Promise<void>;
  disconnect(): Promise<void>;
  
  // Health
  probe(): Promise<boolean>;
  
  // Messaging
  sendMessage(recipient: string, content: MessageContent): Promise<void>;
  onMessage(handler: MessageHandler): void;
  
  // Optional features
  sendReaction?(messageId: string, reaction: string): Promise<void>;
  onReaction?(handler: ReactionHandler): void;
}

export interface MessageContent {
  text?: string;
  media?: MediaAttachment[];
  replyTo?: string;
}

export interface MessageHandler {
  (message: IncomingMessage): Promise<void>;
}

export interface IncomingMessage {
  id: string;
  channelName: string;
  sender: SenderIdentity;
  content: MessageContent;
  timestamp: Date;
  isFromGroup: boolean;
  groupId?: string;
}
```

#### Standard Channel Structure

```
src/channels/telegram/
├── index.ts           # Public API
├── types.ts           # Telegram-specific types
├── config.ts          # Channel configuration
├── connection.ts      # Connection management
├── send.ts            # Message sending
├── receive.ts         # Message receiving
├── probe.ts           # Health check
├── media.ts           # Media handling
└── telegram.test.ts   # Tests
```

#### Migration Checklist per Channel

```markdown
## Channel Migration: [Name]

- [ ] Implements Channel interface
- [ ] Standard directory structure
- [ ] Config follows ChannelConfig
- [ ] Probe implements health check
- [ ] Message sending follows standard
- [ ] Message receiving follows standard
- [ ] Tests cover all interface methods
- [ ] Documentation updated
```

---

### Solution 6.5: Gateway Modularization

**Addresses**: Issue 6.5 - Gateway Complexity  
**Priority**: P2  
**Effort**: High (2-3 sprints)

#### Target Structure

```
src/gateway/
├── index.ts                    # Main export
├── server/
│   ├── http-server.ts         # HTTP server setup
│   ├── ws-server.ts           # WebSocket server setup
│   └── index.ts
├── protocol/
│   ├── messages.ts            # Protocol message types
│   ├── schemas.ts             # Zod schemas
│   └── index.ts
├── methods/
│   ├── registry.ts            # Method registration
│   ├── chat/                  # Chat-related methods
│   ├── channels/              # Channel methods
│   ├── config/                # Config methods
│   └── index.ts
├── middleware/
│   ├── auth.ts                # Authentication
│   ├── cors.ts                # CORS
│   ├── rate-limit.ts          # Rate limiting
│   ├── logging.ts             # Request logging
│   └── index.ts
├── session/
│   ├── manager.ts             # Session management
│   ├── store.ts               # Session storage
│   └── index.ts
└── coordination/
    ├── channel-coordinator.ts # Channel management
    ├── agent-coordinator.ts   # Agent management
    └── index.ts
```

#### Refactoring Strategy

1. **Extract middleware** (Sprint 1)
   - Auth, CORS, rate limiting, logging
   - Each as independent, testable module

2. **Extract protocol** (Sprint 1)
   - Message types
   - Schema definitions

3. **Organize methods** (Sprint 2)
   - Group by domain (chat, channels, config)
   - Each method as separate file

4. **Extract coordination** (Sprint 3)
   - Channel lifecycle management
   - Agent coordination

---

### Solution 6.6: Configuration Simplification

**Addresses**: Issue 6.6 - Configuration Complexity  
**Priority**: P2  
**Effort**: Medium (1-2 sprints)

#### Strategy

1. **Auto-generate documentation from Zod schemas**
2. **Centralize defaults in one file**
3. **Add environment-specific config layers**

```typescript
// src/core/config/defaults.ts

import { z } from 'zod';

export const DEFAULTS = {
  gateway: {
    port: 18789,
    host: '127.0.0.1',
    timeout: 30_000,
  },
  logging: {
    level: 'info' as const,
    redact: true,
  },
  channels: {
    telegram: {
      maxMessageLength: 4096,
    },
    discord: {
      maxMessageLength: 2000,
    },
    // ... other channels
  },
} as const;

// Environment-specific overrides
export const ENV_OVERRIDES = {
  development: {
    logging: { level: 'debug' as const },
  },
  production: {
    logging: { level: 'info' as const, redact: true },
  },
  test: {
    logging: { level: 'warn' as const },
    gateway: { port: 0 }, // Random port for tests
  },
};

export function getDefaults(env: 'development' | 'production' | 'test' = 'development') {
  return deepMerge(DEFAULTS, ENV_OVERRIDES[env] ?? {});
}
```

---

### Solution 6.7: Plugin Architecture Documentation

**Addresses**: Issue 6.7 - Plugin/Extension Boundary  
**Priority**: P3  
**Effort**: Low (documentation only)

#### Plugin Architecture Guide

```markdown
# Moltbot Plugin Development Guide

## Overview

Moltbot supports plugins (extensions) that can add:
- New messaging channels
- Custom tools
- Event handlers
- UI components

## Plugin Structure

```
my-plugin/
├── package.json          # Plugin metadata
├── src/
│   ├── index.ts         # Plugin entry point
│   ├── channel.ts       # Channel implementation (if applicable)
│   └── tools.ts         # Tool implementations (if applicable)
├── README.md
└── LICENSE
```

## Plugin Interface

```typescript
import { Plugin, PluginContext } from 'moltbot/plugin-sdk';

export default function createPlugin(): Plugin {
  return {
    name: 'my-plugin',
    version: '1.0.0',
    
    async onLoad(context: PluginContext) {
      // Called when plugin is loaded
    },
    
    async onUnload() {
      // Called when plugin is unloaded
    },
    
    channels: [
      // Channel implementations
    ],
    
    tools: [
      // Tool implementations
    ],
  };
}
```

## Security Considerations

- Plugins run in the same process as the core
- Plugins have access to configured credentials
- Plugin code should be audited before installation
- Consider sandboxing for untrusted plugins

## Best Practices

1. Use TypeScript for type safety
2. Follow the standard channel interface
3. Include comprehensive tests
4. Document all configuration options
5. Handle errors gracefully
```

---

## Implementation Roadmap

### Sprint 1: Foundation
- [ ] Create target directory structure
- [ ] Add barrel exports for backward compatibility
- [ ] Extract gateway middleware

### Sprint 2: Core Migration
- [ ] Move core utilities
- [ ] Standardize channel interfaces
- [ ] Implement dependency rules

### Sprint 3: Gateway Refactoring
- [ ] Organize gateway methods
- [ ] Extract coordination logic
- [ ] Update gateway tests

### Sprint 4: Channel Standardization
- [ ] Migrate channels to standard structure
- [ ] Implement standard interfaces
- [ ] Update channel documentation

### Sprint 5: Cleanup
- [ ] Remove deprecated paths
- [ ] Update all imports
- [ ] Final documentation

---

## Success Criteria

- [ ] All channels implement standard interface
- [ ] Gateway split into <500 LOC modules
- [ ] Dependency rules enforced via ESLint
- [ ] No circular dependencies
- [ ] Plugin architecture documented
- [ ] Migration complete without breaking changes

---

**Document Maintainer**: Architecture Team  
**Last Updated**: 2026-01-28
