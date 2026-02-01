/**
 * 模組 C：詢問模式 API Routes
 * 僅處理 HTTP 請求/回應，業務邏輯委託給 Service 層
 */
const express = require('express');
const router = express.Router();
const { requireAuth, optionalAuth } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const { validateBody, validateQuery, askSchemas, recordSchemas } = require('../middleware/validate');
const askService = require('../services/askService');

/**
 * API C-1: 建立詢問標點
 * POST /api/v1/asks
 */
router.post('/', 
  requireAuth, 
  validateBody(askSchemas.create),
  asyncHandler(async (req, res) => {
    const { center, radius_meters, question, images } = req.body;
    const userId = req.user.id;

    const ask = await askService.createAsk(userId, {
      center,
      radiusMeters: radius_meters,
      question,
      images,
    });

    res.status(201).json(ask);
  })
);

/**
 * API C-2: 取得地圖範圍內的詢問標點
 * GET /api/v1/asks/map
 */
router.get('/map', 
  validateQuery(recordSchemas.mapQuery),
  asyncHandler(async (req, res) => {
    const { min_lat, max_lat, min_lng, max_lng } = req.query;

    const asks = await askService.getMapAsks({
      minLat: min_lat,
      maxLat: max_lat,
      minLng: min_lng,
      maxLng: max_lng,
    });

    res.json({ asks });
  })
);

/**
 * API C-3: 取得詢問標點詳情
 * GET /api/v1/asks/:id
 */
router.get('/:id', optionalAuth, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const currentUserId = req.user?.id;

  const ask = await askService.getAskDetail(id, currentUserId);
  res.json(ask);
}));

/**
 * API C-4: 編輯詢問標點
 * PATCH /api/v1/asks/:id
 */
router.patch('/:id', 
  requireAuth, 
  validateBody(askSchemas.update),
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { question, status, sorted_images } = req.body;
    const userId = req.user.id;

    const result = await askService.updateAsk(id, userId, {
      question,
      status,
      sortedImages: sorted_images,
    });

    res.json(result);
  })
);

/**
 * API C-5: 刪除詢問標點
 * DELETE /api/v1/asks/:id
 */
router.delete('/:id', requireAuth, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user.id;

  const result = await askService.deleteAsk(id, userId);
  res.json(result);
}));

module.exports = router;
