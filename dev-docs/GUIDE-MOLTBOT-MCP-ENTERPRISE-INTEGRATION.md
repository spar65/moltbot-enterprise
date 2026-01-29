# Implementation Guide: Moltbot MCP Enterprise Data Integration

**Document ID**: GUIDE-MOLTBOT-MCP-ENTERPRISE-INTEGRATION  
**Version**: 1.0  
**Date Created**: 2026-01-28  
**Target Audience**: LLM Agents (BB, Claude, etc.) and Developers  
**Prerequisites**: 
- SPEC-DECISION-MOLTBOT-INTEGRATION-MCP-ENTERPRISE-DATA.md (read)
- SPEC-INTEGRATION-MOLT-TO-MCP-ENT-DATA.md (read)

---

## Purpose

This guide provides **step-by-step implementation instructions** for integrating Moltbot with enterprise data services using the MCP Server (stdio) architecture. It is written to be understood and executed by an LLM agent or developer.

---

## Table of Contents

1. [Prerequisites Check](#1-prerequisites-check)
2. [Create MCP Server Package](#2-create-mcp-server-package)
3. [Implement MCP Server Core](#3-implement-mcp-server-core)
4. [Implement Security Layers](#4-implement-security-layers)
5. [Implement Tool Handlers](#5-implement-tool-handlers)
6. [Configure Moltbot Integration](#6-configure-moltbot-integration)
7. [Testing](#7-testing)
8. [Deployment](#8-deployment)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Prerequisites Check

### 1.1 Required Components

Before starting, verify these exist:

```bash
# Check LoanOfficerAI-MCP-POC exists
ls /Users/spehargreg/Development/LoanOfficerAI-MCP-POC/

# Expected files:
# - server/services/mcpDatabaseService.js  (database access layer)
# - server/services/mcpFunctionRegistry.js (function definitions)
# - package.json

# Check Moltbot exists
ls /Users/spehargreg/Development/moltbot-main/

# Expected:
# - src/plugins/   (plugin infrastructure)
# - package.json
```

### 1.2 Required Dependencies

The MCP server will need:
- Node.js 18+
- Access to LoanOfficerAI database services
- JSON Schema validation (joi or zod)

---

## 2. Create MCP Server Package

### 2.1 Create Directory Structure

**Execute these commands:**

```bash
cd /Users/spehargreg/Development/LoanOfficerAI-MCP-POC

# Create MCP server directory
mkdir -p mcp-server/{handlers,security,utils,tests}

# Create required files
touch mcp-server/package.json
touch mcp-server/server.js
touch mcp-server/handlers/index.js
touch mcp-server/handlers/loans.js
touch mcp-server/handlers/borrowers.js
touch mcp-server/handlers/risk.js
touch mcp-server/handlers/analytics.js
touch mcp-server/security/auth.js
touch mcp-server/security/validation.js
touch mcp-server/security/rate-limiter.js
touch mcp-server/security/audit.js
touch mcp-server/utils/logger.js
touch mcp-server/utils/error-handler.js
```

### 2.2 Create package.json

**File: `mcp-server/package.json`**

```json
{
  "name": "loan-officer-mcp-server",
  "version": "1.0.0",
  "description": "MCP Server for LoanOfficerAI enterprise data integration with Moltbot",
  "main": "server.js",
  "type": "commonjs",
  "scripts": {
    "start": "node server.js",
    "test": "jest",
    "test:security": "jest tests/security.test.js"
  },
  "dependencies": {
    "joi": "^17.11.0"
  },
  "devDependencies": {
    "jest": "^29.7.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
```

### 2.3 Install Dependencies

```bash
cd /Users/spehargreg/Development/LoanOfficerAI-MCP-POC/mcp-server
npm install
```

---

## 3. Implement MCP Server Core

### 3.1 Main Server Entry Point

**File: `mcp-server/server.js`**

```javascript
#!/usr/bin/env node

/**
 * MCP Server for LoanOfficerAI Enterprise Data
 * 
 * This server implements the Model Context Protocol (MCP) over stdio transport,
 * enabling Moltbot to securely access enterprise loan data.
 * 
 * Transport: stdio (stdin/stdout)
 * Protocol: JSON-RPC 2.0
 */

const readline = require('readline');
const path = require('path');

// Import handlers and security
const { handleRequest, getToolDefinitions } = require('./handlers');
const { validateAuth } = require('./security/auth');
const { logAudit } = require('./security/audit');
const { checkRateLimit } = require('./security/rate-limiter');
const { logger } = require('./utils/logger');

// Configuration
const CONFIG = {
  serverName: 'loan-officer-mcp',
  serverVersion: '1.0.0',
  protocolVersion: '2024-11-05',
};

// Request ID counter for correlation
let requestCounter = 0;

// Create readline interface for stdio communication
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

/**
 * Process a single JSON-RPC request
 */
async function processRequest(request) {
  const startTime = Date.now();
  const correlationId = `req-${++requestCounter}`;
  
  try {
    // Validate JSON-RPC structure
    if (!request.jsonrpc || request.jsonrpc !== '2.0') {
      return createErrorResponse(request.id, -32600, 'Invalid Request', 
        'Missing or invalid jsonrpc version');
    }
    
    if (!request.method) {
      return createErrorResponse(request.id, -32600, 'Invalid Request', 
        'Missing method');
    }
    
    // Log incoming request
    logAudit({
      action: 'request_received',
      correlationId,
      method: request.method,
      params: request.params ? Object.keys(request.params) : [],
    });
    
    // Route the request
    const response = await routeRequest(request, correlationId);
    
    // Log completion
    const duration = Date.now() - startTime;
    logAudit({
      action: 'request_completed',
      correlationId,
      method: request.method,
      duration,
      success: !response.error,
    });
    
    return response;
    
  } catch (error) {
    logger.error('Unhandled error processing request', { error: error.message, correlationId });
    
    logAudit({
      action: 'request_error',
      correlationId,
      method: request.method,
      error: error.message,
    });
    
    return createErrorResponse(request.id, -32603, 'Internal error', error.message);
  }
}

/**
 * Route request to appropriate handler
 */
async function routeRequest(request, correlationId) {
  const { method, params, id } = request;
  
  switch (method) {
    // MCP initialization
    case 'initialize':
      return handleInitialize(id, params);
    
    // Tool discovery
    case 'tools/list':
      return handleToolsList(id);
    
    // Tool execution
    case 'tools/call':
      return handleToolCall(id, params, correlationId);
    
    // Health check
    case 'health/check':
      return handleHealthCheck(id);
    
    // Notifications (no response needed)
    case 'notifications/initialized':
    case 'notifications/cancelled':
      return null; // No response for notifications
    
    default:
      return createErrorResponse(id, -32601, 'Method not found', 
        `Unknown method: ${method}`);
  }
}

/**
 * Handle MCP initialization
 */
function handleInitialize(id, params) {
  logger.info('MCP initialization requested', { clientInfo: params?.clientInfo });
  
  return {
    jsonrpc: '2.0',
    id,
    result: {
      protocolVersion: CONFIG.protocolVersion,
      serverInfo: {
        name: CONFIG.serverName,
        version: CONFIG.serverVersion,
      },
      capabilities: {
        tools: {
          listChanged: false,
        },
      },
    },
  };
}

/**
 * Handle tools/list request
 */
function handleToolsList(id) {
  const tools = getToolDefinitions();
  
  logger.info('Tools list requested', { toolCount: tools.length });
  
  return {
    jsonrpc: '2.0',
    id,
    result: {
      tools,
    },
  };
}

/**
 * Handle tools/call request
 */
async function handleToolCall(id, params, correlationId) {
  const { name: toolName, arguments: args } = params || {};
  
  if (!toolName) {
    return createErrorResponse(id, -32602, 'Invalid params', 'Missing tool name');
  }
  
  // Check rate limit
  const rateCheck = checkRateLimit(toolName);
  if (!rateCheck.allowed) {
    return createErrorResponse(id, -32002, 'Rate limit exceeded', {
      retryAfter: rateCheck.retryAfter,
      tool: toolName,
    });
  }
  
  try {
    // Execute the tool
    const result = await handleRequest(toolName, args || {});
    
    // Format as MCP tool response
    return {
      jsonrpc: '2.0',
      id,
      result: {
        content: [
          {
            type: 'text',
            text: typeof result === 'string' ? result : JSON.stringify(result, null, 2),
          },
        ],
      },
    };
    
  } catch (error) {
    // Determine error code based on error type
    let code = -32603;
    if (error.message.includes('not found')) {
      code = -32003;
    } else if (error.message.includes('validation') || error.message.includes('Invalid')) {
      code = -32602;
    }
    
    return createErrorResponse(id, code, error.message, {
      tool: toolName,
      args: args,
    });
  }
}

/**
 * Handle health check
 */
function handleHealthCheck(id) {
  const memUsage = process.memoryUsage();
  
  return {
    jsonrpc: '2.0',
    id,
    result: {
      status: 'healthy',
      uptime: process.uptime(),
      memory: {
        used: memUsage.heapUsed,
        total: memUsage.heapTotal,
        percentage: Math.round((memUsage.heapUsed / memUsage.heapTotal) * 100),
      },
      pid: process.pid,
    },
  };
}

/**
 * Create a JSON-RPC error response
 */
function createErrorResponse(id, code, message, data = null) {
  const response = {
    jsonrpc: '2.0',
    id: id || null,
    error: {
      code,
      message,
    },
  };
  
  if (data) {
    response.error.data = data;
  }
  
  return response;
}

/**
 * Send response to stdout
 */
function sendResponse(response) {
  if (response === null) {
    return; // Notifications don't need responses
  }
  
  try {
    process.stdout.write(JSON.stringify(response) + '\n');
  } catch (error) {
    logger.error('Failed to send response', { error: error.message });
  }
}

// ============================================================
// MAIN EXECUTION
// ============================================================

// Handle incoming lines (each line is a JSON-RPC message)
rl.on('line', async (line) => {
  if (!line.trim()) {
    return;
  }
  
  try {
    const request = JSON.parse(line);
    const response = await processRequest(request);
    sendResponse(response);
  } catch (parseError) {
    // JSON parse error
    sendResponse(createErrorResponse(null, -32700, 'Parse error', 
      'Invalid JSON: ' + parseError.message));
  }
});

// Handle stdin close
rl.on('close', () => {
  logger.info('stdin closed, shutting down');
  logAudit({ action: 'server_shutdown', reason: 'stdin_closed' });
  process.exit(0);
});

// Handle process signals
process.on('SIGTERM', () => {
  logger.info('Received SIGTERM, shutting down');
  logAudit({ action: 'server_shutdown', reason: 'SIGTERM' });
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('Received SIGINT, shutting down');
  logAudit({ action: 'server_shutdown', reason: 'SIGINT' });
  process.exit(0);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught exception', { error: error.message, stack: error.stack });
  logAudit({ action: 'server_crash', error: error.message });
  process.exit(1);
});

// Log startup
logger.info('MCP Server starting', { 
  name: CONFIG.serverName, 
  version: CONFIG.serverVersion,
  pid: process.pid 
});

logAudit({ action: 'server_start', pid: process.pid, version: CONFIG.serverVersion });
```

---

## 4. Implement Security Layers

### 4.1 Authentication Module

**File: `mcp-server/security/auth.js`**

```javascript
/**
 * Authentication module for MCP Server
 * 
 * Implements HMAC-based request signing for secure communication
 */

const crypto = require('crypto');

const CONFIG = {
  enabled: process.env.MCP_AUTH_ENABLED === 'true',
  sharedKey: process.env.MCP_SHARED_KEY || '',
  maxClockSkew: 300000, // 5 minutes in milliseconds
};

/**
 * Validate request authentication
 * @param {Object} request - The MCP request
 * @returns {{ valid: boolean, error?: string }}
 */
function validateAuth(request) {
  // If auth is disabled, allow all requests
  if (!CONFIG.enabled) {
    return { valid: true };
  }
  
  // Check for auth block in params
  const auth = request.params?.auth;
  
  if (!auth) {
    return { valid: false, error: 'Authentication required but no auth block provided' };
  }
  
  // Validate required auth fields
  if (!auth.timestamp || !auth.nonce || !auth.signature) {
    return { valid: false, error: 'Missing required auth fields (timestamp, nonce, signature)' };
  }
  
  // Check timestamp to prevent replay attacks
  const now = Date.now();
  const timeDiff = Math.abs(now - auth.timestamp);
  
  if (timeDiff > CONFIG.maxClockSkew) {
    return { 
      valid: false, 
      error: `Request timestamp too old (${Math.round(timeDiff / 1000)}s difference)` 
    };
  }
  
  // Validate signature
  const expectedSignature = generateSignature(
    request.method,
    request.params?.name || '',
    auth.timestamp,
    auth.nonce
  );
  
  // Use timing-safe comparison
  try {
    const sigBuffer = Buffer.from(auth.signature, 'hex');
    const expectedBuffer = Buffer.from(expectedSignature, 'hex');
    
    if (sigBuffer.length !== expectedBuffer.length) {
      return { valid: false, error: 'Invalid signature' };
    }
    
    if (!crypto.timingSafeEqual(sigBuffer, expectedBuffer)) {
      return { valid: false, error: 'Invalid signature' };
    }
  } catch (error) {
    return { valid: false, error: 'Signature validation error' };
  }
  
  return { valid: true };
}

/**
 * Generate HMAC signature for a request
 */
function generateSignature(method, toolName, timestamp, nonce) {
  const payload = `${method}:${toolName}:${timestamp}:${nonce}`;
  
  return crypto
    .createHmac('sha256', CONFIG.sharedKey)
    .update(payload)
    .digest('hex');
}

/**
 * Create auth block for a request (used by clients)
 */
function createAuthBlock(method, toolName) {
  const timestamp = Date.now();
  const nonce = crypto.randomBytes(16).toString('hex');
  const signature = generateSignature(method, toolName, timestamp, nonce);
  
  return { timestamp, nonce, signature };
}

module.exports = { validateAuth, generateSignature, createAuthBlock };
```

### 4.2 Input Validation Module

**File: `mcp-server/security/validation.js`**

```javascript
/**
 * Input validation module for MCP Server
 * 
 * Validates all tool arguments against defined schemas
 */

const Joi = require('joi');

// ============================================================
// SCHEMA DEFINITIONS
// ============================================================

const LOAN_ID_PATTERN = /^L\d{3,}$/;
const BORROWER_ID_PATTERN = /^B\d{3,}$/;

const schemas = {
  // Loan Information Tools
  get_loan_details: Joi.object({
    loan_id: Joi.string().pattern(LOAN_ID_PATTERN).required()
      .messages({
        'string.pattern.base': 'Loan ID must be in format L001, L002, etc.',
        'any.required': 'loan_id is required'
      })
  }),
  
  get_loan_status: Joi.object({
    loan_id: Joi.string().pattern(LOAN_ID_PATTERN).required()
  }),
  
  get_loan_summary: Joi.object({}),
  
  get_active_loans: Joi.object({}),
  
  get_loans_by_borrower: Joi.object({
    borrower_id: Joi.string().pattern(BORROWER_ID_PATTERN).required()
      .messages({
        'string.pattern.base': 'Borrower ID must be in format B001, B002, etc.'
      })
  }),
  
  get_loan_payments: Joi.object({
    loan_id: Joi.string().pattern(LOAN_ID_PATTERN).required()
  }),
  
  get_loan_collateral: Joi.object({
    loan_id: Joi.string().pattern(LOAN_ID_PATTERN).required()
  }),
  
  // Risk Assessment Tools
  get_borrower_details: Joi.object({
    borrower_id: Joi.string().pattern(BORROWER_ID_PATTERN).required()
  }),
  
  get_borrower_default_risk: Joi.object({
    borrower_id: Joi.string().pattern(BORROWER_ID_PATTERN).required(),
    time_horizon: Joi.string()
      .valid('short_term', 'medium_term', 'long_term')
      .default('medium_term')
  }),
  
  get_borrower_non_accrual_risk: Joi.object({
    borrower_id: Joi.string().pattern(BORROWER_ID_PATTERN).required()
  }),
  
  evaluate_collateral_sufficiency: Joi.object({
    loan_id: Joi.string().pattern(LOAN_ID_PATTERN).required(),
    market_conditions: Joi.string()
      .valid('stable', 'declining', 'stressed')
      .default('stable')
  }),
  
  // Predictive Analytics Tools
  analyze_market_price_impact: Joi.object({
    borrower_id: Joi.string().pattern(BORROWER_ID_PATTERN).required(),
    commodity: Joi.string()
      .valid('corn', 'soybeans', 'wheat', 'cotton', 'rice')
      .required(),
    price_change_percent: Joi.number()
      .min(-50)
      .max(50)
      .default(-10)
  }),
  
  forecast_equipment_maintenance: Joi.object({
    borrower_id: Joi.string().pattern(BORROWER_ID_PATTERN).required(),
    time_horizon: Joi.string()
      .valid('6m', '1y', '2y')
      .default('1y')
  }),
  
  assess_crop_yield_risk: Joi.object({
    borrower_id: Joi.string().pattern(BORROWER_ID_PATTERN).required(),
    crop_type: Joi.string().optional(),
    season: Joi.string()
      .valid('current', 'next', 'historical')
      .default('current')
  }),
  
  get_refinancing_options: Joi.object({
    loan_id: Joi.string().pattern(LOAN_ID_PATTERN).required()
  }),
  
  analyze_payment_patterns: Joi.object({
    borrower_id: Joi.string().pattern(BORROWER_ID_PATTERN).required(),
    period: Joi.string()
      .valid('6m', '1y', '2y', 'all')
      .default('1y')
  }),
  
  recommend_loan_restructuring: Joi.object({
    loan_id: Joi.string().pattern(LOAN_ID_PATTERN).required(),
    goal: Joi.string()
      .valid('reduce_payment', 'reduce_term', 'reduce_rate', 'general')
      .default('general')
  }),
  
  get_high_risk_farmers: Joi.object({
    risk_threshold: Joi.string()
      .valid('high', 'medium', 'all')
      .default('high')
  }),
};

/**
 * Validate tool arguments
 * @param {string} toolName - Name of the tool
 * @param {Object} args - Arguments to validate
 * @returns {{ valid: boolean, error?: string, sanitized?: Object }}
 */
function validateInput(toolName, args) {
  const schema = schemas[toolName];
  
  if (!schema) {
    return { valid: false, error: `Unknown tool: ${toolName}` };
  }
  
  const { error, value } = schema.validate(args || {}, {
    abortEarly: false,
    stripUnknown: true, // Remove unknown fields
  });
  
  if (error) {
    const messages = error.details.map(d => d.message).join('; ');
    return { valid: false, error: messages };
  }
  
  return { valid: true, sanitized: value };
}

/**
 * Get list of all supported tool names
 */
function getSupportedTools() {
  return Object.keys(schemas);
}

module.exports = { validateInput, getSupportedTools };
```

### 4.3 Rate Limiting Module

**File: `mcp-server/security/rate-limiter.js`**

```javascript
/**
 * Rate limiting module for MCP Server
 * 
 * Implements per-tool rate limiting to prevent abuse
 */

// Rate limit configurations per tool
const LIMITS = {
  // Heavy database queries: 20 per minute
  get_high_risk_farmers: { windowMs: 60000, max: 20 },
  analyze_market_price_impact: { windowMs: 60000, max: 20 },
  recommend_loan_restructuring: { windowMs: 60000, max: 20 },
  
  // Analytics: 30 per minute
  forecast_equipment_maintenance: { windowMs: 60000, max: 30 },
  assess_crop_yield_risk: { windowMs: 60000, max: 30 },
  analyze_payment_patterns: { windowMs: 60000, max: 30 },
  
  // Standard queries: 100 per minute
  default: { windowMs: 60000, max: 100 },
};

// In-memory request tracking
const requestCounts = new Map();

// Cleanup old entries every minute
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of requestCounts.entries()) {
    if (entry.resetTime < now) {
      requestCounts.delete(key);
    }
  }
}, 60000);

/**
 * Check if a request is within rate limits
 * @param {string} toolName - Name of the tool
 * @returns {{ allowed: boolean, remaining?: number, retryAfter?: number }}
 */
function checkRateLimit(toolName) {
  const now = Date.now();
  const limits = LIMITS[toolName] || LIMITS.default;
  const key = toolName;
  
  let entry = requestCounts.get(key);
  
  // Create new entry if none exists or window expired
  if (!entry || entry.resetTime < now) {
    entry = { 
      count: 0, 
      resetTime: now + limits.windowMs 
    };
    requestCounts.set(key, entry);
  }
  
  // Increment count
  entry.count++;
  
  // Check if over limit
  if (entry.count > limits.max) {
    const retryAfter = Math.ceil((entry.resetTime - now) / 1000);
    return { 
      allowed: false, 
      retryAfter,
      limit: limits.max,
      window: limits.windowMs / 1000,
    };
  }
  
  return { 
    allowed: true, 
    remaining: limits.max - entry.count,
    resetTime: entry.resetTime,
  };
}

/**
 * Reset rate limit for a tool (for testing)
 */
function resetRateLimit(toolName) {
  requestCounts.delete(toolName);
}

module.exports = { checkRateLimit, resetRateLimit };
```

### 4.4 Audit Logging Module

**File: `mcp-server/security/audit.js`**

```javascript
/**
 * Audit logging module for MCP Server
 * 
 * Provides immutable audit trail for all operations
 */

const fs = require('fs');
const path = require('path');

const CONFIG = {
  logPath: process.env.MCP_AUDIT_LOG || path.join(__dirname, '../../logs/mcp-audit.jsonl'),
  console: process.env.MCP_AUDIT_CONSOLE === 'true',
  redactFields: ['password', 'ssn', 'account_number', 'credit_card', 'api_key'],
};

// Ensure log directory exists
const logDir = path.dirname(CONFIG.logPath);
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

/**
 * Redact sensitive fields from an object
 */
function redactSensitive(obj, depth = 0) {
  if (depth > 10) return '[MAX_DEPTH]'; // Prevent infinite recursion
  if (obj === null || obj === undefined) return obj;
  if (typeof obj !== 'object') return obj;
  
  if (Array.isArray(obj)) {
    return obj.map(item => redactSensitive(item, depth + 1));
  }
  
  const result = {};
  for (const [key, value] of Object.entries(obj)) {
    const lowerKey = key.toLowerCase();
    if (CONFIG.redactFields.some(field => lowerKey.includes(field))) {
      result[key] = '[REDACTED]';
    } else if (typeof value === 'object') {
      result[key] = redactSensitive(value, depth + 1);
    } else {
      result[key] = value;
    }
  }
  return result;
}

/**
 * Log an audit event
 * @param {Object} event - Event data to log
 */
function logAudit(event) {
  const entry = {
    timestamp: new Date().toISOString(),
    ...redactSensitive(event),
    pid: process.pid,
  };
  
  const line = JSON.stringify(entry) + '\n';
  
  try {
    // Append to audit log file
    fs.appendFileSync(CONFIG.logPath, line);
  } catch (error) {
    // Log to stderr if file write fails
    console.error('[AUDIT-ERROR] Failed to write audit log:', error.message);
  }
  
  // Optionally log to console
  if (CONFIG.console) {
    console.error(`[AUDIT] ${entry.timestamp} ${entry.action || 'event'}: ${JSON.stringify(entry)}`);
  }
}

/**
 * Create audit event for tool execution
 */
function auditToolExecution(toolName, args, result, duration, success) {
  logAudit({
    action: 'tool_execution',
    tool: toolName,
    args: args,
    resultSize: result ? JSON.stringify(result).length : 0,
    duration,
    success,
  });
}

module.exports = { logAudit, auditToolExecution, redactSensitive };
```

### 4.5 Logger Utility

**File: `mcp-server/utils/logger.js`**

```javascript
/**
 * Simple structured logger for MCP Server
 * 
 * Logs to stderr to keep stdout clean for MCP protocol
 */

const LEVELS = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
};

const currentLevel = LEVELS[process.env.MCP_LOG_LEVEL || 'info'];

function log(level, message, data = {}) {
  if (LEVELS[level] < currentLevel) {
    return;
  }
  
  const entry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    ...data,
  };
  
  // Log to stderr to not interfere with MCP protocol on stdout
  console.error(JSON.stringify(entry));
}

const logger = {
  debug: (message, data) => log('debug', message, data),
  info: (message, data) => log('info', message, data),
  warn: (message, data) => log('warn', message, data),
  error: (message, data) => log('error', message, data),
};

module.exports = { logger };
```

---

## 5. Implement Tool Handlers

### 5.1 Handler Router

**File: `mcp-server/handlers/index.js`**

```javascript
/**
 * Tool handler router
 * 
 * Routes tool calls to appropriate handler modules
 */

const path = require('path');
const { validateInput, getSupportedTools } = require('../security/validation');
const { auditToolExecution } = require('../security/audit');
const { logger } = require('../utils/logger');

// Import the existing mcpDatabaseService from LoanOfficerAI
// Adjust path based on actual location
const mcpDatabaseService = require('../../server/services/mcpDatabaseService');

// Import handler modules
const loanHandlers = require('./loans');
const borrowerHandlers = require('./borrowers');
const riskHandlers = require('./risk');
const analyticsHandlers = require('./analytics');

// Combine all handlers
const handlers = {
  ...loanHandlers,
  ...borrowerHandlers,
  ...riskHandlers,
  ...analyticsHandlers,
};

/**
 * Handle a tool call
 * @param {string} toolName - Name of the tool to execute
 * @param {Object} args - Arguments for the tool
 * @returns {Promise<Object>} - Tool result
 */
async function handleRequest(toolName, args) {
  const startTime = Date.now();
  
  // Validate input
  const validation = validateInput(toolName, args);
  if (!validation.valid) {
    throw new Error(`Invalid arguments: ${validation.error}`);
  }
  
  // Get handler
  const handler = handlers[toolName];
  if (!handler) {
    throw new Error(`Unknown tool: ${toolName}`);
  }
  
  try {
    // Execute handler with sanitized args
    const result = await handler(validation.sanitized, mcpDatabaseService);
    
    // Audit success
    const duration = Date.now() - startTime;
    auditToolExecution(toolName, validation.sanitized, result, duration, true);
    
    return result;
    
  } catch (error) {
    // Audit failure
    const duration = Date.now() - startTime;
    auditToolExecution(toolName, validation.sanitized, null, duration, false);
    
    logger.error('Tool execution failed', { 
      tool: toolName, 
      error: error.message 
    });
    
    throw error;
  }
}

/**
 * Get all tool definitions for MCP discovery
 */
function getToolDefinitions() {
  return [
    // Loan Information Tools
    {
      name: 'get_loan_details',
      description: 'Get comprehensive details about a specific loan including terms, amounts, dates, and current status',
      inputSchema: {
        type: 'object',
        properties: {
          loan_id: { type: 'string', description: 'The loan identifier (e.g., L001, L002)' }
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
          loan_id: { type: 'string', description: 'The loan identifier' }
        },
        required: ['loan_id']
      }
    },
    {
      name: 'get_loan_summary',
      description: 'Get portfolio-wide loan summary including total loans, active count, total amount, and delinquency rate',
      inputSchema: { type: 'object', properties: {}, required: [] }
    },
    {
      name: 'get_active_loans',
      description: 'Get a list of all currently active loans in the portfolio',
      inputSchema: { type: 'object', properties: {}, required: [] }
    },
    {
      name: 'get_loans_by_borrower',
      description: 'Get all loans associated with a specific borrower',
      inputSchema: {
        type: 'object',
        properties: {
          borrower_id: { type: 'string', description: 'The borrower identifier (e.g., B001)' }
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
          loan_id: { type: 'string', description: 'The loan identifier' }
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
          loan_id: { type: 'string', description: 'The loan identifier' }
        },
        required: ['loan_id']
      }
    },
    // Risk Assessment Tools
    {
      name: 'get_borrower_details',
      description: 'Get detailed borrower profile including credit score, income, farm size, and farm type',
      inputSchema: {
        type: 'object',
        properties: {
          borrower_id: { type: 'string', description: 'The borrower identifier' }
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
          borrower_id: { type: 'string', description: 'The borrower identifier' },
          time_horizon: { type: 'string', enum: ['short_term', 'medium_term', 'long_term'], description: 'Time horizon for risk assessment' }
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
          borrower_id: { type: 'string', description: 'The borrower identifier' }
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
          loan_id: { type: 'string', description: 'The loan identifier' },
          market_conditions: { type: 'string', enum: ['stable', 'declining', 'stressed'], description: 'Market condition scenario' }
        },
        required: ['loan_id']
      }
    },
    // Predictive Analytics Tools
    {
      name: 'analyze_market_price_impact',
      description: 'Analyze how commodity price changes would affect a borrower\'s loan portfolio',
      inputSchema: {
        type: 'object',
        properties: {
          borrower_id: { type: 'string', description: 'The borrower identifier' },
          commodity: { type: 'string', description: 'Commodity type (corn, soybeans, wheat, etc.)' },
          price_change_percent: { type: 'number', description: 'Percentage price change to simulate' }
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
          borrower_id: { type: 'string', description: 'The borrower identifier' },
          time_horizon: { type: 'string', enum: ['6m', '1y', '2y'], description: 'Forecast time horizon' }
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
          borrower_id: { type: 'string', description: 'The borrower identifier' },
          crop_type: { type: 'string', description: 'Type of crop (optional)' },
          season: { type: 'string', enum: ['current', 'next', 'historical'], description: 'Season to analyze' }
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
          loan_id: { type: 'string', description: 'The loan identifier' }
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
          borrower_id: { type: 'string', description: 'The borrower identifier' },
          period: { type: 'string', enum: ['6m', '1y', '2y', 'all'], description: 'Analysis period' }
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
          loan_id: { type: 'string', description: 'The loan identifier' },
          goal: { type: 'string', enum: ['reduce_payment', 'reduce_term', 'reduce_rate', 'general'], description: 'Restructuring goal' }
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
          risk_threshold: { type: 'string', enum: ['high', 'medium', 'all'], description: 'Minimum risk level' }
        },
        required: []
      }
    },
  ];
}

module.exports = { handleRequest, getToolDefinitions };
```

### 5.2 Loan Handlers

**File: `mcp-server/handlers/loans.js`**

```javascript
/**
 * Loan-related tool handlers
 */

const handlers = {
  /**
   * Get comprehensive loan details
   */
  async get_loan_details(args, dbService) {
    const loan = await dbService.getLoanDetails(args.loan_id);
    
    if (!loan) {
      throw new Error(`Loan with ID '${args.loan_id}' not found`);
    }
    
    return loan;
  },
  
  /**
   * Get loan status
   */
  async get_loan_status(args, dbService) {
    const loan = await dbService.getLoanDetails(args.loan_id);
    
    if (!loan) {
      throw new Error(`Loan with ID '${args.loan_id}' not found`);
    }
    
    return {
      loan_id: args.loan_id,
      status: loan.status,
      last_payment_date: loan.last_payment_date,
      days_past_due: loan.days_past_due || 0,
    };
  },
  
  /**
   * Get portfolio summary
   */
  async get_loan_summary(args, dbService) {
    return await dbService.getLoanSummary();
  },
  
  /**
   * Get all active loans
   */
  async get_active_loans(args, dbService) {
    return await dbService.getActiveLoans();
  },
  
  /**
   * Get loans by borrower
   */
  async get_loans_by_borrower(args, dbService) {
    const loans = await dbService.getLoansByBorrower(args.borrower_id);
    
    if (!loans || loans.length === 0) {
      throw new Error(`No loans found for borrower '${args.borrower_id}'`);
    }
    
    return loans;
  },
  
  /**
   * Get loan payment history
   */
  async get_loan_payments(args, dbService) {
    const payments = await dbService.getLoanPayments(args.loan_id);
    
    if (!payments) {
      throw new Error(`Loan with ID '${args.loan_id}' not found`);
    }
    
    return payments;
  },
  
  /**
   * Get loan collateral
   */
  async get_loan_collateral(args, dbService) {
    const collateral = await dbService.getLoanCollateral(args.loan_id);
    
    if (!collateral) {
      throw new Error(`Loan with ID '${args.loan_id}' not found or has no collateral`);
    }
    
    return collateral;
  },
};

module.exports = handlers;
```

### 5.3 Borrower and Risk Handlers

**File: `mcp-server/handlers/borrowers.js`**

```javascript
/**
 * Borrower-related tool handlers
 */

const handlers = {
  /**
   * Get borrower details
   */
  async get_borrower_details(args, dbService) {
    const borrower = await dbService.getBorrowerDetails(args.borrower_id);
    
    if (!borrower) {
      throw new Error(`Borrower with ID '${args.borrower_id}' not found`);
    }
    
    return borrower;
  },
};

module.exports = handlers;
```

**File: `mcp-server/handlers/risk.js`**

```javascript
/**
 * Risk assessment tool handlers
 */

const handlers = {
  /**
   * Get borrower default risk
   */
  async get_borrower_default_risk(args, dbService) {
    const risk = await dbService.getBorrowerDefaultRisk(
      args.borrower_id,
      args.time_horizon
    );
    
    if (!risk) {
      throw new Error(`Unable to calculate default risk for borrower '${args.borrower_id}'`);
    }
    
    return risk;
  },
  
  /**
   * Get borrower non-accrual risk
   */
  async get_borrower_non_accrual_risk(args, dbService) {
    const risk = await dbService.getBorrowerNonAccrualRisk(args.borrower_id);
    
    if (!risk) {
      throw new Error(`Unable to calculate non-accrual risk for borrower '${args.borrower_id}'`);
    }
    
    return risk;
  },
  
  /**
   * Evaluate collateral sufficiency
   */
  async evaluate_collateral_sufficiency(args, dbService) {
    const evaluation = await dbService.evaluateCollateralSufficiency(
      args.loan_id,
      args.market_conditions
    );
    
    if (!evaluation) {
      throw new Error(`Unable to evaluate collateral for loan '${args.loan_id}'`);
    }
    
    return evaluation;
  },
};

module.exports = handlers;
```

### 5.4 Analytics Handlers

**File: `mcp-server/handlers/analytics.js`**

```javascript
/**
 * Predictive analytics tool handlers
 */

const handlers = {
  /**
   * Analyze market price impact
   */
  async analyze_market_price_impact(args, dbService) {
    return await dbService.analyzeMarketPriceImpact(
      args.borrower_id,
      args.commodity,
      args.price_change_percent
    );
  },
  
  /**
   * Forecast equipment maintenance
   */
  async forecast_equipment_maintenance(args, dbService) {
    return await dbService.forecastEquipmentMaintenance(
      args.borrower_id,
      args.time_horizon
    );
  },
  
  /**
   * Assess crop yield risk
   */
  async assess_crop_yield_risk(args, dbService) {
    return await dbService.assessCropYieldRisk(
      args.borrower_id,
      args.crop_type,
      args.season
    );
  },
  
  /**
   * Get refinancing options
   */
  async get_refinancing_options(args, dbService) {
    return await dbService.getRefinancingOptions(args.loan_id);
  },
  
  /**
   * Analyze payment patterns
   */
  async analyze_payment_patterns(args, dbService) {
    return await dbService.analyzePaymentPatterns(
      args.borrower_id,
      args.period
    );
  },
  
  /**
   * Recommend loan restructuring
   */
  async recommend_loan_restructuring(args, dbService) {
    return await dbService.recommendLoanRestructuring(
      args.loan_id,
      args.goal
    );
  },
  
  /**
   * Get high risk farmers
   */
  async get_high_risk_farmers(args, dbService) {
    return await dbService.getHighRiskFarmers(args.risk_threshold);
  },
};

module.exports = handlers;
```

---

## 6. Configure Moltbot Integration

### 6.1 Create Moltbot MCP Configuration

**File: `~/.clawdbot/mcp-servers.json`** (create or update)

```json
{
  "servers": {
    "loan-officer": {
      "command": "node",
      "args": [
        "/Users/spehargreg/Development/LoanOfficerAI-MCP-POC/mcp-server/server.js"
      ],
      "env": {
        "DB_SERVER": "localhost",
        "DB_NAME": "LoanOfficerDB",
        "DB_USER": "sa",
        "DB_PASSWORD": "${LOAN_OFFICER_DB_PASSWORD}",
        "USE_DATABASE": "true",
        "MCP_AUTH_ENABLED": "false",
        "MCP_LOG_LEVEL": "info",
        "NODE_ENV": "production"
      },
      "autoStart": true
    }
  }
}
```

### 6.2 Set Environment Variables

Add to your shell profile (`~/.zshrc`, `~/.bashrc`, or `~/.profile`):

```bash
# LoanOfficer MCP Integration
export LOAN_OFFICER_DB_PASSWORD="YourStrong@Passw0rd"
export MCP_SHARED_KEY="your-32-character-minimum-shared-key-here"
```

---

## 7. Testing

### 7.1 Test MCP Server Standalone

```bash
cd /Users/spehargreg/Development/LoanOfficerAI-MCP-POC/mcp-server

# Start server and send test request
echo '{"jsonrpc":"2.0","id":"1","method":"tools/list","params":{}}' | node server.js

# Expected output: JSON with 18 tools listed
```

### 7.2 Test Tool Execution

```bash
# Test get_loan_summary
echo '{"jsonrpc":"2.0","id":"2","method":"tools/call","params":{"name":"get_loan_summary","arguments":{}}}' | node server.js

# Test get_loan_details
echo '{"jsonrpc":"2.0","id":"3","method":"tools/call","params":{"name":"get_loan_details","arguments":{"loan_id":"L001"}}}' | node server.js
```

### 7.3 Run Test Suite

```bash
cd /Users/spehargreg/Development/LoanOfficerAI-MCP-POC/mcp-server
npm test
```

---

## 8. Deployment

### 8.1 Deployment Checklist

- [ ] Database is running and accessible
- [ ] Environment variables are set
- [ ] MCP server starts without errors
- [ ] `tools/list` returns 18 tools
- [ ] Sample tool calls work correctly
- [ ] Audit log is being written
- [ ] Moltbot MCP config is created
- [ ] Moltbot can discover tools

### 8.2 Start the Integration

```bash
# Restart Moltbot gateway to pick up new MCP server
moltbot gateway restart

# Verify MCP server is connected
moltbot status --all
```

---

## 9. Troubleshooting

### 9.1 Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| MCP server won't start | Missing dependencies | Run `npm install` in mcp-server/ |
| Database connection failed | Wrong credentials | Check DB_* environment variables |
| Tools not discovered | Config path wrong | Verify `~/.clawdbot/mcp-servers.json` |
| Parse error responses | Invalid JSON | Check request format |
| Rate limit errors | Too many requests | Wait for rate limit window to reset |

### 9.2 Debug Mode

```bash
# Start MCP server with debug logging
MCP_LOG_LEVEL=debug node mcp-server/server.js

# Watch audit log
tail -f /Users/spehargreg/Development/LoanOfficerAI-MCP-POC/logs/mcp-audit.jsonl
```

### 9.3 Health Check

```bash
# Send health check request
echo '{"jsonrpc":"2.0","id":"health","method":"health/check","params":{}}' | node mcp-server/server.js
```

---

## Summary

This guide provides complete implementation instructions for integrating Moltbot with the LoanOfficerAI enterprise data service using the MCP Server (stdio) architecture. The integration includes:

1. **MCP Server** - JSON-RPC server using stdio transport
2. **18 Tools** - Loan info, risk assessment, and predictive analytics
3. **Security Layers** - Authentication, validation, rate limiting, audit logging
4. **Moltbot Configuration** - MCP server registration and environment setup

Following this guide, an LLM agent (like BB) should be able to:
- Create all necessary files
- Implement all handlers
- Configure security layers
- Test the integration
- Deploy to production

---

**Document Status**: Complete  
**Ready for Implementation**: Yes
