#!/usr/bin/env python3
"""
extract_poi_details.py
從 OSM PBF 提取 POI 詳細資訊 (phone, opening_hours, housenumber, addr:street)，
產出 SQLite DB 供 ResQMesh App 離線查詢。
"""

import sqlite3
import sys
import os
import time
import osmium

# 要提取的 amenity / shop / tourism 等 POI 標籤 (OpenMapTiles POI 涵蓋的 class)
POI_KEYS = {
    "amenity", "shop", "tourism", "leisure", "sport", "office",
    "aerialway", "highway", "railway", "waterway",
    "place_of_worship", "healthcare", "craft"
}

# 我們關心的 detail tags
DETAIL_TAGS = ["phone", "contact:phone", "opening_hours", "addr:housenumber", "addr:street"]


class POIHandler(osmium.SimpleHandler):
    """osmium handler: 掃描 nodes 和 ways，找出有 detail tags 的 POI。"""

    def __init__(self):
        super().__init__()
        self.rows = []
        self.count = 0
        self.skipped = 0

    def _is_poi(self, tags):
        """判斷是否屬於常見 POI 類型"""
        for key in ("amenity", "shop", "tourism", "leisure", "sport",
                     "office", "craft", "healthcare", "aeroway"):
            if key in tags:
                return True
        # highway=bus_stop 等
        hw = tags.get("highway", "")
        if hw in ("bus_stop",):
            return True
        rw = tags.get("railway", "")
        if rw in ("station", "halt", "tram_stop"):
            return True
        return False

    def _has_detail(self, tags):
        """至少有一個 detail tag"""
        return any(k in tags for k in ("phone", "contact:phone",
                                         "opening_hours",
                                         "addr:housenumber"))

    def _extract(self, tags, lon, lat):
        if not self._is_poi(tags):
            return
        if not self._has_detail(tags):
            self.skipped += 1
            return

        name = tags.get("name", "")
        # class 推導 (簡化版)
        cls = ""
        sub = ""
        for key in ("amenity", "shop", "tourism", "leisure", "sport",
                     "office", "craft", "healthcare", "aeroway",
                     "highway", "railway"):
            val = tags.get(key, "")
            if val:
                cls = key
                sub = val
                break

        phone = tags.get("phone", "") or tags.get("contact:phone", "")
        hours = tags.get("opening_hours", "")
        housenumber = tags.get("addr:housenumber", "")
        street = tags.get("addr:street", "")

        self.rows.append((
            round(lat, 7), round(lon, 7),
            name, cls, sub,
            phone, hours, housenumber, street
        ))
        self.count += 1
        if self.count % 10000 == 0:
            print(f"  已提取 {self.count} 筆 POI ...", flush=True)

    def node(self, n):
        self._extract(n.tags, n.location.lon, n.location.lat)

    def way(self, w):
        # 用 way 的中心點（osmium 需 locations=True）
        # 但 way centroid 需要 NodeLocationsForWays，這裡直接跳過較安全
        # 實作上用第一個 node 近似
        pass  # ways as POI 比較少，先只處理 nodes


def create_db(db_path, rows):
    """建立 SQLite DB"""
    if os.path.exists(db_path):
        os.remove(db_path)

    conn = sqlite3.connect(db_path)
    c = conn.cursor()

    c.execute("""
        CREATE TABLE poi_details (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            name TEXT,
            class TEXT,
            subclass TEXT,
            phone TEXT,
            opening_hours TEXT,
            housenumber TEXT,
            addr_street TEXT
        )
    """)

    c.executemany("""
        INSERT INTO poi_details (lat, lon, name, class, subclass,
                                  phone, opening_hours, housenumber, addr_street)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, rows)

    # 空間索引 (用 lat/lon 的網格)
    c.execute("CREATE INDEX idx_poi_lat ON poi_details(lat)")
    c.execute("CREATE INDEX idx_poi_lon ON poi_details(lon)")
    # 複合索引方便附近查找
    c.execute("CREATE INDEX idx_poi_latlon ON poi_details(lat, lon)")
    # name 索引（用於 name 匹配）
    c.execute("CREATE INDEX idx_poi_name ON poi_details(name)")

    conn.commit()

    # 統計
    c.execute("SELECT COUNT(*) FROM poi_details")
    total = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM poi_details WHERE phone != ''")
    with_phone = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM poi_details WHERE opening_hours != ''")
    with_hours = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM poi_details WHERE housenumber != ''")
    with_addr = c.fetchone()[0]

    conn.close()
    return total, with_phone, with_hours, with_addr


def main():
    pbf_path = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\radio\Downloads\IDE\CoReM\docs\taiwan-260225.osm.pbf"
    db_path = sys.argv[2] if len(sys.argv) > 2 else r"C:\Users\radio\Downloads\IDE\CoReM\resqmesh_app\assets\maps\poi_details.db"

    print(f"[1/3] 讀取 PBF: {pbf_path}")
    t0 = time.time()

    handler = POIHandler()
    handler.apply_file(pbf_path, locations=True)

    t1 = time.time()
    print(f"[2/3] 掃描完成: {handler.count} 筆有詳情的 POI, "
          f"{handler.skipped} 筆無詳情已跳過 ({t1 - t0:.1f}s)")

    print(f"[3/3] 寫入 SQLite: {db_path}")
    total, with_phone, with_hours, with_addr = create_db(db_path, handler.rows)

    t2 = time.time()
    file_size = os.path.getsize(db_path)
    print(f"\n完成！")
    print(f"  總 POI: {total}")
    print(f"  有電話: {with_phone}")
    print(f"  有營業時間: {with_hours}")
    print(f"  有門牌號: {with_addr}")
    print(f"  檔案大小: {file_size / 1024 / 1024:.2f} MB")
    print(f"  總耗時: {t2 - t0:.1f}s")


if __name__ == "__main__":
    main()
