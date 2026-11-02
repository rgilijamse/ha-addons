"""End-to-end test of the proxy against a stand-in webhook. Runs inside the built image:

    docker run --rm -v "$PWD/ecowitt-proxy/tests:/tests:ro" --entrypoint python3 IMAGE /tests/test_proxy.py
"""

import json
import os
import socket
import subprocess
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PROXY = "/usr/local/bin/ecowitt-proxy"
WEBHOOK_ID = "0123456789abcdef0123456789abcdef"
TOKEN = "test-supervisor-token"
# A trimmed real WS2900 upload.
SAMPLE = (
    "PASSKEY=ABCDEF0123456789&stationtype=EasyWeatherV1.6.4&dateutc=2026-11-02+10:49:40"
    "&tempinf=69.6&humidityin=55&baromrelin=30.442&baromabsin=30.454&tempf=50.2&humidity=88"
    "&winddir=226&windspeedmph=0.7&dailyrainin=0.059&solarradiation=41.82&uv=0&model=WS2900_V2.02.03"
).encode()


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class Webhook(BaseHTTPRequestHandler):
    received = []
    status = 200

    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        Webhook.received.append((self.path, dict(self.headers), body))
        self.send_response(Webhook.status)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, *args):
        pass


class Proxy:
    """Runs the proxy against a stand-in webhook and collects its log as it goes."""

    def __init__(self, webhook_port, log_level="debug", **env):
        self.tmp = tempfile.TemporaryDirectory()
        options = os.path.join(self.tmp.name, "options.json")
        with open(options, "w") as fh:
            json.dump({"webhook_id": WEBHOOK_ID, "log_level": log_level}, fh)
        self.port = free_port()
        self.lines = []
        full_env = dict(
            os.environ,
            OPTIONS_FILE=options,
            WEBHOOK_BASE=f"http://127.0.0.1:{webhook_port}/api/webhook/",
            LISTEN_PORT=str(self.port),
            SUPERVISOR_TOKEN=TOKEN,
            **env,
        )
        self.proc = subprocess.Popen([PROXY], env=full_env, stdout=subprocess.PIPE,
                                     stderr=subprocess.STDOUT, text=True)
        self.reader = threading.Thread(target=self._read, daemon=True)
        self.reader.start()
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline and self.proc.poll() is None:
            try:
                socket.create_connection(("127.0.0.1", self.port), timeout=0.2).close()
                return
            except OSError:
                time.sleep(0.1)
        code = self.proc.poll()
        self.proc.kill()
        self.proc.wait()
        self.reader.join(timeout=5)
        self.proc.stdout.close()
        self.tmp.cleanup()
        raise RuntimeError(f"proxy did not start (exit code {code}):\n{self.output}")

    def _read(self):
        for line in self.proc.stdout:
            self.lines.append(line.rstrip("\n"))

    @property
    def output(self):
        return "\n".join(self.lines)

    def wait_for(self, text, timeout=10):
        """The first log line containing text, waiting up to timeout seconds for it."""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            for line in list(self.lines):
                if text in line:
                    return line
            time.sleep(0.05)
        raise AssertionError(f"no log line with {text!r} in:\n{self.output}")

    def stop(self):
        self.proc.terminate()
        self.proc.wait(timeout=5)
        self.reader.join(timeout=5)
        self.proc.stdout.close()
        self.tmp.cleanup()
        # The webhook ID must never reach the log.
        assert WEBHOOK_ID not in self.output, self.output


