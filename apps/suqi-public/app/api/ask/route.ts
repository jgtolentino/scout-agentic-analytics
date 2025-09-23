import { NextRequest, NextResponse } from "next/server";
import { plan } from "./router/planner";
import { scoreAgents } from "./router/router";
import { executePlan } from "./router/executor";

export const runtime = "nodejs";

export async function POST(req: NextRequest) {
  const startTime = Date.now();

  try {
    const body = await req.json();
    const { message, filters, user, session_id } = body;

    // Validate required fields
    if (!message || typeof message !== 'string') {
      return NextResponse.json(
        { error: "Message is required and must be a string" },
        { status: 400 }
      );
    }

    if (message.trim().length === 0) {
      return NextResponse.json(
        { error: "Message cannot be empty" },
        { status: 400 }
      );
    }

    // Rate limiting check (simple implementation)
    const rateLimitResult = await checkRateLimit(user, session_id);
    if (!rateLimitResult.allowed) {
      return NextResponse.json(
        { error: "Rate limit exceeded. Please wait before sending another message." },
        { status: 429 }
      );
    }

    // Quick heuristic: score agents (safety net if planning fails)
    const scored = scoreAgents(message);
    console.log('Agent scores:', scored.slice(0, 3));

    // Create execution context
    const context = {
      filters: filters || {},
      user: user || 'anonymous',
      session_id: session_id || generateSessionId(),
      topCandidates: scored.slice(0, 3),
      timestamp: new Date().toISOString()
    };

    // Plan with LLM (has guardrails in prompt)
    console.log('Creating execution plan for:', message);
    const planResult = await plan(message, context);
    console.log('Generated plan:', planResult);

    // Execute the plan
    console.log('Executing plan...');
    const executionResult = await executePlan(planResult);
    console.log('Execution completed:', {
      success: executionResult.success,
      artifactCount: executionResult.artifacts.length,
      executionTime: executionResult.execution_time_ms
    });

    // Log the query for analytics (async, don't await)
    logQuery(message, planResult, executionResult, context).catch(err =>
      console.warn('Failed to log query:', err)
    );

    // Prepare response
    const response = {
      intent: planResult.intent,
      confidence: planResult.confidence,
      plan: {
        steps: planResult.steps,
        fallback_reason: planResult.fallback_reason
      },
      reply: executionResult.reply,
      artifacts: executionResult.artifacts.map(a => ({
        tool: a.step.tool,
        success: a.success,
        execution_time_ms: a.execution_time_ms,
        has_warnings: (a.verification_result?.warnings?.length || 0) > 0,
        error: a.error
      })),
      execution: {
        total_time_ms: Date.now() - startTime,
        success: executionResult.success,
        error: executionResult.error
      },
      session_id: context.session_id,
      timestamp: context.timestamp
    };

    return NextResponse.json(response);

  } catch (error) {
    console.error('Ask Suqi error:', error);

    const errorResponse = {
      error: "Internal server error",
      message: error instanceof Error ? error.message : 'Unknown error occurred',
      execution: {
        total_time_ms: Date.now() - startTime,
        success: false
      },
      timestamp: new Date().toISOString()
    };

    return NextResponse.json(errorResponse, { status: 500 });
  }
}

// Simple rate limiting implementation
async function checkRateLimit(user?: string, sessionId?: string): Promise<{ allowed: boolean; remaining?: number }> {
  // For now, just return allowed
  // In production, implement Redis-based rate limiting
  // Example: 10 requests per minute per user/session
  return { allowed: true };
}

function generateSessionId(): string {
  return `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

// Query logging for analytics and improvement
async function logQuery(
  message: string,
  plan: any,
  execution: any,
  context: any
): Promise<void> {
  try {
    // Skip logging in development
    if (process.env.NODE_ENV === 'development') {
      return;
    }

    const logEntry = {
      user_message: message,
      intent: plan.intent,
      confidence: plan.confidence,
      plan_json: JSON.stringify(plan),
      execution_success: execution.success,
      execution_time_ms: execution.execution_time_ms,
      artifacts_count: execution.artifacts.length,
      session_id: context.session_id,
      user_id: context.user,
      created_at: new Date().toISOString(),
      reply_type: execution.reply?.type,
      has_errors: !!execution.error,
      error_message: execution.error
    };

    // In production, send to your analytics/logging service
    // For now, just log to console
    console.log('Query logged:', {
      session_id: logEntry.session_id,
      intent: logEntry.intent,
      success: logEntry.execution_success
    });

    // TODO: Implement actual database logging
    // await logToDatabase(logEntry);

  } catch (error) {
    console.warn('Failed to log query:', error);
  }
}

// Health check endpoint
export async function GET() {
  return NextResponse.json({
    service: "Ask Suqi",
    version: "1.0.0",
    status: "healthy",
    capabilities: [
      "SEMANTIC_QUERY",
      "GEO_EXPORT",
      "PARITY_CHECK",
      "AUTO_SYNC_FLAT",
      "CATALOG_QA"
    ],
    llm_provider: process.env.LLM_PROVIDER || 'mock',
    timestamp: new Date().toISOString()
  });
}