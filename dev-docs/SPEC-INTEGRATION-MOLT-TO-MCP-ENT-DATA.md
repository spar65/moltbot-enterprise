# SPEC-INTEGRATION: Moltbot to Enterprise MCP Data Services

**Document ID**: SPEC-INTEGRATION-MOLT-TO-MCP-ENT-DATA  
**Version**: 1.0  
**Date Created**: 2026-01-28  
**Status**: Draft  
**Prerequisites**: SPEC-DECISION-MOLTBOT-INTEGRATION-MCP-ENTERPRISE-DATA (Approved)

---

## 1. Overview

### 1.1 Purpose

This specification defines the complete integration between Moltbot and enterprise data services using the MCP (Model Context Protocol) Server architecture. The integration enables Moltbot AI agents to securely query enterprise loan data, perform risk assessments, and access predictive analytics.

### 1.2 Scope

| In Scope | Out of Scope |
|----------|--------------|
| MCP server wrapper for LoanOfficerAI | Database schema changes |
| Moltbot MCP client configuration | UI changes to LoanOfficerAI |
| Security layers (auth, validation, audit) | New MCP functions beyond existing 18 |
| Error handling and recovery | Multi-tenant isolation |
| Health monitoring and logging | Real-time streaming responses |

### 1.3 Key Components

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           INTEGRATION COMPONENTS                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. MCP SERVER (New)              2. MOLTBOT CONFIG (Modify)                │
│  ┌─────────────────────┐          ┌─────────────────────┐                   │
│  │ loan-officer-mcp/   │          │ ~/.clawdbot/        │                   │
│  │ ├── server.js       │          │ └── mcp-servers.json│                   │
│  │ ├── handlers/       │          └─────────────────────┘                   │
│  │ ├── security/       │                                                    │
│  │ └── package.json    │          3. MOLTBOT TOOLS (Auto-discovered)        │
│  └─────────────────────┘          ┌─────────────────────┐                   │
│                                   │ Available as agent  │                   │
│                                   │ tools automatically │                   │
│                                   └─────────────────────┘                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. MCP Server Specification

### 2.1 Directory Structure

```
LoanOfficerAI-MCP-POC/
├── mcp-server/                    # NEW: MCP Server for Moltbot integration
│   ├── package.json               # Dependencies
│   ├── server.js                  # Main entry point (stdio transport)
│   ├── handlers/
│   │   ├── index.js               # Function router
│   │   ├── loans.js               # Loan-related handlers
│   │   ├── borrowers.js           # Borrower-related handlers
│   │   ├── risk.js                # Risk assessment handlers
│   │   └── analytics.js           # Predictive analytics handlers
│   ├── security/
│   │   ├── auth.js                # Request authentication
│   │   ├── validation.js          # Input validation
│   │   ├── audit.js               # Audit logging
│   │   └── rate-limiter.js        # Rate limiting
│   └── utils/
│       ├── logger.js              # Structured logging
│       └── error-handler.js       # Error formatting
├── server/                         # EXISTING: Express API server
│   └── services/
│       └── mcpDatabaseService.js  # Reused for database access
└── ...
```

### 2.2 MCP Protocol Implementation

#### 2.2.1 Transport Layer

The server uses **stdio transport** (JSON-RPC over stdin/stdout):

```javascript
// mcp-server/server.js

const readline = require('readline');
const { handleRequest } = require('./handlers');
const { logAudit } = require('./security/audit');

// Create readline interface for stdio
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

// Handle incoming JSON-RPC requests
rl.on('line', async (line) => {
  try {
    const request = JSON.parse(line);
    const response = await handleRequest(request);
    
    // Write response to stdout
    process.stdout.write(JSON.stringify(response) + '\n');
  } catch (error) {
    const errorResponse = {
      jsonrpc: '2.0',
      id: null,
      error: {
        code: -32700,
        message: 'Parse error',
        data: error.message
      }
    };
    process.stdout.write(JSON.stringify(errorResponse) + '\n');
  }
});

// Handle process signals
process.on('SIGTERM', () => {
  logAudit({ action: 'server_shutdown', reason: 'SIGTERM' });
  process.exit(0);
});

// Log startup
logAudit({ action: 'server_start', pid: process.pid });
```

