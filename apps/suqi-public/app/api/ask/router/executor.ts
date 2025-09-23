import { runSemantic } from "../tools/tool_semantic";
import { runGeo } from "../tools/tool_geo";
import { runParity } from "../tools/tool_parity";
import { runSync } from "../tools/tool_sync";
import { runCatalogQA } from "../tools/tool_catalog";
import type { Plan, PlanStep } from "./planner";

export type ExecutionResult = {
  artifacts: ExecutionArtifact[];
  reply: any;
  execution_time_ms: number;
  success: boolean;
  error?: string;
};

export type ExecutionArtifact = {
  step: PlanStep;
  output: any;
  execution_time_ms: number;
  success: boolean;
  error?: string;
  verification_result?: VerificationResult;
};

export type VerificationResult = {
  passed: boolean;
  warnings: string[];
  metrics?: any;
};

export async function executePlan(plan: Plan): Promise<ExecutionResult> {
  const startTime = Date.now();
  const artifacts: ExecutionArtifact[] = [];
  let totalSuccess = true;
  let executionError: string | undefined;

  try {
    for (const [index, step] of plan.steps.entries()) {
      const stepStartTime = Date.now();
      let stepOutput: any;
      let stepSuccess = true;
      let stepError: string | undefined;

      try {
        // Execute the step
        stepOutput = await executeStep(step);

        // Verify the output
        const verification = await verifyStepOutput(step, stepOutput);

        artifacts.push({
          step,
          output: stepOutput,
          execution_time_ms: Date.now() - stepStartTime,
          success: stepSuccess,
          verification_result: verification
        });

        // If verification failed for critical steps, consider it an error
        if (!verification.passed && isCriticalStep(step)) {
          stepSuccess = false;
          stepError = `Verification failed: ${verification.warnings.join(', ')}`;
          totalSuccess = false;
        }

      } catch (error) {
        stepSuccess = false;
        stepError = error instanceof Error ? error.message : 'Unknown error';
        totalSuccess = false;

        artifacts.push({
          step,
          output: { error: stepError },
          execution_time_ms: Date.now() - stepStartTime,
          success: stepSuccess,
          error: stepError
        });

        // For some errors, we should continue with other steps
        if (!shouldContinueOnError(step, error)) {
          executionError = `Step ${index + 1} failed: ${stepError}`;
          break;
        }
      }
    }

    // Generate the final reply for the chat
    const reply = await generateReply(plan, artifacts);

    return {
      artifacts,
      reply,
      execution_time_ms: Date.now() - startTime,
      success: totalSuccess,
      error: executionError
    };

  } catch (error) {
    return {
      artifacts,
      reply: { type: "error", message: error instanceof Error ? error.message : 'Execution failed' },
      execution_time_ms: Date.now() - startTime,
      success: false,
      error: error instanceof Error ? error.message : 'Unknown execution error'
    };
  }
}

async function executeStep(step: PlanStep): Promise<any> {
  switch (step.tool) {
    case "SEMANTIC_QUERY":
      return await runSemantic(step.params);

    case "GEO_EXPORT":
      return await runGeo(step.params);

    case "PARITY_CHECK":
      return await runParity(step.params);

    case "AUTO_SYNC_FLAT":
      return await runSync(step.params);

    case "CATALOG_QA":
      return await runCatalogQA(step.params.question || step.params.query);

    default:
      throw new Error(`Unknown tool: ${step.tool}`);
  }
}

