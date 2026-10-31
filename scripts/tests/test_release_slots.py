import importlib.util
from pathlib import Path
import tempfile
import unittest


class ReleaseSlotTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location(
            "release_slots", Path(__file__).parents[1] / "check-release-slots.py"
        )
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()
        self.release = self.root / "releases" / ("a" * 40)
        self.release.mkdir(parents=True)
        (self.root / "current").symlink_to(self.release)

    def test_current_and_optional_rollback(self):
        self.module.check(self.root)
        (self.root / "rollback").symlink_to(self.release)
        self.module.check(self.root)

    def test_legacy_tag_rollback_is_rejected_without_mutation(self):
        legacy = self.root / "releases" / "v0.1.2"
        legacy.mkdir()
        link = self.root / "rollback"
        link.symlink_to(legacy)
        with self.assertRaisesRegex(ValueError, "rollback"):
            self.module.check(self.root)
        self.assertEqual(link.readlink(), legacy)

    def test_external_and_indirect_slots_are_rejected(self):
        for target in [self.root, self.root / "current"]:
            with self.subTest(target=target):
                link = self.root / "rollback"
                link.symlink_to(target)
                with self.assertRaises(ValueError):
                    self.module.check(self.root)
                link.unlink()

    def test_missing_current_and_dangling_rollback_are_rejected(self):
        (self.root / "rollback").symlink_to(self.root / "missing")
        with self.assertRaises(ValueError):
            self.module.check(self.root)
        (self.root / "rollback").unlink()
        (self.root / "current").unlink()
        with self.assertRaises(ValueError):
            self.module.check(self.root)


if __name__ == "__main__":
    unittest.main()