#### 2.2.2 Message Format

**Request Format (from Moltbot):**

```json
{
  "jsonrpc": "2.0",
  "id": "req-12345",
  "method": "tools/call",
  "params": {
    "name": "get_loan_details",
    "arguments": {
      "loan_id": "L001"
    }
  }
}
```

**Response Format (to Moltbot):**

```json
{
  "jsonrpc": "2.0",
  "id": "req-12345",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"loan_id\":\"L001\",\"borrower_id\":\"B001\",\"amount\":45000,...}"
      }
    ]
  }
}
```

**Error Response Format:**

```json
{
  "jsonrpc": "2.0",
  "id": "req-12345",
  "error": {
    "code": -32602,
    "message": "Invalid params",
    "data": {
      "field": "loan_id",
      "error": "Loan ID 'INVALID' not found"
    }
  }
}
```

### 2.3 Tool Definitions

The MCP server exposes 18 tools to Moltbot:

#### 2.3.1 Loan Information Tools (7)

```javascript
// Tool definitions for MCP discovery

const LOAN_TOOLS = [
  {
    name: 'get_loan_details',
    description: 'Get comprehensive details about a specific loan including terms, amounts, dates, and current status',
    inputSchema: {
      type: 'object',
      properties: {
        loan_id: {
          type: 'string',
          description: 'The loan identifier (e.g., L001, L002)'
        }
      },
      required: ['loan_id']
    }
  },
  {
    name: 'get_loan_status',
    description: 'Get the current status of a loan (Active, Pending, Closed, Delinquent)',
    inputSchema: {
      type: 'object',
      properties: {
        loan_id: {
          type: 'string',
          description: 'The loan identifier'
        }
      },
      required: ['loan_id']
    }
  },
  {
    name: 'get_loan_summary',
    description: 'Get portfolio-wide loan summary including total loans, active count, total amount, and delinquency rate',
    inputSchema: {
      type: 'object',
      properties: {},
      required: []
    }
  },
  {
    name: 'get_active_loans',
    description: 'Get a list of all currently active loans in the portfolio',
    inputSchema: {
      type: 'object',
      properties: {},
      required: []
    }
  },
  {
    name: 'get_loans_by_borrower',
    description: 'Get all loans associated with a specific borrower',
    inputSchema: {
      type: 'object',
      properties: {
        borrower_id: {
          type: 'string',
          description: 'The borrower identifier (e.g., B001)'
        }
      },
      required: ['borrower_id']
    }
  },
  {
    name: 'get_loan_payments',
    description: 'Get payment history for a specific loan including dates, amounts, and on-time status',
    inputSchema: {
      type: 'object',
      properties: {
        loan_id: {
          type: 'string',
          description: 'The loan identifier'
        }
      },
      required: ['loan_id']
    }
  },
  {
    name: 'get_loan_collateral',
    description: 'Get collateral information for a specific loan including type, description, and valuation',
    inputSchema: {
      type: 'object',
      properties: {
        loan_id: {
          type: 'string',
          description: 'The loan identifier'
        }
      },
      required: ['loan_id']
    }
  }
];
```

#### 2.3.2 Risk Assessment Tools (4)

```javascript
const RISK_TOOLS = [
  {
    name: 'get_borrower_details',
    description: 'Get detailed borrower profile including credit score, income, farm size, and farm type',
    inputSchema: {
      type: 'object',
      properties: {
        borrower_id: {
          type: 'string',
          description: 'The borrower identifier'
        }
      },
      required: ['borrower_id']
    }
  },
  {
    name: 'get_borrower_default_risk',
    description: 'Calculate probability of default for a borrower with risk factors and recommendations',
    inputSchema: {
      type: 'object',
      properties: {
        borrower_id: {
          type: 'string',
          description: 'The borrower identifier'
        },
        time_horizon: {
          type: 'string',
          enum: ['short_term', 'medium_term', 'long_term'],
          description: 'Time horizon for risk assessment'
        }
      },
      required: ['borrower_id']
    }
  },
  {
    name: 'get_borrower_non_accrual_risk',
    description: 'Assess risk of loan becoming non-accrual (90+ days past due)',
    inputSchema: {
      type: 'object',
      properties: {
        borrower_id: {
          type: 'string',
          description: 'The borrower identifier'
        }
      },
      required: ['borrower_id']
    }
  },
  {
    name: 'evaluate_collateral_sufficiency',
    description: 'Evaluate whether loan collateral is sufficient under various market conditions',
    inputSchema: {
      type: 'object',
      properties: {
        loan_id: {
          type: 'string',
          description: 'The loan identifier'
        },
        market_conditions: {
          type: 'string',
          enum: ['stable', 'declining', 'stressed'],
          description: 'Market condition scenario for evaluation'
        }
      },
      required: ['loan_id']
    }
  }
];
```

