
path = r"c:\Users\radio\Downloads\CoReM\docs\01_產品需求規格書_SRS.md"
with open(path, encoding="utf-8") as f:
    lines = f.readlines()

# Print lines 18-22 (0-indexed 17-21) completely
for i in range(17, 23):
    print(f"=== Line {i+1} ===")
    print(repr(lines[i]))
