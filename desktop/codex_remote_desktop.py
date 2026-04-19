from __future__ import annotations

import argparse
import json
import os
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlencode


APP_NAME = "Codex Remote"
DEFAULT_PORT = 8765
DEFAULT_HOST = "0.0.0.0"
DEFAULT_PUBLIC_NAME = "Codex Remote"
WINDOWS_APPS = Path(r"C:\Program Files\WindowsApps")
LOCALAPPDATA = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
STATE_ROOT = LOCALAPPDATA / "CodexRemote"
RUNTIME_ROOT = STATE_ROOT / "runtime"
RUNTIME_RESOURCES = RUNTIME_ROOT / "resources"
RUNTIME_MANIFEST = RUNTIME_ROOT / "manifest.json"
STATUS_FILE = STATE_ROOT / "status.json"
TOKEN_FILE = STATE_ROOT / "capability.token"
PAIRING_FILE = STATE_ROOT / "pairing.json"
LOG_FILE = STATE_ROOT / "app-server.log"
PID_FILE = STATE_ROOT / "app-server.pid"
CONFIG_FILE = STATE_ROOT / "config.json"
DETACHED_PROCESS = 0x00000008
CREATE_NEW_PROCESS_GROUP = 0x00000200
CREATE_NO_WINDOW = 0x08000000


def ensure_dirs() -> None:
    STATE_ROOT.mkdir(parents=True, exist_ok=True)
    RUNTIME_ROOT.mkdir(parents=True, exist_ok=True)


def default_config() -> dict[str, Any]:
    return {
        "listen_host": DEFAULT_HOST,
        "listen_port": DEFAULT_PORT,
        "public_ws_url": "",
        "desktop_shortcut_name": DEFAULT_PUBLIC_NAME,
        "token_file": str(TOKEN_FILE),
    }


def load_config() -> dict[str, Any]:
    ensure_dirs()
    config = default_config()
    if CONFIG_FILE.exists():
        try:
            stored = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
            if isinstance(stored, dict):
                config.update(stored)
        except json.JSONDecodeError:
            pass
    return config


def save_config(config: dict[str, Any]) -> None:
    ensure_dirs()
    CONFIG_FILE.write_text(json.dumps(config, indent=2), encoding="utf-8")


@dataclass
class LaunchSettings:
    listen_host: str
    listen_port: int
    public_ws_url: str
    shortcut_name: str


def parse_settings(args: argparse.Namespace) -> LaunchSettings:
    config = load_config()
    if args.listen_host:
        config["listen_host"] = args.listen_host
    if args.listen_port:
        config["listen_port"] = args.listen_port
    if args.public_ws_url is not None:
        config["public_ws_url"] = args.public_ws_url
    if args.shortcut_name:
        config["desktop_shortcut_name"] = args.shortcut_name
    save_config(config)
    return LaunchSettings(
        listen_host=str(config["listen_host"]),
        listen_port=int(config["listen_port"]),
        public_ws_url=str(config.get("public_ws_url", "")),
        shortcut_name=str(config.get("desktop_shortcut_name", DEFAULT_PUBLIC_NAME)),
    )


def appx_install_resources(package_name: str) -> Path | None:
    command = [
        "powershell",
        "-NoProfile",
        "-Command",
        (
            f"$pkg = Get-AppxPackage {package_name}; "
            "if ($pkg) { Join-Path $pkg.InstallLocation 'app\\resources' }"
        ),
    ]
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
            timeout=15,
        )
    except (OSError, subprocess.SubprocessError):
        return None

    if completed.returncode != 0:
        return None

    location = completed.stdout.strip()
    if not location:
        return None

    resources = Path(location)
    if (resources / "codex.exe").exists():
        return resources
    return None


def newest_codex_package() -> Path:
    resolved = appx_install_resources("OpenAI.Codex")
    if resolved is not None:
        return resolved

    candidates = sorted(WINDOWS_APPS.glob("OpenAI.Codex_*"), key=lambda item: item.name, reverse=True)
    for candidate in candidates:
        resources = candidate / "app" / "resources"
        if (resources / "codex.exe").exists():
            return resources
    raise FileNotFoundError(
        "Could not find the installed Codex app resources under C:\\Program Files\\WindowsApps."
    )


