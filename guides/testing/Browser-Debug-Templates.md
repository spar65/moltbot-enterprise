# Browser Debug Templates

**Ready-to-Use JavaScript Templates Based on Successful Troubleshooting Patterns**

These templates are based on the successful debugging techniques used during the UUID migration and PRD troubleshooting sessions documented in the August 2025 chat logs.

## 🚀 **Quick Start Templates**

### **Template 1: PRD Workflow Step Monitoring**

```javascript
// Copy-paste this into browser console to monitor PRD workflow steps
const monitorPRDStep = (stepNumber) => {
  console.log(`🔍 MONITORING PRD STEP ${stepNumber}...`);

  fetch("/api/tools/prd-basic/dashboard-list")
    .then((r) => r.json())
    .then((data) => {
      const latestPrd = data.prds[0];
      const analysis = {
        timestamp: new Date().toLocaleTimeString(),
        stepNumber: stepNumber,
        prdId: latestPrd?.id,
        title: latestPrd?.title,
        currentStep: latestPrd?.current_step,
        status: latestPrd?.status,
        organizationId: latestPrd?.organization_id || "NULL",
        userOrgId: data.userOrganization?.id || "NULL",
        organizationMatch:
          latestPrd?.organization_id === data.userOrganization?.id,
        readyForNextStep: latestPrd?.current_step >= stepNumber,
        // AI Enhancement tracking
        isAiEnhanced: latestPrd?.is_ai_enhanced,
        aiModelMetadata: latestPrd?.ai_model_metadata,
        finalAiResponse: latestPrd?.final_ai_response ? "HAS_CONTENT" : "NULL",
        wordCount: latestPrd?.word_count,
        aiDataSaved: !!(
          latestPrd?.final_ai_response || latestPrd?.ai_model_metadata
        ),
        // UUID validation
        uuidValid: {
          prdId:
            /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
              latestPrd?.id
            ),
          orgId:
            /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
              latestPrd?.organization_id
            ),
        },
      };

      console.log(`📊 STEP ${stepNumber} ANALYSIS:`, analysis);

      // Critical alerts
      if (!latestPrd?.organization_id) {
        console.log(`🚨 CRITICAL: Missing organization at Step ${stepNumber}`);
      }
      if (!analysis.organizationMatch) {
        console.log(`⚠️ WARNING: Organization mismatch at Step ${stepNumber}`);
      }
      if (!analysis.uuidValid.prdId || !analysis.uuidValid.orgId) {
        console.log(`🚨 UUID VALIDATION FAILED:`, analysis.uuidValid);
      }
      if (analysis.currentStep >= stepNumber) {
        console.log(`✅ STEP ${stepNumber} COMPLETE`);
      } else {
        console.log(`⏳ Step ${stepNumber} not complete yet`);
      }

      // Store for next step
      window[`prdStep${stepNumber}Data`] = latestPrd;
      return analysis;
    })
    .catch((err) =>
      console.error(`❌ Step ${stepNumber} monitoring failed:`, err)
    );
};

// Usage: monitorPRDStep(8);
```

### **Template 2: Task Generation Real-Time Monitoring**

