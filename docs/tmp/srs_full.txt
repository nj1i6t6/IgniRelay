# 產品需求規格書 (Software Requirements Specification - SRS)
## 系統：災難應急 Mesh 物資調度系統 (Project ResQMesh)

### 1. 系統目的與願景
建立一套在無基礎通訊設施（無 4G/5G、無室內外 WiFi AP）的災難現場，能供民眾自主形成通訊網路 (Mesh) 以媒合「緊急物資」與「急難需求」的手機應用程式，並提供政府與救災單位後端系統以進行巨觀資源調度。此系統不僅是通訊工具，更是具備防篡改、優先級調度及動態避險防護的韌性基礎設施。

### 2. 使用者角色定義
1. **供給端災民 (Provider)**：擁有額外物資、空間或技能。
2. **需求端災民 (Requester)**：需要取得物資或急難救助。
3. **中繼傳遞者 (Mule / Router)**：僅開啟 App 在背景運行，自動協助搬運、轉發 Mesh 封包的路人。
4. **硬體資料騾子 (Hardware Data Mule)**：安裝於公務車輛（警車、垃圾車）等之 IoT 節點，無電池焦慮，負責大範圍資料拉取與傳遞。
5. **邊緣節點/閘道器 (Gateway)**：走出災區邊緣或取得衛星網路的用戶，負責將收集到的離線資料上傳。
6. **中央指揮官 (Commander)**：透過 Web 後端統籌戰情。

### 3. 功能需求 (Functional Requirements)

#### 3.1 離線端功能 (App)
*   **F_APP_01 多層級身分建立 (Trust Ladder)**：身份驗證採漸進式四等級架構，各等級共用同一 Ed25519 金鑰對，升級時就地提升 `identity_level` 欄位，不重新產生金鑰。
    *   **Level 0 — 匿名 (Gray Badge)**：App 安裝時自動產生 Ed25519 金鑰對，無需網路連線，Day 1 可用。Quarantine Vote 權重 0.2。
    *   **Level 1 — 手機號驗證 (Bronze Badge)**：透過商業 SMS OTP 服務（如 Twilio / AWS SNS）驗證門號，需一次性網路連線。一門號對應一裝置，大幅提升 Sybil 攻擊成本。Quarantine Vote 權重 0.5。
    *   **Level 2 — 社群背書 (Silver Badge)**：由 ≥3 個 Level-1 已驗證用戶，各自透過 Proof-of-Encounter 為其背書。純網內機制，無外部依賴。Quarantine Vote 權重 0.8。
    *   **Level 3 — 政府實名 (Gold Badge / 金盾)**：接入 TW FidO（台灣行動身分識別），核發基於 W3C Verifiable Credentials 格式的憑證，可附加職業徽章（如醫護紅十字）。由功能開關控制，政府合作達成前停用，不影響 Level 0–2 的正常運作。Quarantine Vote 權重 1.0。
    *   **無網緊急啟動**：首次啟用若無網路，自動落入 Level 0（匿名模式），Badge 顯示灰色盾牌。
*   **F_APP_02 檢傷分級的求救發佈 (Triage)**：發佈需求時需標示緊急度 (INFO / RESOURCE / SOS_YELLOW / SOS_RED)，最高級別 SOS_RED 可強制夾帶確切 GPS 座標並請求周圍設備發出警報。
*   **F_APP_03 物資登記與發佈**：無網狀態下新增物資紀錄，標註類型、數量與有效範圍。
*   **F_APP_04 鄰近節點發現與通訊（含 Tier 限制）**：依裝置能力分級執行節點探索與封包交換。節點共分四個等級：
    *   **Tier 0 裝置**（硬體資料騾子 Hardware Data Mule）：安裝於公務車輛（警車、垃圾車）等之 IoT 節點。無電池焦慮，無儲存上限，負責跨縣市大範圍資料拉取與搬運。享有最高等級豁免：距離衰減豁免、資料驅逐保護（不受 LRU 清除）、Rate Limiting 豁免、直接上報中央（車載設備可能配備 4G 路由器），以及永遠使用分塊 Bloom Filter 進行大容量握手。
    *   **Tier 1 裝置**（Android WiFi Aware NAN + BLE / iOS 前台）：Android 可在背景持續維持 Wi-Fi Aware 與 BLE 雙通道，以確保高頻寬與跨系統(iOS)的通訊相容性；iOS 前台平時以 BLE 索敵，遇大檔案需求則配對 AWDL 高速傳輸。**注意：Tier 1 Android（掛載 Foreground Service）具備跨區距離衰減豁免特權；iOS 前台雖屬 Tier 1 但不具備此特權，因其無法全天候在背景保持穩定連線。**
    *   **Tier 2 裝置**（iOS 背景 / 退化之 Android）：依賴 BLE 進行背景低頻寬脈衝中繼。為了突破 iOS 系統對於背景的嚴格冰凍限制，除了 `bluetooth-central / peripheral` 喚醒外，系統亦實作 **Background Fetch / Background Processing Tasks (BGTaskScheduler)** 以定期拉起資源；且在災區邊緣（具備間歇性微弱網際網路 / 衛星網路）者，系統會整合 **PushKit** 以靜默推播（Silent Push）強制喚醒 App 執行短暫的藍牙周邊同步。
    *   **Tier 3 裝置**（極低電量）：僅能透過 BLE 被動發送求救 Beacon。
    *   所有裝置握手均透過 Bloom Filter（5,000容量 / 1% FPR / 約 5.85KB）比對差異事件。