def stage_runtime(force: bool = False) -> Path:
    ensure_dirs()
    source = newest_codex_package()
    manifest = {
        "source": str(source),
    }
    existing = {}
    if RUNTIME_MANIFEST.exists():
        try:
            existing = json.loads(RUNTIME_MANIFEST.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            existing = {}
    if force or existing.get("source") != manifest["source"] or not (RUNTIME_RESOURCES / "codex.exe").exists():
        if RUNTIME_RESOURCES.exists():
            shutil.rmtree(RUNTIME_RESOURCES)
        shutil.copytree(source, RUNTIME_RESOURCES)
        RUNTIME_MANIFEST.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return RUNTIME_RESOURCES / "codex.exe"


def ensure_token() -> str:
    ensure_dirs()
    if TOKEN_FILE.exists():
        token = TOKEN_FILE.read_text(encoding="utf-8").strip()
        if token:
            return token
    token = secrets.token_urlsafe(36)
    TOKEN_FILE.write_text(token, encoding="utf-8")
    return token


def process_running(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        completed = subprocess.run(
            ["tasklist", "/FI", f"PID eq {pid}", "/FO", "CSV", "/NH"],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return False
    if completed.returncode != 0:
        return False
    output = completed.stdout.strip().strip('"')
    return bool(output) and "No tasks are running" not in output


def read_pid() -> int | None:
    if not PID_FILE.exists():
        return None
    try:
        return int(PID_FILE.read_text(encoding="utf-8").strip())
    except ValueError:
        return None


def write_status(payload: dict[str, Any]) -> None:
    ensure_dirs()
    STATUS_FILE.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    PAIRING_FILE.write_text(
        json.dumps(
            {
                "websocket_url": payload["websocket_url"],
                "token": payload["token"],
                "pairing_url": payload["pairing_url"],
            },
            indent=2,
        ),
        encoding="utf-8",
    )


def detect_lan_ip() -> str:
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect(("8.8.8.8", 80))
        return probe.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        probe.close()


def build_websocket_url(host: str, port: int, public_ws_url: str) -> str:
    if public_ws_url:
        return public_ws_url
    actual_host = host
    if host in {"0.0.0.0", "::"}:
        actual_host = detect_lan_ip()
    return f"ws://{actual_host}:{port}"


def build_pairing_url(websocket_url: str, token: str) -> str:
    query = urlencode({"url": websocket_url, "token": token, "name": APP_NAME})
    return f"codexremote://pair?{query}"


def read_status() -> dict[str, Any] | None:
    if not STATUS_FILE.exists():
        return None
    try:
        payload = json.loads(STATUS_FILE.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    if not isinstance(payload, dict):
        return None
    return payload


def launch(args: argparse.Namespace) -> int:
    settings = parse_settings(args)
    existing_pid = read_pid()
    if existing_pid and process_running(existing_pid):
        payload = read_status() or {}
        print(f"{APP_NAME} is already running (PID {existing_pid}).")
        if payload:
            print(json.dumps(payload, indent=2))
        return 0

    codex_exe = stage_runtime(force=args.refresh_runtime)
    token = ensure_token()
    websocket_url = build_websocket_url(settings.listen_host, settings.listen_port, settings.public_ws_url)
    pairing_url = build_pairing_url(websocket_url, token)

    command = [
        str(codex_exe),
        "app-server",
        "--listen",
        f"ws://{settings.listen_host}:{settings.listen_port}",
        "--ws-auth",
        "capability-token",
        "--ws-token-file",
        str(TOKEN_FILE),
    ]

    ensure_dirs()
    if args.foreground:
        payload = {
            "pid": os.getpid(),
            "started_at": int(time.time()),
            "listen_host": settings.listen_host,
            "listen_port": settings.listen_port,
            "websocket_url": websocket_url,
            "pairing_url": pairing_url,
            "token": token,
            "command": command,
            "foreground": True,
        }
        write_status(payload)
        print(json.dumps(payload, indent=2))
        return subprocess.call(command, cwd=str(STATE_ROOT))

    with LOG_FILE.open("a", encoding="utf-8") as log_handle:
        process = subprocess.Popen(
            command,
            cwd=str(STATE_ROOT),
            stdin=subprocess.DEVNULL,
            stdout=log_handle,
            stderr=subprocess.STDOUT,
            creationflags=DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP | CREATE_NO_WINDOW,
        )

    PID_FILE.write_text(str(process.pid), encoding="utf-8")
    payload = {
        "pid": process.pid,
        "started_at": int(time.time()),
        "listen_host": settings.listen_host,
        "listen_port": settings.listen_port,
        "websocket_url": websocket_url,
        "pairing_url": pairing_url,
        "token": token,
        "runtime_executable": str(codex_exe),
        "log_file": str(LOG_FILE),
        "token_file": str(TOKEN_FILE),
        "status_file": str(STATUS_FILE),
    }
    write_status(payload)

    time.sleep(1.2)
    if not process_running(process.pid):
        print(f"{APP_NAME} failed to stay running. Check {LOG_FILE}.", file=sys.stderr)
        return 1

    print(f"{APP_NAME} started.")
    print(json.dumps(payload, indent=2))
    return 0


def stop(_args: argparse.Namespace) -> int:
    pid = read_pid()
    if not pid or not process_running(pid):
        print(f"{APP_NAME} is not running.")
        if PID_FILE.exists():
            PID_FILE.unlink()
        return 0

    subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], check=False)
    if PID_FILE.exists():
        PID_FILE.unlink()
    print(f"Stopped {APP_NAME} (PID {pid}).")
    return 0


def status(_args: argparse.Namespace) -> int:
    pid = read_pid()
    payload = read_status() or {}
    payload["running"] = bool(pid and process_running(pid))
    payload["pid"] = pid
    print(json.dumps(payload, indent=2))
    return 0 if payload["running"] else 1


def pairing(_args: argparse.Namespace) -> int:
    payload = read_status()
    if not payload:
        print("No pairing information found. Start the server first.", file=sys.stderr)
        return 1
    print(json.dumps(payload, indent=2))
    return 0


def doctor(_args: argparse.Namespace) -> int:
    config = load_config()
    token = ensure_token()
    try:
        source = newest_codex_package()
    except FileNotFoundError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    existing_pid = read_pid()
    report = {
        "app_name": APP_NAME,
        "config_file": str(CONFIG_FILE),
        "state_root": str(STATE_ROOT),
        "source_resources": str(source),
        "runtime_resources": str(RUNTIME_RESOURCES),
        "token_file": str(TOKEN_FILE),
        "token_length": len(token),
        "running_pid": existing_pid,
        "running": bool(existing_pid and process_running(existing_pid)),
        "config": config,
    }
    print(json.dumps(report, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=f"Desktop launcher for {APP_NAME}.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    launch_parser = subparsers.add_parser("launch", help="Stage runtime and start the Codex websocket app-server.")
    launch_parser.add_argument("--listen-host", default=None)
    launch_parser.add_argument("--listen-port", type=int, default=None)
    launch_parser.add_argument("--public-ws-url", default=None)
    launch_parser.add_argument("--shortcut-name", default=None)
    launch_parser.add_argument("--refresh-runtime", action="store_true")
    launch_parser.add_argument("--foreground", action="store_true")
    launch_parser.set_defaults(handler=launch)

    stop_parser = subparsers.add_parser("stop", help="Stop the background Codex websocket server.")
    stop_parser.set_defaults(handler=stop)

    status_parser = subparsers.add_parser("status", help="Print current launcher status.")
    status_parser.set_defaults(handler=status)

    pairing_parser = subparsers.add_parser("pairing", help="Print websocket and pairing-link details.")
    pairing_parser.set_defaults(handler=pairing)

    doctor_parser = subparsers.add_parser("doctor", help="Inspect the local runtime and config state.")
    doctor_parser.set_defaults(handler=doctor)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return int(args.handler(args))


if __name__ == "__main__":
    raise SystemExit(main())
