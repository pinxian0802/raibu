/**
 * 結構化日誌模組
 * 使用 pino 提供高效能的 JSON 日誌
 */
const pino = require('pino');

// 判斷是否為開發環境
const isDevelopment = process.env.NODE_ENV !== 'production';

// 建立 logger 實例
const logger = pino({
  level: process.env.LOG_LEVEL || (isDevelopment ? 'debug' : 'info'),
  
  // 開發環境使用 pino-pretty 美化輸出
  transport: isDevelopment ? {
    target: 'pino-pretty',
    options: {
      colorize: true,
      translateTime: 'SYS:standard',
      ignore: 'pid,hostname',
    }
  } : undefined,
  
  // 正式環境使用 JSON 格式
  formatters: {
    level: (label) => {
      return { level: label };
    },
  },
  
  // 基礎欄位
  base: {
    service: 'raibu-api',
    version: process.env.npm_package_version || '1.0.0',
  },
});

/**
 * 建立帶有請求上下文的 child logger
 * @param {Object} req - Express request 物件
 * @returns {Object} Child logger
 */
function createRequestLogger(req) {
  return logger.child({
    requestId: req.headers['x-request-id'] || generateRequestId(),
    method: req.method,
    path: req.path,
    userId: req.user?.id || 'anonymous',
  });
}

/**
 * 產生請求 ID
 */
function generateRequestId() {
  return `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * 請求日誌中間件
 */
function requestLogger(req, res, next) {
  const startTime = Date.now();
  const requestLogger = createRequestLogger(req);
  
  // 將 logger 附加到 request
  req.log = requestLogger;
  
  // 記錄請求開始
  requestLogger.info({
    type: 'request_start',
    query: req.query,
    body: sanitizeBody(req.body),
  }, `→ ${req.method} ${req.path}`);
  
  // 監聽回應完成
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    const logData = {
      type: 'request_end',
      statusCode: res.statusCode,
      duration: `${duration}ms`,
    };
    
    if (res.statusCode >= 400) {
      requestLogger.warn(logData, `← ${res.statusCode} ${req.method} ${req.path} (${duration}ms)`);
    } else {
      requestLogger.info(logData, `← ${res.statusCode} ${req.method} ${req.path} (${duration}ms)`);
    }
  });
  
  next();
}

/**
 * 清理敏感資料（不記錄密碼等）
 */
function sanitizeBody(body) {
  if (!body) return undefined;
  
  const sanitized = { ...body };
  const sensitiveFields = ['password', 'token', 'secret', 'api_key', 'accessToken', 'refreshToken'];
  
  for (const field of sensitiveFields) {
    if (sanitized[field]) {
      sanitized[field] = '[REDACTED]';
    }
  }
  
  return sanitized;
}

// 常用日誌方法快捷函數
const log = {
  debug: (msg, data = {}) => logger.debug(data, msg),
  info: (msg, data = {}) => logger.info(data, msg),
  warn: (msg, data = {}) => logger.warn(data, msg),
  error: (msg, data = {}) => logger.error(data, msg),
  
  // 資料庫操作日誌
  db: {
    query: (operation, table, data = {}) => 
      logger.debug({ type: 'db_query', operation, table, ...data }, `DB: ${operation} ${table}`),
    error: (operation, table, error) => 
      logger.error({ type: 'db_error', operation, table, error: error.message }, `DB Error: ${operation} ${table}`),
  },
  
  // 外部服務日誌
  external: {
    request: (service, operation, data = {}) =>
      logger.debug({ type: 'external_request', service, operation, ...data }, `External: ${service} ${operation}`),
    error: (service, operation, error) =>
      logger.error({ type: 'external_error', service, operation, error: error.message }, `External Error: ${service} ${operation}`),
  },
  
  // 認證相關日誌
  auth: {
    success: (userId, action) =>
      logger.info({ type: 'auth_success', userId, action }, `Auth: ${action} success for ${userId}`),
    failure: (action, reason) =>
      logger.warn({ type: 'auth_failure', action, reason }, `Auth: ${action} failed - ${reason}`),
  },
};

module.exports = {
  logger,
  log,
  requestLogger,
  createRequestLogger,
};
