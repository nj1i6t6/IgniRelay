
import io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

targets = [
    (r"c:\Users\radio\Downloads\CoReM\docs\04_資料庫規劃與狀態同步_DB.md", "is_blacklisted"),
    (r"c:\Users\radio\Downloads\CoReM\docs\05_介面流程與測試計畫_UI_QA.md", "\u9a3c\u5b50\u6a21\u5f0f"),
    (r"c:\Users\radio\Downloads\CoReM\docs\05_介面流程與測試計畫_UI_QA.md", "Quarantine"),
]

out_lines = []
for path, keyword in targets:
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()
    out_lines.append(f"\n=== {keyword} ===")
    for i, line in enumerate(lines):
        if keyword in line:
            out_lines.append(f"  L{i+1}: {line.strip()[:120]}")

with open(r"c:\Users\radio\Downloads\CoReM\docs\tmp\check_out2.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(out_lines))
print("done")
