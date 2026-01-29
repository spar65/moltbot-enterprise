# SPEC-ISSUES 6.0: Structural Challenges

**Document ID**: SPEC-ISSUES-6.0  
**Category**: Architecture & Structure  
**Priority**: P2 (Important)  
**Date Created**: 2026-01-28  
**Status**: Open  
**Related Solutions**: SPEC-SOLUTION-6.0 (to be created)

---

## Executive Summary

This document identifies structural and architectural challenges in the Moltbot codebase. These issues relate to code organization, module boundaries, coupling, and scalability patterns.

---

## Issue Registry

### 6.1 Source Directory Organization

**Category**: Code Organization  
**Severity**: LOW-MEDIUM

#### Current Structure

```
src/
├── acp/              (13 files)  - Agent Client Protocol
├── agents/           (436 files) - AI agent runtime ⚠️ LARGE
├── auto-reply/       (206 files) - Message auto-reply ⚠️ LARGE
├── browser/          (81 files)  - Browser automation
├── canvas-host/      (4 files)   - Canvas rendering
├── channels/         (mixed)     - Channel integrations
├── cli/              (169 files) - CLI commands ⚠️ LARGE
├── commands/         (223 files) - Command handlers ⚠️ LARGE
├── config/           (130 files) - Configuration ⚠️ LARGE
├── cron/             (1 file)    - Cron jobs
├── daemon/           (31 files)  - System daemons
├── discord/          (61 files)  - Discord integration
├── docs/             (2 files)   - Docs utilities
├── gateway/          (187 files) - WebSocket gateway ⚠️ LARGE
├── hooks/            (39 files)  - Event hooks
├── imessage/         (16 files)  - iMessage integration
├── infra/            (182 files) - Infrastructure ⚠️ LARGE
├── line/             (34 files)  - LINE integration
├── logging/          (14 files)  - Logging
├── macos/            (4 files)   - macOS utilities
├── markdown/         (8 files)   - Markdown processing
├── media/            (19 files)  - Media handling
├── media-understanding/ (36 files) - Media analysis
├── memory/           (33 files)  - Memory/vector storage
├── node-host/        (3 files)   - Node hosting
├── pairing/          (5 files)   - Device pairing
├── plugins/          (37 files)  - Plugin system
├── process/          (9 files)   - Process management
├── providers/        (8 files)   - LLM providers
├── routing/          (4 files)   - Message routing
├── security/         (9 files)   - Security utilities
├── sessions/         (7 files)   - Session management
├── signal/           (24 files)  - Signal integration
├── slack/            (65 files)  - Slack integration
├── telegram/         (84 files)  - Telegram integration
├── terminal/         (11 files)  - Terminal utilities
├── tts/              (2 files)   - Text-to-speech
├── tui/              (37 files)  - Terminal UI
├── utils/            (13 files)  - Utilities
├── web/              (77 files)  - WhatsApp Web
├── whatsapp/         (2 files)   - WhatsApp utilities
└── wizard/           (9 files)   - Setup wizard
```

#### Observations

1. **Oversized Modules**: `agents/` (436 files) and `auto-reply/` (206 files) are very large
2. **Overlapping Concerns**: `cli/` and `commands/` have similar purposes
3. **Inconsistent Depth**: Some modules are flat, others deeply nested
4. **Channel Fragmentation**: Channels split between `channels/` and individual directories

---

### 6.2 Module Coupling Analysis

**Category**: Architecture  
**Severity**: MEDIUM

#### High Coupling Areas

| Module | Coupled With | Type |
|--------|--------------|------|
| `agents/` | `infra/`, `config/`, `gateway/` | High |
| `auto-reply/` | `agents/`, `channels/`, `gateway/` | High |
| `gateway/` | Almost everything | Hub |
| `config/` | All modules | Foundation |

#### Circular Dependency Risk

```
agents/ ←→ gateway/
agents/ ←→ auto-reply/
config/ ←→ various modules
```

#### Recommendation

Implement clear dependency direction:
```
config/ → infra/ → core/ → channels/ → gateway/
                  ↓
               agents/
                  ↓
              auto-reply/
```

---

### 6.3 Test File Organization

**Category**: Testing Structure  
**Severity**: LOW

#### Current Pattern

Tests are colocated with source files (e.g., `file.ts` + `file.test.ts`).

**Pros**:
- Easy to find tests
- Good for unit tests
- Matches CLAUDE.md guidelines

**Cons**:
- Long test file names (e.g., `sandbox-agent-config.agent-specific-sandbox-config.includes-session-status-default-sandbox-allowlist.test.ts`)
- Harder to find all tests for a feature
- Integration tests mixed with unit tests

#### Observed Patterns

| Pattern | Example | Count |
|---------|---------|-------|
| Simple colocated | `file.test.ts` | Many |
| Descriptive names | `file.scenario-name.test.ts` | Many |
| E2E tests | `*.e2e.test.ts` | Some |
| Live tests | `*.live.test.ts` | Some |