#### 2.3.3 Predictive Analytics Tools (7)

```javascript
const ANALYTICS_TOOLS = [
  {
    name: 'analyze_market_price_impact',
    description: 'Analyze how commodity price changes would affect a borrower\'s loan portfolio',
    inputSchema: {
      type: 'object',
      properties: {
        borrower_id: {
          type: 'string',
          description: 'The borrower identifier'
        },
        commodity: {
          type: 'string',
          description: 'Commodity type (corn, soybeans, wheat, etc.)'
        },
        price_change_percent: {
          type: 'number',
          description: 'Percentage price change to simulate (e.g., -10 for 10% decrease)'
        }
      },
      required: ['borrower_id', 'commodity']
    }
  },
  {
    name: 'forecast_equipment_maintenance',
    description: 'Forecast upcoming equipment maintenance costs for a borrower',
    inputSchema: {
      type: 'object',
      properties: {
        borrower_id: {
          type: 'string',
          description: 'The borrower identifier'
        },
        time_horizon: {
          type: 'string',
          enum: ['6m', '1y', '2y'],
          description: 'Forecast time horizon'
        }
      },
      required: ['borrower_id']
    }
  },
  {
    name: 'assess_crop_yield_risk',
    description: 'Assess agricultural yield risk based on crop type, weather, and historical data',
    inputSchema: {
      type: 'object',
      properties: {
        borrower_id: {
          type: 'string',
          description: 'The borrower identifier'
        },
        crop_type: {
          type: 'string',
          description: 'Type of crop (optional, defaults to all crops)'
        },
        season: {
          type: 'string',
          enum: ['current', 'next', 'historical'],
          description: 'Season to analyze'
        }
      },
      required: ['borrower_id']
    }
  },
  {
    name: 'get_refinancing_options',
    description: 'Generate refinancing options and recommendations for a loan',
    inputSchema: {
      type: 'object',
      properties: {
        loan_id: {
          type: 'string',
          description: 'The loan identifier'
        }
      },
      required: ['loan_id']
    }
  },
  {
    name: 'analyze_payment_patterns',
    description: 'Analyze payment behavior patterns for a borrower over time',
    inputSchema: {
      type: 'object',
      properties: {
        borrower_id: {
          type: 'string',
          description: 'The borrower identifier'
        },
        period: {
          type: 'string',
          enum: ['6m', '1y', '2y', 'all'],
          description: 'Analysis period'
        }
      },
      required: ['borrower_id']
    }
  },
  {
    name: 'recommend_loan_restructuring',
    description: 'Generate AI-powered loan restructuring recommendations',
    inputSchema: {
      type: 'object',
      properties: {
        loan_id: {
          type: 'string',
          description: 'The loan identifier'
        },
        goal: {
          type: 'string',
          enum: ['reduce_payment', 'reduce_term', 'reduce_rate', 'general'],
          description: 'Restructuring goal'
        }
      },
      required: ['loan_id']
    }
  },
  {
    name: 'get_high_risk_farmers',
    description: 'Identify high-risk borrowers across the portfolio based on multiple risk factors',
    inputSchema: {
      type: 'object',
      properties: {
        risk_threshold: {
          type: 'string',
          enum: ['high', 'medium', 'all'],
          description: 'Minimum risk level to include'
        }
      },
      required: []
    }
  }
];
```

---

