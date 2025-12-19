/**
 * 統一錯誤代碼定義
 * 符合系統框架規格書 3.0 節
 */

const ErrorCodes = {
  // 參數錯誤 (如欄位缺漏、格式不符)
  INVALID_ARGUMENT: "INVALID_ARGUMENT",

  // 未登入或 Token 無效
  UNAUTHENTICATED: "UNAUTHENTICATED",

  // 無權限 (如編輯他人的文章)
  PERMISSION_DENIED: "PERMISSION_DENIED",

  // 找不到資源
  NOT_FOUND: "NOT_FOUND",

  // 配額不足 (如上傳超過限制)
  RESOURCE_EXHAUSTED: "RESOURCE_EXHAUSTED",

  // 伺服器內部錯誤
  INTERNAL: "INTERNAL",
};

/**
 * 自定義 API 錯誤類別
 */
class ApiError extends Error {
  constructor(code, message, details = null, httpStatus = 400) {
    super(message);
    this.code = code;
    this.details = details;
    this.httpStatus = httpStatus;
    this.name = "ApiError";
  }

  toJSON() {
    const error = {
      code: this.code,
      message: this.message,
    };
    if (this.details) {
      error.details = this.details;
    }
    return { error };
  }
}

/**
 * 常用錯誤建構函數
 */
const Errors = {
  invalidArgument: (message, details = null) =>
    new ApiError(ErrorCodes.INVALID_ARGUMENT, message, details, 400),

  unauthenticated: (message = "未登入或 Token 無效") =>
    new ApiError(ErrorCodes.UNAUTHENTICATED, message, null, 401),

  permissionDenied: (message = "無權限執行此操作") =>
    new ApiError(ErrorCodes.PERMISSION_DENIED, message, null, 403),

  notFound: (message = "找不到資源") =>
    new ApiError(ErrorCodes.NOT_FOUND, message, null, 404),

  resourceExhausted: (message, details = null) =>
    new ApiError(ErrorCodes.RESOURCE_EXHAUSTED, message, details, 429),

  internal: (message = "伺服器內部錯誤") =>
    new ApiError(ErrorCodes.INTERNAL, message, null, 500),
};

module.exports = {
  ErrorCodes,
  ApiError,
  Errors,
};
