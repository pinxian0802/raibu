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

      // 檢查是否被管理者封鎖（只在強制認證的路由才查，避免不必要的 DB 請求）
      if (required) {
        try {
          const { data: profile } = await supabase
            .from('users')
            .select('is_banned')
            .eq('id', user.id)
            .single();

          // profile 可能為 null（新用戶尚未建立 profile）
          // is_banned 欄位可能不存在（migration 尚未執行），此時 profile.is_banned = undefined → falsy → 安全
          if (profile?.is_banned === true) {
            return res.status(403).json({
              error: {
                code: 'ACCOUNT_BANNED',
                message: '您的帳號已被封鎖，如有疑問請聯繫客服',
              },
            });
          }
        } catch (banCheckErr) {
          // is_banned 查詢失敗不應中斷正常流程（例如欄位尚未 migration）
          // 只記錄 warning，繼續放行
          console.warn('is_banned check failed (migration pending?):', banCheckErr.message);
        }
      }

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
