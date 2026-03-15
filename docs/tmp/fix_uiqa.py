
path = r"c:\Users\radio\Downloads\CoReM\docs\05_介面流程與測試計畫_UI_QA.md"
with open(path, encoding="utf-8") as f:
    c = f.read()

# Fix 1: Split 高能騾子模式 → Android騾子模式 + iOS高能模式, fix comms tech (AWDL or Wi-Fi Aware → correct per platform)
old1 = "    *   **高能騾子模式（Tier 1 Android 前背景 / iOS 前景）**：電量達門檻，UI 主題切換，光暈擴大，宣示裝置正啟動 AWDL 或 Wi-Fi Aware 進行全功率廣域網橋接。為配合 Android 14+ 作業系統要求，進入超級節點模式時，上方通知列會掛載醒目的「騾子模式運行中」常駐卡片，彰顯使用者正奉獻頻寬與電量。電量跌破 40% 時 UI 自動回退省電模式，此時介面會明確提示使用者：「已降級為省電模式。請充電至 60% 以上以恢復高能超級節點模式」，避免使用者在 40% 邊界感到困惑。"
new1 = """    *   **騾子模式（Tier 1 Android 前台 / 背景掛 Foreground Service）**：電量達門檻，UI 主題切換，光暈擴大，宣示裝置正啟動 **Wi-Fi Aware (NAN)** 進行全功率廣域網橋接。為配合 Android 14+ 作業系統要求，進入騾子模式時，上方通知列會掛載醒目的「騾子模式運行中」常駐卡片，彰顯使用者正奉獻頻寬與電量。電量跌破 40% 時 UI 自動回退省電模式，此時介面會明確提示使用者：「已降級為省電模式。請充電至 60% 以上以恢復騾子模式」，避免使用者在 40% 邊界感到困惑。\r\n    *   **高能模式（iOS 前台 Tier 1）**：iOS 前台屬 Tier 1 節點，具備大檔傳輸能力，UI 主題同步切換顯示「高能模式」。平時以 **BLE** 發現周圍節點，遇大檔案（地圖 / 照片）需求時自動升級建立 **AWDL** 專用高速點對點傳輸通道。**注意：iOS 前台不擔任全天候 Data Mule 角色**，UI 不顯示「騾子模式」常駐別框；進入背景後自動降為 Tier 2 BLE 脈衝中繼。"""

# Fix 2: Quarantine 集滿3張 -> 加權投票超過3.0
old2 = "驗證周遭設備在集滿 3 張 `Quarantine_Vote` 是否自動啟動免疫機制封殺該節點。"
new2 = "驗證周遭設備在**累計加權投票超過 3.0（> 3.0，不含）**時是否自動啟動免疫機制封殺該節點。"

# Fix 3: Nearby Connections -> Wi-Fi Aware / AWDL / BLE
old3 = "所有中斷點的底層傳輸 (Nearby Connections) 應立即中斷現有大型傳輸迴圈"
new3 = "所有中斷點的底層傳輸 **(Wi-Fi Aware / AWDL / BLE)** 應立即中斷現有大型傳輸迴圈"

for old, new in [(old1, new1), (old2, new2), (old3, new3)]:
    if old in c:
        c = c.replace(old, new)
        print(f"Replaced: {old[:40]}...")
    else:
        print(f"NOT FOUND: {old[:60]}")

with open(path, "w", encoding="utf-8") as f:
    f.write(c)
print("done")