## 3. Security Specification

### 3.1 Security Layers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SECURITY LAYERS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  REQUEST FLOW:                                                              │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │             │    │             │    │             │    │             │  │
│  │  Layer 1    │───►│  Layer 2    │───►│  Layer 3    │───►│  Layer 4    │  │
│  │  Auth       │    │  Validate   │    │  Rate Limit │    │  Audit      │  │
│  │             │    │             │    │             │    │             │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│        │                  │                  │                  │          │
│        ▼                  ▼                  ▼                  ▼          │
│  Verify caller      Validate input     Check limits       Log request     │
│  identity           schema             per function       for audit       │
│                                                                             │
│                                      ┌─────────────┐                       │
│                                      │             │                       │
│                                 ────►│  Layer 5    │                       │
│                                      │  Execute    │                       │
│                                      │             │                       │
│                                      └──────┬──────┘                       │
│                                             │                              │
│                                             ▼                              │
│                                      Database Query                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Authentication (Layer 1)

```javascript
// mcp-server/security/auth.js

const AUTH_CONFIG = {
  // Authentication is optional but recommended for production
  enabled: process.env.MCP_AUTH_ENABLED === 'true',
  
  // Pre-shared key (set in both Moltbot and MCP server)
  sharedKey: process.env.MCP_SHARED_KEY,
  
  // Maximum clock skew for timestamp validation (5 minutes)
  maxClockSkew: 300000,
};

/**
 * Validate request authentication
 * @param {Object} request - The MCP request
 * @returns {Object} - { valid: boolean, error?: string }
 */
function validateAuth(request) {
  if (!AUTH_CONFIG.enabled) {
    return { valid: true };
  }
  
  const auth = request.params?.auth;
  
  if (!auth) {
    return { valid: false, error: 'Missing auth block' };
  }
  
  // Validate timestamp (prevent replay attacks)
  const now = Date.now();
  if (Math.abs(now - auth.timestamp) > AUTH_CONFIG.maxClockSkew) {
    return { valid: false, error: 'Request timestamp too old' };
  }
  
  // Validate signature
  const expectedSignature = generateSignature(
    request.method,
    request.params?.name,
    auth.timestamp,
    auth.nonce
  );
  
  if (auth.signature !== expectedSignature) {
    return { valid: false, error: 'Invalid signature' };
  }
  
  return { valid: true };
}

function generateSignature(method, toolName, timestamp, nonce) {
  const crypto = require('crypto');
  const payload = `${method}:${toolName}:${timestamp}:${nonce}`;
  return crypto
    .createHmac('sha256', AUTH_CONFIG.sharedKey)
    .update(payload)
    .digest('hex');
}

module.exports = { validateAuth, generateSignature };
```

### 3.3 Input Validation (Layer 2)

```javascript
// mcp-server/security/validation.js

const Joi = require('joi');

// Schema definitions for each tool
const SCHEMAS = {
  get_loan_details: Joi.object({
    loan_id: Joi.string()
      .pattern(/^L\d{3,}$/)
      .required()
      .messages({
        'string.pattern.base': 'Loan ID must be in format L001, L002, etc.'
      })
  }),
  
  get_borrower_default_risk: Joi.object({
    borrower_id: Joi.string()
      .pattern(/^B\d{3,}$/)
      .required(),
    time_horizon: Joi.string()
      .valid('short_term', 'medium_term', 'long_term')
      .default('medium_term')
  }),
  
  analyze_market_price_impact: Joi.object({
    borrower_id: Joi.string()
      .pattern(/^B\d{3,}$/)
      .required(),
    commodity: Joi.string()
      .valid('corn', 'soybeans', 'wheat', 'cotton', 'rice')
      .required(),
    price_change_percent: Joi.number()
      .min(-50)
      .max(50)
      .default(-10)
  }),
  
  // ... schemas for all 18 tools
};

/**
 * Validate tool arguments against schema
 */
function validateInput(toolName, args) {
  const schema = SCHEMAS[toolName];
  
  if (!schema) {
    return { valid: false, error: `Unknown tool: ${toolName}` };
  }
  
  const { error, value } = schema.validate(args, { abortEarly: false });
  
  if (error) {
    return {
      valid: false,
      error: error.details.map(d => d.message).join('; ')
    };
  }
  
  return { valid: true, sanitized: value };
}

module.exports = { validateInput };
```

