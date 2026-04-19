from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock
import subprocess

import desktop.codex_remote_desktop as launcher


class CodexRemoteDesktopTests(unittest.TestCase):
    def test_build_pairing_url_includes_token_and_url(self) -> None:
        pairing_url = launcher.build_pairing_url("ws://192.168.1.10:8765", "abc123")
        self.assertIn("codexremote://pair?", pairing_url)
        self.assertIn("token=abc123", pairing_url)
        self.assertIn("url=ws%3A%2F%2F192.168.1.10%3A8765", pairing_url)

    def test_build_websocket_url_prefers_public_override(self) -> None:
        actual = launcher.build_websocket_url("0.0.0.0", 8765, "wss://remote.example/ws")
        self.assertEqual(actual, "wss://remote.example/ws")

    @mock.patch("desktop.codex_remote_desktop.detect_lan_ip", return_value="10.0.0.12")
    def test_build_websocket_url_uses_lan_ip_for_wildcard_host(self, _mock_ip: mock.Mock) -> None:
        actual = launcher.build_websocket_url("0.0.0.0", 8765, "")
        self.assertEqual(actual, "ws://10.0.0.12:8765")

    def test_default_config_has_expected_port(self) -> None:
        config = launcher.default_config()
        self.assertEqual(config["listen_port"], launcher.DEFAULT_PORT)

    @mock.patch("desktop.codex_remote_desktop.Path.exists", return_value=True)
    @mock.patch("desktop.codex_remote_desktop.subprocess.run")
    def test_appx_install_resources_uses_get_appxpackage(self, mock_run: mock.Mock, _mock_exists: mock.Mock) -> None:
        mock_run.return_value = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout="C:\\Program Files\\WindowsApps\\OpenAI.Codex_26\\app\\resources\r\n",
            stderr="",
        )
        resources = launcher.appx_install_resources("OpenAI.Codex")
        self.assertEqual(
            resources,
            Path(r"C:\Program Files\WindowsApps\OpenAI.Codex_26\app\resources"),
        )

    def test_write_status_emits_pairing_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            with mock.patch.object(launcher, "STATE_ROOT", root), mock.patch.object(
                launcher, "STATUS_FILE", root / "status.json"
            ), mock.patch.object(launcher, "PAIRING_FILE", root / "pairing.json"), mock.patch.object(
                launcher, "RUNTIME_ROOT", root / "runtime"
            ):
                payload = {
                    "websocket_url": "ws://127.0.0.1:8765",
                    "token": "secret-token",
                    "pairing_url": "codexremote://pair?url=ws%3A%2F%2F127.0.0.1%3A8765&token=secret-token",
                }
                launcher.write_status(payload)
                pairing = json.loads((root / "pairing.json").read_text(encoding="utf-8"))
                self.assertEqual(pairing["token"], "secret-token")
                self.assertEqual(pairing["websocket_url"], "ws://127.0.0.1:8765")


if __name__ == "__main__":
    unittest.main()