```javascript
// Copy-paste this to monitor task generation in real-time
const monitorTaskGeneration = (prdId, maxChecks = 30) => {
  console.log(`⏱️ STARTING TASK GENERATION MONITORING`);
  console.log(`📋 PRD ID: ${prdId}`);
  console.log(`⏰ Will check every 2 seconds for ${maxChecks * 2} seconds`);

  let checkCount = 0;

  const checkTasks = () => {
    checkCount++;
    console.log(`🔄 Check ${checkCount}/${maxChecks}...`);

    Promise.all([
      fetch(`/api/tools/task-manager/tasks?prdId=${prdId}`).then((r) =>
        r.json()
      ),
      fetch("/api/tools/prd-basic/dashboard-list").then((r) => r.json()),
    ])
      .then(([taskData, prdData]) => {
        const prd = prdData.prds.find((p) => p.id === prdId);
        const analysis = {
          timestamp: new Date().toLocaleTimeString(),
          checkNumber: checkCount,
          tasks: taskData.summary?.total_tasks || taskData.tasks?.length || 0,
          taskGroups: taskData.summary?.total_groups || 0,
          success: taskData.success,
          organizationMatch:
            prd?.organization_id === prdData.userOrganization?.id,
          prdStatus: prd?.status,
          qualityScore: taskData.quality_metrics?.overall_quality_score,
          errors: taskData.error ? [taskData.error] : [],
        };

        console.log(`📊 Task Check ${checkCount}:`, analysis);

        // Issue detection
        if (!analysis.success && analysis.errors.length > 0) {
          console.log(`🚨 TASK GENERATION ERROR:`, analysis.errors);
        }
        if (analysis.tasks === 0 && checkCount > 5) {
          console.log(
            `⚠️ WARNING: No tasks persisted after ${checkCount} checks - possible silent failure`
          );
        }

        // Success detection
        if (analysis.tasks > 0 && analysis.success) {
          console.log(
            `✅ TASK GENERATION SUCCESS: ${analysis.tasks} tasks generated!`
          );
          clearInterval(interval);
          return;
        }
      })
      .catch((err) =>
        console.error(`❌ Task check ${checkCount} failed:`, err)
      );
  };

  const interval = setInterval(checkTasks, 2000);
  setTimeout(() => {
    clearInterval(interval);
    console.log(`⏹️ Task monitoring stopped after ${maxChecks} checks`);
  }, maxChecks * 2000);

  return interval;
};

// Usage: monitorTaskGeneration('16869344-3e4e-4b02-a3df-c633a9bcfa60');
```

### **Template 3: Organization Consistency Checker**

```javascript
// Copy-paste this to check organization consistency across all endpoints
const checkOrganizationConsistency = () => {
  console.log(`🏢 CHECKING ORGANIZATION CONSISTENCY...`);

  const endpoints = [
    { name: "user", url: "/api/user/dashboard" },
    { name: "prds", url: "/api/tools/prd-basic/dashboard-list" },
    { name: "tasks", url: "/api/tools/task-manager/prds" },
  ];

  Promise.all(
    endpoints.map((endpoint) =>
      fetch(endpoint.url)
        .then((r) => r.json())
        .then((data) => ({ ...endpoint, data, success: true }))
        .catch((err) => ({ ...endpoint, error: err.message, success: false }))
    )
  ).then((results) => {
    const analysis = {
      timestamp: new Date().toLocaleTimeString(),
      results: results,
      organizationIds: {},
      consistency: true,
    };

    // Extract organization IDs
    results.forEach((result) => {
      if (result.success && result.data) {
        if (result.data.userOrganization?.id) {
          analysis.organizationIds[result.name] =
            result.data.userOrganization.id;
        }
        if (result.data.organization_id) {
          analysis.organizationIds[result.name] = result.data.organization_id;
        }
        if (result.data.prds && result.data.prds[0]?.organization_id) {
          analysis.organizationIds[`${result.name}_latest`] =
            result.data.prds[0].organization_id;
        }
      }
    });

    // Check consistency
    const uniqueOrgIds = [...new Set(Object.values(analysis.organizationIds))];
    analysis.consistency = uniqueOrgIds.length <= 1;
    analysis.uniqueOrganizations = uniqueOrgIds;

    console.log(`🏢 ORGANIZATION CONSISTENCY ANALYSIS:`, analysis);

    if (!analysis.consistency) {
      console.log(`🚨 ORGANIZATION INCONSISTENCY DETECTED!`);
      console.log(
        `   Found ${uniqueOrgIds.length} different organization IDs:`,
        uniqueOrgIds
      );
      console.log(`   Per endpoint:`, analysis.organizationIds);
    } else {
      console.log(`✅ ORGANIZATION CONSISTENCY VERIFIED`);
      console.log(`   Single organization ID: ${uniqueOrgIds[0]}`);
    }

    return analysis;
  });
};

// Usage: checkOrganizationConsistency();
```

### **Template 4: API Endpoint Tester**