### 3.4 Rate Limiting (Layer 3)

```javascript
// mcp-server/security/rate-limiter.js

const RATE_LIMITS = {
  // Default: 100 requests per minute
  default: { windowMs: 60000, max: 100 },
  
  // Heavy queries: 20 per minute
  get_high_risk_farmers: { windowMs: 60000, max: 20 },
  analyze_market_price_impact: { windowMs: 60000, max: 20 },
  
  // Analytics: 30 per minute
  forecast_equipment_maintenance: { windowMs: 60000, max: 30 },
  assess_crop_yield_risk: { windowMs: 60000, max: 30 },
};

const requestCounts = new Map();

function checkRateLimit(toolName) {
  const now = Date.now();
  const limits = RATE_LIMITS[toolName] || RATE_LIMITS.default;
  const key = toolName;
  
  let entry = requestCounts.get(key);
  
  if (!entry || entry.resetTime < now) {
    entry = { count: 0, resetTime: now + limits.windowMs };
    requestCounts.set(key, entry);
  }
  
  entry.count++;
  
  if (entry.count > limits.max) {
    return {
      allowed: false,
      retryAfter: Math.ceil((entry.resetTime - now) / 1000)
    };
  }
  
  return { allowed: true, remaining: limits.max - entry.count };
}

module.exports = { checkRateLimit };
```

### 3.5 Audit Logging (Layer 4)

```javascript
// mcp-server/security/audit.js

const fs = require('fs');
const path = require('path');

const AUDIT_CONFIG = {
  logPath: process.env.MCP_AUDIT_LOG || './logs/mcp-audit.jsonl',
  redactFields: ['password', 'ssn', 'account_number'],
};

/**
 * Log an audit event
 */
function logAudit(event) {
  const entry = {
    timestamp: new Date().toISOString(),
    ...redactSensitive(event),
    pid: process.pid,
  };
  
  const line = JSON.stringify(entry) + '\n';
  
  // Ensure log directory exists
  const dir = path.dirname(AUDIT_CONFIG.logPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  
  // Append to audit log
  fs.appendFileSync(AUDIT_CONFIG.logPath, line);
  
  // Also log to stderr for process monitoring
  console.error(`[AUDIT] ${entry.timestamp} ${entry.action || 'event'}`);
}

function redactSensitive(obj) {
  if (typeof obj !== 'object' || obj === null) {
    return obj;
  }
  
  const result = Array.isArray(obj) ? [] : {};
  
  for (const [key, value] of Object.entries(obj)) {
    if (AUDIT_CONFIG.redactFields.includes(key.toLowerCase())) {
      result[key] = '[REDACTED]';
    } else if (typeof value === 'object') {
      result[key] = redactSensitive(value);
    } else {
      result[key] = value;
    }
  }
  
  return result;
}

module.exports = { logAudit, redactSensitive };
```

---

## 4. Moltbot Configuration

### 4.1 MCP Server Registration

```json
// ~/.clawdbot/mcp-servers.json

{
  "servers": {
    "loan-officer": {
      "command": "node",
      "args": [
        "/path/to/LoanOfficerAI-MCP-POC/mcp-server/server.js"
      ],
      "env": {
        "DB_SERVER": "localhost",
        "DB_NAME": "LoanOfficerDB",
        "DB_USER": "sa",
        "DB_PASSWORD": "${LOAN_OFFICER_DB_PASSWORD}",
        "USE_DATABASE": "true",
        "MCP_AUTH_ENABLED": "true",
        "MCP_SHARED_KEY": "${MCP_SHARED_KEY}",
        "MCP_AUDIT_LOG": "/var/log/moltbot/mcp-audit.jsonl",
        "NODE_ENV": "production"
      },
      "autoStart": true,
      "healthCheck": {
        "enabled": true,
        "intervalMs": 30000,
        "timeoutMs": 5000
      }
    }
  }
}
```

### 4.2 Environment Variables

