
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

files = {
    "agemd": r"c:\Users\radio\Downloads\CoReM\agemd.md",
    "SRS":   r"c:\Users\radio\Downloads\CoReM\docs\01_產品需求規格書_SRS.md",
    "SAD":   r"c:\Users\radio\Downloads\CoReM\docs\02_系統架構設計書_SAD.md",
    "API":   r"c:\Users\radio\Downloads\CoReM\docs\03_通訊協定與API設計_API.md",
    "DB":    r"c:\Users\radio\Downloads\CoReM\docs\04_資料庫規劃與狀態同步_DB.md",
    "UIQA":  r"c:\Users\radio\Downloads\CoReM\docs\05_介面流程與測試計畫_UI_QA.md",
}

checks = [
    ("Old >=60% first launch [agemd]",  "agemd", "with battery \u2265 60%"),
    ("New hysteresis >=40% [agemd]",    "agemd", "first launch if battery \u2265 40%"),
    ("Old path docs/ResQMesh [agemd]",  "agemd", "docs/ResQMesh"),
    ("New path docs/ [agemd]",          "agemd", "refer to the files in `docs/`"),
    ("Quarantine > 3.0 [agemd]",        "agemd", "> 3.0 (exclusive)"),
    ("SOS_YELLOW 30min [SRS]",          "SRS",   "SOS_YELLOW` \u7269\u8cc7 = 30 \u5206\u9418"),
    ("Old Quarantine >=3.0 [SAD]",      "SAD",   "\u2265 3.0"),
    ("New Quarantine >3.0 [SAD]",       "SAD",   "> 3.0\uff08\u4e0d\u542b\uff09"),
    ("SOS_YELLOW 30min [API]",          "API",   "SOS_YELLOW` = 30 \u5206\u9418"),
    ("is_blacklisted >3.0 [DB]",        "DB",    "weight > 3.0\uff08\u4e0d\u542b\uff09"),
    ("match_expires SOS_YELLOW [DB]",   "DB",    "SOS_YELLOW` = 30 \u5206\u9418"),
    ("Old Nearby Connections [UIQA]",   "UIQA",  "Nearby Connections"),
    ("New Wi-Fi/AWDL/BLE [UIQA]",       "UIQA",  "Wi-Fi Aware / AWDL / BLE"),
    ("Old 高能騾子 [UIQA]",              "UIQA",  "\u9ad8\u80fd\u9a3c\u5b50\u6a21\u5f0f"),
    ("New 騾子模式Android [UIQA]",       "UIQA",  "\u9a3c\u5b50\u6a21\u5f0f\uff08Tier 1 Android"),
    ("New 高能模式iOS [UIQA]",           "UIQA",  "\u9ad8\u80fd\u6a21\u5f0f\uff08iOS \u524d\u53f0 Tier 1\uff09"),
    ("Quarantine >3.0 vote [UIQA]",     "UIQA",  "> 3.0\uff0c\u4e0d\u542b\uff09\u6642\u662f\u5426"),
]

contents = {}
for k, path in files.items():
    with open(path, encoding="utf-8") as f:
        contents[k] = f.read()

results = []
for desc, key, substr in checks:
    found = substr in contents[key]
    status = "OK   FOUND" if found else "FAIL MISSING"
    results.append(f"{status} | {desc}")

out_path = r"c:\Users\radio\Downloads\CoReM\docs\tmp\verify_result.txt"
with open(out_path, "w", encoding="utf-8") as f:
    f.write("\n".join(results))
print("written")
