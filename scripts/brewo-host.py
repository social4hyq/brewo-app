#!/usr/bin/env python3
"""Run Brewo's fixed Homebrew operations in the terminal's configuration context."""

import argparse
import hmac
import json
import os
import re
import secrets
import signal
import subprocess
import tempfile
import threading
import time
from urllib.request import Request, ProxyHandler, build_opener
from urllib.error import URLError
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


PORT = 19877
BUNDLE = "com.social4hyq.brewo"
HARBOR_BUNDLE = "com.social4hyq.harbor"
SERVICE = "brewo-app"
HARBOR_TOKEN = "/data/storage/el2/base/haps/entry/files/brewo-host-token"
HARBOR_CONFIG_HOME = "/data/storage/el2/base/files/brewo-host"
READ_COMMANDS = (("info", "--installed", "--json=v2"), ("doctor", "--json"), ("config",))
PACKAGE = re.compile(r"[A-Za-z0-9][A-Za-z0-9+_.@-]*(?:/[A-Za-z0-9][A-Za-z0-9+_.@-]*){0,2}")
MAX_JOBS = 24
MAX_OUTPUT = 16 * 1024 * 1024
HOME = Path.home()
BREW = HOME / ".harmonybrew/bin/brew"


def command_type(arguments):
    if not isinstance(arguments, list) or not all(isinstance(arg, str) for arg in arguments):
        raise ValueError("Invalid Homebrew arguments")
    if tuple(arguments) in READ_COMMANDS:
        return "read"
    if len(arguments) == 3 and arguments[0] == "install" and arguments[1] in ("--formula", "--cask"):
        target = arguments[2]
        if (len(target) <= 256 and PACKAGE.fullmatch(target) and target.count("/") in (0, 2)
                and not target.lower().endswith((".rb", ".json"))
                and all(segment not in (".", "..") for segment in target.split("/"))):
            return "write"
    if arguments and arguments[0] in ("trust", "untrust"):
        if len(arguments) == 2 and valid_trust_target(arguments[1], 2):
            return "write"
        if len(arguments) == 3 and arguments[1] == "--formula" and valid_trust_target(arguments[2], 3):
            return "write"
    for prefix, kind in (
        (["upgrade", "--dry-run", "--formula"], "preview"),
        (["upgrade", "--formula"], "write"),
        (["uninstall", "--formula"], "write"),
    ):
        if arguments[:len(prefix)] == prefix:
            names = arguments[len(prefix):]
            if names and all(PACKAGE.fullmatch(name) for name in names):
                if prefix[0] != "uninstall" or len(names) == 1:
                    if kind == "write" and any(name.split("/")[-1] in ("brewo-app", "harbor-app") for name in names):
                        raise ValueError("Update or uninstall Brewo and Harbor from the Harmonybrew terminal")
                    return kind
    raise ValueError("Unsupported Homebrew operation")


def valid_trust_target(target, segments):
    return len(target) <= 256 and PACKAGE.fullmatch(target) and len(target.split("/")) == segments


def brew_environment():
    keys = ("USER", "LOGNAME", "TMPDIR", "HOMEBREW_TEMP", "XDG_CONFIG_HOME", "HOMEBREW_XDG_CONFIG_HOME")
    env = {key: os.environ[key] for key in keys if os.environ.get(key)}
    env.update(HOME=str(HOME), SHELL="/usr/bin/zsh", LANG="en_US.UTF-8", TERM="dumb",
               PATH=f"{BREW.parent}:{BREW.parent.parent}/sbin:/usr/bin:/bin:/usr/sbin:/sbin",
               HOMEBREW_NO_AUTO_UPDATE="1", HOMEBREW_NO_ANALYTICS="1", HOMEBREW_NO_COLOR="1")
    return env


def read_output(path, limit):
    with path.open("rb") as stream:
        length = path.stat().st_size
        if length > limit:
            stream.seek(length - limit)
        return stream.read(limit).decode("utf-8", errors="replace")