```bash
# ~/.clawdbot/.env or environment

# Database credentials (kept in MCP server process only)
LOAN_OFFICER_DB_PASSWORD=YourStrong@Passw0rd

# MCP authentication (shared between Moltbot and MCP server)
MCP_SHARED_KEY=your-secure-random-key-here-at-least-32-chars
```

### 4.3 Tool Discovery

When Moltbot starts with the MCP server configured, it will:

1. Spawn the MCP server process
2. Send `initialize` request
3. Send `tools/list` request to discover available tools
4. Register tools with the agent runtime

The 18 loan officer tools will then be available to all Moltbot agents.

---

## 5. Error Handling

### 5.1 Error Codes

| Code | Name | Description |
|------|------|-------------|
| -32700 | Parse error | Invalid JSON received |
| -32600 | Invalid request | Request not valid JSON-RPC |
| -32601 | Method not found | Unknown MCP method |
| -32602 | Invalid params | Invalid tool arguments |
| -32603 | Internal error | Server-side error |
| -32001 | Auth failed | Authentication failure |
| -32002 | Rate limited | Too many requests |
| -32003 | Not found | Resource not found (loan, borrower) |
| -32004 | Database error | Database connection or query failure |

### 5.2 Error Response Examples

```json
// Not found error
{
  "jsonrpc": "2.0",
  "id": "req-123",
  "error": {
    "code": -32003,
    "message": "Loan not found",
    "data": {
      "loan_id": "L999",
      "suggestion": "Verify the loan ID exists in the system"
    }
  }
}

// Validation error
{
  "jsonrpc": "2.0",
  "id": "req-124",
  "error": {
    "code": -32602,
    "message": "Invalid params",
    "data": {
      "field": "borrower_id",
      "error": "Borrower ID must be in format B001, B002, etc.",
      "received": "invalid-id"
    }
  }
}

// Rate limit error
{
  "jsonrpc": "2.0",
  "id": "req-125",
  "error": {
    "code": -32002,
    "message": "Rate limit exceeded",
    "data": {
      "retryAfter": 45,
      "limit": 20,
      "window": "60 seconds"
    }
  }
}
```

---

## 6. Health Monitoring

### 6.1 Health Check Protocol

Moltbot periodically sends health check requests:

```json
// Request
{
  "jsonrpc": "2.0",
  "id": "health-1",
  "method": "health/check",
  "params": {}
}

// Response
{
  "jsonrpc": "2.0",
  "id": "health-1",
  "result": {
    "status": "healthy",
    "uptime": 3600,
    "database": {
      "connected": true,
      "latency": 5
    },
    "memory": {
      "used": 52428800,
      "total": 134217728
    },
    "requestCount": 1250,
    "errorRate": 0.02
  }
}
```

### 6.2 Recovery Procedures

| Scenario | Detection | Recovery |
|----------|-----------|----------|
| MCP server crash | Health check timeout | Auto-restart with backoff |
| Database disconnection | Error code -32004 | Retry with exponential backoff |
| Rate limit exhaustion | Error code -32002 | Respect retryAfter, queue requests |
| Memory exhaustion | Health check memory > 90% | Restart server |

---

## 7. Testing Requirements

### 7.1 Unit Tests

```javascript
// mcp-server/tests/handlers.test.js

describe('MCP Handlers', () => {
  describe('get_loan_details', () => {
    it('returns loan details for valid ID', async () => {
      const result = await handlers.get_loan_details({ loan_id: 'L001' });
      expect(result).toHaveProperty('loan_id', 'L001');
      expect(result).toHaveProperty('borrower_id');
      expect(result).toHaveProperty('amount');
    });
    
    it('throws not found for invalid ID', async () => {
      await expect(handlers.get_loan_details({ loan_id: 'L999' }))
        .rejects.toThrow(/not found/i);
    });
  });
  
  // ... tests for all 18 handlers
});
```

### 7.2 Integration Tests

