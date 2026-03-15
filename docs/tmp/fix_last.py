
import io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

# Fix DB is_blacklisted: still shows >= 3.0
path_db = r"c:\Users\radio\Downloads\CoReM\docs\04_資料庫規劃與狀態同步_DB.md"
with open(path_db, encoding="utf-8") as f:
    c = f.read()

# Print current line 17
lines = c.split("\n")
for i, l in enumerate(lines):
    if "is_blacklisted" in l:
        print(f"Line {i+1}: {repr(l[:80])}")

# Try replacing (the check2.py showed ≥ which is \u2265)
old = "`is_blacklisted` (BOOLEAN): \u9054\u5230\u9694\u96e2\u9580\u6bb3\uff08weight \u2265 3.0\uff09\u6216\u624b\u52d5\u5c01\u9396\u5f8c\uff0c\u62d2\u7d55\u5efa\u7acb Socket \u9023\u7dda\u3002"
new = "`is_blacklisted` (BOOLEAN): \u9054\u5230\u9694\u96e2\u9580\u6bb3\uff08**weight > 3.0\uff08\u4e0d\u542b\uff09**\uff09\u6216\u624b\u52d5\u5c01\u9396\u5f8c\uff0c\u62d2\u7d55\u5efa\u7acb Socket \u9023\u7dda\u3002"

if old in c:
    c = c.replace(old, new)
    print("DB is_blacklisted FIXED")
else:
    # Try variant with \r\n
    old2 = old.rstrip() 
    if old2 in c:
        print("found without trailing")
    else:
        # Find and print the actual line
        for l in c.split("\n"):
            if "is_blacklisted" in l and "BOOLEAN" in l:
                print("Actual:", repr(l[:120]))

with open(path_db, "w", encoding="utf-8") as f:
    f.write(c)

# Check UIQA for 騾子模式 (correct char: \u9a3e)
path_ui = r"c:\Users\radio\Downloads\CoReM\docs\05_介面流程與測試計畫_UI_QA.md"
with open(path_ui, encoding="utf-8") as f:
    cu = f.read()

# The correct char for 騾 is U+9A3E
mule_char = "\u9a3e\u5b50\u6a21\u5f0f"  # 騾子模式
print("\nUIQA 騾子模式 occurrences:")
lines_u = cu.split("\n")
for i, l in enumerate(lines_u):
    if mule_char in l or "\u9ad8\u80fd\u6a21\u5f0f" in l:  # also 高能模式
        print(f"  L{i+1}: {l.strip()[:100]}")

print("done")