def post(port, body=SAMPLE):
    req = urllib.request.Request(f"http://127.0.0.1:{port}/log/ha", data=body, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.status
    except urllib.error.HTTPError as err:
        with err:
            return err.code


class WebhookTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.webhook = ThreadingHTTPServer(("127.0.0.1", 0), Webhook)
        threading.Thread(target=cls.webhook.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.webhook.shutdown()
        cls.webhook.server_close()


class ProxyTest(WebhookTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.proxy = Proxy(cls.webhook.server_port)
        cls.port = cls.proxy.port
        cls.proc = cls.proxy.proc

    @classmethod
    def tearDownClass(cls):
        cls.proxy.stop()
        super().tearDownClass()

    def setUp(self):
        Webhook.received.clear()
        Webhook.status = 200

    def request(self, method, path, body=None, headers=None):
        req = urllib.request.Request(f"http://127.0.0.1:{self.port}{path}", data=body, method=method)
        for key, value in (headers or {}).items():
            req.add_header(key, value)
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                return resp.status, resp.read().decode()
        except urllib.error.HTTPError as err:
            with err:
                return err.code, err.read().decode()

    def test_forwards_upload_unchanged(self):
        status, _ = self.request("POST", "/log/ha", SAMPLE,
                                 {"Content-Type": "application/x-www-form-urlencoded"})
        self.assertEqual(status, 200)
        self.assertEqual(len(Webhook.received), 1)
        path, headers, body = Webhook.received[0]
        self.assertEqual(path, f"/api/webhook/{WEBHOOK_ID}")
        self.assertEqual(body, SAMPLE)
        self.assertEqual(headers["Authorization"], f"Bearer {TOKEN}")
        self.assertEqual(headers["Content-Type"], "application/x-www-form-urlencoded")

    def test_home_assistant_error_is_502(self):
        Webhook.status = 500
        status, _ = self.request("POST", "/log/ha", SAMPLE)
        self.assertEqual(status, 502)

    def test_root_answers(self):
        self.assertEqual(self.request("GET", "/")[0], 200)

    def test_get_upload_path_is_405(self):
        self.assertEqual(self.request("GET", "/log/ha")[0], 405)

    def test_other_paths_are_404_and_not_forwarded(self):
        self.assertEqual(self.request("POST", "/api/webhook/x", SAMPLE)[0], 404)
        self.assertEqual(Webhook.received, [])

    def test_oversized_upload_is_refused(self):
        self.assertEqual(self.request("POST", "/log/ha", b"x" * (64 * 1024 + 1))[0], 413)
        self.assertEqual(Webhook.received, [])

    def test_runs_as_nobody(self):
        with open(f"/proc/{self.proc.pid}/status") as fh:
            uid_line = next(line for line in fh if line.startswith("Uid:"))
        self.assertEqual(uid_line.split()[1:], ["65534"] * 4)



class LogTest(WebhookTestCase):
    """What an operator sees at INFO: first upload, failing/working changes, summaries, and the
    station going quiet. Timings are shortened through the test-only environment variables."""

    def setUp(self):
        Webhook.received.clear()
        Webhook.status = 200

    def start(self, **env):
        proxy = Proxy(self.webhook.server_port, log_level="info", CHECK_INTERVAL="0.1", **env)
        self.addCleanup(proxy.stop)
        return proxy

    def test_first_upload_failures_recovery_and_summary(self):
        proxy = self.start(SUMMARY_INTERVAL="3", STALE_AFTER_SECONDS="0")
        self.assertEqual(post(proxy.port), 200)
        proxy.wait_for("First upload since start, from 127.0.0.1: forwarded to Home Assistant")
        self.assertEqual(post(proxy.port), 200)
        Webhook.status = 401
        self.assertEqual(post(proxy.port), 502)
        self.assertEqual(post(proxy.port), 502)
        proxy.wait_for("ERROR   Forwarding is failing: Home Assistant answered HTTP 401")
        Webhook.status = 200
        self.assertEqual(post(proxy.port), 200)
        proxy.wait_for("Forwarding to Home Assistant works again")
        proxy.wait_for("Last 3 seconds: 5 uploads from 127.0.0.1, 3 forwarded, 2 not")
        proxy.wait_for("Last 3 seconds: no uploads")
        # One failure line for two failed uploads; no line per upload at INFO.
        self.assertEqual(proxy.output.count("Forwarding is failing"), 1, proxy.output)
        self.assertNotIn("Warning when no upload", proxy.output)  # 0 turns the warning off

    def test_first_upload_refused(self):
        Webhook.status = 500
        proxy = self.start()
        self.assertEqual(post(proxy.port), 502)
        proxy.wait_for("ERROR   First upload since start, from 127.0.0.1: not forwarded "
                       "(Home Assistant answered HTTP 500)")

    def test_no_upload_since_start(self):
        proxy = self.start(STALE_AFTER_SECONDS="1")
        proxy.wait_for("WARNING No upload in the 1 second since start; check the station's "
                       "customized upload settings")
        self.assertEqual(post(proxy.port), 200)
        proxy.wait_for("Uploads resumed after")
        proxy.wait_for("First upload since start")

    def test_station_goes_quiet_and_comes_back(self):
        proxy = self.start(STALE_AFTER_SECONDS="1")
        self.assertEqual(post(proxy.port), 200)
        proxy.wait_for("WARNING No upload for 1 second; check the station")
        self.assertEqual(post(proxy.port), 200)
        proxy.wait_for("INFO    Uploads resumed after 1 second")
        # Warned once per quiet spell, not on every check.
        time.sleep(0.5)
        self.assertEqual(proxy.output.count("No upload for"), 1, proxy.output)


if __name__ == "__main__":
    unittest.main(verbosity=2)