class Job:
    def __init__(self, arguments, kind):
        self.kind = kind
        self.cancelled = False
        self.lock = threading.Lock()
        self.directory = tempfile.TemporaryDirectory(prefix="brewo-job-")
        self.stdout = Path(self.directory.name) / "stdout"
        self.stderr = Path(self.directory.name) / "stderr"
        try:
            with self.stdout.open("wb") as out, self.stderr.open("wb") as err:
                # HarmonyOS shared storage presents new directories as owned by
                # File Manager. Brew needs group access to traverse bottle snapshots.
                self.process = subprocess.Popen([BREW, *arguments], cwd=HOME, env=brew_environment(),
                                                stdin=subprocess.DEVNULL, stdout=out,
                                                stderr=err if kind == "read" else subprocess.STDOUT,
                                                start_new_session=True, umask=0o022)
        except OSError:
            self.directory.cleanup()
            raise

    def status(self):
        with self.lock:
            code = self.process.poll()
            if self.kind == "read" and code is None:
                return {"exitCode": None, "output": "", "cancelled": False}
            limit = MAX_OUTPUT if self.kind == "read" else 64 * 1024
            if self.kind == "read" and self.stdout.stat().st_size > limit:
                return {"exitCode": 1, "output": "Read output exceeds 16 MiB", "cancelled": False}
            output = read_output(self.stdout, limit)
            # doctor can report findings with a nonzero status. JSON remains on stdout.
            if self.kind == "read" and not output:
                output = read_output(self.stderr, 64 * 1024)
            return {"exitCode": code, "output": output, "cancelled": self.cancelled}

    def cancel(self):
        with self.lock:
            if self.process.poll() is not None:
                return
            try:
                os.killpg(self.process.pid, signal.SIGTERM)
            except ProcessLookupError:
                return
            self.cancelled = True
            try:
                self.process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                pass
            # The leader can exit before its children. Signal the group again.
            try:
                os.killpg(self.process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            self.process.wait(timeout=2)


class Server(ThreadingHTTPServer):
    def __init__(self, token):
        super().__init__(("127.0.0.1", PORT), Handler)
        self.token = token
        self.jobs = {}
        self.jobs_lock = threading.Lock()

    def start(self, arguments):
        kind = command_type(arguments)
        with self.jobs_lock:
            if kind != "read" and any(job.kind != "read" and job.process.poll() is None
                                      for job in self.jobs.values()):
                raise ValueError("Another Homebrew operation is already running")
            if len(self.jobs) >= MAX_JOBS:
                for key, job in list(self.jobs.items()):
                    if job.process.poll() is not None:
                        del self.jobs[key]
                        break
                else:
                    raise ValueError("Too many running Homebrew jobs")
            job_id = secrets.token_hex(16)
            self.jobs[job_id] = Job(arguments, kind)
            return job_id


class Handler(BaseHTTPRequestHandler):
    def setup(self):
        self.request.settimeout(5)
        super().setup()

    def reply(self, code, data):
        payload = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def handle_request(self):
        header = self.headers.get("Authorization", "")
        if not hmac.compare_digest(header.encode(), f"Bearer {self.server.token}".encode()):
            self.reply(401, {"error": "Brewo host pairing token did not match"})
            return
        if self.command == "GET" and self.path == "/ready":
            self.reply(200, {"ready": True, "harbor": self.server.harbor})
            return
        if self.command == "POST" and self.path == "/jobs":
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= 64 * 1024:
                raise ValueError("Invalid request length")
            data = json.loads(self.rfile.read(length))
            if not isinstance(data, dict):
                raise ValueError("Invalid request body")
            self.reply(201, {"id": self.server.start(data.get("arguments"))})
            return
        match = re.fullmatch(r"/jobs/([0-9a-f]{32})", self.path)
        job = self.server.jobs.get(match[1]) if match else None
        if job is None:
            self.reply(404, {"error": "Unknown Homebrew job"})
        elif self.command in ("GET", "DELETE"):
            if self.command == "DELETE":
                job.cancel()
            self.reply(200, job.status())
        else:
            self.reply(405, {"error": "Unsupported request method"})

    def dispatch(self):
        try:
            self.handle_request()
        except ValueError as error:
            self.reply(400, {"error": str(error)})
        except (BrokenPipeError, ConnectionResetError, TimeoutError):
            return
        except (OSError, subprocess.TimeoutExpired):
            self.reply(500, {"error": "Could not run or stop Harmonybrew on the host"})

    do_GET = do_POST = do_DELETE = dispatch

    def log_message(self, *_):
        pass


def pairing_file():
    config = Path(os.environ.get("XDG_CONFIG_HOME") or os.environ.get("HOMEBREW_XDG_CONFIG_HOME")
                  or HOME / ".config")
    path = config / "brewo-host" / "token"
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    try:
        with path.open("x") as stream:
            stream.write(secrets.token_hex(32) + "\n")
    except FileExistsError:
        pass
    token = path.read_text().strip()
    if not re.fullmatch(r"[0-9a-f]{64}", token):
        raise ValueError("Invalid local Brewo pairing file")
    return path, token


def register_harbor_service(development_unit=None, launch_app=False):
    targets = subprocess.check_output(["hdc", "list", "targets"], text=True).splitlines()
    local = [target.strip() for target in targets if re.fullmatch(r"127\.0\.0\.1:\d+", target.strip())]
    if len(local) != 1:
        raise ValueError("registration requires one local HDC device")
    hdc = ["hdc", "-t", local[0]]
    harbor = HOME / ".harmonybrew/bin/harbor"
    if not harbor.is_file():
        raise ValueError("Harbor must be installed before registering Brewo")
    try:
        subprocess.run([harbor, "ping"], check=True, capture_output=True, timeout=3)
    except (subprocess.SubprocessError, OSError):
        subprocess.run([*hdc, "shell", "aa", "start", "-a", "EntryAbility", "-b", HARBOR_BUNDLE,
                        "-m", "entry"], check=True, timeout=10)
        for _ in range(12):
            time.sleep(0.4)
            if subprocess.run([harbor, "ping"], capture_output=True, timeout=3).returncode == 0:
                break
        else:
            raise ValueError("Harbor did not start")

    with tempfile.TemporaryDirectory(prefix="brewo-pair-") as scratch:
        token_file = Path(scratch) / "token"
        token_file.write_text(secrets.token_hex(32) + "\n")
        new_token = token_file.read_text().strip()
        # Reuse the service credential across application upgrades.
        previous = Path(scratch) / "previous"
        subprocess.run([*hdc, "file", "recv", "-b", HARBOR_BUNDLE, HARBOR_TOKEN, str(previous)],
                       check=False, capture_output=True, timeout=15)
        if previous.is_file() and re.fullmatch(r"[0-9a-f]{64}", previous.read_text().strip()):
            new_token = previous.read_text().strip()
            token_file.write_text(new_token + "\n")
        else:
            send_pairing(hdc, HARBOR_BUNDLE, HARBOR_TOKEN, token_file)
        send_pairing(hdc, BUNDLE, HARBOR_TOKEN, token_file)

    config_path = HOME / ".config/harbor/apps.json"
    config = json.loads(config_path.read_text())
    unit = development_unit or HOME / ".harmonybrew/opt/brewo-app/sh.brew.brewo-app.service"
    if not unit.is_file():
        raise ValueError(f"Homebrew service unit not found: {unit}")
    registered = next((app for app in config["apps"] if app["name"] == SERVICE), None)
    if registered is None and development_unit is None:
        subprocess.run([harbor, "discover", "--add", SERVICE], check=True, timeout=10)
    elif registered is None or registered.get("unit") != str(unit):
        if registered is None:
            registered = {"name": SERVICE, "pidfile": "/data/storage/el2/base/cache/harbor/brewo-app.pid"}
            config["apps"].append(registered)
        elif registered.get("type") != "unit" or not str(registered.get("unit", "")).endswith("sh.brew.brewo-app.service"):
            raise ValueError("Harbor already has a different service named brewo-app")
        registered.update(type="unit", unit=str(unit))
        with tempfile.NamedTemporaryFile(mode="w", dir=config_path.parent, delete=False) as output:
            pending = Path(output.name)
            json.dump(config, output, ensure_ascii=False, indent=2)
            output.write("\n")
        try:
            os.replace(pending, config_path)
        finally:
            pending.unlink(missing_ok=True)
    if registered is not None and registered.get("enabled") is False:
        raise ValueError("Harbor service brewo-app is disabled")
    subprocess.run([harbor, "reload"], check=True, timeout=10)
    subprocess.run([harbor, "start", SERVICE], check=True, timeout=10)
    opener = build_opener(ProxyHandler({}))
    ready = Request(f"http://127.0.0.1:{PORT}/ready", headers={"Authorization": f"Bearer {new_token}"})
    for _ in range(24):
        try:
            with opener.open(ready, timeout=1) as response:
                if json.load(response).get("harbor") is True:
                    print("Brewo paired with the Harbor service", flush=True)
                    if launch_app:
                        subprocess.run([*hdc, "shell", "aa", "start", "-a", "EntryAbility", "-b", BUNDLE,
                                        "-m", "entry"], check=True, timeout=10)
                    return
        except (URLError, TimeoutError):
            pass
        time.sleep(0.4)
    raise ValueError("The Harbor-managed Brewo service did not become ready")


def send_pairing(hdc, bundle, remote, token_file):
    sent = subprocess.check_output([*hdc, "file", "send", "-b", bundle, str(token_file), remote], text=True, timeout=15)
    if "FileTransfer finish" not in sent:
        raise ValueError(f"Could not pair {bundle}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pair", action="store_true", help="pair this host with the local debug HAP via HDC")
    parser.add_argument("--harbor", action="store_true", help="run under Harbor with its private configuration")
    parser.add_argument("--register-harbor", action="store_true", help="pair and register the Homebrew unit")
    parser.add_argument("--development-unit", type=Path, help="register a local development unit instead")
    parser.add_argument("--launch-app", action="store_true", help="open Brewo when Harbor is ready")
    args = parser.parse_args()
    os.umask(0o077)
    if args.register_harbor:
        register_harbor_service(args.development_unit, args.launch_app)
        return
    if args.harbor:
        os.environ["XDG_CONFIG_HOME"] = HARBOR_CONFIG_HOME
        token = Path(HARBOR_TOKEN).read_text().strip()
        if not re.fullmatch(r"[0-9a-f]{64}", token):
            parser.error("invalid Harbor pairing token")
    else:
        path, token = pairing_file()
    if args.pair:
        targets = subprocess.check_output(["hdc", "list", "targets"], text=True).splitlines()
        local = [target.strip() for target in targets if re.fullmatch(r"127\.0\.0\.1:\d+", target.strip())]
        if len(local) != 1:
            parser.error("pairing requires one local HDC device")
        remote = "/data/storage/el2/base/haps/entry/files/brewo-host-token"
        command = ["hdc", "-t", local[0], "file"]
        sent = subprocess.check_output([*command, "send", "-b", BUNDLE, str(path), remote], text=True)
        if "FileTransfer finish" not in sent:
            parser.error("could not pair the Brewo HAP")
        with tempfile.TemporaryDirectory(prefix="brewo-pair-") as scratch:
            copy = Path(scratch) / "token"
            subprocess.run([*command, "recv", "-b", BUNDLE, remote, str(copy)], check=True, stdout=subprocess.DEVNULL)
            if not copy.is_file() or not hmac.compare_digest(copy.read_bytes(), path.read_bytes()):
                parser.error("Brewo pairing could not be verified")
        print("Brewo paired with the local host", flush=True)
        return
    def terminate(*_):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, terminate)
    with Server(token) as server:
        server.harbor = args.harbor
        print(f"Brewo host listening on 127.0.0.1:{PORT}", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            for job in list(server.jobs.values()):
                job.cancel()


if __name__ == "__main__":
    main()
