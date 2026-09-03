import sys, os, time, threading, subprocess
from datetime import datetime, timedelta

UPDATE_HOUR = 2
PACKAGES = ["yt-dlp", "spotdl"]

def installed_version(package):
    result = subprocess.run([sys.executable, "-m", "pip", "show", package], capture_output=True, text=True, check=True,)
    for line in result.stdout.splitlines():
        if line.startswith("Version:"):
            return line.split(":", 1)[1].strip()
    return None

def latest_version(package):
    result = subprocess.run([sys.executable, "-m", "pip", "index", "versions", package], capture_output=True, text=True, check=True,)
    first_line = result.stdout.splitlines()[0]
    return first_line.split("(")[-1].rstrip(")").strip()

def upgrade(package):
    subprocess.run([sys.executable, "-m", "pip", "install", "--upgrade", package], capture_output=True, text=True, check=True,)

def seconds_until_next(hour):
    now = datetime.now()
    target = now.replace(hour=hour, minute=0, second=0, microsecond=0)
    if target <= now:
        target += timedelta(days=1)
    return (target - now).total_seconds()

def check_and_update(packages=PACKAGES):
    results = {}
    any_updated = False

    for package in packages:
        entry = {"current": None, "latest": None, "updated": False, "error": None}
        try:
            entry["current"] = installed_version(package)
            entry["latest"] = latest_version(package)
        except Exception as exc:
            entry["error"] = f"Version check failed: {exc}"
            results[package] = entry
            continue

        if entry["current"] and entry["latest"] and entry["current"] != entry["latest"]:
            try:
                upgrade(package)
                entry["current"] = installed_version(package) or entry["latest"]
                entry["updated"] = True
                any_updated = True
            except subprocess.CalledProcessError as exc:
                entry["error"] = f"Upgrade failed: {exc}"

        results[package] = entry

    return results, any_updated

def run_update_cycle(any_job_running, restart_on_update=True):
    results, any_updated = check_and_update()

    if not any_updated:
        return results, False

    while any_job_running():
        print("[auto-update] Job running, waiting 10 minutes...", flush=True)
        time.sleep(600)

    if restart_on_update:
        print("[auto-update] Updated, restarting.", flush=True)
        os._exit(0)

    return results, any_updated

def start_auto_update(any_job_running):
    def loop():
        while True:
            time.sleep(seconds_until_next(UPDATE_HOUR))
            try:
                run_update_cycle(any_job_running)
            except Exception as exc:
                print(f"[auto-update] Unexpected error: {exc}", flush=True)

    threading.Thread(target=loop, daemon=True).start()