*   **F_APP_05 動態危險圖層標記 (Hazard Marker) 與地理圍欄 TTL**：
    *   使用者能在離線地圖上長按繪製或標記實體阻礙（如路斷、火災），系統需作為特權事件在 Mesh 中快速傳播。
    *   **動態地理圍欄 (Adaptive Geo-Fencing)**：為兼顧市區防洪與深山訊號延續，系統採以下四層分級邏輯決定是否轉發封包：
        1.  **通用前置驗證（所有封包皆適用）**：首先驗證 Ed25519 簽章有效性，並確認發送者未在本地黑名單，不合規者一律丟棄。
        2.  **SOS_RED 身分分級豁免（Urgency × Identity Override）**：SOS_RED 封包依發送者的 `identity_level` 給予不同待遇：`identity_level >= 1`（手機號已驗證）→ 完整跳過所有距離限制，全力擴散；`identity_level == 0`（匿名）→ 不享完整豁免，改以「5 倍寬鬆倍率」計算（即 `max_range_meters * 5.0`），確保真實遇難的匿名用戶訊號仍可傳遠，同時防止惡意匿名帳號燒遍全台 Mesh。
        3.  **Tier 0 / Mule 特權（Data Mule Exemption）**：Tier 0 硬體騾子永遠豁免。Tier 1 Android（必須掛載 Foreground Service）亦豁免。iOS 前台裝置（即使是 Tier 1）**不在此豁免範圍**。
        4.  **常規距離衰減計算**：使用「**接收位置快照** (`received_lat`/`received_lng`)」而非轉發時的當前位置，防止搬運途中的節點在移動後錯殺合法封包。衰減倍率依緊急程度分層：`SOS_RED`（匿名）= 5×、`SOS_YELLOW` = 5×、`RESOURCE` = 2×、`INFO` = 1×。
    *   **環境自適應預設半徑（GeoContext Resolver）**：發布物資或需求時，系統會透過查詢本機 MBTiles 圖資（`place` 圖層聚落等級、`transportation` 圖層道路等級、`park` 圖層國家公園範圍、`landcover` 圖層地表覆蓋），自動判斷用戶當前所處環境，並建議 `max_range_meters` 預設值，由 Provider 微調確認。GeoContext 快取結果，位置移動超過 2 公里時才重新觸發查詢。
        *   **市區**（附近 place = city/suburb/town，或主要路網為 motorway/primary）→ 預設 **1,000 公尺**。
        *   **郊區 / 農村**（附近 place = village/hamlet，或路網為 secondary/tertiary）→ 預設 **5,000 公尺**。
        *   **深山 / 荒野**（位於 national_park/nature_reserve 內，或地表覆蓋為 wood 且路網僅有 track/path）→ 預設 **15,000 公尺**。
*   **F_APP_06 自動超級節點切換 (Auto Super Node)**：**僅限 Tier 1 Android 裝置（硬體支援 WiFi Aware NAN）**。因災難初期最重要的是構建通訊網路，**設備首次啟動時只要電量 ≥ 40% 皆會預設為全功率 Data Mule 模式 (Tier 1)**，釋放 WiFi Aware 大範圍廣播與無限制背景執行。鑒於 Android 14+ 對背景網路操作極為嚴格，此模式啟用時會強制掛載明顯的「常駐通知列 (Foreground Service Notification)」，並引導用戶顯式授予 `NEARBY_WIFI_DEVICES` 權限，讓用戶清楚知道手機正為災區網路做出神聖貢獻。**當運作至電量跌破 40% 時，自動降回 Tier 2**，以保留基本電量供用戶發送 SOS。後續若重新獲得電源，電量需回充至 **≥ 60%** 時才會重新自動切換回全功率 Data Mule 模式（遲滯設定）。iOS 裝置因沙盒限制，背景僅能維持 Tier 2 脈衝中繼角色。
    *   **（特別說明）Tier 0 硬體騾子與 Tier 1 Android 的差異**：Tier 1 Android 仍受電量限制與 500MB 資料驅逐策略約束；Tier 0 硬體騾子（如車載 IoT 設備）則完全豁免上述限制，其儲存空間上限、Rate Limiting 和資料驅逐策略由硬體本身的儲存容量決定，且可直接透過車載 4G 路由器上報中央，無需等待 Gateway。
