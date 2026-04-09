package main

import (
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"path/filepath"
)

type PageData struct {
	Theme     string
	Title     string
	NodeName  string
	ActiveTab string
	RoleLabel string
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	role := os.Getenv("ROLE")
	if role == "" {
		role = "shelter"
	}

	baseDir := "."
	if _, err := os.Stat("web"); os.IsNotExist(err) {
		baseDir = ".."
	}

	staticDir := filepath.Join(baseDir, "web", "static")
	layoutPath := filepath.Join(baseDir, "web", "templates", "components", "layout.html")

	mux := http.NewServeMux()
	mux.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir(staticDir))))

	render := func(w http.ResponseWriter, tmplName string, data PageData) {
		tmplPath := filepath.Join(baseDir, "web", "templates", tmplName)
		tmpl, err := template.ParseFiles(layoutPath, tmplPath)
		if err != nil {
			http.Error(w, fmt.Sprintf("Template error: %v", err), http.StatusInternalServerError)
			log.Printf("Template parse error for %s: %v", tmplName, err)
			return
		}
		w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
		if err := tmpl.Execute(w, data); err != nil {
			log.Printf("Template execute error: %v", err)
		}
	}

	switch role {
	case "shelter":
		registerShelterRoutes(mux, render)
	case "village":
		registerVillageRoutes(mux, render)
	case "township":
		registerTownshipRoutes(mux, render)
	case "fire":
		registerFireRoutes(mux, render)
	default:
		log.Fatalf("Unknown role: %s", role)
	}

	log.Printf("ResQMesh Edge Node [%s] started on http://localhost:%s", role, port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}

type renderFunc func(http.ResponseWriter, string, PageData)

// ── 避難所 (Shelter) ──
func registerShelterRoutes(mux *http.ServeMux, render renderFunc) {
	node := "信義國小避難所"
	theme := "shelter"
	label := "避難所"

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		render(w, "shelter/dashboard.html", PageData{theme, "首頁", node, "dashboard", label})
	})
	mux.HandleFunc("/inventory", func(w http.ResponseWriter, r *http.Request) {
		render(w, "shelter/inventory.html", PageData{theme, "物資管理", node, "inventory", label})
	})
	mux.HandleFunc("/register", func(w http.ResponseWriter, r *http.Request) {
		render(w, "shelter/register.html", PageData{theme, "收容登記", node, "register", label})
	})
	mux.HandleFunc("/claims", func(w http.ResponseWriter, r *http.Request) {
		render(w, "shelter/claims.html", PageData{theme, "申領記錄", node, "claims", label})
	})
	mux.HandleFunc("/announcements", func(w http.ResponseWriter, r *http.Request) {
		render(w, "shelter/announcements.html", PageData{theme, "系統公告", node, "announcements", label})
	})
	mux.HandleFunc("/settings", func(w http.ResponseWriter, r *http.Request) {
		render(w, "shelter/settings.html", PageData{theme, "節點設定", node, "settings", label})
	})
}

// ── 里 (Village) ──
func registerVillageRoutes(mux *http.ServeMux, render renderFunc) {
	node := "信義里辦公處"
	theme := "village"
	label := "里"

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		render(w, "village/dashboard.html", PageData{theme, "里總覽", node, "dashboard", label})
	})
	mux.HandleFunc("/shelters", func(w http.ResponseWriter, r *http.Request) {
		render(w, "village/shelters.html", PageData{theme, "避難所總覽", node, "shelters", label})
	})
	mux.HandleFunc("/events", func(w http.ResponseWriter, r *http.Request) {
		render(w, "village/events.html", PageData{theme, "Mesh 事件", node, "events", label})
	})
	mux.HandleFunc("/map", func(w http.ResponseWriter, r *http.Request) {
		render(w, "village/map.html", PageData{theme, "離線地圖", node, "map", label})
	})
	mux.HandleFunc("/sync", func(w http.ResponseWriter, r *http.Request) {
		render(w, "village/sync.html", PageData{theme, "同步管理", node, "sync", label})
	})
}

// ── 鄉鎮區 (Township) ──
func registerTownshipRoutes(mux *http.ServeMux, render renderFunc) {
	node := "信義區災害應變中心"
	theme := "township"
	label := "EOC"

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		render(w, "township/dashboard.html", PageData{theme, "EOC 戰情", node, "dashboard", label})
	})
	mux.HandleFunc("/dispatch", func(w http.ResponseWriter, r *http.Request) {
		render(w, "township/dispatch.html", PageData{theme, "調度指令", node, "dispatch", label})
	})
	mux.HandleFunc("/map", func(w http.ResponseWriter, r *http.Request) {
		render(w, "shared/map.html", PageData{theme, "戰情地圖", node, "map", label})
	})
	mux.HandleFunc("/reports", func(w http.ResponseWriter, r *http.Request) {
		render(w, "township/reports.html", PageData{theme, "統計報表", node, "reports", label})
	})
	mux.HandleFunc("/sync", func(w http.ResponseWriter, r *http.Request) {
		render(w, "township/sync.html", PageData{theme, "同步管理", node, "sync", label})
	})
}

// ── 警消 (Fire/Police) ──
func registerFireRoutes(mux *http.ServeMux, render renderFunc) {
	node := "信義消防分隊"
	theme := "fire"
	label := "警消"

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		render(w, "fire/kanban.html", PageData{theme, "任務看板", node, "dashboard", label})
	})
	mux.HandleFunc("/sos", func(w http.ResponseWriter, r *http.Request) {
		render(w, "fire/sos.html", PageData{theme, "SOS 警報", node, "sos", label})
	})
	mux.HandleFunc("/resources", func(w http.ResponseWriter, r *http.Request) {
		render(w, "fire/resources.html", PageData{theme, "可用資源", node, "resources", label})
	})
	mux.HandleFunc("/map", func(w http.ResponseWriter, r *http.Request) {
		render(w, "shared/map.html", PageData{theme, "戰情地圖", node, "map", label})
	})
}
