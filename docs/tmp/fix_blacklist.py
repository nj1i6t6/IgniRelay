
import io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

path_db = r"c:\Users\radio\Downloads\CoReM\docs\04_資料庫規劃與狀態同步_DB.md"
with open(path_db, encoding="utf-8") as f:
    c = f.read()

# Find and print exact bytes around is_blacklisted BOOLEAN
idx = c.find("is_blacklisted` (BOOLEAN)")
if idx >= 0:
    segment = c[idx:idx+120]
    print("Found segment:", repr(segment))
    # Replace just the threshold part
    old_seg = "is_blacklisted` (BOOLEAN): \u9054\u5230\u9694\u96e2\u9580\u6bb3\uff08weight \u2265 3.0\uff09"
    new_seg = "is_blacklisted` (BOOLEAN): \u9054\u5230\u9694\u96e2\u9580\u6bb3\uff08**weight > 3.0\uff08\u4e0d\u542b\uff09**\uff09"
    if old_seg in c:
        c = c.replace(old_seg, new_seg)
        print("REPLACED")
    else:
        print("old_seg not found, trying with repr match...")
        print("old_seg repr:", repr(old_seg))
        print("actual repr:", repr(segment[:len(old_seg)+5]))
else:
    print("is_blacklisted not found at all")

with open(path_db, "w", encoding="utf-8") as f:
    f.write(c)
print("done")
