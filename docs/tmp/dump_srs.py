
path = r"c:\Users\radio\Downloads\CoReM\docs\01_產品需求規格書_SRS.md"
with open(path, encoding="utf-8") as f:
    content = f.read()

with open(r"c:\Users\radio\Downloads\CoReM\docs\tmp\srs_full.txt", "w", encoding="utf-8") as f:
    f.write(content)

print("written")
