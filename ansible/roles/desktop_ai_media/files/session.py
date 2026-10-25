import os
import pathlib
import signal
import shutil
import subprocess
import sys
import time
import urllib.request

app = os.environ["APP"]
os.chdir("/opt/app")
if sys.argv[1:] == ["verify"]:
    os.execv(sys.executable, [sys.executable, "/opt/verify.py"])
if sys.argv[1:2] == ["ffmpeg"]:
    os.execv("/usr/bin/ffmpeg", ["ffmpeg", *sys.argv[2:]])
if sys.argv[1:2] == ["cli"]:
    if app != "facefusion":
        raise SystemExit("CLI is available for FaceFusion only")
    os.execv(sys.executable, [sys.executable, "facefusion.py", *sys.argv[2:]])
if app == "facefusion":
    command = [
        sys.executable, "facefusion.py", "run",
        "--execution-providers", "cpu", "--processors", "face_swapper",
        "--temp-path", "/work/state/tmp", "--jobs-path", "/work/state",
        "--output-path", "/work/output",
    ]
    port = 7860
else:
    pathlib.Path("/tmp/rvc-temp").mkdir(exist_ok=True)
    weights = pathlib.Path("/work/state/weights")
    weights.mkdir(exist_ok=True)
    for source in pathlib.Path("/work/models/weights").glob("*.pth"):
        target = weights / source.name
        if not target.exists() and not target.is_symlink():
            target.symlink_to(source)
    fixture = pathlib.Path("/opt/training-fixture/mute")
    for source in fixture.rglob("*"):
        target = pathlib.Path("/work/state/mute") / source.relative_to(fixture)
        if source.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        elif not target.exists():
            shutil.copyfile(source, target)
    os.environ.update(
        weight_root="/work/state/weights",
        outside_index_root="/work/models/indices",
        index_root="/work/state",
        weight_pymss_root="/opt/app/assets/pymss_weights",
    )
    command = [sys.executable, "webui.py", "--noautoopen", "--port", "7865"]
    port = 7865
server = subprocess.Popen(command)
browser = None
profile = pathlib.Path("/tmp/browser")
profile.mkdir(exist_ok=True)
(profile / "user.js").write_text('''
user_pref("browser.download.folderList", 2);
user_pref("browser.download.dir", "/work/output");
user_pref("browser.download.useDownloadDir", true);
user_pref("widget.use-xdg-desktop-portal.file-picker", 0);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
''')
bookmarks = pathlib.Path.home() / ".config/gtk-3.0/bookmarks"
bookmarks.parent.mkdir(parents=True, exist_ok=True)
bookmarks.write_text("file:///work/input Input\nfile:///work/output Output\nfile:///work/models Models\n")


def stop(*_):
    if browser is not None and browser.poll() is None:
        browser.terminate()
    if server.poll() is None:
        server.terminate()


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
try:
    url = f"http://127.0.0.1:{port}"
    for _ in range(180):
        if server.poll() is not None:
            raise RuntimeError(f"{app} exited: {server.returncode}")
        try:
            with urllib.request.urlopen(url, timeout=1) as response:
                if response.status == 200:
                    break
        except OSError:
            time.sleep(1)
    else:
        raise RuntimeError("Offline WebUI did not become ready")
    print(f"{app}: offline WebUI ready", flush=True)
    if sys.argv[1:] == ["smoke"]:
        subprocess.run([
            "firefox-esr", "--headless", "--no-remote", "--profile", "/tmp/browser",
            "--screenshot", "/tmp/offline-ui.png", url,
        ], check=True, timeout=90)
        assert pathlib.Path("/tmp/offline-ui.png").stat().st_size > 1000
        raise SystemExit(0)
    browser = subprocess.Popen([
        "firefox-esr", "--no-remote", "--profile", "/tmp/browser", url,
    ])
    while browser.poll() is None:
        if server.poll() is not None:
            raise RuntimeError("WebUI terminated unexpectedly")
        time.sleep(1)
finally:
    stop()
    if browser is not None:
        browser.wait(timeout=15)
    server.wait(timeout=15)
