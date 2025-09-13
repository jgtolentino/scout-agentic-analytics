import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { ComputerUseTool } from './computer-use-tool.js';
import { AgentLoop } from './agent-loop.js';
import { SecuritySandbox } from './security-sandbox.js';

const COMPUTER_USE_VERSION = process.env.CLAUDE_MODEL?.includes('3.5') 
  ? 'computer_20241022' 
  : 'computer_20250124';

class ComputerUseMCPServer {
  private server: Server;
  private computerTool: ComputerUseTool;
  private agentLoop: AgentLoop;
  private securitySandbox: SecuritySandbox;

  constructor() {
    this.server = new Server(
      {
        name: 'pulser-computer-use',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    // Initialize components
    this.securitySandbox = new SecuritySandbox({
      enableInternet: process.env.ENABLE_INTERNET === 'true',
      allowedDomains: process.env.ALLOWED_DOMAINS?.split(',') || [],
    });

    this.computerTool = new ComputerUseTool({
      displayWidth: parseInt(process.env.DISPLAY_WIDTH || '1024'),
      displayHeight: parseInt(process.env.DISPLAY_HEIGHT || '768'),
      displayNumber: parseInt(process.env.DISPLAY_NUMBER || '1'),
      version: COMPUTER_USE_VERSION,
    });

    this.agentLoop = new AgentLoop({
      maxIterations: parseInt(process.env.MAX_ITERATIONS || '10'),
      model: process.env.CLAUDE_MODEL || 'claude-sonnet-4-20250514',
      betaFlag: process.env.CLAUDE_BETA_FLAG || 'computer-use-2025-01-24',
    });

    this.setupHandlers();
  }

  private setupHandlers() {
    // Handle tool listing
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'computer_use',
          description: 'Control computer through screenshots, mouse, and keyboard actions',
          inputSchema: {
            type: 'object',
            properties: {
              task: {
                type: 'string',
                description: 'The task to perform using computer control',
              },
              constraints: {
                type: 'object',
                properties: {
                  maxSteps: {
                    type: 'number',
                    description: 'Maximum number of steps to take',
                  },
                  timeout: {
                    type: 'number',
                    description: 'Timeout in seconds',
                  },
                },
              },
            },
            required: ['task'],
          },
        },
        {
          name: 'screenshot',
          description: 'Take a screenshot of the current display',
          inputSchema: {
            type: 'object',
            properties: {},
          },
        },
        {
          name: 'click',
          description: 'Click at specific coordinates',
          inputSchema: {
            type: 'object',
            properties: {
              x: { type: 'number' },
              y: { type: 'number' },
              button: {
                type: 'string',
                enum: ['left', 'right', 'middle'],
                default: 'left',
              },
            },
            required: ['x', 'y'],
          },
        },
        {
          name: 'type_text',
          description: 'Type text on the keyboard',
          inputSchema: {
            type: 'object',
            properties: {
              text: { type: 'string' },
            },
            required: ['text'],
          },
        },
        {
          name: 'key_press',
          description: 'Press a key or key combination',
          inputSchema: {
            type: 'object',
            properties: {
              key: { type: 'string' },
              modifiers: {
                type: 'array',
                items: {
                  type: 'string',
                  enum: ['ctrl', 'alt', 'shift', 'cmd', 'meta'],
                },
              },
            },
            required: ['key'],
          },
        },
      ],
    }));

    // Handle tool execution
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        // Check security sandbox
        await this.securitySandbox.validateAction(name, args);

        switch (name) {
          case 'computer_use': {
            // Run the full agent loop for complex tasks
            const result = await this.agentLoop.execute({
              task: args.task as string,
              constraints: args.constraints,
              tools: [this.computerTool],
            });
            return {
              content: [
                {
                  type: 'text',
                  text: `Task completed: ${result.summary}\nSteps taken: ${result.steps}`,
                },
              ],
            };
          }

          case 'screenshot': {
            const screenshot = await this.computerTool.takeScreenshot();
            return {
              content: [
                {
                  type: 'image',
                  data: screenshot.data,
                  mimeType: 'image/png',
                },
              ],
            };
          }

          case 'click': {
            await this.computerTool.click({
              x: args.x as number,
              y: args.y as number,
              button: args.button as string || 'left',
            });
            return {
              content: [
                {
                  type: 'text',
                  text: `Clicked at (${args.x}, ${args.y})`,
                },
              ],
            };
          }

          case 'type_text': {
            await this.computerTool.typeText(args.text as string);
            return {
              content: [
                {
                  type: 'text',
                  text: `Typed: "${args.text}"`,
                },
              ],
            };
          }

          case 'key_press': {
            await this.computerTool.keyPress({
              key: args.key as string,
              modifiers: args.modifiers as string[] || [],
            });
            return {
              content: [
                {
                  type: 'text',
                  text: `Pressed: ${args.modifiers?.join('+') || ''}${args.key}`,
                },
              ],
            };
          }

          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Pulser Computer Use MCP server running on stdio');
  }
}

// Error handling
process.on('uncaughtException', (error) => {
  console.error('Uncaught exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Start the server
const server = new ComputerUseMCPServer();
server.run().catch((error) => {
  console.error('Failed to start server:', error);
  process.exit(1);
});