# MeTify
Self-hosted music downloader for Spotify (web UI for spotdl)

A lightweight web interface to download Spotify tracks and playlists using **spotDL**, with job tracking and file management.

---

## ⚙️ Features

- Download Spotify tracks/playlists via spotDL
- Downloads from YouTube (Music) also work
- Background job queue with progress tracking
- Live logs per download
- File management (list, download, delete)
- Simple web UI (Flask + JavaScript)

---

## 🐳 Getting Started (Docker)

### 1. Build and run
```bash
docker-compose up --build -d
```

### 2. Open in browser
```
http://localhost:5000
```

---

## 📡 API Endpoints

### Jobs
- `POST /api/jobs` → Start download
- `GET /api/jobs` → List jobs

### Files
- `GET /api/downloads` → List downloaded files
- `POST /api/download` → Download a file
- `DELETE /api/downloads/<filename>` → Delete a file

---

## 🐍 Run Locally (without Docker)

### 1. Install dependencies
```bash
pip install -r requirements.txt
```

### 2. Start app
```bash
python app.py
```

---
