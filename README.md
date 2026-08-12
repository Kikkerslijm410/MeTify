# **MeTify**

![Docker Pulls](https://img.shields.io/docker/pulls/lucas410/metify)
![Last Commit](https://img.shields.io/github/last-commit/kikkerslijm410/metify)
![GitHub Stars](https://img.shields.io/github/stars/kikkerslijm410/metify)

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
## 🖥️ Run using Proxmox

### 1. Build and run
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Kikkerslijm410/MeTify/refs/heads/main/installers/proxmox-install.sh)"
```

### 2. Update
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Kikkerslijm410/MeTify/refs/heads/11-proxmox-update-script/installers/proxmox-update.sh)"
```

---

## 📡 API Endpoints

### Jobs
- `POST /api/jobs` → Start download
- `GET /api/jobs` → List jobs
- `DELETE /api/jobs/<job_id>` → Delete job
- `DELETE /api/jobs` → Delete all completed jobs

### Files
- `GET /api/downloads` → List downloaded files
- `POST /api/download` → Download a file
- `DELETE /api/downloads/<path:filename>` → Delete a file
