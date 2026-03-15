# 系統架構設計書 (System Architecture Document - SAD)
## 系統：災難應急 Mesh 物資調度系統 (Project ResQMesh)

### 1. 系統總覽與拓撲設計
系統採「去中心化邊緣運算為主，中央雲端收集為輔」的分散式架構。無網時為 **M-to-N P2P 網狀叢集 (P2P_CLUSTER)**。

**App 技術框架**：Flutter（跨平台 iOS/Android 統一代碼庫）

考量現實設備的硬體異質性，網路節點明確分為**四個**傳輸能力層級：

| 層級 | 裝置狀態條件 | 通訊技術 | 系統角色與職責 |
|------|---------|---------|---------|
| **Tier 0<br>(硬體騾子)** | 安裝於公務車輛的 IoT 節點<br>(警車、垃圾車等) | Wi-Fi Aware (NAN) + BLE 雙通道<br>+ 車載 4G 路由器 (可選) | **跨區絕子主幹**：<br>無電池焦慮、無儲存上限，負責跨縣市大範圍資料拉取與搬運。享有最高豁免：距離衰減豁免、資料驅逐保護、Rate Limiting 豁免、直接透過車載 4G 路由器上報中央、永遠使用分塊 Bloom Filter。 |
| **Tier 1<br>(全速節點)** | **Android**: 前景或背景 (掛載 Foreground Service)<br>**iOS**: 前台 (Foreground) | **Android**: Wi-Fi Aware (NAN) + BLE 雙通道<br>**iOS**: BLE 探索 + 發起 AWDL 通道 | **Mesh 主幹網路**：<br>Android 建立常態高速通道，**且同時維持 BLE 廣播監聽以相容跨系統(iOS)與低階節點**。iOS 則透過 BLE 發現彼此並接收小封包，遇大檔(地圖/照片)需求時，透過 BLE 協商配對 AWDL 建立大頻寬高速通道。**(Tier 1 Android (掛載 Foreground Service) 具備跨區距離衰減豁免特權；iOS 前台雖屬 Tier 1 但不具備此特權，因系統對背景廣播的嚴格限制，全功率 Data Mule 模式僅限 Android Tier 1 設備實施)**。 |
| **Tier 2<br>(背景中繼)** | **iOS**: 背景 (Suspended狀態靠 BLE 喚醒)<br>**Android**: 電量 < 40% 降級狀態 | **BLE Only**<br>(事件驅動與低速) | **低頻寬中繼站**：<br>關閉 Wi-Fi 級別廣播。僅靠 BLE 發送/接收 512 Bytes 等級核心短訊 (如 SOS, INFO)。 |
| **Tier 3<br>(瀕死求生)** | **所有設備**: 電量極低 (如跌破 20%) | **BLE 廣播 Only** | **極限求生 Beacon**：<br>關閉所有高耗電連線與接收功能，停止轉發任何路人封包。全機僅保留 BLE 向外廣播自身的求救訊號 (SOS)。 |

> **iOS 傳輸特別宣告**：
> 1. iOS App 進入背景即會被暫停，無法維持 AWDL 通道。但可受惠於 CoreBluetooth 喚醒機制，在背景以 Tier 2 進行基礎中繼轉發。
> 2. iOS 前台裝置平時以 BLE 索敵可節省電量，當有大頻寬交換需求（如離線地圖、照片 Chunking 交換）時，才臨時觸發 **AWDL (Network Framework `includePeerToPeer`)** 自動配對連線。跨系統高速傳輸仍有待突破，跨平台依舊以 BLE 為通用骨幹。
> 3. **iOS 前台裝置雖屬 Tier 1，但不具備跨區距離衰減豁免特權（Mule Exemption），因其無法在背景全天候保持穩定連線，系統不允許 iOS 自動擔任 Data Mule 角色。**
> 4. **Tier 0 硬體騾子**（車載 IoT 設備）享有所有層級中最高等級的豁免，不受電量限制、儲存容量限制、Rate Limiting 或資料驅逐策略約束。

