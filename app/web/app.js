// ============================================
// OpenTelemetry Initialization (MUST BE FIRST)
// ============================================
const { NodeSDK } = require("@opentelemetry/sdk-node");
const { getNodeAutoInstrumentations } = require("@opentelemetry/auto-instrumentations-node");
const { OTLPTraceExporter } = require("@opentelemetry/exporter-trace-otlp-http");
const { OTLPMetricExporter } = require("@opentelemetry/exporter-metrics-otlp-http");
const { PeriodicExportingMetricReader } = require("@opentelemetry/sdk-metrics");
const { resourceFromAttributes } = require("@opentelemetry/resources");
const { SemanticResourceAttributes } = require("@opentelemetry/semantic-conventions");

const traceExporter = new OTLPTraceExporter({
  url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || "http://jaeger:4318/v1/traces",
});

const metricExporter = new OTLPMetricExporter({
  url: process.env.OTEL_EXPORTER_OTLP_METRIC_ENDPOINT || "http://jaeger:4318/v1/metrics",
});

const resource = resourceFromAttributes({
  [SemanticResourceAttributes.SERVICE_NAME]: "express-app",
});

const sdk = new NodeSDK({
  resource,
  traceExporter,
  metricReader: new PeriodicExportingMetricReader({
    exporter: metricExporter,
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      "@opentelemetry/instrumentation-fs": { enabled: false },
      "@opentelemetry/instrumentation-http": { enabled: true },
      "@opentelemetry/instrumentation-express": { enabled: true },
      "@opentelemetry/instrumentation-mysql2": { enabled: true },
      "@opentelemetry/instrumentation-mysql": { enabled: true },
    }),
  ],
});

sdk.start();

console.log("OpenTelemetry SDK initialized");

// ============================================
// Dependencies
// ============================================
const express = require("express");
const mysql = require("mysql2/promise");
const { register, Counter, Histogram, Gauge } = require("prom-client");
const winston = require("winston");
const { v4: uuidv4 } = require("uuid");
const { trace, context } = require("@opentelemetry/api");

// ============================================
// Logger Configuration (Structured JSON Logs)
// ============================================
const logger = winston.createLogger({
  format: winston.format.combine(
    winston.format.timestamp({ format: "YYYY-MM-DD HH:mm:ss.SSS" }),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: "express-app" },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp({ format: "YYYY-MM-DD HH:mm:ss.SSS" }),
        winston.format.json()
      ),
    }),
  ],
});

// ============================================
// Prometheus Metrics (RED Pattern)
// ============================================
const httpRequestDuration = new Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["route", "method", "status_code"],
  buckets: [0.1, 0.5, 1, 2, 5],
});

const httpRequestTotal = new Counter({
  name: "http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["route", "method", "status_code"],
});

const httpErrorsTotal = new Counter({
  name: "http_errors_total",
  help: "Total number of HTTP errors (5xx)",
  labelNames: ["route", "method"],
});

const activeConnections = new Gauge({
  name: "http_active_connections",
  help: "Number of active connections",
});

// ============================================
// Express Application
// ============================================
const app = express();
const PORT = process.env.PORT || 5000;

const dbConfig = {
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
};

// ============================================
// Middleware: Extract trace context & log requests
// ============================================
app.use((req, res, next) => {
  const startTime = Date.now();
  
  // Extract or create trace_id and span_id from OTel context
  const activeSpan = trace.getActiveSpan();
  const traceId = activeSpan?.spanContext().traceId || uuidv4().replace(/-/g, "").slice(0, 32);
  const spanId = activeSpan?.spanContext().spanId || uuidv4().replace(/-/g, "").slice(0, 16);
  
  // Attach to request for logging
  req.traceId = traceId;
  req.spanId = spanId;
  
  activeConnections.inc();

  res.on("finish", () => {
    const duration = (Date.now() - startTime) / 1000;
    const route = req.route?.path || req.path;
    const statusCode = res.statusCode;

    // Record metrics
    httpRequestDuration.labels(route, req.method, statusCode).observe(duration);
    httpRequestTotal.labels(route, req.method, statusCode).inc();

    if (statusCode >= 500) {
      httpErrorsTotal.labels(route, req.method).inc();
    }

    activeConnections.dec();

    // Structured JSON log
    logger.info("HTTP request completed", {
      trace_id: traceId,
      span_id: spanId,
      method: req.method,
      path: req.path,
      route: route,
      status_code: statusCode,
      duration_ms: Math.round(duration * 1000),
      timestamp: new Date().toISOString(),
    });
  });

  next();
});