async function verifyStepOutput(step: PlanStep, output: any): Promise<VerificationResult> {
  const warnings: string[] = [];
  let passed = true;

  switch (step.tool) {
    case "SEMANTIC_QUERY":
      if (!output.data || !Array.isArray(output.data)) {
        warnings.push("Semantic query did not return data array");
        passed = false;
      } else if (output.data.length === 0) {
        warnings.push("Semantic query returned no rows - check filters and date range");
      } else if (output.data.length > 5000) {
        warnings.push("Large result set returned - consider adding filters");
      }

      // Check for expected columns
      if (output.data.length > 0) {
        const firstRow = output.data[0];
        if (step.params.dimensions) {
          for (const dim of step.params.dimensions) {
            if (!(dim in firstRow)) {
              warnings.push(`Expected dimension '${dim}' not found in results`);
            }
          }
        }
        if (step.params.measures) {
          for (const measure of step.params.measures) {
            if (!(measure in firstRow)) {
              warnings.push(`Expected measure '${measure}' not found in results`);
            }
          }
        }
      }
      break;

    case "GEO_EXPORT":
      if (!output.features || !Array.isArray(output.features)) {
        warnings.push("Geo export did not return features array");
        passed = false;
      } else if (output.features.length === 0) {
        warnings.push("Geo export returned no features - check level and filters");
        passed = false;
      } else {
        // Check feature structure
        const validFeatures = output.features.filter((f: any) =>
          f.type === "Feature" && f.geometry && f.properties
        );
        if (validFeatures.length !== output.features.length) {
          warnings.push("Some features have invalid GeoJSON structure");
        }
      }
      break;

    case "PARITY_CHECK":
      if (output.status === "ERROR") {
        warnings.push("Parity check failed to execute");
        passed = false;
      } else if (output.difference_percent && output.difference_percent > 0.05) {
        warnings.push(`High parity difference detected: ${(output.difference_percent * 100).toFixed(2)}%`);
      }
      break;

    case "AUTO_SYNC_FLAT":
      if (output.status === "ERROR") {
        warnings.push("Auto-sync failed to execute");
        passed = false;
      } else if (output.status === "INITIATED" && !output.run_id) {
        warnings.push("Sync initiated but no run ID returned");
      }
      break;

    case "CATALOG_QA":
      if (!output.answer || output.answer.length < 10) {
        warnings.push("Catalog Q&A returned very short or empty answer");
      }
      if (output.confidence && output.confidence < 0.5) {
        warnings.push("Low confidence in catalog Q&A response");
      }
      break;
  }

  return { passed, warnings };
}

function isCriticalStep(step: PlanStep): boolean {
  // Consider SEMANTIC_QUERY and GEO_EXPORT as critical for user-facing results
  return ['SEMANTIC_QUERY', 'GEO_EXPORT'].includes(step.tool);
}

function shouldContinueOnError(step: PlanStep, error: any): boolean {
  // Continue execution for non-critical operations
  return ['PARITY_CHECK', 'AUTO_SYNC_FLAT'].includes(step.tool);
}

async function generateReply(plan: Plan, artifacts: ExecutionArtifact[]): Promise<any> {
  // Find the primary artifact (usually the last successful one)
  const successfulArtifacts = artifacts.filter(a => a.success);

  if (successfulArtifacts.length === 0) {
    return {
      type: "error",
      message: "All execution steps failed",
      intent: plan.intent,
      errors: artifacts.map(a => a.error).filter(Boolean)
    };
  }

  const primary = successfulArtifacts[successfulArtifacts.length - 1];

  // Shape the response based on the primary tool
  switch (primary.step.tool) {
    case "SEMANTIC_QUERY":
      return {
        type: "table",
        intent: plan.intent,
        data: primary.output.data,
        row_count: primary.output.row_count,
        has_rollup: primary.output.has_rollup,
        summary: primary.output.summary,
        query_params: primary.output.query_params,
        sql: primary.output.sql,
        warnings: primary.verification_result?.warnings || []
      };

    case "GEO_EXPORT":
      return {
        type: "map",
        intent: plan.intent,
        features: primary.output.features,
        feature_count: primary.output.feature_count,
        bounds: primary.output.bounds,
        summary: primary.output.summary,
        export_params: primary.output.export_params,
        warnings: primary.verification_result?.warnings || []
      };

    case "PARITY_CHECK":
      return {
        type: "report",
        intent: plan.intent,
        status: primary.output.status,
        summary: primary.output.summary,
        details: {
          days_checked: primary.output.days_checked,
          flat_count: primary.output.flat_count,
          crosstab_count: primary.output.crosstab_count,
          difference: primary.output.difference,
          difference_percent: primary.output.difference_percent
        },
        warnings: primary.verification_result?.warnings || []
      };

    case "AUTO_SYNC_FLAT":
      return {
        type: "status",
        intent: plan.intent,
        operation: "auto_sync",
        status: primary.output.status,
        summary: primary.output.summary,
        run_id: primary.output.run_id,
        records_processed: primary.output.records_processed,
        warnings: primary.verification_result?.warnings || []
      };

    case "CATALOG_QA":
      return {
        type: "answer",
        intent: plan.intent,
        question: primary.output.question,
        answer: primary.output.answer,
        citations: primary.output.citations || [],
        confidence: primary.output.confidence,
        summary: primary.output.summary,
        warnings: primary.verification_result?.warnings || []
      };

    default:
      return {
        type: "result",
        intent: plan.intent,
        data: primary.output,
        summary: `Completed ${primary.step.tool} operation`,
        warnings: primary.verification_result?.warnings || []
      };
  }
}