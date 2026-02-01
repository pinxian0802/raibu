# 🏗️ 後端架構文件 (Backend Architecture)

## 📋 目錄

1. [系統概述](#系統概述)
2. [技術堆疊](#技術堆疊)
3. [專案結構](#專案結構)
4. [資料庫架構](#資料庫架構)
5. [API 端點詳解](#api-端點詳解)
6. [資料流程](#資料流程)
7. [圖片處理流程](#圖片處理流程)
8. [安全性設計](#安全性設計)
9. [改善建議](#改善建議)

---

## 系統概述

這是一個基於 **Node.js + Express** 的 RESTful API 後端系統,用於支援地圖即時圖片分享應用程式。系統整合了 **Supabase** (PostgreSQL + Auth + Realtime) 作為資料庫,以及 **Cloudflare R2** 作為圖片儲存服務。

### 核心功能

- ✅ 使用者認證與授權 (Supabase Auth)
- ✅ 地圖標點管理 (CRUD)
- ✅ 圖片上傳與儲存 (R2 + 自動縮圖)
- ✅ 社交互動 (愛心、留言)
- ✅ 即時資料同步 (Supabase Realtime)
- ✅ 地理位置資訊儲存

---

## 技術堆疊

### 後端框架

| 技術        | 版本   | 用途                    |
| ----------- | ------ | ----------------------- |
| **Node.js** | 18+    | JavaScript 執行環境     |
| **Express** | 5.2.1  | Web 框架,處理 HTTP 請求 |
| **dotenv**  | 17.2.3 | 環境變數管理            |
| **cors**    | 2.8.5  | 跨域資源共享            |

### 資料庫與認證

| 技術           | 版本   | 用途                                |
| -------------- | ------ | ----------------------------------- |
| **Supabase**   | 2.87.1 | PostgreSQL 資料庫 + Auth + Realtime |
| **PostgreSQL** | -      | 關聯式資料庫 (透過 Supabase)        |

### 圖片處理與儲存

| 技術              | 版本    | 用途                          |
| ----------------- | ------- | ----------------------------- |
| **Cloudflare R2** | -       | S3 相容的物件儲存             |
| **AWS SDK S3**    | 3.948.0 | R2 客戶端                     |
| **Sharp**         | 0.34.5  | 圖片壓縮與縮圖生成            |
| **Multer**        | 2.0.2   | 處理 multipart/form-data 上傳 |

### 測試工具

| 技術           | 版本  | 用途          |
| -------------- | ----- | ------------- |
| **node-fetch** | 2.7.0 | HTTP 請求測試 |
| **form-data**  | 4.0.5 | 模擬表單上傳  |

---

## 專案結構

```
backend/
├── config/                    # 配置檔案
│   ├── supabase.js           # Supabase 客戶端初始化
│   └── r2.js                 # Cloudflare R2 客戶端初始化
├── middleware/                # 中介層
│   ├── auth.js               # JWT 認證中介層
│   ├── errorHandler.js       # 統一錯誤處理
│   └── validate.js           # 請求驗證 (Joi)
├── routes/                    # API 路由 (僅處理 HTTP 請求/回應)
│   ├── records.js            # 紀錄模式 API
│   ├── asks.js               # 詢問模式 API
│   ├── replies.js            # 回覆 API
│   ├── likes.js              # 點讚 API
│   ├── users.js              # 使用者 API
│   ├── upload.js             # 上傳 API
│   └── reports.js            # 檢舉 API
├── services/                  # 業務邏輯層 (Service Layer)
│   ├── recordService.js      # 紀錄業務邏輯
│   └── askService.js         # 詢問業務邏輯
├── utils/                     # 工具函數
│   ├── errorCodes.js         # 統一錯誤碼定義
│   ├── geo.js                # 地理位置工具
│   ├── r2Helpers.js          # R2 儲存工具
│   └── logger.js             # 結構化日誌 (pino)
├── .env                       # 環境變數 (不納入版控)
├── server.js                  # 主程式入口
├── schema.sql                 # 資料庫 Schema
└── package.json               # 專案依賴
```

### 架構分層說明

本專案採用 **三層架構** 設計：

1. **Routes 層**：僅處理 HTTP 請求/回應，不包含業務邏輯
2. **Service 層**：處理業務邏輯，可重用且易於測試
3. **Repository 層**：資料存取（透過 Supabase Client）

```
Request → Routes → Middleware → Service → Supabase → Response
```

### 檔案說明

#### 🔧 `server.js` - 主程式入口

- 初始化 Express 應用
- 設定安全性中間件 (Helmet, CORS, Rate Limiting)
- 設定請求日誌 (pino)
- 掛載路由模組
- 全域錯誤處理

#### ⚙️ `config/supabase.js`

- 從 `.env` 讀取 Supabase URL 和 API Key
- 建立並匯出 Supabase 客戶端實例

#### ⚙️ `config/r2.js`

- 從 `.env` 讀取 R2 憑證
- 使用 AWS S3 SDK 建立 R2 客戶端
- 設定 endpoint 為 Cloudflare R2

#### 🛣️ `routes/points.js`

- `GET /points` - 列出所有標點 (支援地理範圍篩選)
- `GET /points/:id` - 取得單一標點詳細資料
- `POST /points` - 建立新標點

#### 🛣️ `routes/images.js`

- `POST /points/:pointId/images` - 上傳圖片到 R2
- `GET /points/:pointId/images` - 取得標點的所有圖片 (含 Signed URL)

#### 🛣️ `routes/interactions.js`

- `POST /points/:pointId/like` - 對標點按愛心
- `POST /points/:pointId/unlike` - 取消愛心
- `POST /points/:pointId/comments` - 新增留言
- `GET /points/:pointId/comments` - 取得留言列表

---

## 資料庫架構

### ER Diagram (實體關聯圖)

```mermaid
erDiagram
    auth_users ||--o{ points : creates
    auth_users ||--o{ images : uploads
    auth_users ||--o{ point_likes : likes
    auth_users ||--o{ point_comments : comments
    auth_users ||--o{ comment_likes : likes

    points ||--o{ images : contains
    points ||--o{ point_likes : has
    points ||--o{ point_comments : has

    point_comments ||--o{ comment_likes : has

    points {
        uuid id PK
        uuid user_id FK
        text title
        text description
        double lat
        double lng
        int likes_count
        int comments_count
        timestamp created_at
    }

    images {
        uuid id PK
        uuid point_id FK
        uuid uploader_id FK
        text image_url
        text thumbnail_url
        timestamp taken_at
        double latitude
        double longitude
        text country
        text administrative_area
        text locality
        text sub_locality
        text thoroughfare
        text sub_thoroughfare
        timestamp created_at
    }

    point_likes {
        uuid id PK
        uuid point_id FK
        uuid user_id FK
        timestamp created_at
    }

    point_comments {
        uuid id PK
        uuid point_id FK
        uuid user_id FK
        text content
        int likes_count
        timestamp created_at
    }

    comment_likes {
        uuid id PK
        uuid comment_id FK
        uuid user_id FK
        timestamp created_at
    }
```

### 資料表詳解

#### 1️⃣ `points` - 標點資料表

| 欄位             | 型別             | 說明                          |
| ---------------- | ---------------- | ----------------------------- |
| `id`             | uuid             | 主鍵,自動生成                 |
| `user_id`        | uuid             | 建立者 ID (外鍵至 auth.users) |
| `title`          | text             | 標點標題                      |
| `description`    | text             | 標點描述                      |
| `lat`            | double precision | 緯度                          |
| `lng`            | double precision | 經度                          |
| `likes_count`    | int              | 快取的愛心數量                |
| `comments_count` | int              | 快取的留言數量                |
| `created_at`     | timestamp        | 建立時間                      |

**索引建議**: 在 `(lat, lng)` 上建立空間索引以加速地理查詢

#### 2️⃣ `images` - 圖片資料表

| 欄位                           | 型別             | 說明                     |
| ------------------------------ | ---------------- | ------------------------ |
| `id`                           | uuid             | 主鍵                     |
| `point_id`                     | uuid             | 所屬標點 (外鍵,級聯刪除) |
| `uploader_id`                  | uuid             | 上傳者 ID                |
| `image_url`                    | text             | R2 原圖路徑 (Key)        |
| `thumbnail_url`                | text             | R2 縮圖路徑 (Key)        |
| `taken_at`                     | timestamp        | 拍攝時間                 |
| `latitude`                     | double precision | 拍攝位置緯度             |
| `longitude`                    | double precision | 拍攝位置經度             |
| `country` ~ `sub_thoroughfare` | text             | 詳細地址資訊             |
| `created_at`                   | timestamp        | 上傳時間                 |

**儲存策略**:

- `image_url` 和 `thumbnail_url` 儲存的是 R2 的 **Key** (路徑),而非完整 URL
- 實際 URL 由後端動態生成 Signed URL (有效期 1 小時)

#### 3️⃣ `point_likes` - 標點愛心表

| 欄位         | 型別      | 說明      |
| ------------ | --------- | --------- |
| `id`         | uuid      | 主鍵      |
| `point_id`   | uuid      | 標點 ID   |
| `user_id`    | uuid      | 使用者 ID |
| `created_at` | timestamp | 按讚時間  |

**唯一約束**: `(point_id, user_id)` - 確保每人每標點只能按一次讚

#### 4️⃣ `point_comments` - 標點留言表

| 欄位          | 型別      | 說明           |
| ------------- | --------- | -------------- |
| `id`          | uuid      | 主鍵           |
| `point_id`    | uuid      | 標點 ID        |
| `user_id`     | uuid      | 留言者 ID      |
| `content`     | text      | 留言內容       |
| `likes_count` | int       | 快取的愛心數量 |
| `created_at`  | timestamp | 留言時間       |

#### 5️⃣ `comment_likes` - 留言愛心表

| 欄位         | 型別      | 說明      |
| ------------ | --------- | --------- |
| `id`         | uuid      | 主鍵      |
| `comment_id` | uuid      | 留言 ID   |
| `user_id`    | uuid      | 使用者 ID |
| `created_at` | timestamp | 按讚時間  |

**唯一約束**: `(comment_id, user_id)` - 確保每人每留言只能按一次讚

### Row Level Security (RLS) 政策

所有資料表都啟用了 RLS,主要政策如下:

| 資料表           | SELECT | INSERT            | UPDATE | DELETE |
| ---------------- | ------ | ----------------- | ------ | ------ |
| `points`         | 所有人 | 認證使用者 (自己) | 擁有者 | 擁有者 |
| `images`         | 所有人 | 認證使用者 (自己) | -      | -      |
| `point_likes`    | 所有人 | 認證使用者 (自己) | -      | 擁有者 |
| `point_comments` | 所有人 | 認證使用者 (自己) | -      | -      |
| `comment_likes`  | 所有人 | 認證使用者 (自己) | -      | 擁有者 |

---

## API 端點詳解

### 基礎 URL

```
http://localhost:3000
```

### 1. 標點管理 API

#### 📍 `GET /points` - 列出標點

**功能**: 取得所有標點列表,支援地理範圍篩選

**Query Parameters**:

```
lat_min: number (optional) - 最小緯度
lat_max: number (optional) - 最大緯度
lng_min: number (optional) - 最小經度
lng_max: number (optional) - 最大經度
```

**範例請求**:

```bash
# 取得所有標點
GET http://localhost:3000/points

# 取得特定範圍內的標點 (台北市區)
GET http://localhost:3000/points?lat_min=25.0&lat_max=25.1&lng_min=121.5&lng_max=121.6
```

**回應範例**:

```json
[
  {
    "id": "f5574333-c4d1-4477-b9b7-88c1672005b2",
    "user_id": "bd20af78-fb94-430b-9ea4-3f4aa6b3808c",
    "title": "台北101",
    "description": "美麗的夜景",
    "lat": 25.033,
    "lng": 121.5654,
    "likes_count": 15,
    "comments_count": 8,
    "thumbnail_url": "points/thumbnail/xxx/123_thumb.jpg",
    "created_at": "2025-12-10T07:00:00Z"
  }
]
```

#### 📍 `GET /points/:pointId` - 取得標點詳細資料

**功能**: 取得單一標點的完整資訊,包含所有圖片

**範例請求**:

```bash
GET http://localhost:3000/points/f5574333-c4d1-4477-b9b7-88c1672005b2
```

**回應範例**:

```json
{
  "id": "f5574333-c4d1-4477-b9b7-88c1672005b2",
  "user_id": "bd20af78-fb94-430b-9ea4-3f4aa6b3808c",
  "title": "台北101",
  "description": "美麗的夜景",
  "lat": 25.033,
  "lng": 121.5654,
  "likes_count": 15,
  "comments_count": 8,
  "created_at": "2025-12-10T07:00:00Z",
  "images": [
    {
      "id": "img-uuid-1",
      "image_url": "points/image/xxx/123_original.jpg",
      "thumbnail_url": "points/thumbnail/xxx/123_thumb.jpg",
      "taken_at": "2025-12-10T06:00:00Z"
    }
  ]
}
```

#### 📍 `POST /points` - 建立新標點

**功能**: 建立一個新的地圖標點

**Request Body**:

```json
{
  "title": "台北101",
  "description": "美麗的夜景",
  "lat": 25.033,
  "lng": 121.5654,
  "user_id": "bd20af78-fb94-430b-9ea4-3f4aa6b3808c"
}
```

**回應範例**:

```json
{
  "id": "f5574333-c4d1-4477-b9b7-88c1672005b2",
  "user_id": "bd20af78-fb94-430b-9ea4-3f4aa6b3808c",
  "title": "台北101",
  "description": "美麗的夜景",
  "lat": 25.033,
  "lng": 121.5654,
  "likes_count": 0,
  "comments_count": 0,
  "created_at": "2025-12-10T07:00:00Z"
}
```

---

### 2. 圖片管理 API

#### 🖼️ `POST /points/:pointId/images` - 上傳圖片

**功能**: 上傳圖片到 Cloudflare R2,自動生成縮圖

**Content-Type**: `multipart/form-data`

**Form Fields**:

```
image_file: File (required) - 圖片檔案
uploader_id: string (required) - 上傳者 UUID
taken_at: string (optional) - 拍攝時間 ISO 8601
latitude: number (optional) - 拍攝位置緯度
longitude: number (optional) - 拍攝位置經度
country: string (optional) - 國家
administrative_area: string (optional) - 省/州
locality: string (optional) - 市/區
sub_locality: string (optional) - 街道/次級區域
thoroughfare: string (optional) - 街道名稱
sub_thoroughfare: string (optional) - 街道號碼
```

**範例請求 (使用 curl)**:

```bash
curl -X POST http://localhost:3000/points/f5574333-c4d1-4477-b9b7-88c1672005b2/images \
  -F "image_file=@ajiao.png" \
  -F "uploader_id=bd20af78-fb94-430b-9ea4-3f4aa6b3808c" \
  -F "latitude=25.0330" \
  -F "longitude=121.5654" \
  -F "country=台灣" \
  -F "locality=台北市"
```

**範例請求 (使用 Node.js)**:

```javascript
const FormData = require("form-data");
const fs = require("fs");

const form = new FormData();
form.append("image_file", fs.createReadStream("ajiao.png"));
form.append("uploader_id", "bd20af78-fb94-430b-9ea4-3f4aa6b3808c");
form.append("latitude", "25.0330");
form.append("longitude", "121.5654");

const response = await fetch("http://localhost:3000/points/xxx/images", {
  method: "POST",
  body: form,
  headers: form.getHeaders(),
});
```

**回應範例**:

```json
{
  "id": "img-uuid",
  "point_id": "f5574333-c4d1-4477-b9b7-88c1672005b2",
  "uploader_id": "bd20af78-fb94-430b-9ea4-3f4aa6b3808c",
  "image_url": "points/image/f5574333-c4d1-4477-b9b7-88c1672005b2/1733832000000_original.jpg",
  "thumbnail_url": "points/thumbnail/f5574333-c4d1-4477-b9b7-88c1672005b2/1733832000000_thumb.jpg",
  "latitude": 25.033,
  "longitude": 121.5654,
  "country": "台灣",
  "locality": "台北市",
  "created_at": "2025-12-10T08:00:00Z"
}
```

#### 🖼️ `GET /points/:pointId/images` - 取得圖片列表

**功能**: 取得標點的所有圖片,包含 Signed URL

**範例請求**:

```bash
GET http://localhost:3000/points/f5574333-c4d1-4477-b9b7-88c1672005b2/images
```

**回應範例**:

```json
[
  {
    "id": "img-uuid",
    "point_id": "f5574333-c4d1-4477-b9b7-88c1672005b2",
    "image_url": "points/image/xxx/123_original.jpg",
    "thumbnail_url": "points/thumbnail/xxx/123_thumb.jpg",
    "signed_image_url": "https://xxx.r2.cloudflarestorage.com/...?X-Amz-Expires=3600",
    "signed_thumbnail_url": "https://xxx.r2.cloudflarestorage.com/...?X-Amz-Expires=3600",
    "latitude": 25.033,
    "longitude": 121.5654,
    "taken_at": "2025-12-10T06:00:00Z",
    "created_at": "2025-12-10T08:00:00Z"
  }
]
```

**重要**: `signed_image_url` 和 `signed_thumbnail_url` 是臨時 URL,有效期為 1 小時

---

### 3. 互動功能 API

#### ❤️ `POST /points/:pointId/like` - 按愛心

**功能**: 對標點按愛心

**Request Body**:

```json
{
  "user_id": "bd20af78-fb94-430b-9ea4-3f4aa6b3808c"
}
```

**回應範例**:

```json
{
  "success": true
}
```

**錯誤回應** (已按過):

```json
{
  "error": "Already liked"
}
```

#### 💔 `POST /points/:pointId/unlike` - 取消愛心

**功能**: 取消對標點的愛心

**Request Body**:

```json
{
  "user_id": "bd20af78-fb94-430b-9ea4-3f4aa6b3808c"
}
```

**回應範例**:

```json
{
  "success": true
}
```

#### 💬 `POST /points/:pointId/comments` - 新增留言

**功能**: 對標點新增留言

**Request Body**:

```json
{
  "user_id": "bd20af78-fb94-430b-9ea4-3f4aa6b3808c",
  "content": "這裡的夜景真的很美!"
}
```

**回應範例**:

```json
{
  "id": "comment-uuid",
  "point_id": "f5574333-c4d1-4477-b9b7-88c1672005b2",
  "user_id": "bd20af78-fb94-430b-9ea4-3f4aa6b3808c",
  "content": "這裡的夜景真的很美!",
  "likes_count": 0,
  "created_at": "2025-12-10T09:00:00Z"
}
```

#### 💬 `GET /points/:pointId/comments` - 取得留言列表

**功能**: 取得標點的所有留言

**範例請求**:

```bash
GET http://localhost:3000/points/f5574333-c4d1-4477-b9b7-88c1672005b2/comments
```

**回應範例**:

```json
[
  {
    "id": "comment-uuid",
    "point_id": "f5574333-c4d1-4477-b9b7-88c1672005b2",
    "user_id": "bd20af78-fb94-430b-9ea4-3f4aa6b3808c",
    "content": "這裡的夜景真的很美!",
    "likes_count": 5,
    "created_at": "2025-12-10T09:00:00Z"
  }
]
```

---

## 資料流程

### 前端 ↔️ 後端 ↔️ 資料庫/儲存 資料流程圖

```mermaid
sequenceDiagram
    participant F as 前端 App
    participant B as Express Backend
    participant S as Supabase DB
    participant R as Cloudflare R2

    Note over F,R: 1. 建立標點流程
    F->>B: POST /points {title, lat, lng, user_id}
    B->>S: INSERT INTO points
    S-->>B: 回傳新標點資料
    B-->>F: 201 Created {point data}

    Note over F,R: 2. 上傳圖片流程
    F->>B: POST /points/:id/images (multipart)
    B->>B: Sharp 壓縮原圖 (90% quality)
    B->>B: Sharp 生成縮圖 (300x300, 80% quality)
    B->>R: PutObject (原圖)
    B->>R: PutObject (縮圖)
    B->>S: INSERT INTO images {urls, metadata}
    S-->>B: 回傳圖片記錄
    B-->>F: 201 Created {image data}

    Note over F,R: 3. 取得圖片流程
    F->>B: GET /points/:id/images
    B->>S: SELECT * FROM images WHERE point_id=?
    S-->>B: 回傳圖片記錄 (含 R2 Keys)
    B->>B: 生成 Signed URLs (1小時有效)
    B-->>F: 200 OK {images with signed URLs}
    F->>R: 直接下載圖片 (使用 Signed URL)

    Note over F,R: 4. 按愛心流程
    F->>B: POST /points/:id/like {user_id}
    B->>S: INSERT INTO point_likes
    S-->>B: 成功
    B->>S: Realtime 推送更新
    S-->>F: Realtime 通知其他客戶端
    B-->>F: 200 OK {success: true}

    Note over F,R: 5. 新增留言流程
    F->>B: POST /points/:id/comments {user_id, content}
    B->>S: INSERT INTO point_comments
    S-->>B: 回傳留言資料
    B->>S: Realtime 推送更新
    S-->>F: Realtime 通知其他客戶端
    B-->>F: 201 Created {comment data}
```

### 資料流程說明

#### 🔄 前端 → 後端

1. **HTTP/HTTPS 請求**: 前端透過 RESTful API 發送請求
2. **格式**: JSON (一般資料) 或 multipart/form-data (圖片上傳)
3. **認證**: 目前使用 `user_id` 在 body 中傳遞 (開發階段)

#### 🔄 後端 → Supabase

1. **使用 Supabase JS Client** 進行資料庫操作
2. **自動處理**: 連線池、錯誤處理、RLS 政策驗證
3. **查詢方式**: 使用 Supabase 的 Query Builder (類似 ORM)

#### 🔄 後端 → Cloudflare R2

1. **使用 AWS S3 SDK** (R2 完全相容 S3 API)
2. **操作**: PutObject (上傳)、GetObject (下載)
3. **Signed URL**: 後端生成臨時 URL,前端直接存取 R2

#### 🔄 Supabase → 前端 (Realtime)

1. **WebSocket 連線**: Supabase Realtime 使用 WebSocket
2. **訂閱機制**: 前端訂閱特定資料表的變更
3. **即時推送**: 新增/更新/刪除時自動推送到所有訂閱者

---

## 圖片處理流程

### 上傳與處理流程圖

```mermaid
flowchart TD
    A[前端選擇圖片] --> B[發送 multipart/form-data]
    B --> C[Multer 接收檔案到記憶體]
    C --> D{Sharp 處理}

    D --> E[生成縮圖<br/>300x300, 80% quality]
    D --> F[壓縮原圖<br/>90% quality]

    E --> G[上傳縮圖到 R2<br/>points/thumbnail/:pointId/:timestamp_thumb.jpg]
    F --> H[上傳原圖到 R2<br/>points/image/:pointId/:timestamp_original.jpg]

    G --> I[儲存 metadata 到 Supabase]
    H --> I

    I --> J[回傳圖片記錄給前端]

    style D fill:#f9f,stroke:#333,stroke-width:2px
    style I fill:#bbf,stroke:#333,stroke-width:2px
```

### 圖片處理細節

#### 📤 上傳階段

1. **接收**: Multer 將檔案儲存在記憶體 (`memoryStorage`)
2. **處理**: Sharp 同時處理兩個版本
   - **縮圖**: 300x300 像素,cover 模式,JPEG 80% 品質
   - **原圖**: 保持原尺寸,JPEG 90% 品質 (輕度壓縮)
3. **命名**: `points/image/:pointId/:timestamp_original.jpg`
4. **上傳**: 使用 AWS S3 SDK 的 `PutObjectCommand`

#### 📥 下載階段

1. **查詢**: 從 Supabase 取得圖片記錄 (含 R2 Key)
2. **生成 URL**: 使用 `getSignedUrl` 生成臨時 URL (有效期 1 小時)
3. **回傳**: 前端收到 Signed URL 後直接向 R2 請求圖片
4. **優勢**: 減輕後端負擔,R2 直接服務圖片

#### 🗂️ 儲存結構

```
R2 Bucket/
├── points/
│   ├── image/
│   │   └── {pointId}/
│   │       ├── 1733832000000_original.jpg
│   │       └── 1733832100000_original.jpg
│   └── thumbnail/
│       └── {pointId}/
│           ├── 1733832000000_thumb.jpg
│           └── 1733832100000_thumb.jpg
```

**優點**:

- ✅ 依標點 ID 分類,易於管理
- ✅ 原圖與縮圖分開儲存
- ✅ 使用 timestamp 避免檔名衝突

---

## 安全性設計

### 🔐 認證與授權

#### 目前實作 (開發階段)

```javascript
// ⚠️ 開發階段:直接傳遞 user_id
{
  "user_id": "bd20af78-fb94-430b-9ea4-3f4aa6b3808c"
}
```

#### 建議實作 (生產環境)

```javascript
// ✅ 生產環境:使用 JWT Token
headers: {
  'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
}

// 後端驗證
const token = req.headers.authorization?.split(' ')[1];
const { data: { user } } = await supabase.auth.getUser(token);
// 使用 user.id 而非 req.body.user_id
```

### 🛡️ Row Level Security (RLS)

Supabase RLS 提供資料庫層級的安全性:

```sql
-- 範例:只有擁有者可以刪除標點
create policy "Users can delete their own points"
on public.points for delete
using (auth.uid() = user_id);
```

**優點**:

- ✅ 即使後端被繞過,資料庫層仍有保護
- ✅ 自動驗證 JWT Token 中的 `auth.uid()`
- ✅ 細粒度權限控制

### 🔒 圖片存取安全

#### Signed URL 機制

```javascript
// 生成有效期 1 小時的臨時 URL
const signedUrl = await getSignedUrl(r2, command, { expiresIn: 3600 });
```

**優點**:

- ✅ 防止直接存取 R2 URL
- ✅ 自動過期,無需手動撤銷
- ✅ 可追蹤存取記錄

### 🚫 CORS 設定

```javascript
app.use(cors()); // 目前允許所有來源
```

**生產環境建議**:

```javascript
app.use(
  cors({
    origin: ["https://yourdomain.com", "https://app.yourdomain.com"],
    credentials: true,
  })
);
```

### 🔍 輸入驗證

**目前實作**:

```javascript
if (!title || !lat || !lng || !user_id) {
  return res.status(400).json({ error: "Missing required fields" });
}
```

**建議改善**: 使用驗證庫 (如 `joi` 或 `zod`)

```javascript
const schema = z.object({
  title: z.string().min(1).max(100),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  user_id: z.string().uuid(),
});
```

---

## 改善建議

### 🎯 高優先級改善

#### 1. **實作完整的 JWT 認證**

**現況**: 目前直接在 body 傳遞 `user_id`,不安全
**建議**:

```javascript
// middleware/auth.js
async function authenticateUser(req, res, next) {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.status(401).json({ error: "Unauthorized" });

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser(token);
  if (error) return res.status(401).json({ error: "Invalid token" });

  req.user = user; // 將使用者資訊附加到 req
  next();
}

// 在路由中使用
router.post("/", authenticateUser, async (req, res) => {
  const user_id = req.user.id; // 從 token 取得,而非 body
  // ...
});
```

#### 2. **新增資料驗證層**

**建議**: 使用 `zod` 或 `joi` 進行輸入驗證

```javascript
const { z } = require("zod");

const createPointSchema = z.object({
  title: z.string().min(1).max(100),
  description: z.string().max(500).optional(),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

router.post("/", async (req, res) => {
  try {
    const validated = createPointSchema.parse(req.body);
    // 使用 validated 資料
  } catch (error) {
    return res.status(400).json({ error: error.errors });
  }
});
```

#### 3. **實作 Database Triggers 更新快取計數**

**現況**: `likes_count` 和 `comments_count` 欄位存在但未自動更新
**建議**: 在 Supabase 建立 Trigger

```sql
-- 當新增 like 時自動增加計數
create or replace function increment_point_likes()
returns trigger as $$
begin
  update points
  set likes_count = likes_count + 1
  where id = new.point_id;
  return new;
end;
$$ language plpgsql;

create trigger on_point_like_created
after insert on point_likes
for each row execute function increment_point_likes();

-- 刪除 like 時減少計數
create or replace function decrement_point_likes()
returns trigger as $$
begin
  update points
  set likes_count = likes_count - 1
  where id = old.point_id;
  return old;
end;
$$ language plpgsql;

create trigger on_point_like_deleted
after delete on point_likes
for each row execute function decrement_point_likes();
```

#### 4. **新增錯誤處理與日誌系統**

**建議**: 使用 `winston` 或 `pino` 進行日誌記錄

```javascript
const winston = require("winston");

const logger = winston.createLogger({
  level: "info",
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: "error.log", level: "error" }),
    new winston.transports.File({ filename: "combined.log" }),
  ],
});

// 在錯誤處理中使用
app.use((err, req, res, next) => {
  logger.error({
    message: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
  });
  res.status(500).json({ error: "Internal server error" });
});
```

---

### 🔧 中優先級改善

#### 5. **實作 Rate Limiting**

**目的**: 防止 API 濫用

```javascript
const rateLimit = require("express-rate-limit");

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 分鐘
  max: 100, // 最多 100 次請求
  message: "Too many requests from this IP",
});

app.use("/points", limiter);
```

#### 6. **新增圖片格式與大小限制**

```javascript
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = ["image/jpeg", "image/png", "image/webp"];
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error("Invalid file type"));
    }
  },
});
```

#### 7. **實作分頁功能**

**現況**: `GET /points` 會回傳所有標點
**建議**:

```javascript
router.get("/", async (req, res) => {
  const { page = 1, limit = 20 } = req.query;
  const offset = (page - 1) * limit;

  const { data, error, count } = await supabase
    .from("points")
    .select("*", { count: "exact" })
    .range(offset, offset + limit - 1);

  res.json({
    data,
    pagination: {
      page: parseInt(page),
      limit: parseInt(limit),
      total: count,
      totalPages: Math.ceil(count / limit),
    },
  });
});
```

#### 8. **新增 API 文件 (Swagger/OpenAPI)**

**建議**: 使用 `swagger-jsdoc` 和 `swagger-ui-express`

```javascript
const swaggerJsdoc = require("swagger-jsdoc");
const swaggerUi = require("swagger-ui-express");

const swaggerOptions = {
  definition: {
    openapi: "3.0.0",
    info: {
      title: "Map Photo Sharing API",
      version: "1.0.0",
    },
  },
  apis: ["./routes/*.js"],
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);
app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec));
```

---

### 💡 低優先級改善

#### 9. **實作快取機制**

**建議**: 使用 Redis 快取熱門標點

```javascript
const redis = require("redis");
const client = redis.createClient();

router.get("/:pointId", async (req, res) => {
  const cached = await client.get(`point:${req.params.pointId}`);
  if (cached) return res.json(JSON.parse(cached));

  // 從資料庫查詢...
  await client.setEx(`point:${req.params.pointId}`, 3600, JSON.stringify(data));
  res.json(data);
});
```

#### 10. **新增使用者個人資料 API**

**建議**: 新增取得使用者資訊的端點

```javascript
// routes/users.js
router.get("/me", authenticateUser, async (req, res) => {
  const { data, error } = await supabase
    .from("profiles") // 需要建立 profiles 表
    .select("*")
    .eq("id", req.user.id)
    .single();

  res.json(data);
});
```

#### 11. **實作圖片 CDN**

**建議**: 使用 Cloudflare CDN 加速圖片載入

- 在 R2 設定中啟用 Public Access
- 設定 Custom Domain
- 使用 CDN URL 而非 Signed URL (公開圖片)

#### 12. **新增搜尋功能**

**建議**: 實作全文搜尋

```javascript
router.get("/search", async (req, res) => {
  const { q } = req.query;

  const { data, error } = await supabase
    .from("points")
    .select("*")
    .textSearch("title", q); // 需要在 Supabase 設定 full-text search

  res.json(data);
});
```

---

## 📊 效能優化建議

### 資料庫優化

1. **建立索引**:

   ```sql
   -- 地理查詢索引
   create index idx_points_location on points(lat, lng);

   -- 外鍵索引
   create index idx_images_point_id on images(point_id);
   create index idx_comments_point_id on point_comments(point_id);
   ```

2. **使用 Connection Pooling**: Supabase 已內建

3. **避免 N+1 查詢**: 使用 Supabase 的 nested select

   ```javascript
   // ✅ 好的做法
   .select('*, images(*), point_likes(count)')

   // ❌ 避免
   for (const point of points) {
     const images = await getImages(point.id); // N+1 問題
   }
   ```

### API 優化

1. **壓縮回應**: 使用 `compression` middleware

   ```javascript
   const compression = require("compression");
   app.use(compression());
   ```

2. **HTTP/2**: 部署時使用支援 HTTP/2 的伺服器

3. **圖片最佳化**: 考慮使用 WebP 格式
   ```javascript
   .webp({ quality: 80 }) // 而非 .jpeg()
   ```

---

## 🚀 部署建議

### 推薦平台

1. **Vercel** (推薦)

   - 優點: 自動 HTTPS、CDN、易於部署
   - 限制: Serverless,有冷啟動時間

2. **Railway**

   - 優點: 支援長時間執行、WebSocket
   - 價格: 合理

3. **Render**
   - 優點: 免費方案、自動部署
   - 限制: 免費方案有休眠機制

### 環境變數設定

在部署平台設定以下環境變數:

```
PORT=3000
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_KEY=eyJhbGc...
R2_ACCOUNT_ID=xxx
R2_ACCESS_KEY_ID=xxx
R2_SECRET_ACCESS_KEY=xxx
R2_BUCKET_NAME=your-bucket
R2_PUBLIC_URL=https://your-r2-domain.com
```

---

## 📝 總結

### 優點

✅ **架構清晰**: 模組化設計,易於維護  
✅ **技術選擇**: Supabase + R2 是成本效益高的組合  
✅ **功能完整**: 涵蓋標點、圖片、互動等核心功能  
✅ **安全性基礎**: RLS + Signed URL 提供基本保護

### 需要改善

⚠️ **認證機制**: 需實作完整的 JWT 驗證  
⚠️ **輸入驗證**: 需加強資料驗證  
⚠️ **錯誤處理**: 需統一的錯誤處理與日誌  
⚠️ **效能優化**: 需新增快取、分頁、索引

### 建議優先順序

1. **立即處理**: JWT 認證、輸入驗證、Database Triggers
2. **短期處理**: Rate Limiting、錯誤日誌、分頁
3. **長期處理**: 快取、CDN、搜尋功能

---

**文件版本**: 1.0  
**最後更新**: 2025-12-10  
**作者**: Antigravity AI