---

### 6.4 Channel Architecture Inconsistency

**Category**: Architecture  
**Severity**: MEDIUM

#### Current State

Channels are organized inconsistently:

| Channel | Location | Plugin? |
|---------|----------|---------|
| WhatsApp | `src/web/` | Core |
| Telegram | `src/telegram/` | Core |
| Discord | `src/discord/` | Core |
| Slack | `src/slack/` | Core |
| Signal | `src/signal/` | Core |
| iMessage | `src/imessage/` | Core |
| LINE | `src/line/` | Core |
| MS Teams | `extensions/msteams/` | Extension |
| Matrix | `extensions/matrix/` | Extension |
| Zalo | `extensions/zalo/` | Extension |

#### Issues

1. Core channels have inconsistent internal structure
2. Some channel logic in `src/channels/plugins/` (e.g., `onboarding/`, `normalize/`)
3. WhatsApp in `src/web/` (historical naming)

#### Recommendation

Standardize channel structure:
```
src/channels/
├── shared/           # Shared channel utilities
├── whatsapp/         # Renamed from web
├── telegram/
├── discord/
├── slack/
├── signal/
├── imessage/
└── line/

extensions/
├── msteams/
├── matrix/
└── zalo/
```

---

### 6.5 Gateway Complexity

**Category**: Architecture  
**Severity**: MEDIUM

#### Description

The gateway module (`src/gateway/`, 187 files) handles many responsibilities:

1. WebSocket server
2. HTTP endpoints
3. Protocol handling
4. Session management
5. Tool invocation
6. Authentication
7. Configuration management
8. Model management
9. Channel coordination

#### Concern

Single module handling too many concerns increases:
- Cognitive load
- Testing complexity
- Change risk

#### Recommendation

Consider splitting:
```
src/gateway/
├── server/           # WebSocket + HTTP servers
├── protocol/         # Protocol schemas (exists)
├── methods/          # RPC method handlers (exists, continue)
├── auth/             # Authentication
└── coordination/     # Cross-module coordination
```

---

### 6.6 Configuration Complexity

**Category**: Configuration  
**Severity**: MEDIUM

#### Description

Configuration system (130 files) is comprehensive but complex:

1. Multiple schema files (`zod-schema.*.ts`)
2. Legacy migration support
3. Multiple validation layers
4. Test coverage for edge cases

#### Positive Aspects

- Type-safe with Zod
- Good test coverage
- Supports migrations

#### Improvement Areas

1. **Documentation**: Schema documentation could be auto-generated
2. **Defaults**: Default values spread across files
3. **Environment-specific**: Handling of dev/staging/prod

---

### 6.7 Plugin/Extension Boundary

**Category**: Extension Architecture  
**Severity**: LOW

#### Current State

```
extensions/          # External extensions
├── msteams/
├── matrix/
├── voice-call/
└── zalo*/

src/plugins/         # Plugin system core
├── loader.ts
├── schema-validator.ts
└── ...
```

#### Plugin SDK

`src/plugin-sdk/` provides SDK for extensions.

#### Observations

1. Clear separation between core and extensions
2. SDK provides typed interface
3. Extensions can add channels, tools

#### Improvement

Document the plugin architecture more thoroughly.

---

### 6.8 Mobile App Code Organization

**Category**: Multi-platform  
**Severity**: LOW

#### Current Structure

```
apps/
├── android/         # 63 Kotlin files
├── ios/             # 47 Swift files  
├── macos/           # 262 Swift files
└── shared/          # 70 Swift files (MoltbotKit)
```

#### Observations

1. Good separation between platforms
2. Shared code in `shared/MoltbotKit`
3. macOS is largest (menu bar app + features)
4. Protocol generation for Swift types

#### Potential Issues

1. Code duplication between iOS and macOS
2. Protocol sync between Node and native
3. Feature parity across platforms

---

## Structural Debt Summary

| Issue | Severity | Effort to Fix | Impact |
|-------|----------|---------------|--------|
| Large modules | Medium | High | Maintainability |
| Module coupling | Medium | High | Testability |
| Test organization | Low | Medium | Developer experience |
| Channel inconsistency | Medium | Medium | Onboarding |
| Gateway complexity | Medium | High | Change risk |
| Config complexity | Medium | Medium | Developer experience |
| Plugin boundary | Low | Low | Extension development |

---

## Recommendations

### Short-term (Low Effort)
1. Document module boundaries
2. Add architecture diagrams
3. Establish naming conventions

### Medium-term (Medium Effort)
1. Standardize channel structure
2. Split oversized modules
3. Reduce circular dependencies

### Long-term (High Effort)
1. Refactor gateway into sub-modules
2. Implement strict module boundaries
3. Create architecture decision records (ADRs)

---

**Document Maintainer**: Development Team  
**Last Updated**: 2026-01-28
