import os, uuid, time, threading, subprocess
from pathlib import Path
from datetime import datetime
from flask import Flask, request, jsonify, render_template, send_from_directory, abort

app = Flask(__name__)

DOWNLOAD_DIR = Path("/downloads").resolve()
DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)

jobs = {}
jobs_lock = threading.Lock()

def list_downloads():
    items = []
    for p in sorted(DOWNLOAD_DIR.iterdir(), key=lambda x: x.stat().st_mtime, reverse=True):
        if p.is_file():
            stat = p.stat()
            items.append({
                "name": p.name,
                "size": stat.st_size,
                "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(timespec="seconds"),
            })
    return items

def build_spotdl_command(data):
    url = (data.get("url") or "").strip()
    if not url:
        raise ValueError("Enter a Spotify/playlist/track URL.")

    cmd = ["python", "-m", "spotdl", "download", url]

    audio = data.get("audio") or []
    if isinstance(audio, str):
        audio = [audio]
    audio = [a for a in audio]
    if audio:
        cmd += ["--audio", *audio]

    lyrics = data.get("lyrics") or []
    if isinstance(lyrics, str):
        lyrics = [lyrics]
    lyrics = [l for l in lyrics]
    if lyrics:
        cmd += ["--lyrics", *lyrics]

    max_retries = str(data.get("max_retries") or "3").strip()
    cmd += ["--max-retries", max_retries]

    threads = str(data.get("threads") or "1").strip()
    cmd += ["--threads", threads]

    bitrate = (data.get("bitrate") or "auto").strip()
    cmd += ["--bitrate", bitrate]

    fmt = (data.get("format") or "mp3").strip()
    cmd += ["--format", fmt]

    return cmd

def run_job(job_id, data):
    try:
        cmd = build_spotdl_command(data)
        with jobs_lock:
            jobs[job_id].update({
                "status": "running",
                "command": " ".join(cmd),
                "started_at": datetime.now().isoformat(timespec="seconds"),
                "progress": 5,
                "log": [cmd],
            })
        process = subprocess.Popen(cmd, cwd=str(DOWNLOAD_DIR), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1,)

        last_update = time.time()
        for line in process.stdout:
            line = line.rstrip()
            if not line:
                continue
            with jobs_lock:
                log = jobs[job_id].setdefault("log", [])
                log.append(line)
                jobs[job_id]["log"] = log[-300:]

                if "Downloaded" in line or "Finished" in line:
                    jobs[job_id]["progress"] = max(jobs[job_id].get("progress", 5), 90)
                elif time.time() - last_update > 1:
                    jobs[job_id]["progress"] = min(jobs[job_id].get("progress", 5) + 2, 85)
                    last_update = time.time()

        code = process.wait()
        with jobs_lock:
            jobs[job_id]["finished_at"] = datetime.now().isoformat(timespec="seconds")
            jobs[job_id]["return_code"] = code
            jobs[job_id]["progress"] = 100 if code == 0 else jobs[job_id].get("progress", 0)
            jobs[job_id]["status"] = "completed" if code == 0 else "failed"
            jobs[job_id].setdefault("log", []).append("Done ✅" if code == 0 else f"Failed ❌ exit code {code}")
    except Exception as exc:
        with jobs_lock:
            jobs[job_id].update({
                "status": "failed",
                "finished_at": datetime.now().isoformat(timespec="seconds"),
                "progress": 100,
            })
            jobs[job_id].setdefault("log", []).append(f"Fout: {exc}")

@app.route("/")
def index():
    return render_template("index.html")

@app.post("/api/jobs") # Method POST
def create_job():
    data = request.get_json(force=True)
    job_id = str(uuid.uuid4())
    with jobs_lock:
        jobs[job_id] = {
            "id": job_id,
            "status": "queued",
            "progress": 0,
            "created_at": datetime.now().isoformat(timespec="seconds"),
            "log": [],
        }
    thread = threading.Thread(target=run_job, args=(job_id, data), daemon=True)
    thread.start()
    return jsonify(jobs[job_id]), 202

@app.get("/api/jobs") # Method GET
def get_jobs():
    with jobs_lock:
        return jsonify(list(jobs.values())[::-1])

@app.get("/api/downloads")
def downloads():
    return jsonify(list_downloads())

@app.post("/api/download")
def download_file():
    data = request.get_json()
    filename = data.get("filename") if data else None

    path = Path(DOWNLOAD_DIR) / filename
    if not path.exists() or not path.is_file():
        abort(404, "File not found")

    return send_from_directory(DOWNLOAD_DIR, filename, as_attachment=True)

@app.delete("/api/downloads/<path:filename>")
def delete_file(filename):
    try:
        filename = os.path.basename(filename)
        path = DOWNLOAD_DIR / filename

        if not path.exists():
            abort(404, "File not found")

        path.unlink()
        return jsonify({"deleted": filename})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
