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


class ProxyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.webhook = ThreadingHTTPServer(("127.0.0.1", 0), Webhook)
        threading.Thread(target=cls.webhook.serve_forever, daemon=True).start()
        cls.tmp = tempfile.TemporaryDirectory()
        options = os.path.join(cls.tmp.name, "options.json")
        with open(options, "w") as fh:
            json.dump({"webhook_id": WEBHOOK_ID, "log_level": "debug"}, fh)
        cls.port = free_port()
        env = dict(
            os.environ,
            OPTIONS_FILE=options,
            WEBHOOK_BASE=f"http://127.0.0.1:{cls.webhook.server_port}/api/webhook/",
            LISTEN_PORT=str(cls.port),
            SUPERVISOR_TOKEN=TOKEN,
        )
        cls.proc = subprocess.Popen([PROXY], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        for _ in range(50):
            try:
                socket.create_connection(("127.0.0.1", cls.port), timeout=0.2).close()
                break
            except OSError:
                time.sleep(0.1)
        else:
            cls.proc.kill()
            raise RuntimeError("proxy did not start: " + cls.proc.stdout.read().decode())

    @classmethod
    def tearDownClass(cls):
        cls.proc.terminate()
        cls.output = cls.proc.communicate(timeout=5)[0].decode()
        cls.webhook.shutdown()
        cls.webhook.server_close()
        cls.tmp.cleanup()
        # The webhook ID must never reach the log.
        assert WEBHOOK_ID not in cls.output, cls.output

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


if __name__ == "__main__":
    unittest.main(verbosity=2)
