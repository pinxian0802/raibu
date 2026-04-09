/**
 * Admin 認證 Middleware
 * 用簡單的 secret token 保護 /admin 路由
 * Token 設定在環境變數 ADMIN_SECRET
 */

/**
 * 驗證管理者 session（瀏覽器 cookie / session）
 * 這裡使用最簡單的 token 比對方式
 */
function requireAdminSession(req, res, next) {
  const adminSecret = process.env.ADMIN_SECRET;

  if (!adminSecret) {
    return res.status(500).send('Admin secret not configured');
  }

  // 從 cookie 讀取 session token
  const cookieHeader = req.headers.cookie || '';
  const cookies = Object.fromEntries(
    cookieHeader.split(';').map(c => {
      const [k, ...v] = c.trim().split('=');
      return [k, v.join('=')];
    })
  );

  if (cookies['admin_token'] === adminSecret) {
    return next();
  }

  // 未登入，導向登入頁
  return res.redirect('/admin/login');
}

/**
 * 驗證管理者 API 請求（用 Bearer token 或 X-Admin-Token header）
 */
function requireAdminToken(req, res, next) {
  const adminSecret = process.env.ADMIN_SECRET;

  if (!adminSecret) {
    return res.status(500).json({ error: 'Admin secret not configured' });
  }

  const token =
    req.headers['x-admin-token'] ||
    (req.headers.authorization?.startsWith('Bearer ') ? req.headers.authorization.slice(7) : null);

  if (token === adminSecret) {
    return next();
  }

  return res.status(401).json({ error: '未授權' });
}

module.exports = { requireAdminSession, requireAdminToken };