### 2. 四層架構定義與優化 (Architecture Layers)

#### 2.1 傳輸層 (Transport Layer)
*   **核心技術與頻寬通道**：
    *   **iOS ↔ iOS 高速通道**：使用 Apple **AWDL** (Network Framework, `includePeerToPeer=true`)，前台自動發現與建立 TCP/UDP 連線，傳輸大檔案 (如離線地圖、照片)，無須用戶配對。
    *   **Android ↔ Android 高速通道**：使用 **Wi-Fi Aware (NAN)**，前景與掛載 Foreground Service 時，建立高速通道與自動轉運。
    *   **跨系統及背景中繼 (異質骨幹)**：使用 **BLE (GATT / L2CAP)**。為 iOS 與 Android 之間唯一可靠免配對通道，且是 iOS 背景狀態 (Tier 2) 下的唯一傳輸選項。
*   **協商與切換流程**：
    1.  設備固定以 BLE 廣告 (Advertising) 形式向周圍廣播自己存在的 Beacon，交換極小 Metadata (含 `device_tier` 與支援的頻寬能力)。
    2.  若雙方皆為 `Tier 1` 且屬同系統（iOS碰iOS / Android碰Android），自動轉入 AWDL 或 Wi-Fi Aware 完成 Bloom Filter 與大數據交換。
    3.  若雙方跨系統，或其中一方為 iOS 背景 `Tier 2`，系統將降速採用 BLE 模式進行 512 bytes 級別的 Protobuf 狀態與求救訊息握手。
    4.  完成或斷開後，節點各自回歸休眠或維持脈衝監聽，節省總體耗電。

#### 2.2 路由與擴散層 (Routing & Dissemination Layer)
*   **演算法**：優先權驅動的疫情路由 (Priority-Driven Epidemic Routing)。
*   **封包 QoS 與路由霸權 (Triage)**：
    *   `SOS_RED`：賦予最大初始 TTL (如 20) 及最高頻寬優先度，強制中斷節點內其他低優先級 Socket。
    *   `INFO` / `RESOURCE`：常規擴散，TTL 設定較低 (如 5)。
    *   **地理圍欄 —動態自適應機制 (Adaptive Geo-Fencing)**：為對應台灣山地地形起伏極大的環境差異（西山市區 vs. 南迢公路深山），路由層採用四層分級邏輯決定是否轉發：

        **第一層：通用前置驗證**（所有封包皆適用）
        *   驗證 Ed25519 簽章有效性 + 發送者未在本地黑名單。不合規者一律丟棄，不進入後續判斷。

        **第二層：SOS_RED 身分分級豁免（Urgency × Identity Override）**
        *   `urgency == SOS_RED` 且 `identity_level >= 1`（手機號已驗證）：**完整跳過所有距離限制，全功率擴散。**手機號認證的僳造成本足夠仇禮止假用，此級用戶的 SOS_RED 話號完全信任。
        *   `urgency == SOS_RED` 且 `identity_level == 0`（匿名）：**不享完整豁免，改以 5× 寬鬆倍率往下計算。**確保真實遇難的匿名用戶訊號仍可在附近範圍傳播，並防止惡意批量產生匿名帳號發假 SOS 燒遍全台 Mesh。

        **第三層：Tier 0 & Data Mule 特權（Mule Exemption）**
        *   `currentNode.tier == TIER_0_HARDWARE_MULE`：永遠豁免，不計算距離。
        *   `currentNode.platform == ANDROID && currentNode.tier == TIER_1 && currentNode.hasForegroundService`：跨區搬運豁免。
        *   **重要：iOS 前台（即使是 Tier 1）不在此豁免範圍。**

        **第四層：常規距離衰減計算**
        *   使用**「接收位置快照 (`received_lat` / `received_lng`)」**而非轉發時的當前位置，防止搬運途中的節點在移動後錯殺合法封包。
        *   緊急程度**自適應衰減倍率表**：

        | `urgency` | 衰減倍率 | 適用場景 |
        |-----------|:---:|------|
        | `SOS_RED` (匿名降級) | **5×** | 院免匿名假 SOS 燒全台 |
        | `SOS_YELLOW` | **5×** | 登山客輕傷、需要誓期救援 |
        | `RESOURCE` | **2×** | 一般物資交換 |
        | `INFO` | **1×** | 純資訊，最嚴格限制 |

        *   `dropThreshold = event.max_range_meters * multiplier`；距離超過限制則主動拒絕轉發。

        **GeoContext Resolver —地理環境自適應預設半徑**
        *   App 在發布物資時，透過查詢本機 MBTiles (`place` / `transportation` / `park` / `landcover` 圖層) 判斷用戶所处環境，并建議 `max_range_meters` 預設值。快取結果，位置移動 > 2km 時才重新觸發。

        | 環境類型 | 判斷條件 | 預設 `max_range_meters` |
        |----------|---------|:---:|
        | 市區 | `place` = city/suburb/town 或主要路網 = motorway/primary | **1,000 m** |
        | 郊區 / 農村 | `place` = village/hamlet 或路網 = secondary/tertiary | **5,000 m** |
        | 深山 / 荒野 | 位於 national_park 內，或 landcover = wood 且路網 = track/path | **15,000 m** |
