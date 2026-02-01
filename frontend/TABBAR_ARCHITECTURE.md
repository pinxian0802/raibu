# TabBar 架構與頁面載入邏輯詳解

## 📋 目錄
1. [TabBar 架構](#tabbar-架構)
2. [頁面載入邏輯](#頁面載入邏輯)
3. [狀態管理](#狀態管理)
4. [資料流向](#資料流向)

---

## 🏗️ TabBar 架構

### 1. 整體結構

```
ContentView (認證路由)
    └── MainTabView (主頁面容器)
        ├── ZStack (頁面層疊)
        │   ├── MapContainerView (地圖頁，Tag 0)
        │   └── ProfileView (個人頁，Tag 2)
        ├── CustomTabBar (底部 Tab Bar)
        └── Sheet (新增紀錄 Modal)
```

### 2. MainTabView 關鍵設計

#### **使用 ZStack 而非 TabView 的原因：**

**❌ 傳統 TabView 的問題：**
```swift
TabView(selection: $selectedTab) {
    MapView().tag(0)      // ⚠️ 每次切換都會重新建立
    ProfileView().tag(1)  // ⚠️ 狀態會丟失
}
```
- 切換 Tab 時會**銷毀並重建** View
- ViewModel 的資料會**丟失**
- 需要**重新載入**所有資料
- 地圖會**重置**到初始位置

**✅ ZStack + Opacity 的優勢：**
```swift
ZStack {
    MapView()
        .opacity(selectedTab == 0 ? 1 : 0)  // 👈 只是隱藏，不銷毀
    ProfileView()
        .opacity(selectedTab == 2 ? 1 : 0)  // 👈 保持狀態
}
```
- View 一旦建立就**持續存在**
- ViewModel 和資料**不會丟失**
- 切換回來時**立即顯示**
- 地圖位置、搜尋狀態都**保留**

#### **程式碼解析：**

```swift
struct MainTabView: View {
    // 1️⃣ 依賴注入
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    // 2️⃣ 狀態變數
    @State private var showCreateRecord = false      // 新增紀錄 Sheet 顯示狀態
    @State private var previousTab: Int = 0          // 記錄上一個 Tab（備用）
    @State private var hasLoadedMap = false          // 地圖是否已載入
    @State private var hasLoadedProfile = false      // 個人頁是否已載入
    
    var body: some View {
        ZStack {
            // 3️⃣ 地圖頁（永遠存在）
            MapContainerView()
                .opacity(navigationCoordinator.selectedTab == 0 ? 1 : 0)
                .zIndex(navigationCoordinator.selectedTab == 0 ? 1 : 0)
                .onAppear {
                    hasLoadedMap = true  // 標記已載入
                }
            
            // 4️⃣ 個人頁（延遲載入）
            if hasLoadedProfile || navigationCoordinator.selectedTab == 2 {
                ProfileView()
                    .opacity(navigationCoordinator.selectedTab == 2 ? 1 : 0)
                    .zIndex(navigationCoordinator.selectedTab == 2 ? 1 : 0)
                    .onAppear {
                        hasLoadedProfile = true
                    }
            }
        }
        .overlay(alignment: .bottom) {
            // 5️⃣ 自定義 Tab Bar
            CustomTabBar(
                selectedTab: Binding(
                    get: { navigationCoordinator.selectedTab },
                    set: { newValue in
                        if newValue == 1 {
                            // Tag 1 = 新增按鈕，不切換頁面
                            showCreateRecord = true
                        } else {
                            // Tag 0/2 = 正常切換
                            navigationCoordinator.selectedTab = newValue
                        }
                    }
                ),
                onCreateTapped: {
                    showCreateRecord = true
                }
            )
        }
        .sheet(isPresented: $showCreateRecord) {
            // 6️⃣ 新增紀錄 Modal
            CreateRecordFullView(...)
        }
    }
}
```

### 3. CustomTabBar 設計

```swift
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let onCreateTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Tab 0: 地圖
            TabBarButton(icon: "map", title: "地圖", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            
            // Tab 1: 新增（中間大按鈕）
            Button(action: onCreateTapped) {
                Circle().fill(Color.blue)
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "plus"))
            }
            .offset(y: -16)  // 👈 上移，突出效果
            
            // Tab 2: 個人
            TabBarButton(icon: "person.circle", title: "個人", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .background(.ultraThinMaterial)  // 毛玻璃效果
    }
}
```

---

## 🔄 頁面載入邏輯

### 1. 地圖頁載入流程

```
用戶啟動 App
    ↓
ContentView.onAppear
    ↓
authService.checkAuthStatus()  (檢查登入狀態)
    ↓
已登入 → MainTabView
    ↓
MapContainerView (立即載入)
    ↓
MapContentView.init
    ↓
建立 MapViewModel
    ↓
MapView 顯示 (初始位置：台北)
    ↓
用戶操作 → 觸發資料載入
```

#### **MapViewModel 載入邏輯：**

```swift
class MapViewModel: ObservableObject {
    // 1️⃣ 初始化
    init(...) {
        self.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 25.033, longitude: 121.565),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }
    
    // 2️⃣ 地圖區域變更時
    func onRegionChanged(_ newRegion: MKCoordinateRegion, mapSize: CGSize) {
        self.region = newRegion
        
        // 檢查是否需要重新載入（移動距離檢測）
        if let lastRegion = lastFetchedRegion {
            let latDiff = abs(newRegion.center.latitude - lastRegion.center.latitude)
            let lngDiff = abs(newRegion.center.longitude - lastRegion.center.longitude)
            
            // 如果移動距離太小，只更新群集，不重新載入
            if latDiff < 0.001 && lngDiff < 0.001 {
                updateClusters()  // 👈 只重新分群，不請求 API
                return
            }
        }
        
        // 防抖：取消之前的請求，500ms 後才執行
        fetchTask?.cancel()
        fetchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms
            
            if !Task.isCancelled {
                await fetchDataForCurrentRegion()  // 👈 請求 API
                updateClusters()
            }
        }
    }
    
    // 3️⃣ 載入地圖資料
    func fetchDataForCurrentRegion() async {
        isLoading = true
        
        do {
            switch currentMode {
            case .record:
                recordImages = try await recordRepository.getMapRecords(
                    minLat: bounds.minLat,
                    maxLat: bounds.maxLat,
                    minLng: bounds.minLng,
                    maxLng: bounds.maxLng
                )
            case .ask:
                asks = try await askRepository.getMapAsks(...)
            }
            
            lastFetchedRegion = region  // 👈 記錄已載入的區域
            updateClusters()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
```

### 2. 個人頁載入流程

```
用戶點擊「個人」Tab
    ↓
MainTabView: hasLoadedProfile = false
    ↓
觸發 if 條件 → 建立 ProfileView
    ↓
ProfileFullView.task { }
    ↓
viewModel.loadProfile()        (載入個人資料)
    ↓
loadCurrentTabData()           (載入當前 Tab 資料)
    ↓
selectedTab == 0 → loadMyRecords()
selectedTab == 1 → loadMyAsks()
```

#### **ProfileViewModel 快取邏輯：**

```swift
class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var myRecords: [Record] = []
    @Published var myAsks: [Ask] = []
    
    // 快取標記
    private var hasLoadedProfile = false
    private var hasLoadedRecords = false
    private var hasLoadedAsks = false
    
    // 1️⃣ 載入個人資料（帶快取）
    func loadProfile(forceRefresh: Bool = false) async {
        // 👇 已載入且非強制刷新 → 跳過
        guard !hasLoadedProfile || forceRefresh else { return }
        
        isLoadingProfile = true
        
        do {
            profile = try await userRepository.getMe()
            hasLoadedProfile = true  // 👈 標記已載入
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoadingProfile = false
    }
    
    // 2️⃣ 載入紀錄列表（帶快取）
    func loadMyRecords(forceRefresh: Bool = false) async {
        guard !hasLoadedRecords || forceRefresh else { return }
        
        isLoadingRecords = true
        myRecords = try await userRepository.getMyRecords()
        hasLoadedRecords = true
        isLoadingRecords = false
    }
    
    // 3️⃣ 刷新所有資料（下拉刷新用）
    func refreshAll() async {
        async let profile: () = loadProfile(forceRefresh: true)
        async let records: () = loadMyRecords(forceRefresh: true)
        async let asks: () = loadMyAsks(forceRefresh: true)
        
        _ = await (profile, records, asks)  // 👈 並行執行
    }
}
```

#### **ProfileFullView 載入策略：**

```swift
struct ProfileFullView: View {
    @StateObject private var viewModel: ProfileViewModel
    @State private var selectedTab = 0  // 0=紀錄, 1=詢問
    
    var body: some View {
        ScrollView {
            // ... UI
        }
        .refreshable {
            // 👇 下拉刷新
            await viewModel.refreshAll()
        }
        .task {
            // 👇 初次載入
            await viewModel.loadProfile()
            await loadCurrentTabData()
        }
        .onChange(of: selectedTab) { _, newTab in
            // 👇 切換 Tab 時載入對應資料
            Task {
                await loadCurrentTabData()
            }
        }
    }
    
    private func loadCurrentTabData() async {
        if selectedTab == 0 {
            await viewModel.loadMyRecords()  // 👈 有快取，不會重複載入
        } else {
            await viewModel.loadMyAsks()
        }
    }
}
```

---

## 🎛️ 狀態管理

### 1. NavigationCoordinator（全域導航）

```swift
class NavigationCoordinator: ObservableObject {
    @Published var selectedTab: Int = 0              // 當前 Tab
    @Published var targetCoordinate: Coordinate?     // 目標座標
    @Published var targetMapMode: MapMode?           // 目標地圖模式
    
    // 跳轉到地圖
    func navigateToMap(coordinate: CLLocationCoordinate2D, mapMode: MapMode? = nil) {
        targetCoordinate = Coordinate(from: coordinate)
        targetMapMode = mapMode
        selectedTab = 0  // 切換到地圖 Tab
    }
}
```

**使用場景：**
```swift
// 在詳情頁點擊「查看位置」
Button("查看位置") {
    dismiss()  // 關閉當前 Sheet
    navigationCoordinator.navigateToMap(
        coordinate: location,
        mapMode: .record
    )
}
```

### 2. DIContainer（依賴注入）

```swift
class DIContainer: ObservableObject {
    // 核心服務（單例）
    let apiClient: APIClient
    let authService: AuthService
    let locationManager: LocationManager
    let uploadService: UploadService
    
    // Repository（延遲載入）
    lazy var recordRepository: RecordRepository = {
        RecordRepository(apiClient: apiClient)
    }()
    
    lazy var userRepository: UserRepository = {
        UserRepository(apiClient: apiClient)
    }()
}
```

**注入方式：**
```swift
@main
struct RaibuApp: App {
    @StateObject private var container = DIContainer()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .environmentObject(container.authService)
                .environmentObject(container.locationManager)
        }
    }
}
```

---

## 📊 資料流向圖

### 完整流程

```
1. App 啟動
   └─> RaibuApp
       └─> 建立 DIContainer (單例)
           ├─> APIClient
           ├─> AuthService
           └─> LocationManager

2. ContentView 載入
   └─> .task { authService.checkAuthStatus() }
       ├─> 未登入 → AuthContainerView
       └─> 已登入 → MainTabView

3. MainTabView 建立
   └─> ZStack {
       ├─> MapContainerView (立即建立)
       │   └─> MapContentView
       │       └─> MapViewModel(@StateObject)
       │           ├─> 初始化（台北）
       │           └─> 等待用戶操作
       │
       └─> ProfileView (延遲建立)
           └─> ProfileFullView
               └─> ProfileViewModel(@StateObject)
   }

4. 用戶操作地圖
   └─> onRegionChanged()
       └─> 500ms 防抖
           └─> 距離檢測
               ├─> 移動太小 → updateClusters()
               └─> 移動夠大 → fetchDataForCurrentRegion()
                   └─> API 請求
                       └─> 更新 recordImages/asks
                           └─> updateClusters()

5. 用戶切換到個人頁
   └─> CustomTabBar: selectedTab = 2
       └─> MainTabView: 觸發 if hasLoadedProfile
           └─> 建立 ProfileView
               └─> .task { }
                   ├─> loadProfile()
                   └─> loadMyRecords()
                       └─> 檢查 hasLoadedRecords
                           ├─> false → API 請求
                           └─> true → 跳過

6. 用戶切換回地圖
   └─> CustomTabBar: selectedTab = 0
       └─> MainTabView: opacity = 1
           └─> 地圖狀態完整保留
               ├─> 位置不變
               ├─> 資料不變
               └─> 搜尋狀態不變
```

---

## 🎯 關鍵優化點

### 1. 防止重複載入
- ✅ 使用 `hasLoaded` 標記
- ✅ 只在 `forceRefresh` 時重新載入
- ✅ 支援下拉刷新

### 2. 地圖效能優化
- ✅ 500ms 防抖
- ✅ 移動距離檢測（< 0.001° 不重新載入）
- ✅ 記錄 `lastFetchedRegion`

### 3. 頁面狀態保持
- ✅ ZStack + opacity（不是 TabView）
- ✅ View 不會被銷毀
- ✅ ViewModel 狀態持續存在

### 4. 按需載入
- ✅ ProfileView 延遲建立
- ✅ Tab 切換時才載入對應資料
- ✅ 並行載入多個資料源

---

## 🔍 常見問題

### Q1: 為什麼地圖會重複載入？
**A:** 確認是否使用了 TabView，應該改用 ZStack + opacity。

### Q2: 切換 Tab 資料丟失？
**A:** 檢查是否使用 `@StateObject`（正確）而非 `@ObservedObject`。

### Q3: 如何強制刷新資料？
**A:** 使用 `.refreshable { }` 或呼叫 `viewModel.refreshAll()`。

### Q4: 地圖移動太頻繁請求 API？
**A:** 已實作 500ms 防抖 + 距離檢測，小範圍移動不會請求。
