#!/bin/bash

# Scout Analytics - Backend Bootstrap Script
# Pulls and configures backend components from multiple sources

set -euo pipefail

BACKEND_DIR="${1:-backend}"
CONFIG_FILE="${2:-bootstrap-config.yaml}"

echo "⚙️ Bootstrapping Backend Components..."

# Create backend structure
mkdir -p "$BACKEND_DIR"/{src/{controllers,services,middleware,routes,models,utils,database},tests,scripts}

# Create base backend files
cat > "$BACKEND_DIR/package.json" << 'EOF'
{
  "name": "scout-analytics-backend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "main": "dist/index.js",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "vitest",
    "test:integration": "vitest run --config vitest.integration.config.ts",
    "lint": "eslint . --ext ts --report-unused-disable-directives --max-warnings 0",
    "type-check": "tsc --noEmit",
    "db:migrate": "tsx src/database/migrate.ts",
    "db:seed": "tsx src/database/seed.ts"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "express-rate-limit": "^7.1.5",
    "dotenv": "^16.3.1",
    "joi": "^17.11.0",
    "pg": "^8.11.3",
    "redis": "^4.6.12",
    "@azure/openai": "^1.0.0-beta.11",
    "@azure/storage-blob": "^12.17.0",
    "@azure/identity": "^4.0.0",
    "winston": "^3.11.0",
    "express-winston": "^4.2.0",
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3",
    "date-fns": "^3.0.0",
    "node-cron": "^3.0.3",
    "socket.io": "^4.6.0"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/cors": "^2.8.17",
    "@types/node": "^20.10.5",
    "@types/pg": "^8.10.9",
    "@types/bcryptjs": "^2.4.6",
    "@types/jsonwebtoken": "^9.0.5",
    "@typescript-eslint/eslint-plugin": "^6.14.0",
    "@typescript-eslint/parser": "^6.14.0",
    "eslint": "^8.55.0",
    "tsx": "^4.7.0",
    "typescript": "^5.3.3",
    "vitest": "^1.0.0",
    "@types/supertest": "^6.0.0",
    "supertest": "^6.3.3"
  }
}
EOF

# Create TypeScript configuration
cat > "$BACKEND_DIR/tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "lib": ["ES2022"],
    "moduleResolution": "node",
    "rootDir": "./src",
    "outDir": "./dist",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    },
    "types": ["node", "express", "jest"]
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
EOF

# Create main server file
cat > "$BACKEND_DIR/src/index.ts" << 'EOF'
import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import rateLimit from 'express-rate-limit'
import { config } from 'dotenv'
import { createServer } from 'http'
import { Server } from 'socket.io'
import winston from 'winston'
import expressWinston from 'express-winston'

// Import routes
import analyticsRoutes from './routes/analytics'
import transactionRoutes from './routes/transactions'
import productRoutes from './routes/products'
import consumerRoutes from './routes/consumers'
import aiRoutes from './routes/ai'
import medallionRoutes from './routes/medallion'

// Import middleware
import { errorHandler } from './middleware/errorHandler'
import { authentication } from './middleware/authentication'
import { requestValidation } from './middleware/validation'

// Load environment variables
config()

// Create Express app
const app = express()
const httpServer = createServer(app)

// Create Socket.IO server for real-time updates
const io = new Server(httpServer, {
  cors: {
    origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
    credentials: true,
  },
})

// Configure Winston logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  defaultMeta: { service: 'scout-analytics-backend' },
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
  ],
})

if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.simple(),
  }))
}

// Middleware
app.use(helmet())
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
  credentials: true,
}))
app.use(express.json())
app.use(express.urlencoded({ extended: true }))

// Request logging
app.use(expressWinston.logger({
  transports: [
    new winston.transports.Console()
  ],
  format: winston.format.combine(
    winston.format.colorize(),
    winston.format.json()
  ),
  meta: true,
  msg: "HTTP {{req.method}} {{req.url}}",
  expressFormat: true,
  colorize: false,
}))

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
})
app.use('/api', limiter)

// API Routes
app.use('/api/analytics', analyticsRoutes)
app.use('/api/transactions', transactionRoutes)
app.use('/api/products', productRoutes)
app.use('/api/consumers', consumerRoutes)
app.use('/api/ai', aiRoutes)
app.use('/api/medallion', medallionRoutes)

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  })
})

// Error handling
app.use(expressWinston.errorLogger({
  transports: [
    new winston.transports.Console()
  ],
  format: winston.format.combine(
    winston.format.colorize(),
    winston.format.json()
  )
}))

app.use(errorHandler)

