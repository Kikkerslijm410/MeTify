# MeTify
Self-hosted music downloader for Spotify (web UI for spotdl)

A lightweight web interface to download Spotify tracks and playlists using **spotDL**, with job tracking and file management.

---

## 📁 Project Structure

```
├── app.py
├── docker-compose.yml
├── Dockerfile.txt
├── requirements.txt
├── README.md
├── templates/
│   └── index.html
├── static/
│   ├── app.js
│   └── style.css
└── downloads/
```

---

## ⚙️ Features

- Download Spotify tracks/playlists via spotDL
- Background job queue with progress tracking
- Live logs per download
- File management (list, download, delete)
- Simple web UI (Flask + JavaScript)

---

## 🚀 Getting Started (Docker)

### 1. Build and run
```bash
docker-compose up --build -d
```

### 2. Open in browser
```
http://localhost:5000
```

---

## 🧠 How It Works

1. Submit a Spotify URL through the UI
2. API creates a job (`/api/jobs`)
3. spotDL runs in a background thread
4. Logs and progress are updated live
5. Files are saved in `/downloads`

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

## ⚠️ Notes

- The `downloads/` folder is created automatically
- Docker uses a volume:
```yaml
./downloads:/downloads
```
- spotDL must be installed in the environment

---

## ✅ Tips

- Use playlists for bulk downloads
- Increase threads for faster downloads
- Check logs for detailed output

---