*   **F_APP_07 離線自體配對與物理交割**：媒合採兩階段設計。
    *   **Phase 1 — 絕對過濾 (Hard Filter)**：`resource_type` 必須與 `request_type` 完全吻合，否則直接排除（O(1) 複雜度）。
    *   **Phase 2 — 加權正規化評分 (Weighted Score)**，各變數正規化至 [0, 1]：
        ```
        D_norm = 1 - clamp(Distance / MAX_RANGE, 0, 1)   // MAX_RANGE 由 Provider 自訂有效半徑
        U_norm = Urgency_Level / 3
        T_norm = Trust_Score / 100
        Match_Score = (U_norm × 50) + (D_norm × 30) + (T_norm × 20)
        ```
    *   **PENDING 超時防死鎖解鎖**：若雙方未實際完成物理交割，或是 Provider 手機剛好沒電關機失連，系統將依據需求緊急程度，使 `Materials_State.status` 動態提早強制回滾為 `AVAILABLE`。超時時長依緊急度分層：**`SOS_RED` 及 `SOS_YELLOW` 物資 = 30 分鐘**內未完成即刻釋放回市場；**`RESOURCE` 及 `INFO` 一般物資 = 4 小時**。
    *   **物理交割**：當面靠近依靠 BLE 交換資料，雙方靠近 BLE 交換資料觸發介面，供給方跳出 4 位數 PIN，需求方跳出 UI 輸入解鎖；具備防護機制（連續錯 3 次鎖 30 秒；解鎖後若再連續錯 3 次則自動取消該次物資配對，回滾為 AVAILABLE 並清空 matched_request_id，並廣播 MATCH_CANCEL 釋放物資回市場）。
*   **F_APP_08 遇網自動上報 (Gateway Mode)**：當偵測到 Internet，背景批次將 SQLite 內新產生 Event Logs 推送至中央伺服器，並拉取全域註銷清單。

#### 3.2 中央後台功能 (Web Dashboard)
*   **F_WEB_01 全域戰情熱力圖**：顯示 Mesh 網路活躍區域、SOS_RED 命危熱點，以及資源閒置的綠色聚落。
*   **F_WEB_02 指揮調度與公務車聯網**：結合警消與公務車軌跡庫，將高層級需求指定推送給即將進入該區的 Hardware Data Mules。
*   **F_WEB_03 衝突排解機制**：處理跨孤島的雙花問題 (Double Spending)，以混合邏輯時鐘 (HLC) 或 LWW 決定資源最後歸屬。

### 4. 非功能需求 (Non-Functional Requirements)

*   **NFR_01 耗電量限制 (Battery Efficiency)**：求生低耗電模式開啟時，每日耗電不超過 15% 總容量。超級節點模式除外。此模式同時需在 Android 與 iOS 畫面上提供一致引導：「請保持 App 在前台運行以確保通訊順暢」。
*   **NFR_02 QoS 網路優先權與搶佔 (Preemption)**：底層與路由層處理需優先為 `SOS_RED` 事件騰出頻寬與 RAM，強制中斷較低級別封包傳輸。
*   **NFR_03 防洗版與節流 (Rate Limiting)**：單一節點每小時廣播次數上限限制（如 20 次），一旦超標即被周遭節點孤立並忽視其廣播，防止廣播風暴。
*   **NFR_04 頻寬最小化與大檔分塊**：核心協商小於 2KB，一般業務 Payload 壓在 512 Bytes 內；若超過（如傷口圖像），必須支援系統級 Chunking 分塊傳輸機制。
*   **NFR_05 資料持久性與隔離保護 (Eviction)**：強迫關機後系統能成功復原。為防超級節點儲存崩潰，資料庫需具備高水位線驅逐策略（冷熱數據淘汰）。
*   **NFR_06 時間軸容錯 (Time Drift)**：系統不能單一依賴裝置絕對時間（防斷電重歸零），強制使用邏輯時鐘記錄事件因果排序。