```javascript
// Copy-paste this to test specific API endpoints with detailed analysis
const testAPIEndpoint = (endpoint, method = "GET", body = null) => {
  console.log(`🧪 TESTING API ENDPOINT: ${method} ${endpoint}`);

  const fetchOptions = {
    method: method,
    headers: { "Content-Type": "application/json" },
    ...(body && { body: JSON.stringify(body) }),
  };

  return fetch(endpoint, fetchOptions)
    .then((response) => {
      const analysis = {
        endpoint: endpoint,
        method: method,
        status: response.status,
        statusText: response.statusText,
        ok: response.ok,
        timestamp: new Date().toLocaleTimeString(),
      };

      console.log(`📊 API RESPONSE ANALYSIS:`, analysis);

      // Status-specific messages
      if (response.status === 405) {
        console.log(
          `⚠️ METHOD NOT ALLOWED: ${method} not supported on ${endpoint}`
        );
      } else if (response.status === 401) {
        console.log(`🔒 AUTHENTICATION REQUIRED: ${endpoint}`);
      } else if (response.status === 403) {
        console.log(`🚫 FORBIDDEN: Access denied to ${endpoint}`);
      } else if (response.status >= 500) {
        console.log(`🚨 SERVER ERROR: ${response.status} on ${endpoint}`);
      } else if (response.ok) {
        console.log(`✅ SUCCESS: ${response.status} ${response.statusText}`);
      }

      return response
        .json()
        .then((data) => {
          analysis.data = data;
          analysis.success = data.success;
          analysis.error = data.error;

          console.log(`📋 API DATA:`, {
            success: data.success,
            error: data.error,
            dataKeys: Object.keys(data),
            organizationId: data.organizationId,
          });

          if (data.error) {
            console.log(`🚨 API ERROR:`, data.error);
          }

          return analysis;
        })
        .catch((jsonErr) => {
          console.log(`⚠️ Response not JSON:`, jsonErr.message);
          return analysis;
        });
    })
    .catch((err) => {
      console.error(`❌ API TEST FAILED:`, err);
      return {
        endpoint: endpoint,
        method: method,
        error: err.message,
        timestamp: new Date().toLocaleTimeString(),
      };
    });
};

// Usage: testAPIEndpoint('/api/tools/prd-basic/ai-enhance', 'POST', {prdId: 'your-id', currentContent: 'test'});
```

## 🔄 **Complete Workflow Templates**

### **Template 5: Full PRD Creation Workflow Monitor**

```javascript
// Complete PRD workflow monitoring (Steps 1-9)
const monitorFullPRDWorkflow = () => {
  console.log(`🎯 STARTING FULL PRD WORKFLOW MONITORING`);

  window.prdWorkflowSession = {
    startTime: Date.now(),
    steps: {},
    issues: [],
  };

  const monitorStep = (stepNumber) => {
    return fetch("/api/tools/prd-basic/dashboard-list")
      .then((r) => r.json())
      .then((data) => {
        const latestPrd = data.prds[0];
        const stepData = {
          timestamp: new Date().toLocaleTimeString(),
          stepNumber: stepNumber,
          prdId: latestPrd?.id,
          currentStep: latestPrd?.current_step,
          status: latestPrd?.status,
          organizationId: latestPrd?.organization_id,
          organizationMatch:
            latestPrd?.organization_id === data.userOrganization?.id,
          completed: latestPrd?.current_step >= stepNumber,
        };

        window.prdWorkflowSession.steps[stepNumber] = stepData;

        console.log(`📊 Step ${stepNumber} Status:`, stepData);

        if (!stepData.organizationMatch) {
          window.prdWorkflowSession.issues.push({
            step: stepNumber,
            issue: "Organization mismatch",
            severity: "high",
          });
        }

        return stepData;
      });
  };

  // Monitor all steps
  const checkAllSteps = () => {
    Promise.all([1, 2, 3, 4, 5, 6, 7, 8, 9].map(monitorStep)).then(
      (results) => {
        const completedSteps = results.filter((r) => r.completed).length;
        console.log(
          `📈 WORKFLOW PROGRESS: ${completedSteps}/9 steps completed`
        );

        if (completedSteps === 9) {
          console.log(`🎉 FULL PRD WORKFLOW COMPLETED!`);
        }
      }
    );
  };

  return { monitorStep, checkAllSteps };
};

// Usage:
// const workflow = monitorFullPRDWorkflow();
// workflow.checkAllSteps(); // Check all steps at once
// workflow.monitorStep(8); // Check specific step
```

