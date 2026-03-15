
# Fix 03_API.md: Clarify SOS_YELLOW = 30 min
path_api = r"c:\Users\radio\Downloads\CoReM\docs\03_通訊協定與API設計_API.md"
with open(path_api, encoding="utf-8") as f:
    c = f.read()

old = "核發壽命依 urgency 動態縮短 (如醫療/SOS物資 30 分鐘，一般 4 小時)"
new = "核發壽命依 urgency 動態縮短：**`SOS_RED` 及 `SOS_YELLOW` = 30 分鐘**；**`RESOURCE` 及 `INFO` = 4 小時**"

if old in c:
    c = c.replace(old, new)
    print("API fixed")
else:
    print("NOT FOUND in API")

with open(path_api, "w", encoding="utf-8") as f:
    f.write(c)

# Fix 04_DB.md: PENDING Timeout Rollback in section 3
path_db = r"c:\Users\radio\Downloads\CoReM\docs\04_資料庫規劃與狀態同步_DB.md"
with open(path_db, encoding="utf-8") as f:
    c = f.read()

old2 = "超時設定依緊急度動態調整（如醫療急需半小時即放行）"
new2 = "超時設定依緊急度動態調整：**`SOS_RED` 及 `SOS_YELLOW` = 30 分鐘**；**`RESOURCE` 及 `INFO` = 4 小時**"

if old2 in c:
    c = c.replace(old2, new2)
    print("DB section3 fixed")
else:
    print("NOT FOUND in DB section3")

with open(path_db, "w", encoding="utf-8") as f:
    f.write(c)

print("all done")
