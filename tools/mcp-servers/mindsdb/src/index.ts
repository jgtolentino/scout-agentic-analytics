#!/usr/bin/env node

/**
 * Scout v7.1 MindsDB MCP Server
 * Provides predictive analytics capabilities through MindsDB Cloud
 * Implements tools for query, train, deploy, and predict operations
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from '@modelcontextprotocol/sdk/types.js';
import mysql from 'mysql2/promise';
import { z } from 'zod';

// Configuration schema
const ConfigSchema = z.object({
  host: z.string().default('cloud.mindsdb.com'),
  port: z.number().default(3306),
  user: z.string(),
  password: z.string(),
  database: z.string().default('mindsdb'),
  timeout: z.number().default(30000),
  retryAttempts: z.number().default(3),
  retryDelay: z.number().default(1000),
});

type Config = z.infer<typeof ConfigSchema>;

// Tool schemas
const QueryToolSchema = z.object({
  sql: z.string().describe('SQL query to execute on MindsDB'),
  timeout: z.number().optional().describe('Query timeout in milliseconds'),
});

const TrainModelToolSchema = z.object({
  modelName: z.string().describe('Name for the ML model'),
  integrationName: z.string().describe('Data integration name (e.g., scout_postgres)'),
  selectQuery: z.string().describe('SELECT query for training data'),
  predictColumn: z.string().describe('Target column to predict'),
  timeColumn: z.string().optional().describe('Time column for time series forecasting'),
  window: z.number().optional().describe('Window size for time series'),
  horizon: z.number().optional().describe('Forecast horizon'),
  hyperparameters: z.record(z.any()).optional().describe('Model hyperparameters'),
});

const PredictToolSchema = z.object({
  modelName: z.string().describe('Name of the trained model'),
  inputData: z.union([
    z.object({}).passthrough(), // Single prediction object
    z.array(z.object({}).passthrough()), // Batch prediction array
  ]).describe('Input data for prediction'),
  horizon: z.number().optional().describe('Forecast horizon for time series'),
  explainability: z.boolean().optional().describe('Include prediction explanations'),
});

const ModelStatusToolSchema = z.object({
  modelName: z.string().optional().describe('Specific model name (if not provided, lists all models)'),
  detailed: z.boolean().optional().describe('Include detailed model information'),
});

const DeployModelToolSchema = z.object({
  modelName: z.string().describe('Name of the model to deploy'),
  endpoint: z.string().optional().describe('Deployment endpoint configuration'),
  schedule: z.string().optional().describe('Automated retraining schedule (cron format)'),
});

class MindsDBMCPServer {
  private server: Server;
  private config: Config;
  private connection: mysql.Connection | null = null;

  constructor() {
    this.server = new Server(
      {
        name: 'scout-mindsdb-server',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    // Get configuration from environment
    this.config = ConfigSchema.parse({
      host: process.env.MINDSDB_HOST,
      port: process.env.MINDSDB_PORT ? parseInt(process.env.MINDSDB_PORT) : undefined,
      user: process.env.MINDSDB_USER,
      password: process.env.MINDSDB_PASSWORD,
      database: process.env.MINDSDB_DATABASE,
      timeout: process.env.MINDSDB_TIMEOUT ? parseInt(process.env.MINDSDB_TIMEOUT) : undefined,
    });

    this.setupToolHandlers();
  }

  private setupToolHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: 'mindsdb_query',
            description: 'Execute SQL queries on MindsDB for general operations',
            inputSchema: {
              type: 'object',
              properties: {
                sql: {
                  type: 'string',
                  description: 'SQL query to execute on MindsDB',
                },
                timeout: {
                  type: 'number',
                  description: 'Query timeout in milliseconds',
                  optional: true,
                },
              },
              required: ['sql'],
            },
          },
          {
            name: 'mindsdb_train_model',
            description: 'Train a new ML model on MindsDB using Scout data',
            inputSchema: {
              type: 'object',
              properties: {
                modelName: {
                  type: 'string',
                  description: 'Name for the ML model',
                },
                integrationName: {
                  type: 'string',
                  description: 'Data integration name (e.g., scout_postgres)',
                },
                selectQuery: {
                  type: 'string',
                  description: 'SELECT query for training data',
                },
                predictColumn: {
                  type: 'string',
                  description: 'Target column to predict',
                },
                timeColumn: {
                  type: 'string',
                  description: 'Time column for time series forecasting',
                  optional: true,
                },
                window: {
                  type: 'number',
                  description: 'Window size for time series',
                  optional: true,
                },
                horizon: {
                  type: 'number',
                  description: 'Forecast horizon',
                  optional: true,
                },
                hyperparameters: {
                  type: 'object',
                  description: 'Model hyperparameters',
                  optional: true,
                },
              },
              required: ['modelName', 'integrationName', 'selectQuery', 'predictColumn'],
            },
          },
          {
            name: 'mindsdb_predict',
            description: 'Make predictions using a trained MindsDB model',
            inputSchema: {
              type: 'object',
              properties: {
                modelName: {
                  type: 'string',
                  description: 'Name of the trained model',
                },
                inputData: {
                  type: ['object', 'array'],
                  description: 'Input data for prediction',
                },
                horizon: {
                  type: 'number',
                  description: 'Forecast horizon for time series',
                  optional: true,
                },
                explainability: {
                  type: 'boolean',
                  description: 'Include prediction explanations',
                  optional: true,
                },
              },
              required: ['modelName', 'inputData'],
            },
          },
          {
            name: 'mindsdb_model_status',
            description: 'Get status and information about MindsDB models',
            inputSchema: {
              type: 'object',
              properties: {
                modelName: {
                  type: 'string',
                  description: 'Specific model name (if not provided, lists all models)',
                  optional: true,
                },
                detailed: {
                  type: 'boolean',
                  description: 'Include detailed model information',
                  optional: true,
                },
              },
              required: [],
            },
          },
          {
            name: 'mindsdb_deploy_model',
            description: 'Deploy a trained model for production use with scheduling',
            inputSchema: {
              type: 'object',
              properties: {
                modelName: {
                  type: 'string',
                  description: 'Name of the model to deploy',
                },
                endpoint: {
                  type: 'string',
                  description: 'Deployment endpoint configuration',
                  optional: true,
                },
                schedule: {
                  type: 'string',
                  description: 'Automated retraining schedule (cron format)',
                  optional: true,
                },
              },
              required: ['modelName'],
            },
          },
        ] as Tool[],
      };
    });

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'mindsdb_query':
            return await this.handleQuery(QueryToolSchema.parse(args));
          case 'mindsdb_train_model':
            return await this.handleTrainModel(TrainModelToolSchema.parse(args));
          case 'mindsdb_predict':
            return await this.handlePredict(PredictToolSchema.parse(args));
          case 'mindsdb_model_status':
            return await this.handleModelStatus(ModelStatusToolSchema.parse(args));
          case 'mindsdb_deploy_model':
            return await this.handleDeployModel(DeployModelToolSchema.parse(args));
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error instanceof Error ? error.message : String(error)}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  private async getConnection(): Promise<mysql.Connection> {
    if (!this.connection) {
      try {
        this.connection = await mysql.createConnection({
          host: this.config.host,
          port: this.config.port,
          user: this.config.user,
          password: this.config.password,
          database: this.config.database,
          timeout: this.config.timeout,
          ssl: this.config.host.includes('cloud.mindsdb.com') ? { rejectUnauthorized: false } : false,
        });

        console.error(`Connected to MindsDB at ${this.config.host}:${this.config.port}`);
      } catch (error) {
        console.error('MindsDB connection failed:', error);
        throw new Error(`Failed to connect to MindsDB: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
    return this.connection;
  }

  private async executeQuery(sql: string, timeout?: number): Promise<any[]> {
    const connection = await this.getConnection();
    
    try {
      const [rows] = await connection.execute(sql);
      return Array.isArray(rows) ? rows : [rows];
    } catch (error) {
      console.error('MindsDB query error:', error);
      throw new Error(`Query execution failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private async handleQuery(args: z.infer<typeof QueryToolSchema>) {
    const { sql, timeout } = args;
    
    console.error(`Executing MindsDB query: ${sql.substring(0, 100)}...`);
    
    const startTime = Date.now();
    const results = await this.executeQuery(sql, timeout);
    const executionTime = Date.now() - startTime;
    
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            status: 'success',
            results,
            rowCount: results.length,
            executionTimeMs: executionTime,
            query: sql.substring(0, 200) + (sql.length > 200 ? '...' : ''),
          }, null, 2),
        },
      ],
    };
  }

  private async handleTrainModel(args: z.infer<typeof TrainModelToolSchema>) {
    const {
      modelName,
      integrationName,
      selectQuery,
      predictColumn,
      timeColumn,
      window = 12,
      horizon = 12,
      hyperparameters = {},
    } = args;

    console.error(`Training model: ${modelName}`);

    // Build CREATE MODEL query
    let createModelSQL = `
      CREATE OR REPLACE MODEL ${modelName}
      FROM ${integrationName} (${selectQuery})
      PREDICT ${predictColumn}
    `;

    // Add time series parameters if provided
    if (timeColumn) {
      createModelSQL += `\n      ORDER BY ${timeColumn}`;
      createModelSQL += `\n      WINDOW ${window}`;
      createModelSQL += `\n      HORIZON ${horizon}`;
    }

    // Add hyperparameters if provided
    if (Object.keys(hyperparameters).length > 0) {
      const hyperparametersList = Object.entries(hyperparameters)
        .map(([key, value]) => `${key}=${JSON.stringify(value)}`)
        .join(', ');
      createModelSQL += `\n      USING ${hyperparametersList}`;
    }

    const startTime = Date.now();
    const results = await this.executeQuery(createModelSQL);
    const executionTime = Date.now() - startTime;

    // Check model status after creation
    const statusQuery = `
      SELECT name, status, accuracy, update_status, training_options
      FROM models 
      WHERE name = '${modelName}'
    `;
    
    const statusResults = await this.executeQuery(statusQuery);
    const modelInfo = statusResults[0] || {};

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            status: 'success',
            operation: 'train_model',
            model: {
              name: modelName,
              status: modelInfo.status || 'training',
              accuracy: modelInfo.accuracy,
              lastUpdated: modelInfo.update_status,
              trainingOptions: modelInfo.training_options,
            },
            executionTimeMs: executionTime,
            query: createModelSQL,
          }, null, 2),
        },
      ],
    };
  }

  private async handlePredict(args: z.infer<typeof PredictToolSchema>) {
    const { modelName, inputData, horizon, explainability = false } = args;

    console.error(`Making predictions with model: ${modelName}`);

    // Handle both single object and array inputs
    const dataArray = Array.isArray(inputData) ? inputData : [inputData];
    
    // Build prediction query
    let predictSQL: string;
    
    if (dataArray.length === 1 && Object.keys(dataArray[0]).length === 0) {
      // Empty input - use for time series forecasting
      predictSQL = `
        SELECT *
        FROM ${modelName}
        ${horizon ? `LIMIT ${horizon}` : ''}
      `;
    } else {
      // With input data
      const inputColumns = Object.keys(dataArray[0]).join(', ');
      const inputValues = dataArray.map(row => 
        '(' + Object.values(row).map(value => 
          typeof value === 'string' ? `'${value}'` : value
        ).join(', ') + ')'
      ).join(', ');
      
      predictSQL = `
        SELECT *
        FROM ${modelName}
        WHERE (${inputColumns}) IN (VALUES ${inputValues})
      `;
    }

    // Add explainability if requested
    if (explainability) {
      predictSQL = `
        SELECT *, explain
        FROM (${predictSQL})
      `;
    }

    const startTime = Date.now();
    const results = await this.executeQuery(predictSQL);
    const executionTime = Date.now() - startTime;

    // Process predictions
    const predictions = results.map((row: any, index: number) => ({
      id: index + 1,
      prediction: row[Object.keys(row).find(key => key.includes('prediction') || key.includes('forecast')) || Object.keys(row)[0]],
      confidence: row.confidence || row.confidence_level || 0.5,
      explanation: explainability ? row.explain : undefined,
      metadata: {
        ...row,
        prediction: undefined,
        confidence: undefined,
        explain: undefined,
      },
    }));

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            status: 'success',
            operation: 'predict',
            model: modelName,
            predictions,
            predictionCount: predictions.length,
            executionTimeMs: executionTime,
            query: predictSQL,
          }, null, 2),
        },
      ],
    };
  }

  private async handleModelStatus(args: z.infer<typeof ModelStatusToolSchema>) {
    const { modelName, detailed = false } = args;

    console.error(`Getting model status${modelName ? ` for: ${modelName}` : ' for all models'}`);

    let statusSQL = `
      SELECT 
        name,
        status,
        accuracy,
        update_status,
        mindsdb_version,
        error,
        created_at
        ${detailed ? ', training_options, data_query' : ''}
      FROM models
    `;

    if (modelName) {
      statusSQL += ` WHERE name = '${modelName}'`;
    }

    statusSQL += ' ORDER BY created_at DESC';

    const startTime = Date.now();
    const results = await this.executeQuery(statusSQL);
    const executionTime = Date.now() - startTime;

    const models = results.map((row: any) => ({
      name: row.name,
      status: row.status,
      accuracy: row.accuracy ? parseFloat(row.accuracy) : null,
      lastUpdated: row.update_status,
      version: row.mindsdb_version,
      error: row.error,
      createdAt: row.created_at,
      ...(detailed && {
        trainingOptions: row.training_options,
        dataQuery: row.data_query,
      }),
    }));

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            status: 'success',
            operation: 'model_status',
            models: modelName ? models[0] || null : models,
            modelCount: models.length,
            executionTimeMs: executionTime,
          }, null, 2),
        },
      ],
    };
  }

  private async handleDeployModel(args: z.infer<typeof DeployModelToolSchema>) {
    const { modelName, endpoint, schedule } = args;

    console.error(`Deploying model: ${modelName}`);

    // Check model exists and is trained
    const statusQuery = `
      SELECT name, status, accuracy
      FROM models 
      WHERE name = '${modelName}'
    `;
    
    const statusResults = await this.executeQuery(statusQuery);
    if (statusResults.length === 0) {
      throw new Error(`Model '${modelName}' not found`);
    }

    const model = statusResults[0];
    if (model.status !== 'complete' && model.status !== 'training complete') {
      throw new Error(`Model '${modelName}' is not ready for deployment. Status: ${model.status}`);
    }

    const deploymentActions: string[] = [];

    // Create deployment endpoint if specified
    if (endpoint) {
      const endpointSQL = `
        CREATE OR REPLACE ENDPOINT ${modelName}_endpoint
        PREDICT ${modelName}
        ${endpoint}
      `;
      await this.executeQuery(endpointSQL);
      deploymentActions.push('endpoint_created');
    }

    // Create automated retraining job if schedule specified
    if (schedule) {
      const jobSQL = `
        CREATE OR REPLACE JOB ${modelName}_retrain_job (
          RETRAIN ${modelName}
        )
        EVERY '${schedule}'
      `;
      await this.executeQuery(jobSQL);
      deploymentActions.push('retrain_job_created');
    }

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            status: 'success',
            operation: 'deploy_model',
            model: {
              name: modelName,
              status: model.status,
              accuracy: model.accuracy,
              deployed: true,
              endpoint: endpoint ? `${modelName}_endpoint` : null,
              retrainSchedule: schedule || null,
            },
            actions: deploymentActions,
            message: `Model '${modelName}' successfully deployed`,
          }, null, 2),
        },
      ],
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Scout MindsDB MCP Server running on stdio');
  }

  async cleanup() {
    if (this.connection) {
      await this.connection.end();
      this.connection = null;
    }
  }
}

// Handle graceful shutdown
process.on('SIGINT', async () => {
  console.error('Shutting down MindsDB MCP Server...');
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.error('Shutting down MindsDB MCP Server...');
  process.exit(0);
});

// Start the server
const server = new MindsDBMCPServer();
server.run().catch((error) => {
  console.error('Failed to start MindsDB MCP Server:', error);
  process.exit(1);
});