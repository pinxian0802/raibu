/**
 * 模組 C：詢問模式 API
 */
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { requireAuth, optionalAuth } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const { Errors } = require('../utils/errorCodes');
const { isValidCoordinate } = require('../utils/geo');
const { deleteObjects } = require('../utils/r2Helpers');

/**
 * API C-1: 建立詢問標點
 * POST /api/v1/asks
 */
router.post('/', requireAuth, asyncHandler(async (req, res) => {
  const { center, radius_meters, question, images } = req.body;
  const userId = req.user.id;

  // 驗證必填欄位
  if (!center || !isValidCoordinate(center.lat, center.lng)) {
    throw Errors.invalidArgument('需要提供有效的中心座標');
  }

  if (!question || typeof question !== 'string') {
    throw Errors.invalidArgument('question 為必填欄位');
  }

  // 驗證圖片數量（詢問模式最多 5 張）
  if (images && images.length > 5) {
    throw Errors.resourceExhausted('詢問模式最多 5 張圖片', { limit: 5 });
  }

  // 如果有圖片，驗證 upload_id 歸屬
  if (images && images.length > 0) {
    const uploadIds = images.map(img => img.upload_id);
    const { data: pendingImages } = await supabase
      .from('image_media')
      .select('id')
      .in('id', uploadIds)
      .eq('user_id', userId)
      .eq('status', 'PENDING');

    if (!pendingImages || pendingImages.length !== uploadIds.length) {
      throw Errors.permissionDenied('部分圖片不屬於當前用戶');
    }
  }

  // 使用 RPC 建立 Ask（包含 PostGIS Point）
  const { data: ask, error: askError } = await supabase.rpc('create_ask', {
    p_user_id: userId,
    p_lng: center.lng,
    p_lat: center.lat,
    p_radius_meters: radius_meters || 500,
    p_question: question,
  });

  // 如果 RPC 不存在，使用普通 insert（需要在 Supabase 設定 PostGIS）
  let askId;
  if (askError) {
    console.warn('RPC not available, using raw SQL');
    const { data, error } = await supabase
      .from('asks')
      .insert({
        user_id: userId,
        radius_meters: radius_meters || 500,
        question,
      })
      .select('id')
      .single();

    if (error) throw Errors.internal('建立詢問失敗');
    askId = data.id;
  } else {
    askId = ask;
  }

  // 關聯圖片
  let mainImageUrl = null;
  if (images && images.length > 0) {
    for (const img of images) {
      await supabase
        .from('image_media')
        .update({
          ask_id: askId,
          status: 'COMPLETED',
          display_order: img.display_order || 0,
        })
        .eq('id', img.upload_id);
    }

    // 取得首圖 URL
    const firstImage = images.find(img => img.display_order === 0) || images[0];
    const { data: imgData } = await supabase
      .from('image_media')
      .select('thumbnail_public_url')
      .eq('id', firstImage.upload_id)
      .single();
    mainImageUrl = imgData?.thumbnail_public_url;

    // 更新 main_image_url
    await supabase
      .from('asks')
      .update({ main_image_url: mainImageUrl })
      .eq('id', askId);
  }

  // 取得完整的 Ask 資料回傳
  const { data: createdAsk, error: fetchError } = await supabase
    .from('asks')
    .select('*')
    .eq('id', askId)
    .single();

  if (fetchError || !createdAsk) {
    throw Errors.internal('取得建立的詢問失敗');
  }

  res.status(201).json({
    id: createdAsk.id,
    user_id: createdAsk.user_id,
    question: createdAsk.question,
    center,
    radius_meters: createdAsk.radius_meters,
    main_image_url: mainImageUrl,
    status: createdAsk.status,
    like_count: createdAsk.like_count || 0,
    view_count: createdAsk.view_count || 0,
    created_at: createdAsk.created_at,
    updated_at: createdAsk.updated_at,
  });
}));

/**
 * API C-2: 取得地圖範圍內的詢問標點
 * GET /api/v1/asks/map
 */