*   **去重、防洪與防碰撞 (Anti-Storm & Collision Avoidance)**：
    *   **隨機退避演算法 (Random Backoff)**：考量到 BLE 在擁擠環境（如收容所內大量設備同時廣播）極易發生封包碰撞 (Collision)，在 MAC 廣播層與路由轉發前加入隨機退避時間（例如 50ms - 500ms），有效錯開併發廣播，提高封包到達率。
    *   **Bloom Filter 參數（工程固定值）**：單次握手預設支援最多 5,000 筆事件比對，容忍 1% False Positive Rate (FPR)，由此計算出 Bit Array 大小 m ≈ 47,926 bits（約 **5.85 KB**），Hash 函數數量 k = 7。過濾器採滑動窗口設計，每次握手建立新 Filter 實例，不跨連線累積。若遇到累積數萬筆 Event Logs 的公務車「硬體資料騾子 (Hardware Data Mule)」，為避免 5,000 容量溢位導致 FPR 飆升至 100% 而拒收正常封包，握手協定將動態觸發「分區塊 (Chunked) Bloom Filter」或「基於 HLC 時間窗的漸進同步」機制。
    *   基於發送者公鑰 (Pub Key) 的 Rate Limiting：每小時廣播上限 20 次，超標即被周遭節點孤立。為防惡意用戶調快系統時間繞過限制，Rate Limit 時間窗口重置欄位 `rate_limit_window_start` 強制綁定設備開機運行時長 (如 `elapsedRealtime`) 或連動 HLC 計數器（詳見 DB Schema）。
    *   **大檔案分塊與重組 (Payload Chunking)**：若需傳送重傷照片等大數據，於底層拆分為多個 Chunk 發送，接收端透過 Reassembly Cache 收集齊全並驗證後始投入應用層廣播。

