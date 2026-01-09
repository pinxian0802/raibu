const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const dotenv = require("dotenv");

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// ===========================================
// 安全性中間件
// ===========================================

// 1. Helmet - 設定安全 HTTP Headers
app.use(helmet());

// 2. CORS - 限制允許的來源
const allowedOrigins = [
  // iOS App URL Scheme (Deep Link)
  "raibu://",
];

// 開發環境允許 localhost
if (process.env.NODE_ENV !== "production") {
  allowedOrigins.push("http://localhost:3000");
  allowedOrigins.push("http://localhost:5173");
  allowedOrigins.push("http://127.0.0.1:3000");
}

app.use(
  cors({
    origin: function (origin, callback) {
      // 允許沒有 origin 的請求（如 iOS App 原生請求、Postman）
      if (!origin) return callback(null, true);

      if (allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        console.warn(`CORS blocked origin: ${origin}`);
        callback(new Error("Not allowed by CORS"));
      }
    },
    credentials: true,
  })
);

// 3. Rate Limiting - 防止暴力破解與 DoS
// 全域限制：每 IP 每 15 分鐘 200 次請求
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 分鐘
  max: 200,
  message: {
    error: {
      code: "RESOURCE_EXHAUSTED",
      message: "請求過於頻繁，請稍後再試",
    },
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// 上傳限制：每 IP 每小時 50 次（防止濫用存儲）
const uploadLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 小時
  max: 50,
  message: {
    error: {
      code: "RESOURCE_EXHAUSTED",
      message: "上傳次數已達上限，請稍後再試",
    },
  },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use("/api/", generalLimiter);

// JSON 解析
app.use(express.json());

// Import error handler
const { errorHandler, notFoundHandler } = require("./middleware/errorHandler");

// Import routes
const uploadRoutes = require("./routes/upload");
const recordsRoutes = require("./routes/records");
const asksRoutes = require("./routes/asks");
const repliesRoutes = require("./routes/replies");
const likesRoutes = require("./routes/likes");
const usersRoutes = require("./routes/users");

// API v1 Routes
app.use("/api/v1/upload", uploadLimiter, uploadRoutes);
app.use("/api/v1/records", recordsRoutes);
app.use("/api/v1/asks", asksRoutes);
app.use("/api/v1/replies", repliesRoutes);
app.use("/api/v1/likes", likesRoutes);
app.use("/api/v1/users", usersRoutes);

// Health Check
app.get("/", (req, res) => {
  res.json({
    status: "ok",
    message: "Raibu Backend API v1",
    version: "3.1",
    endpoints: {
      upload: "/api/v1/upload",
      records: "/api/v1/records",
      asks: "/api/v1/asks",
      replies: "/api/v1/replies",
      likes: "/api/v1/likes",
      users: "/api/v1/users",
    },
  });
});

// 404 Handler
app.use(notFoundHandler);

// Global Error Handler
app.use(errorHandler);

app.listen(PORT, () => {
  console.log(`🚀 Raibu Backend is running on port ${PORT}`);
  console.log(`📍 API Base URL: http://localhost:${PORT}/api/v1`);
});
