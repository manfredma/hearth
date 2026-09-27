"""Fail closed on missing measurements or missed changed-class code."""
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET


def check(root, report, sources):
    try:
        tree = ET.parse(report)
    except (OSError, ET.ParseError) as error:
        return [f"Coverage report unavailable: {error}"]
    errors = []
    for source in sorted(set(sources)):
        if not re.match(r"hearth-[^/]+/src/main/java/.*\.java$", source):
            continue
        path = root / source
        relative = source.split("/src/main/java/", 1)[1]
        package, filename = relative.rsplit("/", 1)
        text = path.read_text()
        abstract_only = (re.search(r"public interface\s", text)
                         and text.count("{") == 1 and not re.search(r"\b(default|static)\b", text))
        if filename == "package-info.java" or abstract_only:
            continue
        classes = tree.findall(f".//package[@name='{package}']/class[@sourcefilename='{filename}']")
        if not classes:
            errors.append(f"{source}: no class measurement")
        for cls in classes:
            counters = {counter.get("type"): counter for counter in cls.findall("counter")}
            if not {"LINE", "METHOD"}.issubset(counters):
                errors.append(f"{cls.get('name')}: incomplete measurement")
            for kind in ("LINE", "BRANCH", "METHOD"):
                if kind in counters and int(counters[kind].get("missed")) != 0:
                    errors.append(f"{cls.get('name')}: {kind} missed={counters[kind].get('missed')}")
    return errors


def main():
    root = Path(__file__).resolve().parent.parent
    base = subprocess.check_output(["git", "merge-base", "origin/main", "HEAD"], cwd=root, text=True).strip()
    changed = subprocess.check_output(["git", "diff", "--name-only", "--diff-filter=ACMR", base], cwd=root, text=True).splitlines()
    changed += subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard"], cwd=root, text=True).splitlines()
    sources = [source for source in changed if re.match(r"hearth-[^/]+/src/main/java/.*\.java$", source)]
    errors = []
    for module in sorted({source.split('/')[0] for source in sources}):
        errors += check(root, root / module / "target/site/jacoco/jacoco.xml",
                        [source for source in sources if source.startswith(module + '/')])
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("Changed Java classes: 100% lines, branches and methods.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
