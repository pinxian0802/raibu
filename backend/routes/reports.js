/**
 * 模組：檢舉 API
 */
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { requireAuth } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const { Errors } = require('../utils/errorCodes');

/**
 * POST /api/v1/reports - 建立檢舉
 */
router.post('/', requireAuth, asyncHandler(async (req, res) => {
  const { record_id, ask_id, reply_id, reason_category, reason } = req.body;
  const reporterId = req.user.id;

  // 驗證：必須提供其中之一
  const targetCount = [record_id, ask_id, reply_id].filter(Boolean).length;
  if (targetCount !== 1) {
    throw Errors.invalidArgument('必須提供 record_id、ask_id 或 reply_id 其中之一');
  }

  // 驗證檢舉原因
  const validCategories = ['SPAM', 'INAPPROPRIATE', 'HARASSMENT', 'FALSE_INFO', 'OTHER'];
  if (!reason_category || !validCategories.includes(reason_category)) {
    throw Errors.invalidArgument('必須提供有效的 reason_category');
  }

  if (!reason || reason.trim().length === 0) {
    throw Errors.invalidArgument('必須提供檢舉原因說明');
  }

  // 確定目標欄位
  let targetColumn, targetId, tableName;
  if (record_id) {
    targetColumn = 'record_id';
    targetId = record_id;
    tableName = 'records';
  } else if (ask_id) {
    targetColumn = 'ask_id';
    targetId = ask_id;
    tableName = 'asks';
  } else {
    targetColumn = 'reply_id';
    targetId = reply_id;
    tableName = 'replies';
  }

  // 檢查目標是否存在
  const { data: target, error: targetError } = await supabase
    .from(tableName)
    .select('id, user_id')
    .eq('id', targetId)
    .single();

  if (targetError || !target) {
    throw Errors.notFound('檢舉目標不存在');
  }

  // 不能檢舉自己的內容
  if (target.user_id === reporterId) {
    throw Errors.invalidArgument('不能檢舉自己的內容');
  }

  // 檢查是否已檢舉過
  const { data: existingReport } = await supabase
    .from('reports')
    .select('id')
    .eq('reporter_id', reporterId)
    .eq(targetColumn, targetId)
    .single();

  if (existingReport) {
    throw Errors.invalidArgument('您已經檢舉過此內容');
  }

  // 建立檢舉記錄
  const insertData = {
    reporter_id: reporterId,
    [targetColumn]: targetId,
    reason_category,
    reason: reason.trim(),
  };

  const { data: report, error: insertError } = await supabase
    .from('reports')
    .insert(insertData)
    .select('id, created_at')
    .single();

  if (insertError) {
    if (insertError.code === '23505') {
      throw Errors.invalidArgument('您已經檢舉過此內容');
    }
    console.error('Insert report error:', insertError);
    throw Errors.internal('建立檢舉失敗');
  }

  res.status(201).json({
    success: true,
    id: report.id,
    created_at: report.created_at,
  });
}));

/**
 * GET /api/v1/reports/check - 檢查是否已檢舉
 */
router.get('/check', requireAuth, asyncHandler(async (req, res) => {
  const { record_id, ask_id, reply_id } = req.query;
  const reporterId = req.user.id;

  // 驗證：必須提供其中之一
  const targetCount = [record_id, ask_id, reply_id].filter(Boolean).length;
  if (targetCount !== 1) {
    throw Errors.invalidArgument('必須提供 record_id、ask_id 或 reply_id 其中之一');
  }

  // 確定目標欄位
  let targetColumn, targetId;
  if (record_id) {
    targetColumn = 'record_id';
    targetId = record_id;
  } else if (ask_id) {
    targetColumn = 'ask_id';
    targetId = ask_id;
  } else {
    targetColumn = 'reply_id';
    targetId = reply_id;
  }

  const { data: existingReport } = await supabase
    .from('reports')
    .select('id')
    .eq('reporter_id', reporterId)
    .eq(targetColumn, targetId)
    .single();

  res.json({
    has_reported: !!existingReport,
    report_id: existingReport?.id || null,
  });
}));

/**
 * DELETE /api/v1/reports/:report_id - 撤回檢舉
 */
router.delete('/:report_id', requireAuth, asyncHandler(async (req, res) => {
  const { report_id } = req.params;
  const reporterId = req.user.id;

  // 檢查檢舉是否存在且屬於當前用戶
  const { data: report, error: fetchError } = await supabase
    .from('reports')
    .select('id, reporter_id, status')
    .eq('id', report_id)
    .single();

  if (fetchError || !report) {
    throw Errors.notFound('檢舉記錄不存在');
  }

  if (report.reporter_id !== reporterId) {
    throw Errors.permissionDenied('無權刪除此檢舉');
  }

  // 只能撤回 PENDING 狀態的檢舉
  if (report.status !== 'PENDING') {
    throw Errors.invalidArgument('已處理的檢舉無法撤回');
  }

  const { error: deleteError } = await supabase
    .from('reports')
    .delete()
    .eq('id', report_id);

  if (deleteError) {
    console.error('Delete report error:', deleteError);
    throw Errors.internal('撤回檢舉失敗');
  }

  res.json({
    success: true,
    message: '檢舉已撤回',
  });
}));

module.exports = router;
