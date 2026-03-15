
files = {
    "agemd": r"c:\Users\radio\Downloads\CoReM\agemd.md",
    "SRS":   r"c:\Users\radio\Downloads\CoReM\docs\01_產品需求規格書_SRS.md",
    "SAD":   r"c:\Users\radio\Downloads\CoReM\docs\02_系統架構設計書_SAD.md",
    "API":   r"c:\Users\radio\Downloads\CoReM\docs\03_通訊協定與API設計_API.md",
    "DB":    r"c:\Users\radio\Downloads\CoReM\docs\04_資料庫規劃與狀態同步_DB.md",
    "UIQA":  r"c:\Users\radio\Downloads\CoReM\docs\05_介面流程與測試計畫_UI_QA.md",
}

checks = [
    ("舊版 ≥ 60% 首次啟動 [agemd]", "agemd", "with battery ≥ 60%"),
    ("新版遲滯邏輯 [agemd]",          "agemd", "first launch if battery ≥ 40%"),
    ("引用路徑 docs/ResQMesh [agemd]","agemd", "docs/ResQMesh"),
    ("引用路徑 docs/ [agemd]",         "agemd", "refer to the files in `docs/`"),
    ("Quarantine > 3.0 [agemd]",      "agemd", "> 3.0 (exclusive)"),
    ("SOS_YELLOW 30min [SRS]",         "SRS",  "SOS_YELLOW` 物資 = 30 分鐘"),
    ("Quarantine ≥3.0 舊版 [SAD]",     "SAD",  "≥ 3.0"),
    ("Quarantine >3.0 新版 [SAD]",     "SAD",  "> 3.0（不含）"),
    ("SOS_YELLOW 30min [API]",         "API",  "SOS_YELLOW` = 30 分鐘"),
    ("is_blacklisted >3.0 [DB]",       "DB",   "weight > 3.0（不含）"),
    ("match_expires SOS_YELLOW [DB]",  "DB",   "SOS_YELLOW` = 30 分鐘"),
    ("Nearby Connections 舊 [UIQA]",   "UIQA", "Nearby Connections"),
    ("Wi-Fi Aware/AWDL/BLE 新 [UIQA]","UIQA", "Wi-Fi Aware / AWDL / BLE"),
    ("高能騾子模式舊 [UIQA]",           "UIQA", "高能騾子模式"),
    ("騾子模式Android [UIQA]",          "UIQA", "騾子模式（Tier 1 Android"),
    ("高能模式iOS [UIQA]",              "UIQA", "高能模式（iOS 前台 Tier 1）"),
    ("Quarantine>3.0 [UIQA]",          "UIQA", "累計加權投票超過 3.0（> 3.0，不含）"),
]

contents = {}
for k, path in files.items():
    with open(path, encoding="utf-8") as f:
        contents[k] = f.read()

print("=" * 60)
for desc, key, substr in checks:
    found = substr in contents[key]
    status = "✅ FOUND" if found else "❌ MISSING"
    print(f"{status} | {desc}")
