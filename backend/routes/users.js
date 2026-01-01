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
  const [recordsResult, asksResult, recordsViewsResult, asksViewsResult] = await Promise.all([
    // 紀錄數量
    supabase
      .from('records')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId),
    // 詢問數量
    supabase
      .from('asks')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId),
    // 紀錄的總觀看次數
    supabase
      .from('records')
      .select('view_count')
      .eq('user_id', userId),
    // 詢問的總觀看次數
    supabase
      .from('asks')
      .select('view_count')
      .eq('user_id', userId),
  ]);

  // 計算總觀看次數
  const recordsViews = (recordsViewsResult.data || []).reduce((sum, r) => sum + (r.view_count || 0), 0);
  const asksViews = (asksViewsResult.data || []).reduce((sum, a) => sum + (a.view_count || 0), 0);
  const totalViews = recordsViews + asksViews;

  res.json({
    id: user.id,
    display_name: user.display_name,
    avatar_url: user.avatar_url,
    total_records: recordsResult.count || 0,
    total_asks: asksResult.count || 0,
    total_views: totalViews,
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
    .select('id, user_id, description, main_image_url, media_count, like_count, view_count, created_at, updated_at')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (error) {
    throw Errors.internal('查詢紀錄失敗');
  }

  const formattedRecords = (records || []).map(record => ({
    id: record.id,
    user_id: record.user_id,
    description: record.description,
    main_image_url: record.main_image_url,
    media_count: record.media_count || 0,
    like_count: record.like_count || 0,
    view_count: record.view_count || 0,
    created_at: record.created_at,
    updated_at: record.updated_at,
  }));

  res.json({ records: formattedRecords });
}));

/**
 * API E-3: 取得使用者的詢問列表
 * GET /api/v1/users/me/asks
 */
router.get('/me/asks', requireAuth, asyncHandler(async (req, res) => {
  const userId = req.user.id;

  // 使用 RPC 取得有 center 座標的 asks
  const { data: asksWithCoords, error: rpcError } = await supabase.rpc('get_user_asks_with_coords', {
    p_user_id: userId,
  });

  if (rpcError) {
    // RPC 不存在時使用基本查詢
    console.warn('RPC not available, using basic query');
    const { data: asks, error } = await supabase
      .from('asks')
      .select('id, user_id, question, radius_meters, main_image_url, status, like_count, view_count, created_at, updated_at')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (error) {
      throw Errors.internal('查詢詢問失敗');
    }

    // 沒有 RPC 時無法取得 center 座標，使用預設值
    const formattedAsks = (asks || []).map(ask => ({
      id: ask.id,
      user_id: ask.user_id,
      center: { lat: 0, lng: 0 },  // 預設值
      radius_meters: ask.radius_meters,
      question: ask.question,
      main_image_url: ask.main_image_url,
      status: ask.status,
      like_count: ask.like_count || 0,
      view_count: ask.view_count || 0,
      created_at: ask.created_at,
      updated_at: ask.updated_at,
    }));

    res.json({ asks: formattedAsks });
    return;
  }

  // 轉換 RPC 回應格式
  const formattedAsks = (asksWithCoords || []).map(ask => ({
    id: ask.id,
    user_id: ask.user_id,
    center: {
      lat: ask.lat,
      lng: ask.lng,
    },
    radius_meters: ask.radius_meters,
    question: ask.question,
    main_image_url: ask.main_image_url,
    status: ask.status,
    like_count: ask.like_count || 0,
    view_count: ask.view_count || 0,
    created_at: ask.created_at,
    updated_at: ask.updated_at,
  }));

  res.json({ asks: formattedAsks });
}));

module.exports = router;
