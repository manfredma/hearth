"""Offline contract tests for the platform's immutable test inputs and receipts."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SHA = "a" * 40
DIGEST = "sha256:" + "b" * 64


class PlatformContextTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.release = self.root / "releases" / SHA
        self.source = self.release / "source"
        self.source.mkdir(parents=True)
        (self.source / ".release-platform-source-commit").write_text(SHA + "\n")
        self.manifest = self.release / "manifest"
        self.manifest.write_text(f"commit={SHA}\nartifact_digest={DIGEST}\n")
        self.history = self.root / "history"
        self.history.write_text(f"commit={SHA}\nartifact_digest={DIGEST}\n")
        self.env = dict(os.environ, RELEASE_PLATFORM_NATIVE_ROOT=str(self.root),
                        RELEASE_PLATFORM_TEST_SOURCE_ROOT=str(self.source),
                        RELEASE_PLATFORM_TEST_RELEASE_MANIFEST=str(self.manifest),
                        RELEASE_PLATFORM_TEST_DEPLOY_HISTORY=str(self.history),
                        RELEASE_PLATFORM_TEST_ARTIFACT_DIGEST=DIGEST,
                        RELEASE_PLATFORM_TASK_NONCE="test-attempt", RELEASE_PLATFORM_TEST_LOCK_HELD="1")

    def run_context(self, env=None, sha=SHA):
        return subprocess.run(["bash", "-c", 'source "$1"; hearth_platform_test_context --commit-sha "$2"',
                               "test", str(ROOT / "deploy/lib/platform-staging-context.sh"), sha],
                              env=env or self.env, text=True, capture_output=True)

    def test_accepts_current_snapshot_and_signed_attempt(self):
        result = self.run_context()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_missing_platform_inputs(self):
        for key in ("RELEASE_PLATFORM_TASK_NONCE", "RELEASE_PLATFORM_TEST_LOCK_HELD",
                    "RELEASE_PLATFORM_TEST_ARTIFACT_DIGEST", "RELEASE_PLATFORM_TEST_SOURCE_ROOT"):
            with self.subTest(key=key):
                env = dict(self.env)
                env.pop(key)
                self.assertNotEqual(self.run_context(env).returncode, 0)

    def test_rejects_stale_sha_and_digest(self):
        self.assertNotEqual(self.run_context(sha="c" * 40).returncode, 0)
        for path in (self.manifest, self.history):
            with self.subTest(path=path):
                original = path.read_text()
                path.write_text(original.replace(DIGEST, "sha256:" + "d" * 64))
                self.assertNotEqual(self.run_context().returncode, 0)
                path.write_text(original)
        (self.source / ".release-platform-source-commit").write_text("c" * 40)
        self.assertNotEqual(self.run_context().returncode, 0)


if __name__ == "__main__":
    unittest.main()