// ============================================
// Routes
// ============================================

// GET / — health check
app.get("/", (req, res) => {
  logger.info("Health check", {
    trace_id: req.traceId,
    span_id: req.spanId,
  });
  
  res.json({
    status: "ok",
    message: "Express + MySQL app is running with full observability",
    timestamp: new Date().toISOString(),
    traceId: req.traceId,
  });
});

// GET /users — fetch all users from DB
app.get("/users", async (req, res) => {
  const span = trace.getActiveSpan();
  
  try {
    logger.info("Fetching users from database", {
      trace_id: req.traceId,
      span_id: req.spanId,
    });

    const connection = await mysql.createConnection(dbConfig);
    const [rows] = await connection.execute("SELECT * FROM users");
    await connection.end();

    logger.info("Users fetched successfully", {
      trace_id: req.traceId,
      span_id: req.spanId,
      user_count: rows.length,
    });

    res.json({ users: rows, traceId: req.traceId });
  } catch (err) {
    logger.error("Error fetching users", {
      trace_id: req.traceId,
      span_id: req.spanId,
      error: err.message,
      stack: err.stack,
    });
    res.status(500).json({ error: err.message, traceId: req.traceId });
  }
});

// GET /health — db connectivity check
app.get("/health", async (req, res) => {
  try {
    logger.info("Health check: testing database connection", {
      trace_id: req.traceId,
      span_id: req.spanId,
    });

    const connection = await mysql.createConnection(dbConfig);
    await connection.ping();
    await connection.end();

    logger.info("Database connection healthy", {
      trace_id: req.traceId,
      span_id: req.spanId,
    });

    res.json({ status: "ok", database: "connected", traceId: req.traceId });
  } catch (err) {
    logger.error("Database connection failed", {
      trace_id: req.traceId,
      span_id: req.spanId,
      error: err.message,
    });
    res.status(500).json({
      status: "error",
      database: err.message,
      traceId: req.traceId,
    });
  }
});

// GET /slow — simulate slow endpoint (for testing)
app.get("/slow", async (req, res) => {
  const delay = Math.random() * 1500 + 500; // 500-2000ms
  
  logger.info("Slow endpoint called", {
    trace_id: req.traceId,
    span_id: req.spanId,
    delay_ms: Math.round(delay),
  });

  try {
    const connection = await mysql.createConnection(dbConfig);
    
    // Simulate slow query
    await new Promise((resolve) => setTimeout(resolve, delay));
    
    const [rows] = await connection.execute(
      "SELECT 'slow query result' as message"
    );
    await connection.end();

    logger.info("Slow endpoint completed", {
      trace_id: req.traceId,
      span_id: req.spanId,
      delay_ms: Math.round(delay),
    });

    res.json({ message: "slow request completed", delay_ms: Math.round(delay), traceId: req.traceId });
  } catch (err) {
    logger.error("Slow endpoint error", {
      trace_id: req.traceId,
      span_id: req.spanId,
      error: err.message,
    });
    res.status(500).json({ error: err.message, traceId: req.traceId });
  }
});

// GET /error — simulate error endpoint
app.get("/error", (req, res) => {
  logger.warn("Error endpoint triggered", {
    trace_id: req.traceId,
    span_id: req.spanId,
  });

  res.status(500).json({
    error: "This is a simulated error for testing",
    traceId: req.traceId,
  });
});

// GET /metrics — Prometheus metrics endpoint
app.get("/metrics", async (req, res) => {
  try {
    res.set("Content-Type", register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err);
  }
});

// ============================================
// Server Start
// ============================================
app.listen(PORT, () => {
  logger.info("Express server started", {
    port: PORT,
    timestamp: new Date().toISOString(),
  });
  console.log(`Server running on port ${PORT}`);
  console.log(`Metrics available at http://localhost:${PORT}/metrics`);
});

// ============================================
// Graceful Shutdown
// ============================================
process.on("SIGTERM", async () => {
  logger.info("SIGTERM received, shutting down gracefully");
  await sdk.shutdown();
  process.exit(0);
});
