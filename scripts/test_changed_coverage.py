import importlib.util
from pathlib import Path
import tempfile
import unittest


class ChangedCoverageTest(unittest.TestCase):
    def check(self, counters, report=True):
        spec = importlib.util.spec_from_file_location("coverage_gate", Path(__file__).with_name("check_changed_coverage.py"))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = "hearth-adapter/src/main/java/sample/Changed.java"
            path = root / source
            path.parent.mkdir(parents=True)
            path.write_text("package sample; public class Changed {}")
            xml = root / "report.xml"
            if report:
                xml.write_text('<report><package name="sample"><class name="sample/Changed" sourcefilename="Changed.java">'
                               + ''.join(f'<counter type="{kind}" missed="{missed}" covered="1"/>' for kind, missed in counters.items())
                               + '</class></package></report>')
            return module.check(root, xml, [source])

    def test_full_coverage_passes(self):
        self.assertEqual(self.check({"LINE": 0, "BRANCH": 0, "METHOD": 0}), [])

    def test_each_missed_counter_fails(self):
        for kind in ["LINE", "BRANCH", "METHOD"]:
            with self.subTest(kind=kind):
                self.assertTrue(self.check({"LINE": 0, "BRANCH": 0, "METHOD": 0, kind: 1}))

    def test_absent_report_or_unmeasured_class_fails(self):
        self.assertTrue(self.check({}, report=False))
        self.assertTrue(self.check({}))


if __name__ == "__main__":
    unittest.main()
