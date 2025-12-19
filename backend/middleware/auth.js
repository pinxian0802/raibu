/**
 * JWT 認證中間件
 * 使用 Supabase Auth 驗證用戶身份
 */
const supabase = require('../config/supabase');
const { Errors } = require('../utils/errorCodes');

/**
 * 驗證 JWT Token 並附加用戶資訊到 req.user
 * @param {boolean} required - 是否強制要求認證
 */
function authenticate(required = true) {
  return async (req, res, next) => {
    try {
      // 🧪 測試模式：如果環境變數有設定 TEST_USER_ID，則直接模擬該用戶
      if (process.env.NODE_ENV !== 'production' && process.env.TEST_USER_ID) {
        req.user = { id: process.env.TEST_USER_ID };
        return next();
      }

      const authHeader = req.headers.authorization;
      
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        if (required) {
          const error = Errors.unauthenticated('缺少認證 Token');
          return res.status(error.httpStatus).json(error.toJSON());
        }
        // 非必要認證，繼續處理
        req.user = null;
        return next();
      }

      const token = authHeader.split(' ')[1];
      
      // 使用 Supabase 驗證 Token
      const { data: { user }, error } = await supabase.auth.getUser(token);

      if (error || !user) {
        if (required) {
          const apiError = Errors.unauthenticated('Token 無效或已過期');
          return res.status(apiError.httpStatus).json(apiError.toJSON());
        }
        req.user = null;
        return next();
      }

      // 附加用戶資訊到請求
      req.user = user;
      next();

    } catch (err) {
      console.error('Auth middleware error:', err);
      const error = Errors.internal('認證過程發生錯誤');
      return res.status(error.httpStatus).json(error.toJSON());
    }
  };
}

/**
 * 必須認證的中間件（簡化版）
 */
const requireAuth = authenticate(true);

/**
 * 可選認證的中間件（簡化版）
 */
const optionalAuth = authenticate(false);

module.exports = {
  authenticate,
  requireAuth,
  optionalAuth,
};