```javascript
// mcp-server/tests/integration.test.js

describe('MCP Server Integration', () => {
  let server;
  
  beforeAll(async () => {
    server = await spawnMcpServer();
  });
  
  afterAll(async () => {
    await server.close();
  });
  
  it('responds to tools/list', async () => {
    const response = await server.send({
      jsonrpc: '2.0',
      id: '1',
      method: 'tools/list',
      params: {}
    });
    
    expect(response.result.tools).toHaveLength(18);
  });
  
  it('executes tool call correctly', async () => {
    const response = await server.send({
      jsonrpc: '2.0',
      id: '2',
      method: 'tools/call',
      params: {
        name: 'get_loan_summary',
        arguments: {}
      }
    });
    
    expect(response.result.content[0].type).toBe('text');
    const data = JSON.parse(response.result.content[0].text);
    expect(data).toHaveProperty('totalLoans');
  });
});
```

### 7.3 Security Tests

```javascript
// mcp-server/tests/security.test.js

describe('Security', () => {
  describe('Authentication', () => {
    it('rejects requests without auth when enabled', async () => {
      // Enable auth
      process.env.MCP_AUTH_ENABLED = 'true';
      
      const response = await sendRequest({ /* no auth */ });
      expect(response.error.code).toBe(-32001);
    });
    
    it('rejects expired timestamps', async () => {
      const response = await sendRequest({
        auth: { timestamp: Date.now() - 600000 } // 10 mins old
      });
      expect(response.error.code).toBe(-32001);
    });
  });
  
  describe('Rate Limiting', () => {
    it('enforces rate limits', async () => {
      // Send 21 requests (limit is 20)
      for (let i = 0; i < 21; i++) {
        await sendRequest({ method: 'tools/call', params: { name: 'get_high_risk_farmers' } });
      }
      
      const response = await sendRequest({ method: 'tools/call', params: { name: 'get_high_risk_farmers' } });
      expect(response.error.code).toBe(-32002);
    });
  });
});
```

---

## 8. Deployment Checklist

### 8.1 Pre-Deployment

- [ ] Database configured and accessible
- [ ] Environment variables set
- [ ] MCP shared key generated and configured
- [ ] Audit log directory exists with proper permissions
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Security tests passing

### 8.2 Deployment

- [ ] MCP server installed (`npm install` in mcp-server/)
- [ ] Moltbot MCP configuration added
- [ ] Health check verified
- [ ] Tool discovery verified (18 tools)
- [ ] Sample queries tested

### 8.3 Post-Deployment

- [ ] Audit log collecting entries
- [ ] Health monitoring active
- [ ] Error rates within acceptable limits
- [ ] Performance metrics established

---

## 9. Appendix

### 9.1 Complete Tool List

| # | Tool Name | Category | Description |
|---|-----------|----------|-------------|
| 1 | get_loan_details | Loan Info | Get comprehensive loan details |
| 2 | get_loan_status | Loan Info | Get current loan status |
| 3 | get_loan_summary | Loan Info | Get portfolio summary |
| 4 | get_active_loans | Loan Info | List all active loans |
| 5 | get_loans_by_borrower | Loan Info | Get borrower's loans |
| 6 | get_loan_payments | Loan Info | Get payment history |
| 7 | get_loan_collateral | Loan Info | Get collateral details |
| 8 | get_borrower_details | Risk | Get borrower profile |
| 9 | get_borrower_default_risk | Risk | Calculate default risk |
| 10 | get_borrower_non_accrual_risk | Risk | Calculate non-accrual risk |
| 11 | evaluate_collateral_sufficiency | Risk | Evaluate collateral |
| 12 | analyze_market_price_impact | Analytics | Analyze commodity impact |
| 13 | forecast_equipment_maintenance | Analytics | Forecast maintenance |
| 14 | assess_crop_yield_risk | Analytics | Assess yield risk |
| 15 | get_refinancing_options | Analytics | Get refinancing options |
| 16 | analyze_payment_patterns | Analytics | Analyze payment patterns |
| 17 | recommend_loan_restructuring | Analytics | AI restructuring recommendations |
| 18 | get_high_risk_farmers | Analytics | Identify high-risk borrowers |

---

**Document Status**: Draft  
**Next Step**: GUIDE-MOLTBOT-MCP-ENTERPRISE-INTEGRATION.md
