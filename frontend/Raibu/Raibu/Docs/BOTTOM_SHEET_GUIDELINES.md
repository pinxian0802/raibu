# Bottom Sheet 實作指南（Raibu）

最後更新：2026-02-22

## 1. 這份文件的目的
本文件是 `raibu` 專案的 Bottom Sheet 統一規格，目標是避免：
- 頂部留白不一致
- 同時出現系統導覽列與自訂導覽列
- 叉叉與返回箭頭切換時機混亂
- 不同頁面按鈕樣式不一致（陰影、圓底、字重不一）

## 2. 整體架構（先看這段）
Bottom Sheet 目前採用「全域單一 Host + Router 路由」模式：

1. `GlobalDetailSheetHost` 掛在 App 全域（只掛一次）
2. 任何地方呼叫 `detailSheetRouter.open(route)` 開啟內容
3. Host 用 `NavigationStack(path:)` 管理 Sheet 內頁面切換
4. 各頁面本身用 `BottomSheetScaffold` 畫一致的頂部結構

資料流概念：

```text
畫面事件（點卡片、點頭像、點編輯）
        ↓
detailSheetRouter.open(.xxx)
        ↓
GlobalDetailSheetHost 讀取 rootRoute/path
        ↓
NavigationStack 顯示對應 routeView
        ↓
每個內容頁用 BottomSheetScaffold 呈現統一 UI
```

## 3. 核心檔案與責任
- `frontend/raibu/raibu/App/DetailSheetRouter.swift`
  - 管理 Sheet 的路由狀態（是否開啟、根頁、堆疊）
- `frontend/raibu/raibu/App/GlobalDetailSheetHost.swift`
  - 真正承載 `.sheet` 的全域容器，依 route 顯示頁面
- `frontend/raibu/raibu/Shared/Components/SheetTopHandle.swift`
  - 統一頂部 UI 常數與骨架元件：`BottomSheetLayoutMetrics`、`SheetTopHandle`、`BottomSheetScaffold`
- 代表頁面
  - `frontend/raibu/raibu/Features/Record/Views/RecordDetailSheetView.swift`
  - `frontend/raibu/raibu/Features/Record/Views/EditRecordView.swift`
  - `frontend/raibu/raibu/Features/Profile/Views/OtherUserProfileView.swift`

## 4. 名詞解釋（含你問的 `open()`）
### `DetailSheetRoute`
用來描述要顯示哪一頁，例如：
- `.record(id:imageIndex:)`
- `.recordEdit(id:)`
- `.ask(id:)`
- `.userProfile(id:)`

### `detailSheetRouter.open(route)`
這是「統一入口」。它會判斷目前 Sheet 狀態，自動決定：
- 若 Sheet 尚未打開：`present(route)`（把它當 root 開新流程）
- 若 Sheet 已打開：`push(route)`（在同一個 Sheet 內切下一頁）

簡單說：`open()` = 「開或推」的智慧封裝，不用每次自己判斷。

### `present(route)`
開啟一個新的 Bottom Sheet 流程：
- 設定 `rootRoute = route`
- 清空 `path`
- `isPresented = true`

### `push(route)`
在現有 Bottom Sheet 流程中往下一頁：
- `path.append(route)`
- 畫面上看起來是同一張 Sheet 內導航，不會再彈第二張 Sheet

### `dismiss()`
關閉整張全域 Sheet 並清空狀態：
- `isPresented = false`
- `rootRoute = nil`
- `path = []`

### `rootRoute`
Sheet 開起來時的第一頁（根頁）。

### `path`
`NavigationStack` 的後續頁堆疊。  
`path` 為空通常代表目前在根頁；`path` 有值代表你已經 push 到下一層。

### `@Environment(\.dismiss)`
SwiftUI 的「關閉當前呈現層」工具。  
在 Sheet 內常用來返回上層或關閉當前頁；但全域流程收尾仍以 `detailSheetRouter.dismiss()` 為主。

### `BottomSheetScaffold`
統一頂部骨架：
- Handle（灰色膠囊）
- Top Bar（leading / title / trailing）
- Content（頁面內容）

## 5. 視覺規格（Source of Truth）
所有頂部尺寸請統一來自 `BottomSheetLayoutMetrics`（`SheetTopHandle.swift`）：
- `handleTopPadding = 10`
- `handleBottomPadding = 10`
- `topBarHorizontalPadding = 24`
- `topBarHeight = 44`
- `topBarBottomPadding = 4`

禁止在 feature view 任意硬編頂部常數，除非「該頁明確特例」且有註解說明原因。

## 6. 統一實作規則（必須遵守）
1. 有自訂 top area 的頁面，必須隱藏系統導覽列
- `.navigationBarBackButtonHidden(true)`
- `.toolbar(.hidden, for: .navigationBar)`

2. 頂部骨架一律用 `BottomSheetScaffold`
- 不自行重做 handle 與 top bar

3. 左上按鈕一律 plain style
- `.buttonStyle(.plain)`
- 不加陰影、不加圓底背景

