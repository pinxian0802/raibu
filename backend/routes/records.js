/**
 * 模組 B：紀錄模式 API Routes
 * 僅處理 HTTP 請求/回應，業務邏輯委託給 Service 層
 */
const express = require('express');
const router = express.Router();
const { requireAuth, optionalAuth } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const { validateBody, validateQuery, recordSchemas } = require('../middleware/validate');
const recordService = require('../services/recordService');

/**
 * API B-1: 建立紀錄標點
 * POST /api/v1/records
 */
router.post(
  '/',
  requireAuth,
  validateBody(recordSchemas.create),
  asyncHandler(async (req, res) => {
    const { description, images } = req.body;
    const userId = req.user.id;

    const record = await recordService.createRecord(userId, description, images);
    res.status(201).json(record);
  })
);

/**
 * API B-2: 取得地圖範圍內的紀錄圖片
 * GET /api/v1/records/map
 */
router.get(
  '/map',
  validateQuery(recordSchemas.mapQuery),
  asyncHandler(async (req, res) => {
    const { min_lat, max_lat, min_lng, max_lng } = req.query;

    const images = await recordService.getMapRecords({
      minLat: min_lat,
      maxLat: max_lat,
      minLng: min_lng,
      maxLng: max_lng,
    });

    res.json({ images });
  })
);

/**
 * API B-3: 取得紀錄標點詳情
 * GET /api/v1/records/:id
 */
router.get(
  '/:id',
  optionalAuth,
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const currentUserId = req.user?.id;

    const record = await recordService.getRecordDetail(id, currentUserId);
    res.json(record);
  })
);

/**
 * API B-4: 編輯紀錄標點 (Snapshot Sync)
 * PATCH /api/v1/records/:id
 */
router.patch(
  '/:id',
  requireAuth,
  validateBody(recordSchemas.update),
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { description, sorted_images } = req.body;
    const userId = req.user.id;

    const result = await recordService.updateRecord(id, userId, {
      description,
      sortedImages: sorted_images,
    });

    res.json(result);
  })
);

/**
 * API B-5: 刪除紀錄標點
 * DELETE /api/v1/records/:id
 */
router.delete(
  '/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.user.id;

    const result = await recordService.deleteRecord(id, userId);
    res.json(result);
  })
);

module.exports = router;
