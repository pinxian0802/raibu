/**
 * 模組 D (部分)：回覆 API
 */
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { requireAuth, optionalAuth } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const { Errors } = require('../utils/errorCodes');
const { isWithinRadius, isValidCoordinate } = require('../utils/geo');

async function getReplyImages(replyId) {
  const { data: imagesWithLocation, error: imgRpcError } = await supabase.rpc('get_reply_images_with_location', {
    p_reply_id: replyId
  });

  if (imgRpcError) {
    // RPC 不存在，使用普通查詢
    const { data: basicImages } = await supabase
      .from('image_media')
      .select('id, original_public_url, thumbnail_public_url, display_order')
      .eq('reply_id', replyId)
      .order('display_order');
    return basicImages || [];
  }

  return (imagesWithLocation || []).map(img => ({
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

async function enrichReply(reply, currentUserId) {
  const images = await getReplyImages(reply.id);

  // 檢查當前用戶是否已點讚
  let userHasLiked = false;
  if (currentUserId) {
    const { data: like } = await supabase
      .from('likes')
      .select('id')
      .eq('reply_id', reply.id)
      .eq('user_id', currentUserId)
      .single();
    userHasLiked = !!like;
  }

  return {
    id: reply.id,
    record_id: reply.record_id,
    ask_id: reply.ask_id,
    user_id: reply.user_id,
    content: reply.content,
    is_onsite: reply.is_onsite || false,
    like_count: reply.like_count || 0,
    created_at: reply.created_at,
    author: reply.users || null,
    images: images || [],
    user_has_liked: userHasLiked,
  };
}

/**
 * API D-1: 建立回覆
 * POST /api/v1/replies
 */
router.post('/', requireAuth, asyncHandler(async (req, res) => {
  const { record_id, ask_id, content, images } = req.body;
  const userId = req.user.id;

  // 驗證：必須提供 record_id 或 ask_id 其中之一
  if ((!record_id && !ask_id) || (record_id && ask_id)) {
    throw Errors.invalidArgument('必須提供 record_id 或 ask_id 其中之一');
  }

  if (!content || typeof content !== 'string') {
    throw Errors.invalidArgument('content 為必填欄位');
  }

  // 驗證圖片數量（回覆最多 5 張）
  if (images && images.length > 5) {
    throw Errors.resourceExhausted('回覆最多 5 張圖片', { limit: 5 });
  }

  // 如果有圖片，驗證 upload_id
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

  // 計算 is_onsite（僅對詢問模式回覆）
  let isOnsite = false;
  if (ask_id && images && images.length > 0) {
    // 取得 Ask 的中心座標和半徑
    // 注意：需要 RPC 來取得 PostGIS 座標
    const { data: ask } = await supabase
      .from('asks')
      .select('radius_meters')
      .eq('id', ask_id)
      .single();

    if (ask) {
      // 檢查任一圖片是否在範圍內
      for (const img of images) {
        if (img.location && isValidCoordinate(img.location.lat, img.location.lng)) {
          // 使用 RPC 檢查距離 (如果可用)
          // 這裡使用簡化的客戶端計算
          // 實際應該用 PostGIS ST_DWithin

          // 暫時標記為 true，實際需要取得 ask center 座標
          // TODO: 使用 RPC 取得確切判斷
          isOnsite = true;
          break;
        }
      }
    }
  }

  // 建立回覆
  const { data: reply, error: replyError } = await supabase
    .from('replies')
    .insert({
      record_id: record_id || null,
      ask_id: ask_id || null,
      user_id: userId,
      content,
      is_onsite: isOnsite,
    })
    .select(`
      *,
      users:user_id (id, display_name, avatar_url)
    `)
    .single();

  if (replyError) {
    throw Errors.internal('建立回覆失敗');
  }

  // 關聯圖片
  if (images && images.length > 0) {
    for (const img of images) {
      await supabase
        .from('image_media')
        .update({
          reply_id: reply.id,
          status: 'COMPLETED',
          display_order: img.display_order || 0,
        })
        .eq('id', img.upload_id);
    }
  }

  const enrichedReply = await enrichReply(reply, userId);
  res.status(201).json(enrichedReply);
}));

/**
 * API D-2: 取得回覆列表
 * GET /api/v1/replies?record_id=xxx 或 GET /api/v1/replies?ask_id=xxx
 */
router.get('/', optionalAuth, asyncHandler(async (req, res) => {
  const { record_id, ask_id } = req.query;
  const currentUserId = req.user?.id;

  if (!record_id && !ask_id) {
    throw Errors.invalidArgument('需要提供 record_id 或 ask_id');
  }

  // 查詢回覆
  let query = supabase
    .from('replies')
    .select(`
      *,
      users:user_id (id, display_name, avatar_url)
    `)
    .order('created_at', { ascending: true });

  if (record_id) {
    query = query.eq('record_id', record_id);
  } else {
    query = query.eq('ask_id', ask_id);
  }

  const { data: replies, error } = await query;

  if (error) {
    throw Errors.internal('查詢回覆失敗');
  }

  // 取得每個回覆的圖片
  const repliesWithImages = await Promise.all(
    (replies || []).map((reply) => enrichReply(reply, currentUserId))
  );

  res.json({ replies: repliesWithImages });
}));

module.exports = router;