router.get('/map', asyncHandler(async (req, res) => {
  const { min_lat, max_lat, min_lng, max_lng } = req.query;

  if (!min_lat || !max_lat || !min_lng || !max_lng) {
    throw Errors.invalidArgument('需要提供 min_lat, max_lat, min_lng, max_lng');
  }

  // 使用 RPC 進行空間查詢 + 48 小時過濾
  const { data, error } = await supabase.rpc('get_asks_in_bounds', {
    p_min_lng: parseFloat(min_lng),
    p_min_lat: parseFloat(min_lat),
    p_max_lng: parseFloat(max_lng),
    p_max_lat: parseFloat(max_lat),
  });

  if (error) {
    // 如果 RPC 不存在，使用基本查詢（不含空間過濾）
    console.warn('RPC not available, using basic query');
    const cutoffTime = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();

    const { data: asks, error: queryError } = await supabase
      .from('asks')
      .select('id, question, radius_meters, status, created_at')
      .gte('created_at', cutoffTime)
      .order('created_at', { ascending: false });

    if (queryError) throw Errors.internal('查詢失敗');

    // 由於沒有 PostGIS，無法取得座標，回傳空陣列
    res.json({ asks: [] });
    return;
  }

  // 轉換 RPC 回應格式以符合 Swift MapAsk 模型
  const transformedAsks = (data || []).map(ask => ({
    id: ask.id,
    center: {
      lat: ask.lat,
      lng: ask.lng,
    },
    radius_meters: ask.radius_meters,
    question: ask.question,
    status: ask.status,
    created_at: ask.created_at,
  }));

  res.json({ asks: transformedAsks });
}));

/**
 * API C-3: 取得詢問標點詳情
 * GET /api/v1/asks/:id
 */
router.get('/:id', optionalAuth, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const currentUserId = req.user?.id;

  // 使用 RPC 取得包含座標的詢問資料
  const { data: askWithCoords, error: rpcError } = await supabase.rpc('get_ask_detail_with_coords', {
    p_ask_id: id,
  });

  let ask;
  let center = null;

  if (rpcError || !askWithCoords || askWithCoords.length === 0) {
    // RPC 不存在或失敗，使用基本查詢
    console.warn('RPC not available, using basic query');
    const { data: basicAsk, error: basicError } = await supabase
      .from('asks')
      .select(`
        *,
        users:user_id (id, display_name, avatar_url)
      `)
      .eq('id', id)
      .single();

    if (basicError || !basicAsk) {
      throw Errors.notFound('找不到此詢問');
    }

    ask = basicAsk;
    // 沒有 RPC 無法取得座標
    center = { lat: 0, lng: 0 };
  } else {
    const askData = askWithCoords[0];
    center = {
      lat: askData.lat,
      lng: askData.lng,
    };

    // 取得使用者資訊
    const { data: userData } = await supabase
      .from('users')
      .select('id, display_name, avatar_url')
      .eq('id', askData.user_id)
      .single();

    ask = {
      ...askData,
      users: userData,
    };
  }

  // 取得關聯圖片（含位置座標）
  let images = [];
  const { data: imagesWithLocation, error: imgRpcError } = await supabase.rpc('get_ask_images_with_location', {
    p_ask_id: id
  });
  
  if (imgRpcError) {
    // RPC 不存在，使用普通查詢（不含 location）
    console.warn('RPC get_ask_images_with_location not available, using basic query');
    const { data: basicImages } = await supabase
      .from('image_media')
      .select('id, original_public_url, thumbnail_public_url, display_order')
      .eq('ask_id', id)
      .eq('status', 'COMPLETED')
      .order('display_order');
    images = basicImages || [];
  } else {
    // 轉換 RPC 回傳格式
    images = (imagesWithLocation || []).map(img => ({
      id: img.id,
      original_public_url: img.original_public_url,
      thumbnail_public_url: img.thumbnail_public_url,
      display_order: img.display_order,
      location: (img.lng !== null && img.lat !== null) ? {
        lng: img.lng,
        lat: img.lat
      } : null
    }));
  }

  // 檢查是否已點讚
  let userHasLiked = false;
  if (currentUserId) {
    const { data: like } = await supabase
      .from('likes')
      .select('id')
      .eq('ask_id', id)
      .eq('user_id', currentUserId)
      .single();
    userHasLiked = !!like;
  }

  res.json({
    id: ask.id,
    user_id: ask.user_id,
    center: center,
    radius_meters: ask.radius_meters,
    question: ask.question,
    main_image_url: ask.main_image_url,
    status: ask.status,
    like_count: ask.like_count || 0,
    view_count: ask.view_count || 0,
    created_at: ask.created_at,
    updated_at: ask.updated_at,
    author: ask.users,
    images: images || [],
    user_has_liked: userHasLiked,
  });
}));

