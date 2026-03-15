# CoReM / ResQMesh 專案文件索引

> **AI 維護說明**：此索引為 AI 助手的文件導覽起點。
> 新增、移動或刪除任何文件後，請同步更新本檔案。

---

## 核心技術規格文件 (Core Specs)

| 檔案 | 說明 |
|------|------|
| [00_專案分析與技術構思報告.md](00_專案分析與技術構思報告.md) | 系統深度分析、架構解構、「暗黑森林」設計哲學 |
| [01_產品需求規格書_SRS.md](01_產品需求規格書_SRS.md) | 軟體需求規格書 (SRS) — 功能需求、邊界條件 |
| [02_系統架構設計書_SAD.md](02_系統架構設計書_SAD.md) | 系統架構設計書 (SAD) — 分層架構、模組關係 |
| [03_通訊協定與API設計_API.md](03_通訊協定與API設計_API.md) | 通訊協定與 API 設計 — Protobuf 結構、BLE/NAN 握手 |
| [04_資料庫規劃與狀態同步_DB.md](04_資料庫規劃與狀態同步_DB.md) | 資料庫規劃與 CRDT 狀態同步 — SQLite Schema、HLC |
| [05_介面流程與測試計畫_UI_QA.md](05_介面流程與測試計畫_UI_QA.md) | UI 流程設計與測試計畫 — 畫面流程、QA 案例 |

---

## 離線地圖工具鏈 (Offline Map Toolchain)

### Tilemaker 建置環境 (`tilemaker/`)
| 檔案 | 說明 |
|------|------|
| `tilemaker/config-resqmesh.json` | ResQMesh 專用 tilemaker 配置 |
| `tilemaker/process-resqmesh.lua` | ResQMesh 地圖處理腳本 (Lua, 32K) |
| `tilemaker/build/RelWithDebInfo/tilemaker.exe` | 已編譯的 tilemaker 執行檔 |
| `tilemaker/resources/` | Tilemaker 範例配置與腳本 |
| `tilemaker/sqlite/` | SQLite 動態連結庫 |
| `tilemaker/out.log` / `tilemaker_log.txt` | Tilemaker 執行輸出 |

### 地圖原始資料 (`sources/`)
| 檔案 | 大小 | 說明 |
|------|------|------|
| `sources/lake_centerline.shp.zip` | 78MB | 湖泊中心線 shapefile |
| `sources/natural_earth_vector.sqlite.zip` | 415MB | Natural Earth 向量資料 |
| `sources/water-polygons-split-3857.zip` | 875MB | 水體多邊形 (EPSG:3857) |

### 地圖成品與工具 (根目錄)
| 檔案 | 大小 | 說明 |
|------|------|------|
| `taiwan-260225.osm.pbf` | 299MB | 台灣 OSM 原始資料 (2026-02-25) |
| `taiwan_resqmesh.mbtiles` | 201MB | 產出的台灣 MBTiles 圖資 |
| `tilemaker-windows.zip` | 22MB | Tilemaker Windows 發行版 |
| `tile_weights.tsv.gz` | 5.6MB | Tile 權重資料 |
| `map_preview.html` | 7.4KB | MBTiles 瀏覽器預覽工具 |
| `inspect_mbtiles.py` | 1.2KB | MBTiles 結構檢查腳本 |

### 操作日誌 (`logs/`)
| 檔案 | 說明 |
|------|------|
| `logs/planetiler_log.txt` | Planetiler 執行完整日誌 |
| `logs/err.txt` / `logs/err_utf8.txt` | 工具執行錯誤輸出 |
| `logs/help.txt` / `logs/help_utf8.txt` | 工具 help 指令輸出 |

---

## 暫存開發腳本 (`tmp/`)

此資料夾存放用於修正、驗證各規格文件的一次性腳本及輸出，屬暫存性質，不代表正式代碼。

| 類型 | 檔案 |
|------|------|
| 驗證腳本 | `verify.py`, `verify2.py`, `check2.py`, `check_lines.py` |
| 修正腳本 | `fix_api_db.py`, `fix_blacklist.py`, `fix_blacklist2.py`, `fix_last.py`, `fix_uiqa.py` |
| 工具腳本 | `dump_srs.py`, `find_srs.py` |
| 輸出紀錄 | `*.txt` (各腳本的標準輸出結果) |
| 暫存資料庫 | `feature.db` (暫存 SQLite，可刪) |

---

*最後更新：2026-02-26*
