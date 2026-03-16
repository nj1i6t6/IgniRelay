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
    *   **Tier 0 裝置**（硬體資料騾子 Hardware Data Mule）：安裝於公務車輛（警車、垃圾車）等之 IoT 節點。無電池焦慮，無儲存上限，負責跨縣市大範圍資料拉取與搬運。享有最高等級豁免：距離衰減豁免、資料驅逐保護（不受 LRU 清除）、Rate Limiting 豁免、直接上報中央（車載設備可能配備 4G 路由器），以及永遠使用分塊 Bloom Filter 進行大容量握手。**內建 Sub-1GHz 433MHz RF 接收模組**，可被動接收市面主流連動型住警器（宏力、TYY 等）之火警 RF 訊號，轉譯為數位 MeshEvent 後注入 Mesh 網路，實現傳統設備「零汰換」智慧升級。
    *   **Tier 1 裝置**（iOS 前台 或 Android 掛載 Foreground Service，電量 ≥ 40%）：全速 BLE 掃描/廣播/中繼，Data Mule 模式。**手機端一律 BLE，不使用 Wi-Fi Aware (NAN) 或 AWDL**。Android 掛載 Foreground Service 時具備跨區距離衰減豁免特權；iOS 前台雖屬 Tier 1 但不具備此特權（無法在背景全天候保持穩定連線）。電量跌破 40% 自動降為 Tier 2。
    *   **Tier 2 裝置**（iOS 前台或 Android FS 但電量 20-40%，或 iOS 背景電量 ≥ 20%）：降頻 BLE 中繼。iOS 背景受惠於 CoreBluetooth `bluetooth-central / peripheral` 喚醒機制，收到 BLE 事件時被系統喚醒、執行 Bloom Filter 比對後回傳差集，再回去低功耗待機。**Android 無 CoreBluetooth 式背景喚醒機制**，進入 Tier 2 仍需保持 Foreground Service 掛著，只是降低掃描頻率。
    *   **Tier 3 裝置**（極低電量）：僅能透過 BLE 被動發送求救 Beacon。
    *   所有裝置握手均透過 Bloom Filter（5,000容量 / 1% FPR / 約 5.85KB）比對差異事件。
*   **F_APP_05 動態危險圖層標記 (Hazard Marker) 與地理圍欄 TTL**：
    *   使用者能在離線地圖上長按繪製或標記實體阻礙（如路斷、火災），系統需作為特權事件在 Mesh 中快速傳播。
    *   **Zone-Based Geo-Fencing（行政區地理圍欄）**：系統以事件創建者的原始座標（`MeshEvent.origin_lat`/`origin_lng`）為基準，對比接收節點當前 GPS，查詢內政部村里界 SQLite 決定是否轉發。路由邊界對齊現實緊急救援單位：

        | urgency / 事件類型 | 路由邊界 | 設計依據 |
        |---|---|---|
        | `INFO` / `RESOURCE` | **里（村里）** | 物資配對以鄰里為單位，減少跨里雜訊 |
        | `SOS_YELLOW` / `SOS_RED` | **鄉鎮市區** | 全台每鄉鎮市區至少設一消防分隊，對齊救援最小行動單位 |
        | `HAZARD_MARKER` | **鄉鎮市區** | 危險區域通常涵蓋整個消防分隊轄區 |

        **邊界緩衝區（< 300m）**：位於行政區邊界附近時，同時納入所有相鄰里/鄉鎮市區（1～N 個），確保邊界民眾不漏接資訊。

        **特殊豁免規則**（以下情況無視行政區邊界，永遠轉發）：
        1.  **通用前置驗證**：Ed25519 簽章驗證 + 黑名單過濾（所有封包皆須通過）。
        2.  **SOS_RED + identity_level ≥ 1**（手機驗證用戶）：生死攸關，無視行政區邊界全力擴散。
        3.  **Tier 0 硬體騾子**：永遠豁免。
        4.  **Tier 1 Android Foreground Service**：跨區搬運豁免。

        **Fallback（離島/資料缺漏）**：VillageGeofence 查無任一端資料時，退回距離衰減（`max_range_meters × multiplier`）：`SOS_RED`（匿名）= 5×、`SOS_YELLOW` = 5×、`RESOURCE` = 2×、`INFO` = 1×。

        **Phase 2（未來規劃）— 鄉鎮市區 → 縣市彙整上報**：鄉鎮市區節點收到 SOS/HAZARD 後定期彙整往縣市指揮節點上報，形成「里 → 鄉鎮市區 → 縣市」三層上報鏈，對接現行 119 指揮體系。

    *   **環境自適應預設半徑（GeoContext Resolver）**：發布物資或需求時，系統自動判斷用戶環境並建議 `max_range_meters` 預設值（主要供 fallback 距離衰減使用）。GeoContext 快取結果，位置移動超過 2 公里時才重新觸發查詢。（實作分兩階段，見 SAD §3.1）
        *   **市區** → 預設 **1,000 公尺**。
        *   **郊區 / 農村** → 預設 **5,000 公尺**。
        *   **深山 / 荒野** → 預設 **15,000 公尺**。
*   **F_APP_06 自動超級節點切換 (Auto Super Node)**：**Tier 1 手機節點（iOS 前台 或 Android 掛載 Foreground Service，電量 ≥ 40%）**。因災難初期最重要的是構建通訊網路，**設備首次啟動時只要電量 ≥ 40% 皆會預設為 Data Mule 模式（Tier 1）**，全速 BLE 掃描/廣播/中繼。**手機端通訊一律 BLE，不使用 Wi-Fi Aware (NAN) 或 AWDL**。Android 掛載 Foreground Service 啟動時，強制掛載明顯的「常駐通知列」，讓用戶清楚知道手機正為災區網路貢獻。**當電量跌破 40% 時，自動降為 Tier 2**（降頻中繼）；跌破 20% 降為 Tier 3（僅自身 SOS）。後續充電需回充至 **≥ 60%** 才會重新自動升回 Tier 1（遲滯設定，防頻繁切換）。iOS 背景透過 CoreBluetooth 喚醒機制維持 Tier 2 低頻中繼；Android 背景無此機制，要嘛 Foreground Service 掛著，要嘛 App 被殺掉。
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
*   **NFR_03 防洗版與節流 (Rate Limiting)**：依賴動態 Bloom Filter 交換間隔進行廣播速率控制（預設 30 秒/次；SOS_RED 狀態縮短至 10 秒且無視速率限制）。廣播風暴防護由 Bloom Filter 差異比對機制實現——接收端僅補傳本地缺失的事件，不盲目全量轉發。
*   **NFR_04 頻寬最小化與大檔分塊**：核心協商小於 2KB，一般業務 Payload 壓在 512 Bytes 內；若超過（如傷口圖像），必須支援系統級 Chunking 分塊傳輸機制。
*   **NFR_05 資料持久性與隔離保護 (Eviction)**：強迫關機後系統能成功復原。為防超級節點儲存崩潰，資料庫需具備高水位線驅逐策略（冷熱數據淘汰）。
*   **NFR_06 時間軸容錯 (Time Drift)**：系統不能單一依賴裝置絕對時間（防斷電重歸零），強制使用邏輯時鐘記錄事件因果排序。