#### 2.3 應用狀態層 (Application & State Layer)
*   **安全性 (Trust & Identity)**：採用 Ed25519 非對稱簽章。
    *   **私鑰儲存（硬體強制規定）**：Ed25519 Private Key **絕對不可存入 SQLite**。iOS 必須呼叫 **Secure Enclave / Keychain**，Android 必須呼叫 **Android Keystore System**，確保設備被物理破解時金鑰不外洩。DB 中僅存公鑰（32 bytes BLOB）與 Keychain 參考 ID。
    *   身份驗證採漸進式 **Trust Ladder（Level 0–3）**，詳見 SRS F_APP_01。所有等級共用同一金鑰對，升級時就地提升 `identity_level` 欄位。
    *   平時（有網路）：執行 Trust Ladder 升級（SMS OTP / 社群背書 / TW FidO），獲取對應等級憑證。
    *   災時（無網路）：所有操作（掛單、求救）均由本機 Private Key 簽名，以當前 `identity_level` 廣播。
    *   **去中心化加權隔離 (Weighted Quarantine)**：節點可發出 `Quarantine_Vote`，每票依發票方 `identity_level` 計入不同權重：Level 0 = 0.2 票、Level 1 = 0.5 票、Level 2 = 0.8 票、Level 3 = 1.0 票。目標節點累積權重 **> 3.0（不含）** 時，自動列入本地黑名單，切斷其路由擴散權。此機制在系統冷啟動早期（多數用戶為 Level 0）仍具備基礎群眾免疫力。
*   **多圖層混合 CRDT (Hybrid CRDT)**：
    *   **混合邏輯時鐘 (HLC)**：物資圖層衝突處理廢棄單純時間戳，採 `[int64 hlc_timestamp, int64 hlc_counter]` 向量（全面對齊資料庫有號整數特性）。即便設備斷電重置回 1970 年，`hlc_counter` 依然能維持事件的正確因果序列。**交會強制校時協議**：節點 A（1970 年）與節點 B（現代）握手時，A 必須強制採用 `max(A.hlc_timestamp, B.hlc_timestamp)` 推進本地 HLC 物理時間部分，防止因果關係錯亂。特別宣告：一旦有具備絕對正確時間的設備（如剛從外區聯網進入的 Data Mule）加入 Mesh 網路，其 HLC 將作為權威基準，強制覆蓋並校正整個網域的偏差時鐘。
    *   **地理危害圖層 (Dynamic Hazard Overlay)**：使用者在地圖建立的災損標記快速擴散至周遭並自動疊加。渲染由 `flutter_map` Polygon Layer 處理（詳見第 4 節離線地圖規格）。

#### 2.4 同步、雲端層與儲存驅逐 (Synchronization & Eviction)
*   **Edge Gateway 上鏈**：
    *   移動的 Data Mules 抵達有 5G / 衛星網路區域。批量推送 Event Logs 並拉取中央更新。
*   **邊緣儲存限界保護 (Data Eviction Strategy)**：
    *   設定 SQLite 空間水位閥值（如 500MB）。一旦觸發，啟動後台「冷數據驅逐」。
    *   優先淘汰 `ttl <= 0` 且 `urgency == INFO` 的歷史資料。
    *   危及生命的 `SOS_RED` 與「動態危險圖層」任務強制標定為 **PINNED** (鎖存)，未達中央前嚴格禁止抹除。在極端情況下若 `SOS_RED` 依然導致空間爆滿，系統將引入 `Verified_by_Authority` (權威認證) 權重，優先選擇保留由政府或高等級用戶 (Level 3 / 官方徽章) 背書的緊急封包。

### 3. 跨平台限制與電量救濟策略
*   **求生模式 (Survival UI)**：提供特製純黑畫面，系統強迫防休眠，鼓勵災民掛機維持 Mesh 網路。不分 iOS 與 Android，介面皆會統一強制引導使用者：「在急難與物資對接的關鍵時刻，請務必保持 App 於前台運行」，以最大程度突破作業系統對背景連線的嚴格頻寬閹割。
*   **加速度計與背景感知**：
    *   設備靜置（如置於桌面）> 15 分鐘：斷開高頻天線，進入深度省電模式。
    *   **Data Mule 遲滯切換模式 (Tier 1 Android 定製)**：為加速初期救災通訊網路建置，首度啟動時只要電量 **≥ 40%** 即強制預設為 **Data Mule 模式**，釋放運算極限進行無間斷 WiFi Aware 聯網。直到運作至電量跌破 **40%** 時才自動降回 Tier 2 以節省維持生存最低電量。後續充電恢復時，則需達 **≥ 60%** 才會再觸發升級回 Data Mule 模式。**(再次強調：iOS 前台雖為 Tier 1 可高速傳檔，但背景時受沙盒機制嚴格限制，永遠維持 Tier 2 葉節點角色，系統絕不會讓 iOS 自動擔任全天候 Data Mule)**。
    *   **Tier 0 硬體騾子無需此遲滯邏輯**：Tier 0 設備（車載 IoT）以外部電源驅動，不存在電量焦慮，恆常以全功率運行，不受上述 40% / 60% 遲滯切換機制約束。

