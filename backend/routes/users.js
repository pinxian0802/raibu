/**
 * 模組 E：使用者 API
 */
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { requireAuth } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const { Errors } = require('../utils/errorCodes');

/**
 * API E-1: 取得個人資訊
 * GET /api/v1/users/me
 */
router.get('/me', requireAuth, asyncHandler(async (req, res) => {
  const userId = req.user.id;

  // 取得用戶資料
  const { data: user, error } = await supabase
    .from('users')
    .select('*')
    .eq('id', userId)
    .single();

  if (error) {
    // 用戶可能尚未建立 profile，使用 Auth 資料
    const authUser = req.user;
    return res.json({
      id: authUser.id,
      display_name: authUser.user_metadata?.display_name || authUser.email?.split('@')[0] || 'User',
      avatar_url: authUser.user_metadata?.avatar_url || null,
      total_records: 0,
      total_asks: 0,
      total_views: 0,
      created_at: authUser.created_at,
    });
  }

  // 計算統計資料
  const [recordsCount, asksCount] = await Promise.all([
    supabase
      .from('records')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId),
    supabase
      .from('asks')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId),
  ]);

  res.json({
    id: user.id,
    display_name: user.display_name,
    avatar_url: user.avatar_url,
    total_records: recordsCount.count || 0,
    total_asks: asksCount.count || 0,
    total_views: user.total_views || 0,
    created_at: user.created_at,
  });
}));

/**
 * API E-2: 取得使用者的紀錄列表
 * GET /api/v1/users/me/records
 */
router.get('/me/records', requireAuth, asyncHandler(async (req, res) => {
  const userId = req.user.id;

  const { data: records, error } = await supabase
    .from('records')
    .select('id, description, main_image_url, like_count, view_count, created_at')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (error) {
    throw Errors.internal('查詢紀錄失敗');
  }

  const formattedRecords = (records || []).map(record => ({
    id: record.id,
    description: record.description,
    thumbnail_url: record.main_image_url,
    like_count: record.like_count,
    view_count: record.view_count,
    created_at: record.created_at,
  }));

  res.json({ records: formattedRecords });
}));

/**
 * API E-3: 取得使用者的詢問列表
 * GET /api/v1/users/me/asks
 */
router.get('/me/asks', requireAuth, asyncHandler(async (req, res) => {
  const userId = req.user.id;

  const { data: asks, error } = await supabase
    .from('asks')
    .select('id, question, status, like_count, view_count, created_at')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (error) {
    throw Errors.internal('查詢詢問失敗');
  }

  res.json({ asks: asks || [] });
}));

module.exports = router;
