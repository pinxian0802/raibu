/**
 * Cloudflare R2 操作輔助函數
 */
const { PutObjectCommand, GetObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const r2 = require('../config/r2');

const BUCKET_NAME = process.env.R2_BUCKET_NAME;
const CDN_BASE_URL = process.env.R2_CDN_URL || process.env.R2_PUBLIC_URL;

/**
 * 生成用於上傳的 Presigned URL (PUT)
 * @param {string} key - R2 物件 Key
 * @param {string} contentType - MIME 類型
 * @param {number} expiresIn - 有效秒數，預設 900 (15 分鐘)
 * @returns {Promise<string>} Presigned URL
 */
async function generatePresignedUploadUrl(key, contentType, expiresIn = 900) {
  const command = new PutObjectCommand({
    Bucket: BUCKET_NAME,
    Key: key,
    ContentType: contentType,
  });
  return await getSignedUrl(r2, command, { expiresIn });
}

/**
 * 生成用於下載的 Presigned URL (GET)
 * @param {string} key - R2 物件 Key
 * @param {number} expiresIn - 有效秒數，預設 3600 (1 小時)
 * @returns {Promise<string>} Presigned URL
 */
async function generatePresignedDownloadUrl(key, expiresIn = 3600) {
  const command = new GetObjectCommand({
    Bucket: BUCKET_NAME,
    Key: key,
  });
  return await getSignedUrl(r2, command, { expiresIn });
}

/**
 * 刪除 R2 物件
 * @param {string} key - R2 物件 Key
 * @returns {Promise<void>}
 */
async function deleteObject(key) {
  const command = new DeleteObjectCommand({
    Bucket: BUCKET_NAME,
    Key: key,
  });
  await r2.send(command);
}

/**
 * 批次刪除多個 R2 物件
 * @param {string[]} keys - R2 物件 Key 陣列
 * @returns {Promise<void>}
 */
async function deleteObjects(keys) {
  await Promise.all(keys.map(key => deleteObject(key)));
}

/**
 * 取得永久公開 URL（透過 CDN）
 * @param {string} key - R2 物件 Key
 * @returns {string} 公開 URL
 */
function getPublicUrl(key) {
  if (!CDN_BASE_URL) {
    console.warn('R2_CDN_URL not set, using key path directly');
    return key;
  }
  // 確保 URL 格式正確
  const baseUrl = CDN_BASE_URL.endsWith('/') ? CDN_BASE_URL.slice(0, -1) : CDN_BASE_URL;
  const keyPath = key.startsWith('/') ? key.slice(1) : key;
  return `${baseUrl}/${keyPath}`;
}

/**
 * 生成上傳用的 R2 Key
 * @param {string} userId - 使用者 ID
 * @param {string} uploadId - 上傳 ID (UUID)
 * @param {string} type - 'original' 或 'thumbnail'
 * @param {string} extension - 檔案副檔名
 * @returns {string} R2 Key
 */
function generateImageKey(userId, uploadId, type, extension = 'jpg') {
  return `images/${userId}/${uploadId}_${type}.${extension}`;
}

/**
 * 生成頭貼用的 R2 Key
 * @param {string} uploadId - 上傳 ID (UUID)
 * @returns {string} R2 Key
 */
function generateAvatarKey(uploadId) {
  return `avatars/${uploadId}.jpg`;
}

/**
 * 解析 R2 Key 取得相關資訊
 * @param {string} key - R2 Key
 * @returns {object} { userId, uploadId, type, extension }
 */
function parseImageKey(key) {
  const regex = /images\/([^/]+)\/([^_]+)_(original|thumbnail)\.(\w+)/;
  const match = key.match(regex);
  if (!match) return null;
  return {
    userId: match[1],
    uploadId: match[2],
    type: match[3],
    extension: match[4],
  };
}

module.exports = {
  generatePresignedUploadUrl,
  generatePresignedDownloadUrl,
  deleteObject,
  deleteObjects,
  getPublicUrl,
  generateImageKey,
  generateAvatarKey,
  parseImageKey,
};
