/**
 * Supabase Admin Client
 * 使用 service_role key，可繞過 RLS，僅供後端管理功能使用
 * 絕對不可暴露給前端
 */
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !serviceRoleKey) {
  console.warn('⚠️  SUPABASE_SERVICE_ROLE_KEY is missing — admin features will not work');
}

// 若 service role key 尚未設定，回傳一個 proxy，讓伺服器能正常啟動
// 實際呼叫 admin API 時才會報錯，不影響一般 API
let supabaseAdmin;
if (supabaseUrl && serviceRoleKey) {
  supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
} else {
  // Stub：讓伺服器啟動，admin API 呼叫時回傳 503
  supabaseAdmin = new Proxy({}, {
    get: () => () => Promise.resolve({ data: null, error: { message: 'SUPABASE_SERVICE_ROLE_KEY not configured' } }),
  });
}

module.exports = supabaseAdmin;
