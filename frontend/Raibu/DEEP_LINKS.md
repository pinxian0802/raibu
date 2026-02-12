# Deep Links (iOS)

本文件說明 Raibu iOS App 目前支援的 deep link 格式與使用方式。

## 支援的路由

### 1. Custom Scheme (`raibu://`)

- 紀錄詳情：`raibu://record/{recordId}`
- 詢問詳情：`raibu://ask/{askId}`
- 使用者頁：`raibu://user/{userId}`

可選參數：

- `imageIndex`（僅紀錄詳情）  
  範例：`raibu://record/abc123?imageIndex=2`

### 2. Universal Link (`https://raibu.app`)

- 紀錄詳情：`https://raibu.app/record/{recordId}`
- 詢問詳情：`https://raibu.app/ask/{askId}`
- 使用者頁：`https://raibu.app/user/{userId}`

`www` 也支援：

- `https://www.raibu.app/record/{recordId}`

## 行為規則

1. 若 URL 被解析為 deep link，會轉成 `DetailSheetRoute` 並由全域 `DetailSheetRouter` 開啟。
2. 若使用者已登入（`AuthState.authenticated`），會立即開啟詳情 Bottom Sheet。
3. 若使用者未登入，route 會先暫存；登入成功後自動開啟。
4. `raibu://auth-callback#...` 不會被 deep link parser 攔截，仍走既有 Auth callback 流程。

## 程式碼位置

- URL 解析：`frontend/raibu/raibu/App/DeepLinkParser.swift`
- App 入口分流：`frontend/raibu/raibu/App/RaibuApp.swift`
- 全域詳情路由：`frontend/raibu/raibu/App/DetailSheetRouter.swift`
- 全域詳情 Sheet Host：`frontend/raibu/raibu/App/GlobalDetailSheetHost.swift`

## 本機測試方式

先啟動模擬器與 App，再執行：

```bash
xcrun simctl openurl booted "raibu://record/RECORD_ID"
xcrun simctl openurl booted "raibu://ask/ASK_ID"
xcrun simctl openurl booted "raibu://user/USER_ID"
```

測試帶參數：

```bash
xcrun simctl openurl booted "raibu://record/RECORD_ID?imageIndex=3"
```

## 注意事項

1. 若要從外部 App/瀏覽器喚起 `raibu://`，需在 iOS target 設定 URL Types（Scheme: `raibu`）。
2. Universal Links 需另外完成 Associated Domains 與網域設定（`apple-app-site-association`）。
3. 不合法格式會被安全忽略，不會造成 App crash。

