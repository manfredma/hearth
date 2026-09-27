"""Run the real local entrypoint with deterministic, process-free tool fixtures."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class LocalQualityTest(unittest.TestCase):
    def run_runner(self, diagnostic="", fail_capture=False, fail_command=False):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "scripts/lib").mkdir(parents=True)
            (root / "deploy/lib").mkdir(parents=True)
            for source in (ROOT / "scripts/lib").glob("*.sh"):
                shutil.copy(source, root / "scripts/lib")
            for source in (ROOT / "deploy/lib").glob("*.sh"):
                shutil.copy(source, root / "deploy/lib")
            shutil.copy(ROOT / "scripts/run-local-quality.sh", root / "scripts")
            (root / "scripts/lib/java-25.sh").write_text('resolve_java_25() { printf /fake/java; }\n')
            for name in ["check-release-readiness", "verify-changed-coverage", "check-staging-checklist"]:
                (root / f"scripts/{name}.sh").write_text("exit 0\n")
            binary = root / "bin"
            binary.mkdir()
            stub = '#!/bin/bash\nif [[ "$1" == test ]]; then printf "%s\\n" "$DIAGNOSTIC"; exit "$COMMAND_STATUS"; fi\nexit 0\n'
            for path in [binary / "npm", binary / "git", root / "mvnw"]:
                path.write_text(stub)
                path.chmod(0o755)
            if fail_capture:
                (binary / "tee").write_text('#!/bin/bash\ncat >/dev/null\nexit 1\n')
                (binary / "tee").chmod(0o755)
            return subprocess.run(["bash", str(root / "scripts/run-local-quality.sh")],
                                  env={**os.environ, "PATH": f"{binary}:{os.environ['PATH']}",
                                       "DIAGNOSTIC": diagnostic, "COMMAND_STATUS": "1" if fail_command else "0"},
                                  capture_output=True, text=True).returncode

    def test_clean_commands_pass(self):
        self.assertEqual(self.run_runner(), 0)

    def test_zero_exit_diagnostics_fail(self):
        for diagnostic in ["[WARNING] build", "WARN framework", "npm warn deprecated", "warning: compiler"]:
            with self.subTest(diagnostic=diagnostic):
                self.assertNotEqual(self.run_runner(diagnostic), 0)

    def test_log_capture_failure_fails(self):
        self.assertNotEqual(self.run_runner(fail_capture=True), 0)

    def test_command_failure_fails(self):
        self.assertNotEqual(self.run_runner(fail_command=True), 0)


if __name__ == "__main__":
    unittest.main()