### **Template 6: Silent Failure Detection**

```javascript
// Detect silent failures where frontend shows success but data isn't persisted
const detectSilentFailures = (
  resourceType,
  checkEndpoint,
  expectedMinimum = 1
) => {
  console.log(`🕵️ DETECTING SILENT FAILURES FOR: ${resourceType}`);

  let checks = 0;
  const maxChecks = 10;

  const checkForSilentFailure = () => {
    checks++;

    fetch(checkEndpoint)
      .then((r) => r.json())
      .then((data) => {
        const count =
          data.summary?.total || data.count || data.items?.length || 0;
        const analysis = {
          timestamp: new Date().toLocaleTimeString(),
          check: checks,
          resourceType: resourceType,
          count: count,
          expectedMinimum: expectedMinimum,
          apiSuccess: data.success,
          silentFailure: data.success && count < expectedMinimum && checks > 3,
        };

        console.log(`🔍 Silent Failure Check ${checks}:`, analysis);

        if (analysis.silentFailure) {
          console.log(`🚨 SILENT FAILURE DETECTED!`);
          console.log(`   API reports success: ${data.success}`);
          console.log(`   Actual ${resourceType} count: ${count}`);
          console.log(`   Expected minimum: ${expectedMinimum}`);
          console.log(
            `   This indicates data is not persisting despite successful API responses`
          );
          clearInterval(interval);
        }

        if (count >= expectedMinimum) {
          console.log(`✅ NO SILENT FAILURE: ${count} ${resourceType} found`);
          clearInterval(interval);
        }
      })
      .catch((err) => console.error(`❌ Silent failure check failed:`, err));
  };

  const interval = setInterval(checkForSilentFailure, 3000);
  setTimeout(() => {
    clearInterval(interval);
    console.log(
      `⏹️ Silent failure detection stopped after ${maxChecks} checks`
    );
  }, maxChecks * 3000);

  return interval;
};

// Usage: detectSilentFailures('tasks', '/api/tools/task-manager/tasks?prdId=your-id', 10);
```

## 🎯 **Quick Reference Commands**

```javascript
// Quick commands for common debugging scenarios

// 1. Check current PRD status
monitorPRDStep(9);

// 2. Monitor task generation
monitorTaskGeneration("your-prd-id");

// 3. Check organization consistency
checkOrganizationConsistency();

// 4. Test problematic API endpoint
testAPIEndpoint("/api/problematic/endpoint", "POST", { test: "data" });

// 5. Detect silent failures
detectSilentFailures("tasks", "/api/tools/task-manager/tasks?prdId=your-id", 5);

// 6. Full workflow monitoring
const workflow = monitorFullPRDWorkflow();
workflow.checkAllSteps();
```

## 📚 **Integration with Development**

### **Add to Component Development**

```javascript
// Add to React components for debugging
useEffect(() => {
  if (process.env.NODE_ENV === "development") {
    monitorPRDStep(currentStep);
  }
}, [currentStep]);
```

### **Add to Test Files**

```javascript
// Add to Jest tests for debugging
beforeEach(() => {
  if (global.window) {
    global.window.testSession = { startTime: Date.now() };
  }
});
```

### **Add to Production Debugging**

```javascript
// Safe production debugging (read-only)
if (window.location.hostname.includes("myvibecoder.us")) {
  // Only use read-only monitoring functions
  checkOrganizationConsistency();
  monitorPRDStep(currentStep);
}
```

---

**These templates are battle-tested and based on successful resolution of real production issues. Use them to quickly identify and resolve complex data flow problems.**
