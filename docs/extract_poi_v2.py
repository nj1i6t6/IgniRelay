#!/usr/bin/env python3
"""extract_poi_details.py – 從 OSM PBF 提取有詳情的 POI → SQLite DB"""
import sqlite3, sys, os, time, traceback
import osmium

PBF = r"C:\Users\radio\Downloads\IDE\CoReM\docs\taiwan-260225.osm.pbf"
DB  = r"C:\Users\radio\Downloads\IDE\CoReM\resqmesh_app\assets\maps\poi_details.db"

class H(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.rows = []
        self.n = 0        # POI with details
        self.skip = 0     # POI w/o details

    def node(self, n):
        t = n.tags
        # 判斷是否 POI
        cls = sub = ""
        for k in ("amenity","shop","tourism","leisure","sport",
                   "office","craft","healthcare","aeroway"):
            v = t.get(k,"")
            if v:
                cls, sub = k, v
                break
        if not cls:
            hw = t.get("highway","")
            if hw == "bus_stop":
                cls, sub = "highway", hw
            rw = t.get("railway","")
            if rw in ("station","halt","tram_stop"):
                cls, sub = "railway", rw
        if not cls:
            return  # 不是 POI

        phone = t.get("phone","") or t.get("contact:phone","")
        hours = t.get("opening_hours","")
        hnum  = t.get("addr:housenumber","")
        street= t.get("addr:street","")

        if not (phone or hours or hnum):
            self.skip += 1
            return

        self.rows.append((
            round(n.location.lat, 7),
            round(n.location.lon, 7),
            t.get("name",""), cls, sub,
            phone, hours, hnum, street
        ))
        self.n += 1
        if self.n % 20000 == 0:
            print(f"  {self.n} POIs ...", flush=True)

def main():
    pbf = sys.argv[1] if len(sys.argv)>1 else PBF
    db  = sys.argv[2] if len(sys.argv)>2 else DB
    print(f"PBF: {pbf}", flush=True)
    print(f"DB:  {db}", flush=True)

    t0 = time.time()
    h = H()
    h.apply_file(pbf)
    t1 = time.time()
    print(f"掃描完成: {h.n} 有詳情, {h.skip} 略過 ({t1-t0:.1f}s)", flush=True)

    # 建 DB
    os.makedirs(os.path.dirname(db), exist_ok=True)
    if os.path.exists(db):
        os.remove(db)
    conn = sqlite3.connect(db)
    c = conn.cursor()
    c.execute("""CREATE TABLE poi_details(
        id INTEGER PRIMARY KEY, lat REAL, lon REAL,
        name TEXT, class TEXT, subclass TEXT,
        phone TEXT, opening_hours TEXT,
        housenumber TEXT, addr_street TEXT)""")
    c.executemany("INSERT INTO poi_details(lat,lon,name,class,subclass,phone,opening_hours,housenumber,addr_street) VALUES(?,?,?,?,?,?,?,?,?)", h.rows)
    c.execute("CREATE INDEX idx_ll ON poi_details(lat,lon)")
    c.execute("CREATE INDEX idx_name ON poi_details(name)")
    conn.commit()
    conn.close()

    sz = os.path.getsize(db) / 1024 / 1024
    print(f"完成! {h.n} 筆, {sz:.2f} MB, 耗時 {time.time()-t0:.1f}s", flush=True)

if __name__=="__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
