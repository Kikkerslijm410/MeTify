import os, uuid, time, threading, subprocess, sys, io, zipfile, json
from pathlib import Path
from datetime import datetime
from flask import Flask, request, jsonify, render_template, send_from_directory, abort, send_file

app = Flask(__name__)

DOWNLOAD_DIR = Path("./downloads").resolve()
DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)

STATE_DIR = Path("./config").resolve()
STATE_DIR.mkdir(parents=True, exist_ok=True)
JOBS_FILE = STATE_DIR / "jobs.json"

ALLOWED_AUDIO_SOURCES = {"youtube", "youtube-music"}
ALLOWED_OPTIONS = {"--generate-lrc", "--skip-explicit", "--only-verified-results"}
ALLOWED_BITRATES = {"auto", "128k", "256k", "320k"}
ALLOWED_FORMATS = {"mp3", "flac", "m4a", "wav"}

def load_jobs():
    if not JOBS_FILE.exists():
        return {}
    try:
        raw = json.loads(JOBS_FILE.read_text())
    except (json.JSONDecodeError, OSError):
        return {}
    for job in raw.values():
        if job.get("status") in ("Queued", "Running"):
            job["status"] = "Failed"
            job.setdefault("log", []).append("Interrupted: server restarted.")
            job["finished_at"] = job.get("finished_at") or datetime.now().isoformat(timespec="seconds")
    return raw

def save_jobs():
    tmp = JOBS_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(jobs, indent=2))
    tmp.replace(JOBS_FILE)

def list_downloads():
    items = []
    for p in sorted(DOWNLOAD_DIR.iterdir(), key=lambda x: x.stat().st_mtime, reverse=True):
        if not p.is_file():
            continue
        stat = p.stat()
        items.append({
            "name": p.name,
            "size": stat.st_size,
            "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(timespec="seconds"),
        })
    return items

def as_list(value):
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    return list(value)

def build_spotdl_command(data):
    url = (data.get("url") or "").strip()
    if not url:
        raise ValueError("Enter a Spotify, playlist, or track URL.")

    cmd = [sys.executable, "-m", "spotdl", "download", url]

    audio = [a for a in as_list(data.get("audio")) if a in ALLOWED_AUDIO_SOURCES]
    if audio:
        cmd += ["--audio", *audio]

    options = [opt for opt in as_list(data.get("options")) if opt in ALLOWED_OPTIONS]
    if options:
        cmd += options

    try:
        max_retries = int(data.get("max_retries", 4))
    except (TypeError, ValueError):
        raise ValueError("Max retries must be a number.")
    cmd += ["--max-retries", str(max_retries)]

    try:
        threads = int(data.get("threads", 1))
    except (TypeError, ValueError):
        raise ValueError("Threads must be a number.")
    cmd += ["--threads", str(threads)]

    bitrate = (data.get("bitrate") or "auto").strip()
    if bitrate not in ALLOWED_BITRATES:
        raise ValueError(f"Unsupported bitrate: {bitrate}")
    cmd += ["--bitrate", bitrate]

    fmt = (data.get("format") or "mp3").strip()
    if fmt not in ALLOWED_FORMATS:
        raise ValueError(f"Unsupported format: {fmt}")
    cmd += ["--format", fmt]

    return cmd

def run_job(job_id, data):
    try:
        cmd = build_spotdl_command(data)
        with jobs_lock:
            jobs[job_id].update({
                "status": "Running",
                "command": " ".join(cmd),
                "started_at": datetime.now().isoformat(timespec="seconds"),
                "progress": 5,
                "log": ["Starting job"],
            })
            save_jobs()

        process = subprocess.Popen(cmd, cwd=str(DOWNLOAD_DIR), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)

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
            jobs[job_id]["status"] = "Completed" if code == 0 else "Failed"
            jobs[job_id].setdefault("log", []).append("Finished job" if code == 0 else f"Failed, exit code {code}")
            save_jobs()
    except Exception as exc:
        with jobs_lock:
            jobs[job_id].update({
                "status": "Failed",
                "finished_at": datetime.now().isoformat(timespec="seconds"),
                "progress": 100,
            })
            jobs[job_id].setdefault("log", []).append(f"Error: {exc}")
            save_jobs()

@app.errorhandler(400)
@app.errorhandler(404)
@app.errorhandler(500)
def handle_error(err):
    return jsonify({"error": getattr(err, "description", str(err))}), err.code

@app.route("/")
def index():
    return render_template("index.html")

@app.post("/api/jobs")
def create_job():
    data = request.get_json(force=True, silent=True) or {}

    try:
        build_spotdl_command(data)
    except ValueError as exc:
        abort(400, str(exc))

    job_id = str(uuid.uuid4())
    with jobs_lock:
        jobs[job_id] = {
            "id": job_id,
            "status": "Queued",
            "progress": 0,
            "created_at": datetime.now().isoformat(timespec="seconds"),
            "log": [],
        }
        save_jobs()
    threading.Thread(target=run_job, args=(job_id, data), daemon=True).start()
    return jsonify(jobs[job_id]), 201

@app.get("/api/jobs")
def get_jobs():
    with jobs_lock:
        return jsonify(list(jobs.values())[::-1])

@app.delete("/api/jobs/<job_id>")
def delete_job(job_id):
    with jobs_lock:
        if job_id not in jobs:
            abort(404, "Job not found")
        jobs.pop(job_id)
        save_jobs()
    return jsonify({"deleted": job_id})

@app.delete("/api/jobs")
def clear_jobs():
    with jobs_lock:
        keep = {jid: j for jid, j in jobs.items() if j.get("status") in ("Queued", "Running")}
        jobs.clear()
        jobs.update(keep)
        save_jobs()
        return jsonify(list(jobs.values())[::-1])

@app.get("/api/downloads")
def downloads():
    return jsonify(list_downloads())

@app.post("/api/download")
def download_file():
    data = request.get_json(silent=True) or {}

    filenames = data.get("filenames")
    if filenames is None:
        single = data.get("filename")
        filenames = [single] if single else []

    if not filenames:
        abort(400, "No filename(s) provided")

    safe_names = [os.path.basename(f) for f in filenames]

    paths = []
    for name in safe_names:
        path = DOWNLOAD_DIR / name
        if not path.exists() or not path.is_file():
            abort(404, f"File not found: {name}")
        paths.append(path)

    if len(paths) == 1:
        return send_from_directory(DOWNLOAD_DIR, safe_names[0], as_attachment=True)

    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as zf:
        for path, name in zip(paths, safe_names):
            zf.write(path, arcname=name)
    buffer.seek(0)

    return send_file(buffer, mimetype="application/zip", as_attachment=True, download_name="MeTify.zip")

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

jobs = load_jobs()
jobs_lock = threading.Lock()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, threaded=True)