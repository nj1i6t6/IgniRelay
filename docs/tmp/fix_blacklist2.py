
import io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

path_db = r"c:\Users\radio\Downloads\CoReM\docs\04_資料庫規劃與狀態同步_DB.md"
with open(path_db, encoding="utf-8") as f:
    c = f.read()

# Use the exact segment we found from the file
old = "is_blacklisted` (BOOLEAN): 達到隔離門檻（weight ≥ 3.0）或手動封鎖後，拒絕建立 Socket 連線。"
new = "is_blacklisted` (BOOLEAN): 達到隔離門檻（**weight > 3.0（不含）**）或手動封鎖後，拒絕建立 Socket 連線。"

if old in c:
    c = c.replace(old, new)
    print("REPLACED successfully")
else:
    print("STILL NOT FOUND")

with open(path_db, "w", encoding="utf-8") as f:
    f.write(c)
print("done")