#### 3.1 GeoContext Resolver 技術實作流程
發布物資或需求前，App 調用此模組一次，結果緩存至本地 `GeoContext_Cache` 表（見 DB Schema §1）。

```
GPS 定位 → 計算 TileXYZ (Zoom=14) → 讀取 MBTiles 對應向量 Tile
  ├─ 查詢 `place` 圖層：找最近 1km 內的聚落節點及其 class
  ├─ 查詢 `transportation` 圖層：判斷當前圖格內的最高道路等級
  ├─ 查詢 `park` 圖層：判斷是否在 national_park / nature_reserve 範圍內
  └─ 查詢 `landcover` 圖層：判斷地表覆蓋是否以 wood/grass 為主
       ↓
分類邏輯 → EnvironmentType (URBAN / SUBURBAN / RURAL_MOUNTAIN)
       ↓
建議 max_range_meters → 寫入 GeoContext_Cache → UI 展示給 Provider 確認
```

觸發條件：App 啟動時 + 位置相對快取座標移動超過 2 公里時（由加速度計輔助判斷，靜止時不重複觸發）。

### 4. 離線地圖技術規格
*   **地圖引擎**：`flutter_map` 套件搭配 `flutter_map_mbtiles` 外掛。
*   **底圖資料格式**：OpenStreetMap MBTiles 向量圖磚（`.mbtiles`）。使用預先過濾 (Planetiler OpenMapTiles schema) 後的高度精簡版向量圖資。
*   **預先打包策略 (Asset Bundle)**：考量災區緊急狀況可能完全無網，且為降低伺服器頻寬成本與避免用戶漏載，將全台灣基礎離線向量圖磚 (`.mbtiles` 檔案，大小控制在 200MB 以內) 直接打包進 App 安裝檔內，確保隨載即用 100% 離線運行。
*   **圖資更新機制**：隨 App 版本更新 (App Store / Google Play) 一併替換地圖資料庫，App 內部不再實作動態下載地圖的邏輯。
*   **前端靜態 POI 本地渲染優先級 (地圖前端效果)**：
    *   考量救災需求，Flutter 前端必須攔截並特別渲染 `poi` 圖層中特定分類標籤 (class)，使其在街道層級 (Zoom > 14) 成為醒目的大型圖標與優先顯示名稱：
        *   🔴 **最高優先 (醫療)**：`hospital`, `clinic`, `doctors` (紅色圓點特效)。
        *   🔵 **次高優先 (警消)**：`police`, `fire_station` (藍色圓點特效)。
        *   🟠 **避難所 (學校)**：`school`, `college`, `university` (橘色圓點特效)。
        *   🟣 **醫療物資 (藥局)**：`pharmacy` (紫色圓點特效)。
        *   🟢 **民生物資 (超市)**：`grocery`, `supermarket` (綠色圓點特效。與藥局在視覺上必須嚴格分離)。
*   **動態危險標記渲染 (Mesh 網路事件)**：`Hazards_State` 中的 `center_lat/lng` 與 `radius_meters`，透過 `flutter_map` Polygon Layer 渲染為橙紅色閃爍多邊形，即時反映 Mesh 網路傳入的危險事件，並疊加於上述靜態底圖之上。