/**
 * API C-4: 編輯詢問標點
 * PATCH /api/v1/asks/:id
 */
router.patch('/:id', requireAuth, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { question, status, sorted_images } = req.body;
  const userId = req.user.id;

  // 驗證擁有權
  const { data: ask } = await supabase
    .from('asks')
    .select('user_id')
    .eq('id', id)
    .single();

  if (!ask) throw Errors.notFound('找不到此詢問');
  if (ask.user_id !== userId) throw Errors.permissionDenied('您無權編輯此詢問');

  // 更新基本欄位
  const updates = { updated_at: new Date().toISOString() };
  if (question !== undefined) updates.question = question;
  if (status !== undefined && ['ACTIVE', 'RESOLVED'].includes(status)) {
    updates.status = status;
  }

  await supabase.from('asks').update(updates).eq('id', id);

  // 處理圖片同步（邏輯同 records）
  if (sorted_images && Array.isArray(sorted_images)) {
    // 簡化版：刪除現有、新增新的、更新順序
    const { data: currentImages } = await supabase
      .from('image_media')
      .select('id')
      .eq('ask_id', id);

    const currentIds = new Set((currentImages || []).map(img => img.id));
    const newIds = sorted_images
      .filter(img => img.type === 'EXISTING')
      .map(img => img.image_id);

    // 刪除不在列表中的圖片
    const toDelete = [...currentIds].filter(cid => !newIds.includes(cid));
    if (toDelete.length > 0) {
      await supabase.from('image_media').delete().in('id', toDelete);
    }

    // 處理新增和排序
    for (let i = 0; i < sorted_images.length; i++) {
      const img = sorted_images[i];
      const imageId = img.type === 'EXISTING' ? img.image_id : img.upload_id;

      if (img.type === 'NEW') {
        await supabase
          .from('image_media')
          .update({ ask_id: id, status: 'COMPLETED', display_order: i })
          .eq('id', img.upload_id)
          .eq('user_id', userId);
      } else {
        await supabase
          .from('image_media')
          .update({ display_order: i })
          .eq('id', imageId);
      }
    }
  }

  res.json({ success: true });
}));

/**
 * API C-5: 刪除詢問標點
 * DELETE /api/v1/asks/:id
 */
router.delete('/:id', requireAuth, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user.id;

  const { data: ask } = await supabase
    .from('asks')
    .select('user_id')
    .eq('id', id)
    .single();

  if (!ask) throw Errors.notFound('找不到此詢問');
  if (ask.user_id !== userId) throw Errors.permissionDenied('您無權刪除此詢問');

  // 取得圖片 URLs 用於 R2 清理
  const { data: images } = await supabase
    .from('image_media')
    .select('original_public_url, thumbnail_public_url')
    .eq('ask_id', id);

  const keysToDelete = (images || []).flatMap(img => [
    img.original_public_url,
    img.thumbnail_public_url,
  ].filter(Boolean));

  // 刪除
  await supabase.from('asks').delete().eq('id', id);

  // 異步清理 R2
  if (keysToDelete.length > 0) {
    deleteObjects(keysToDelete).catch(console.error);
  }

  res.json({ success: true });
}));

module.exports = router;
