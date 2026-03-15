import sqlite3, json
conn = sqlite3.connect('taiwan_resqmesh.mbtiles')
cursor = conn.cursor()
cursor.execute("SELECT value FROM metadata WHERE name='json'")
row = cursor.fetchone()
data = json.loads(row[0])
print("=== 圖層總覽 ===")
for l in data['vector_layers']:
    print(f"- 圖層 [{l['id']}] (支援放大倍率: {l['minzoom']} ~ {l['maxzoom']})")

poi = next((l for l in data['vector_layers'] if l['id'] == 'poi'), None)
if poi:
    print("\n=== POI (興趣點/地標) 支援的分類 (class) 屬性 ===")
    print("這些是您的 App 可以在前端選擇要不要畫出來的屬性標籤：")
    for field, field_type in poi['fields'].items():
        if field == 'class':
            print("【核心分類標籤 class】")
        else:
            print(f"- 屬性: {field} ({field_type})")
            
    # Let's query some distinct POI classes from the database to show the user exactly what was kept
    print("\n=== 實際資料庫中保留的地標類型清單 (class values) ===")
    # Actually, MBTiles stores PBF tiles in the tiles table. We can't query specific features easily without a PBF decoder.
    # But we can query the OpenMapTiles profile we used (config).
