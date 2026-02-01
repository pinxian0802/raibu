/**
 * 請求驗證中間件
 * 使用 Joi 進行統一的請求驗證
 */
const Joi = require('joi');
const { Errors } = require('../utils/errorCodes');

// ==================== Schema Definitions ====================

/**
 * 座標 Schema
 */
const coordinateSchema = Joi.object({
  lat: Joi.number().min(-90).max(90).required(),
  lng: Joi.number().min(-180).max(180).required(),
});

/**
 * 紀錄模式 Schemas
 */
const recordSchemas = {
  // 建立紀錄
  create: Joi.object({
    description: Joi.string().min(1).max(2000).required()
      .messages({
        'string.empty': 'description 為必填欄位',
        'string.max': 'description 最多 2000 字元',
        'any.required': 'description 為必填欄位',
      }),
    images: Joi.array().items(
      Joi.object({
        upload_id: Joi.string().uuid().required(),
        location: coordinateSchema.required(),
        captured_at: Joi.string().isoDate().allow(null),
        display_order: Joi.number().integer().min(0).default(0),
        thumbnail_public_url: Joi.string().uri().allow(null),
        address: Joi.string().max(500).allow(null, ''),
      })
    ).min(1).max(10).required()
      .messages({
        'array.min': '至少需要一張圖片',
        'array.max': '紀錄模式最多 10 張圖片',
        'any.required': '至少需要一張圖片',
      }),
  }),

  // 編輯紀錄
  update: Joi.object({
    description: Joi.string().min(1).max(2000).allow(null),
    sorted_images: Joi.array().items(
      Joi.object({
        type: Joi.string().valid('EXISTING', 'NEW').required(),
        image_id: Joi.string().uuid().when('type', {
          is: 'EXISTING',
          then: Joi.required(),
          otherwise: Joi.forbidden(),
        }),
        upload_id: Joi.string().uuid().when('type', {
          is: 'NEW',
          then: Joi.required(),
          otherwise: Joi.forbidden(),
        }),
        location: coordinateSchema.allow(null),
        captured_at: Joi.string().isoDate().allow(null),
      })
    ).allow(null),
  }),

  // 地圖查詢
  mapQuery: Joi.object({
    min_lat: Joi.number().min(-90).max(90).required(),
    max_lat: Joi.number().min(-90).max(90).required(),
    min_lng: Joi.number().min(-180).max(180).required(),
    max_lng: Joi.number().min(-180).max(180).required(),
  }),
};

/**
 * 詢問模式 Schemas
 */
const askSchemas = {
  // 建立詢問
  create: Joi.object({
    center: coordinateSchema.required()
      .messages({
        'any.required': '需要提供有效的中心座標',
      }),
    radius_meters: Joi.number().integer().min(100).max(5000).default(500),
    question: Joi.string().min(1).max(1000).required()
      .messages({
        'string.empty': 'question 為必填欄位',
        'string.max': 'question 最多 1000 字元',
        'any.required': 'question 為必填欄位',
      }),
    images: Joi.array().items(
      Joi.object({
        upload_id: Joi.string().uuid().required(),
        display_order: Joi.number().integer().min(0).default(0),
      })
    ).max(5).allow(null)
      .messages({
        'array.max': '詢問模式最多 5 張圖片',
      }),
  }),

  // 編輯詢問
  update: Joi.object({
    question: Joi.string().min(1).max(1000).allow(null),
    status: Joi.string().valid('ACTIVE', 'RESOLVED').allow(null),
    sorted_images: Joi.array().items(
      Joi.object({
        type: Joi.string().valid('EXISTING', 'NEW').required(),
        image_id: Joi.string().uuid().allow(null),
        upload_id: Joi.string().uuid().allow(null),
      })
    ).allow(null),
  }),
};

/**
 * 回覆 Schemas
 */
const replySchemas = {
  // 建立回覆
  create: Joi.object({
    content: Joi.string().min(1).max(2000).required()
      .messages({
        'string.empty': 'content 為必填欄位',
        'any.required': 'content 為必填欄位',
      }),
    images: Joi.array().items(
      Joi.object({
        upload_id: Joi.string().uuid().required(),
        location: coordinateSchema.allow(null),
        display_order: Joi.number().integer().min(0).default(0),
      })
    ).max(5).allow(null),
    current_location: coordinateSchema.allow(null),
  }),
};

/**
 * 上傳 Schemas
 */
const uploadSchemas = {
  // 請求上傳憑證
  requestCredential: Joi.object({
    images: Joi.array().items(
      Joi.object({
        client_key: Joi.string().required(),
        content_type: Joi.string().valid('image/jpeg', 'image/png', 'image/heic', 'image/heif').required(),
      })
    ).min(1).max(10).required(),
  }),
};

/**
 * 使用者 Schemas
 */
const userSchemas = {
  // 更新個人資料
  updateProfile: Joi.object({
    display_name: Joi.string().min(1).max(50).allow(null),
    avatar_url: Joi.string().uri().allow(null, ''),
  }),
};

// ==================== Validation Middleware ====================

/**
 * 驗證中間件工廠
 * @param {Joi.Schema} schema - Joi Schema
 * @param {string} source - 驗證來源 ('body' | 'query' | 'params')
 * @returns {Function} Express 中間件
 */
function validate(schema, source = 'body') {
  return (req, res, next) => {
    const dataToValidate = req[source];
    
    const { error, value } = schema.validate(dataToValidate, {
      abortEarly: false,  // 收集所有錯誤
      stripUnknown: true, // 移除未定義的欄位
    });

    if (error) {
      const messages = error.details.map(detail => detail.message).join('; ');
      const apiError = Errors.invalidArgument(messages);
      return res.status(apiError.httpStatus).json(apiError.toJSON());
    }

    // 將驗證後的值寫回（已清理）
    req[source] = value;
    next();
  };
}

/**
 * 快捷驗證函數
 */
const validateBody = (schema) => validate(schema, 'body');
const validateQuery = (schema) => validate(schema, 'query');
const validateParams = (schema) => validate(schema, 'params');

// ==================== Exports ====================

module.exports = {
  // Schemas
  recordSchemas,
  askSchemas,
  replySchemas,
  uploadSchemas,
  userSchemas,
  coordinateSchema,
  
  // Middleware
  validate,
  validateBody,
  validateQuery,
  validateParams,
};
