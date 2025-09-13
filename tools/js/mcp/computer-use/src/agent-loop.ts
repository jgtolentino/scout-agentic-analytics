import Anthropic from '@anthropic-ai/sdk';
import { ComputerUseTool } from './computer-use-tool.js';

interface AgentLoopConfig {
  maxIterations: number;
  model: string;
  betaFlag: string;
  apiKey?: string;
}

interface ExecuteOptions {
  task: string;
  constraints?: {
    maxSteps?: number;
    timeout?: number;
  };
  tools: ComputerUseTool[];
}

interface ExecuteResult {
  success: boolean;
  summary: string;
  steps: number;
  actions: any[];
  error?: string;
}

export class AgentLoop {
  private client: Anthropic;
  private config: AgentLoopConfig;
  private abortController: AbortController;

  constructor(config: AgentLoopConfig) {
    this.config = config;
    this.client = new Anthropic({
      apiKey: config.apiKey || process.env.ANTHROPIC_API_KEY,
    });
    this.abortController = new AbortController();
  }

  async execute(options: ExecuteOptions): Promise<ExecuteResult> {
    const { task, constraints, tools } = options;
    const maxIterations = constraints?.maxSteps || this.config.maxIterations;
    const timeout = constraints?.timeout || 300; // 5 minutes default

    const messages: any[] = [
      {
        role: 'user',
        content: `Please complete the following task: ${task}

Important guidelines:
1. Take a screenshot first to see the current state
2. Plan your actions step by step
3. Verify each action's result before proceeding
4. If something doesn't work, try an alternative approach
5. Complete the task efficiently but thoroughly`,
      },
    ];

    const actions: any[] = [];
    let iterations = 0;
    let success = false;
    let summary = '';

    // Set timeout
    const timeoutId = setTimeout(() => {
      this.abortController.abort();
    }, timeout * 1000);

    try {
      while (iterations < maxIterations && !this.abortController.signal.aborted) {
        iterations++;
        console.error(`[Agent Loop] Iteration ${iterations}/${maxIterations}`);

        // Configure tools for this model version
        const toolsConfig = this.getToolsConfig(tools);

        // Call Claude API
        const response = await this.client.beta.messages.create({
          model: this.config.model,
          max_tokens: 4096,
          messages,
          tools: toolsConfig,
          betas: [this.config.betaFlag],
        });

        // Add Claude's response to conversation
        messages.push({
          role: 'assistant',
          content: response.content,
        });

        // Process tool calls
        const toolResults = [];
        let hasToolUse = false;

        for (const block of response.content) {
          if (block.type === 'tool_use') {
            hasToolUse = true;
            console.error(`[Agent Loop] Executing tool: ${block.name}`);

            try {
              // Execute the tool
              const result = await this.executeToolCall(tools[0], block);
              
              actions.push({
                tool: block.name,
                input: block.input,
                result: result.success ? 'success' : 'error',
                timestamp: new Date().toISOString(),
              });

              toolResults.push({
                type: 'tool_result',
                tool_use_id: block.id,
                content: result.content,
                is_error: result.is_error,
              });
            } catch (error) {
              console.error(`[Agent Loop] Tool error:`, error);
              toolResults.push({
                type: 'tool_result',
                tool_use_id: block.id,
                content: `Error: ${error.message}`,
                is_error: true,
              });
            }
          } else if (block.type === 'text') {
            // Check if task is complete
            const lowerText = block.text.toLowerCase();
            if (
              lowerText.includes('task complete') ||
              lowerText.includes('successfully completed') ||
              lowerText.includes('finished the task')
            ) {
              success = true;
              summary = block.text;
            }
          }
        }

        // If no tools were used, Claude is done
        if (!hasToolUse) {
          if (!success && response.content.length > 0) {
            const lastBlock = response.content[response.content.length - 1];
            if (lastBlock.type === 'text') {
              summary = lastBlock.text;
            }
          }
          break;
        }

        // Add tool results to continue conversation
        messages.push({
          role: 'user',
          content: toolResults,
        });
      }

      clearTimeout(timeoutId);

      return {
        success,
        summary: summary || `Completed ${iterations} iterations`,
        steps: iterations,
        actions,
      };
    } catch (error) {
      clearTimeout(timeoutId);
      console.error('[Agent Loop] Error:', error);
      
      return {
        success: false,
        summary: 'Task failed due to an error',
        steps: iterations,
        actions,
        error: error.message,
      };
    }
  }

  private getToolsConfig(tools: ComputerUseTool[]): any[] {
    const toolVersion = this.config.model.includes('3.5') 
      ? '20241022' 
      : '20250124';

    return tools.map(tool => ({
      type: `computer_${toolVersion}`,
      name: 'computer',
      display_width_px: tool.config.displayWidth,
      display_height_px: tool.config.displayHeight,
      display_number: tool.config.displayNumber,
    }));
  }

  private async executeToolCall(tool: ComputerUseTool, block: any): Promise<any> {
    const { name, input } = block;
    
    // The computer use tool has a specific action format
    if (name === 'computer' && input.action) {
      return await tool.executeAction(input);
    }

    // Fallback for other tool types
    return {
      success: false,
      content: 'Unknown tool call format',
      is_error: true,
    };
  }

  abort() {
    this.abortController.abort();
  }
}