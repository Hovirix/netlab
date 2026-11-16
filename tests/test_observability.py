import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ObservabilityTest(unittest.TestCase):
    def test_router_collector(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            overlay = directory / "files"
            env = dict(os.environ, BUILD_DIR=str(directory), OVERLAY_DIR=str(overlay))
            subprocess.run(
                [str(ROOT / "scripts/render.sh")],
                input=(ROOT / "tests/fixtures/secrets.yaml").read_bytes(),
                cwd=ROOT,
                env=env,
                check=True,
            )
            subprocess.run([str(ROOT / "scripts/validate.sh")], env=env, check=True)
            (directory / "nl80211.uc").write_text(
                "let constants = { NL80211_CMD_GET_INTERFACE: 5 };\n"
                "function request(cmd, flags, payload) { return global.runtime[payload.dev]; }\n"
                "export { request, constants as 'const' };\n"
            )
            subprocess.run(
                [
                    "ucode",
                    "-L",
                    str(directory),
                    str(ROOT / "tests/fixtures/router.uc"),
                    str(overlay / "usr/share/ucode/node-exporter/lib/router.uc"),
                ],
                check=True,
            )

            # Exercise the first-boot edit against the upstream jail mount anchor.
            init = directory / "exporter"
            init.write_text(
                'start_service() {\n\tprocd_add_jail_mount "/etc/config"\n}\n'
            )
            script = (overlay / "etc/uci-defaults/98-observability").read_text()
            setup = script.split("# Merge logging settings", 1)[0].replace(
                "exporter=/etc/init.d/prometheus-node-exporter-ucode",
                f"exporter={json.dumps(str(init))}",
            )
            for _ in range(2):
                subprocess.run(["sh", "-e"], input=setup, text=True, check=True)
            self.assertEqual(
                init.read_text().count("procd_add_jail_mount /tmp/dhcp.leases"), 1
            )
            subprocess.run(["sh", "-n", str(init)], check=True)
            init.write_text("# incompatible upstream init\n")
            self.assertNotEqual(
                subprocess.run(["sh", "-e"], input=setup, text=True).returncode, 0
            )
