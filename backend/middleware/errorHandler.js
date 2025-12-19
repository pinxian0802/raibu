/**
 * 統一錯誤處理中間件
 * 符合系統框架規格書 3.0 節格式
 */
const { ApiError, Errors, ErrorCodes } = require('../utils/errorCodes');

/**
 * 全域錯誤處理中間件
 */
function errorHandler(err, req, res, next) {
  // 記錄錯誤
  console.error('Error:', {
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  // 如果是 ApiError，使用其格式
  if (err instanceof ApiError) {
    return res.status(err.httpStatus).json(err.toJSON());
  }

  // 處理 Supabase 特定錯誤
  if (err.code) {
    // PostgreSQL 唯一約束違反
    if (err.code === '23505') {
      const error = Errors.invalidArgument('資源已存在', { 
        constraint: err.constraint 
      });
      return res.status(error.httpStatus).json(error.toJSON());
    }
    
    // 外鍵約束違反
    if (err.code === '23503') {
      const error = Errors.invalidArgument('參照的資源不存在');
      return res.status(error.httpStatus).json(error.toJSON());
    }
  }

  // 處理 JSON 解析錯誤
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    const error = Errors.invalidArgument('無效的 JSON 格式');
    return res.status(error.httpStatus).json(error.toJSON());
  }

  // 預設為內部錯誤
  const error = Errors.internal(
    process.env.NODE_ENV === 'production' 
      ? '伺服器內部錯誤' 
      : err.message
  );
  return res.status(error.httpStatus).json(error.toJSON());
}

/**
 * 404 處理中間件
 */
function notFoundHandler(req, res) {
  const error = Errors.notFound(`路徑 ${req.path} 不存在`);
  return res.status(error.httpStatus).json(error.toJSON());
}

/**
 * 非同步路由包裝器
 * 自動捕獲 async 函數的錯誤
 */
function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

module.exports = {
  errorHandler,
  notFoundHandler,
  asyncHandler,
};
