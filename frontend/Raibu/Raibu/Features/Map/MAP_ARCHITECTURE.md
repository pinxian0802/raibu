# Map Module Architecture

## 概述

Map 模組負責地圖相關的所有功能，包含地圖顯示、標註管理、群集處理、模式切換等。

---

## 目錄結構

```
Features/Map/
├── Models/
│   └── MapModels.swift          # MapRecordImage, MapAsk, ClusterItem 等
├── ViewModels/
│   └── MapViewModel.swift       # 地圖業務邏輯
└── Views/
    ├── MapContainerView.swift   # 主視圖容器
    ├── MapViewRepresentable.swift  # UIKit MKMapView 橋接
    ├── MapIconFactory.swift     # 圖標繪製工廠
    ├── ClusterAnnotation.swift  # 標註類別
    └── ClusterGridSheetView.swift  # 群集列表 Sheet
```

---

## 元件說明

### MapContainerView.swift

**入口視圖**，負責：

- 注入依賴（DIContainer）
- 管理 ViewModel 生命週期
- 處理 Sheet 呈現邏輯
- 回應導航協調器跳轉請求
- UI 控制元件（搜尋列、模式切換器、定位按鈕）

### MapViewRepresentable.swift

**UIKit 橋接層**，負責：

- 包裝 MKMapView
- 同步 SwiftUI region 與 MKMapView
- 差異化更新標註（避免閃爍）
- 處理手勢（長按建立詢問）
- 委派 MKMapViewDelegate 事件

### MapIconFactory.swift

**圖標繪製工廠**，提供靜態方法：

- `createThumbnailIcon(from:)` - 縮圖圖標
- `createThumbnailWithBadge(from:count:)` - 帶數量的群集縮圖
- `createAskIcon()` - 詢問標點圖標
- `createClusterIcon(count:mode:)` - 群集數字圖標
- 圖片快取管理（限制 100 張 / 50MB）

### ClusterAnnotation.swift

**標註類別**，遵循 `MKAnnotation` 協議，包含：

- 群集資料 (`ClusterResult`)
- 地圖模式 (`MapMode`)
- 唯一識別碼

### MapViewModel.swift

**業務邏輯層**，負責：

- 地圖模式切換
- 資料載入（Records / Asks）
- 群集計算
- 座標搜尋

---

## 資料流

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  MapContentView │────▶│   MapViewModel   │────▶│   Repository    │
│   (SwiftUI)     │◀────│   (@Published)   │◀────│   (API / DB)    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌──────────────────┐
│ MapViewRepre-   │     │ ClusteringService│
│ sentable(UIKit) │◀────│   (群集演算)      │
└─────────────────┘     └──────────────────┘
         │
         ▼
┌─────────────────┐
│ MapIconFactory  │
│   (圖標繪製)     │
└─────────────────┘
```

---

## 地圖模式

| 模式      | 說明     | 標點類型             |
| --------- | -------- | -------------------- |
| `.record` | 紀錄模式 | 顯示使用者的照片紀錄 |
| `.ask`    | 詢問模式 | 顯示 48 小時內的詢問 |

---

## 互動說明

### 點擊標點

1. 單一項目 → 開啟詳情 Sheet
2. 群集（縮放等級高）→ 顯示群集列表
3. 群集（縮放等級低）→ 放大地圖

### 長按地圖

- 僅在 Ask 模式下有效
- 開啟建立詢問 Sheet

---

## 快取策略

- **圖片快取**：`NSCache`，限制 100 張 / 50MB
- **URL 快取**：使用 `.returnCacheDataElseLoad` 策略
