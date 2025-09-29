const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const dbConnection = require('./config/database');
const analyticsRoutes = require('./routes/analytics');
const monitoringRoutes = require('./routes/monitoring');
const culturalRoutes = require('./routes/cultural');
const healthRoutes = require('./routes/health');

const app = express();
const PORT = process.env.PORT || 8080;

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // Limit each IP to 1000 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(limiter);

// Basic middleware
app.use(compression());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true
}));
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Health check endpoint (must be first)
app.use('/health', healthRoutes);

// API routes
app.use('/api/v1/analytics', analyticsRoutes);
app.use('/api/v1/monitoring', monitoringRoutes);
app.use('/api/v1/cultural', culturalRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    service: 'Scout Analytics API',
    version: '1.0.0',
    status: 'operational',
    timestamp: new Date().toISOString(),
    endpoints: {
      health: '/health',
      analytics: '/api/v1/analytics',
      monitoring: '/api/v1/monitoring',
      cultural: '/api/v1/cultural'
    },
    documentation: {
      swagger: '/api/docs',
      readme: 'https://github.com/tbwa/scout-v7/tree/main/apps/dal-agent'
    }
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.originalUrl} not found`,
    availableEndpoints: ['/health', '/api/v1/analytics', '/api/v1/monitoring', '/api/v1/cultural']
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);

  const isDevelopment = process.env.NODE_ENV === 'development';

  res.status(err.status || 500).json({
    error: err.message || 'Internal Server Error',
    timestamp: new Date().toISOString(),
    path: req.originalUrl,
    method: req.method,
    ...(isDevelopment && { stack: err.stack })
  });
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully...');

  try {
    await dbConnection.close();
    console.log('Database connections closed');
  } catch (error) {
    console.error('Error closing database connections:', error);
  }

  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully...');

  try {
    await dbConnection.close();
    console.log('Database connections closed');
  } catch (error) {
    console.error('Error closing database connections:', error);
  }

  process.exit(0);
});

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Scout Analytics API running on port ${PORT}`);
  console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🗄️  Database: ${process.env.AZURE_SQL_DATABASE}`);
  console.log(`🏥 Health check: http://localhost:${PORT}/health`);
  console.log(`📚 API docs: http://localhost:${PORT}/api/v1`);
});

// Handle server errors
server.on('error', (error) => {
  if (error.syscall !== 'listen') {
    throw error;
  }

  const bind = typeof PORT === 'string' ? 'Pipe ' + PORT : 'Port ' + PORT;

  switch (error.code) {
    case 'EACCES':
      console.error(bind + ' requires elevated privileges');
      process.exit(1);
      break;
    case 'EADDRINUSE':
      console.error(bind + ' is already in use');
      process.exit(1);
      break;
    default:
      throw error;
  }
});

module.exports = app;