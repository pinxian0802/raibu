# 添加用戶描述欄位 - 更新說明

## 概述
此更新為用戶資料添加了「個人描述」(bio) 欄位，用戶可以在註冊時設定，並顯示在個人資訊頁面。

## 資料庫遷移

### 方式一：直接在 Supabase 控制台執行
1. 登入 Supabase Dashboard
2. 選擇你的專案
3. 前往 SQL Editor
4. 執行以下 SQL：

```sql
-- Add bio column to users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS bio TEXT;

-- Add comment
COMMENT ON COLUMN public.users.bio IS 'User biography/description';
```

### 方式二：使用遷移檔案
```bash
# 執行遷移檔案
psql <your_database_url> -f backend/migrations/add_user_bio.sql
```

## 更新內容

### 後端變更
1. **資料庫 Schema** (`backend/schema.sql`)
   - 在 `users` 表中新增 `bio TEXT` 欄位

2. **API 更新** (`backend/routes/users.js`)
   - `GET /api/v1/users/me`: 返回 `bio` 欄位
   - `PATCH /api/v1/users/me`: 支援更新 `bio` 欄位

### 前端變更
1. **資料模型** (`frontend/raibu/raibu/Shared/Models/User.swift`)
   - `User` 結構新增 `bio: String?` 屬性
   - `UserProfile` 結構新增 `bio: String?` 屬性

2. **註冊流程** (`frontend/raibu/raibu/Features/Auth/Views/ProfileSetupView.swift`)
   - 新增個人描述輸入框（支援多行，3-5行）
   - 更新 API 請求以包含 bio 欄位

3. **個人資訊頁面** (`frontend/raibu/raibu/Features/Profile/Views/ProfileFullView.swift`)
   - 在姓名下方顯示個人描述
   - 描述字體比姓名小，灰色顯示
   - 最多顯示 2 行，超出省略
   - 更新骨架屏匹配新佈局

## UI 展示

### 註冊設定畫面
- 頭像選擇器
- 個人描述輸入框（佔位符："介紹一下自己吧..."）
- 確認按鈕

### 個人資訊頁面
```
┌────────────────────────────┐
│  [頭像]  使用者名稱         │
│         個人描述...         │
└────────────────────────────┘
```

## 測試建議

1. **新用戶註冊流程**
   - 測試帶描述的註冊
   - 測試不填描述的註冊（應該正常）
   - 測試多行描述

2. **個人資訊頁面**
   - 檢查描述顯示正確
   - 檢查沒有描述時不顯示該區域
   - 檢查長描述的省略功能

3. **API 測試**
   - 測試 PATCH /api/v1/users/me 更新 bio
   - 測試 GET /api/v1/users/me 返回 bio

## 注意事項
- bio 欄位為可選（nullable），不填寫不會影響功能
- 前端會自動處理空描述的顯示
- 描述長度無限制，但前端顯示限制為 2 行
