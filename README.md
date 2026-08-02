# **MeTify**

![Docker Pulls](https://img.shields.io/docker/pulls/lucas410/metify)
![Last Commit](https://img.shields.io/github/last-commit/kikkerslijm410/metify)
![GitHub Stars](https://img.shields.io/github/stars/kikkerslijm410/metify)

<!-- ![GitHub License](https://img.shields.io/github/license/kikkerslijm410/metify)
![GitHub Forks](https://img.shields.io/github/forks/kikkerslijm410/metify)
![GitHub Issues](https://img.shields.io/github/issues/kikkerslijm410/metify)
![GitHub Branches](https://img.shields.io/github/branches/kikkerslijm410/metify.svg)
![GitHub Pull Requests](https://img.shields.io/github/issues-pr/kikkerslijm410/metify) -->


Self-hosted music downloader for Spotify (web UI for spotdl)

A lightweight web interface to download Spotify tracks and playlists using **spotDL**, with job tracking and file management.

---

## ⚙️ Features

- Download Spotify tracks/playlists via spotDL
- Downloads from YouTube (Music) also work
- Background job queue with progress tracking
- Live logs per download
- File management (list, download, delete)

---

## 🐳 Run using Docker

### 1. Build and run
```bash
docker-compose up --build -d
```

### 2. Open in browser
```
http://localhost:5000
```

---

## 🐍 Run using Python

### 1. Install dependencies
```bash
pip install -r requirements.txt
```

### 2. Start app
```bash
python app.py
```

---
## 🖥️ Run using Proxmox

### 1. Build and run
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Kikkerslijm410/MeTify/refs/heads/main/installers/proxmox-install.sh)"
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
