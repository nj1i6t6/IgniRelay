
targets = [
    (r"c:\Users\radio\Downloads\CoReM\docs\04_資料庫規劃與狀態同步_DB.md", "is_blacklisted"),
    (r"c:\Users\radio\Downloads\CoReM\docs\05_介面流程與測試計畫_UI_QA.md", "騾子模式"),
    (r"c:\Users\radio\Downloads\CoReM\docs\05_介面流程與測試計畫_UI_QA.md", "Quarantine"),
]
for path, keyword in targets:
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()
    print(f"\n=== {keyword} in {path.split(chr(92))[-1]} ===")
    for i, line in enumerate(lines):
        if keyword in line:
            print(f"  L{i+1}: {line.strip()}")