// Socket.IO connection handling
io.on('connection', (socket) => {
  logger.info('Client connected:', socket.id)

  socket.on('subscribe', (channel) => {
    socket.join(channel)
    logger.info(`Client ${socket.id} subscribed to ${channel}`)
  })

  socket.on('unsubscribe', (channel) => {
    socket.leave(channel)
    logger.info(`Client ${socket.id} unsubscribed from ${channel}`)
  })

  socket.on('disconnect', () => {
    logger.info('Client disconnected:', socket.id)
  })
})

// Export io instance for use in other modules
export { io }

// Start server
const PORT = process.env.PORT || 3001
httpServer.listen(PORT, () => {
  logger.info(`Server running on port ${PORT}`)
  logger.info(`Environment: ${process.env.NODE_ENV}`)
})

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server')
  httpServer.close(() => {
    logger.info('HTTP server closed')
  })
})
EOF

# Create database connection
cat > "$BACKEND_DIR/src/database/connection.ts" << 'EOF'
import { Pool } from 'pg'
import { createClient } from 'redis'
import winston from 'winston'

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  defaultMeta: { service: 'database' },
})

// PostgreSQL connection pool
export const pgPool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
})

// Redis client
export const redisClient = createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379',
})

redisClient.on('error', (err) => {
  logger.error('Redis Client Error', err)
})

// Initialize connections
export async function initializeDatabase() {
  try {
    // Test PostgreSQL connection
    await pgPool.query('SELECT NOW()')
    logger.info('PostgreSQL connected successfully')

    // Connect to Redis
    await redisClient.connect()
    logger.info('Redis connected successfully')

    return true
  } catch (error) {
    logger.error('Database initialization failed:', error)
    throw error
  }
}

// Graceful shutdown
export async function closeDatabase() {
  await pgPool.end()
  await redisClient.quit()
  logger.info('Database connections closed')
}
EOF

# Create sample controller
cat > "$BACKEND_DIR/src/controllers/AnalyticsController.ts" << 'EOF'
import { Request, Response, NextFunction } from 'express'
import { AnalyticsService } from '../services/AnalyticsService'
import { FilterProcessor } from '../services/FilterProcessor'
import { CacheService } from '../services/CacheService'

export class AnalyticsController {
  constructor(
    private analyticsService: AnalyticsService,
    private filterProcessor: FilterProcessor,
    private cacheService: CacheService
  ) {}

  async getDashboardAnalytics(req: Request, res: Response, next: NextFunction) {
    try {
      const filters = this.filterProcessor.parseFilters(req.query)
      const cacheKey = this.cacheService.generateKey('dashboard', filters)
      
      // Check cache first
      let result = await this.cacheService.get(cacheKey)
      
      if (!result) {
        // Fetch fresh data
        result = await this.analyticsService.getDashboardData(filters)
        
        // Cache for 5 minutes
        await this.cacheService.set(cacheKey, result, 300)
      }
      
      res.json({
        success: true,
        data: result,
        meta: {
          cached: !!result,
          timestamp: new Date().toISOString(),
          filters: filters,
        }
      })
    } catch (error) {
      next(error)
    }
  }

  async getTransactionTrends(req: Request, res: Response, next: NextFunction) {
    try {
      const filters = this.filterProcessor.parseFilters(req.query)
      const { granularity = 'hour' } = req.query
      
      const trends = await this.analyticsService.getTransactionTrends({
        filters,
        granularity: granularity as string,
      })
      
      res.json({
        success: true,
        data: trends,
      })
    } catch (error) {
      next(error)
    }
  }

  async getProductPerformance(req: Request, res: Response, next: NextFunction) {
    try {
      const filters = this.filterProcessor.parseFilters(req.query)
      
      const performance = await this.analyticsService.getProductPerformance(filters)
      
      res.json({
        success: true,
        data: performance,
      })
    } catch (error) {
      next(error)
    }
  }
}
EOF

# Create medallion architecture routes
cat > "$BACKEND_DIR/src/routes/medallion.ts" << 'EOF'
import { Router } from 'express'
import { MedallionController } from '../controllers/MedallionController'
import { authentication } from '../middleware/authentication'
import { validateQuery } from '../middleware/validation'

const router = Router()
const controller = new MedallionController()

// Bronze layer endpoints
router.get('/bronze/raw', authentication, controller.getBronzeData)
router.post('/bronze/ingest', authentication, controller.ingestBronzeData)

// Silver layer endpoints
router.get('/silver/validated', authentication, controller.getSilverData)
router.post('/silver/process', authentication, controller.processSilverData)

// Gold layer endpoints
router.get('/gold/analytics', controller.getGoldAnalytics)
router.get('/gold/kpis', controller.getGoldKPIs)
router.get('/gold/trends', controller.getGoldTrends)

// Unified analytics endpoint
router.get('/analytics', validateQuery, controller.getUnifiedAnalytics)

export default router
EOF

echo "✅ Backend bootstrap completed successfully!"