4. 同頁面的 loading 與 loaded 狀態，頂部 spacing 必須一致
- 避免切換狀態時「內容跳動」

5. 禁止在同流程中開第二張 detail sheet
- 需要切下一頁時用 `detailSheetRouter.open(...)`（讓它走 push）

6. 返回轉場期間，leading button 樣式不可變動（防止箭頭變叉叉）
- 禁止在動畫中直接依 `path.isEmpty` 即時切換 icon
- 進頁時先解析並鎖定樣式（close/back），離開前不再改變

7. 返回轉場期間，top bar 不可瞬間消失（防止箭頭不見）
- 若返回按鈕由路由狀態決定顯示，按下返回時要先設置「保留顯示」旗標
- 例如 `keepBackButtonVisibleDuringDismiss = true` 後再 `dismiss()`

## 7. 叉叉與返回箭頭：何時出現
### 原則
- 根頁（Root）通常用 `xmark`，代表「關閉整個流程」
- 推入頁（Push）通常用 `chevron.left`，代表「回上一層」

### 本專案目前實作要點
1. `EditRecordView`
- 編輯頁作為流程頁面時，以 `xmark` 關閉（設計語意是結束編輯流程）

2. `RecordDetailSheetView`
- 依 `detailSheetRouter.path` 判斷是否顯示 top bar 與返回箭頭
- 有返回箭頭時，通常代表在 detail 內層狀態

3. `OtherUserProfileContentView`
- 會依 `showCloseButton`、`path` 與環境值決定顯示 `xmark` 或 `chevron.left`
- 返回動畫期間必須維持進頁當下的 icon，不可中途從 `chevron.left` 跳成 `xmark`

## 8. `open()` 實際使用情境
### 情境 A：從地圖點紀錄（尚未開 Sheet）
呼叫：`detailSheetRouter.open(.record(...))`  
結果：`open()` 走 `present()`，開一張新的全域 Bottom Sheet。

### 情境 B：在紀錄詳情點作者頭像（Sheet 已開）
呼叫：`detailSheetRouter.open(.userProfile(id: ...))`  
結果：`open()` 走 `push()`，在同一張 Sheet 內切到個人頁。

### 情境 C：在紀錄詳情點編輯
呼叫：`detailSheetRouter.openRecordEdit(id:prefetchedRecord:)`  
結果：
- 先快取既有資料（prefetch）減少等待
- 再透過 `open(.recordEdit)` 進同一張 Sheet 內編輯頁

## 9. 標準模板（新頁面照這個起手）
```swift
BottomSheetScaffold(
    showsHandle: true,
    showsTopBar: true,
    leading: {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
        }
        .buttonStyle(.plain)
    },
    title: {
        Text("標題")
    },
    trailing: {
        Button("儲存") { /* action */ }
            .buttonStyle(.plain)
    },
    content: {
        // page content
    }
)
.navigationBarBackButtonHidden(true)
.toolbar(.hidden, for: .navigationBar)
```

## 10. 常見錯誤與排查
### 問題：頂部變高、留白很怪
先檢查：
- 是否同時存在系統導覽列與自訂 top bar
- 是否某狀態（loading）少了與正式內容相同的 top padding

### 問題：點擊後一瞬間出現錯誤箭頭/叉叉
先檢查：
- 按鈕顯示條件是否只看「當前 route」
- 是否在 route 尚未穩定前就先渲染了錯誤狀態

修正策略（必做）：
- 在 `.onAppear` 鎖定 `leading button style`（`close` 或 `back`）
- 返回動畫期間使用鎖定值，不要重新讀 `path.isEmpty`

### 問題：點返回後，返回箭頭在動畫中消失
先檢查：
- `showsTopBar` 是否直接綁到會在 pop 前就改變的路由條件
- 按返回時是否立即讓 `shouldShowBackButton` 變成 `false`

修正策略（必做）：
- 新增「返回中保留顯示」旗標（如 `keepBackButtonVisibleDuringDismiss`）
- 點返回先開旗標，再呼叫 `dismiss()`

### 問題：開了第二張 Sheet
先檢查：
- 是否誤用 `.sheet` 包另一頁
- 是否該動作其實應改成 `detailSheetRouter.open(...)`

## 11. PR 前檢查清單
1. 沒有「系統導覽列 + 自訂 top bar」雙重頂部。
2. Handle 只出現一次。
3. Top spacing 使用共享常數，特例有註解。
4. 左上按鈕是 `.buttonStyle(.plain)`，無陰影。
5. 同一頁 loading/loaded 的頂部間距一致。
6. 測試 root 與 push 兩種進入方式。
7. 由 detail 進下一頁時，確認是在同一張 Sheet 內切換。
8. 測試「返回動畫中」leading button 不會從箭頭跳叉叉。
9. 測試「返回動畫中」返回箭頭與 top bar 不會消失。

## 12. 目前已採用此規格的頁面
- `CreateRecordFullView`
- `EditRecordView`
- `RecordDetailSheetView`
- `OtherUserProfileContentView`
- `AskDetailSheetView`（建議持續比對一致性）

後續新增或修改 Bottom Sheet，請以本文件為準。
