/**
 * 模組 D (部分)：愛心 API
 */
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { requireAuth } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const { Errors } = require('../utils/errorCodes');

/**
 * API D-3: 點讚/取消點讚 (Toggle)
 * POST /api/v1/likes
 */
router.post('/', requireAuth, asyncHandler(async (req, res) => {
  console.log('--- POST /api/v1/likes starting ---', req.body);
  const { record_id, ask_id, reply_id } = req.body;
  const userId = req.user.id;

  // 驗證：必須提供其中之一
  const targetCount = [record_id, ask_id, reply_id].filter(Boolean).length;
  if (targetCount !== 1) {
    throw Errors.invalidArgument('必須提供 record_id、ask_id 或 reply_id 其中之一');
  }

  // 確定目標類型和 ID
  let targetType, targetId, tableName, targetColumn;
  if (record_id) {
    targetType = 'record';
    targetId = record_id;
    tableName = 'records';
    targetColumn = 'record_id';
  } else if (ask_id) {
    targetType = 'ask';
    targetId = ask_id;
    tableName = 'asks';
    targetColumn = 'ask_id';
  } else {
    targetType = 'reply';
    targetId = reply_id;
    tableName = 'replies';
    targetColumn = 'reply_id';
  }

  // 檢查是否已存在 Like
  const { data: existingLike } = await supabase
    .from('likes')
    .select('id')
    .eq('user_id', userId)
    .eq(targetColumn, targetId)
    .single();

  let action;

  if (existingLike) {
    // 已存在 → 取消點讚
    const { error: deleteError } = await supabase
      .from('likes')
      .delete()
      .eq('id', existingLike.id);

    if (deleteError) throw Errors.internal('取消點讚失敗');

    // 減少計數
    const { error: rpcError } = await supabase.rpc('decrement_like_count', {
      p_table: tableName,
      p_id: targetId,
    });

    if (rpcError) {
      console.warn('RPC decrement_like_count failed, falling back to manual update', rpcError);
      // 如果 RPC 不存在，使用直接更新
      await supabase
        .from(tableName)
        .update({ like_count: supabase.rpc('decrement', { x: 1 }) })
        .eq('id', targetId);
    }

    action = 'unliked';
  } else {
    // 不存在 → 點讚
    const insertData = {
      user_id: userId,
      [targetColumn]: targetId,
    };

    const { error: insertError } = await supabase
      .from('likes')
      .insert(insertData);

    if (insertError) {
      if (insertError.code === '23505') {
        // 唯一約束違反（並發請求）
        return res.json({ success: true, action: 'already_liked' });
      }
      throw Errors.internal('點讚失敗');
    }

    // 增加計數 (忽略 RPC 錯誤)
    await supabase.rpc('increment_like_count', {
      p_table: tableName,
      p_id: targetId,
    });

    action = 'liked';
  }

  // 取得更新後的計數
  const { data: target } = await supabase
    .from(tableName)
    .select('like_count')
    .eq('id', targetId)
    .single();

  res.json({
    success: true,
    action,
    like_count: target?.like_count || 0,
  });
}));

module.exports = router;
