/**
 * 模組 A：圖片上傳 API
 * 實作兩階段上傳流程
 */
const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const supabase = require('../config/supabase');
const { requireAuth } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const { Errors } = require('../utils/errorCodes');
const { 
  generatePresignedUploadUrl, 
  getPublicUrl, 
  generateImageKey 
} = require('../utils/r2Helpers');

// 限制常量
const MAX_IMAGES_PER_REQUEST = 10;
const MAX_FILE_SIZE = 20 * 1024 * 1024; // 20 MB
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/heic', 'image/webp'];
const PRESIGNED_URL_EXPIRES = 900; // 15 分鐘

/**
 * API A-1: 批次上傳授權與 PENDING 創建
 * POST /api/v1/upload/request
 */
router.post('/request', requireAuth, asyncHandler(async (req, res) => {
  const { image_requests } = req.body;
  const userId = req.user.id;

  // 驗證請求
  if (!image_requests || !Array.isArray(image_requests)) {
    throw Errors.invalidArgument('image_requests 必須為陣列');
  }

  if (image_requests.length === 0) {
    throw Errors.invalidArgument('至少需要一張圖片');
  }

  if (image_requests.length > MAX_IMAGES_PER_REQUEST) {
    throw Errors.resourceExhausted(`單次最多上傳 ${MAX_IMAGES_PER_REQUEST} 張圖片`, {
      field: 'image_requests',
      limit: MAX_IMAGES_PER_REQUEST,
      actual: image_requests.length,
    });
  }

  // 驗證每個圖片請求
  for (const req of image_requests) {
    if (!req.client_key) {
      throw Errors.invalidArgument('每個圖片請求都必須包含 client_key');
    }
    if (!req.fileType || !ALLOWED_TYPES.includes(req.fileType)) {
      throw Errors.invalidArgument(`不支援的圖片格式: ${req.fileType}`, {
        allowed: ALLOWED_TYPES,
      });
    }
    if (req.fileSize && req.fileSize > MAX_FILE_SIZE) {
      throw Errors.resourceExhausted('圖片大小超過限制', {
        limit: MAX_FILE_SIZE,
        actual: req.fileSize,
      });
    }
  }

  // 為每個圖片生成上傳憑證
  const uploadCredentials = {};

  for (const imgReq of image_requests) {
    const uploadId = uuidv4();
    const extension = getExtensionFromMime(imgReq.fileType);
    
    // 生成 R2 Keys
    const originalKey = generateImageKey(userId, uploadId, 'original', extension);
    const thumbnailKey = generateImageKey(userId, uploadId, 'thumbnail', 'jpg');

    // 生成 Presigned URLs
    const [originalUploadUrl, thumbnailUploadUrl] = await Promise.all([
      generatePresignedUploadUrl(originalKey, imgReq.fileType, PRESIGNED_URL_EXPIRES),
      generatePresignedUploadUrl(thumbnailKey, 'image/jpeg', PRESIGNED_URL_EXPIRES),
    ]);

    // 生成公開 URLs
    const originalPublicUrl = getPublicUrl(originalKey);
    const thumbnailPublicUrl = getPublicUrl(thumbnailKey);

    // 建立 PENDING 記錄
    const { error: insertError } = await supabase
      .from('image_media')
      .insert({
        id: uploadId,
        user_id: userId,
        client_key: imgReq.client_key,
        status: 'PENDING',
        original_public_url: originalPublicUrl,
        thumbnail_public_url: thumbnailPublicUrl,
      });

    if (insertError) {
      console.error('Failed to create PENDING record:', insertError);
      throw Errors.internal('建立上傳記錄失敗');
    }

    uploadCredentials[imgReq.client_key] = {
      upload_id: uploadId,
      original_upload_url: originalUploadUrl,
      thumbnail_upload_url: thumbnailUploadUrl,
      original_public_url: originalPublicUrl,
      thumbnail_public_url: thumbnailPublicUrl,
    };
  }

  res.json({ upload_credentials: uploadCredentials });
}));

/**
 * 根據 MIME 類型取得副檔名
 */
function getExtensionFromMime(mimeType) {
  const map = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/heic': 'heic',
    'image/webp': 'webp',
  };
  return map[mimeType] || 'jpg';
}

/**
 * API A-2: 頭貼上傳授權
 * POST /api/v1/upload/avatar
 * 為使用者頭貼生成上傳憑證
 */
router.post('/avatar', requireAuth, asyncHandler(async (req, res) => {
  const { file_type } = req.body;
  const userId = req.user.id;

  // 驗證檔案類型
  const fileType = file_type || 'image/jpeg';
  if (!ALLOWED_TYPES.includes(fileType)) {
    throw Errors.invalidArgument(`不支援的圖片格式: ${fileType}`, {
      allowed: ALLOWED_TYPES,
    });
  }

  const uploadId = uuidv4();
  const avatarKey = require('../utils/r2Helpers').generateAvatarKey(uploadId);

  // 生成 Presigned URL
  const uploadUrl = await generatePresignedUploadUrl(avatarKey, 'image/jpeg', PRESIGNED_URL_EXPIRES);
  
  // 生成公開 URL
  const publicUrl = getPublicUrl(avatarKey);

  res.json({
    upload_id: uploadId,
    upload_url: uploadUrl,
    public_url: publicUrl,
  });
}));

module.exports = router;
