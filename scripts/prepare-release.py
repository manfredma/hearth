#!/usr/bin/env python3
"""Prepare the local changelog for a canonical release-platform candidate."""
import argparse
from datetime import datetime
from pathlib import Path
import re
from zoneinfo import ZoneInfo


def prepare(path, version):
    version = version.removeprefix("v")
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        raise ValueError("version must be a release SemVer")
    content = path.read_text()
    matches = list(re.finditer(r"(?m)^## Unreleased$", content))
    if len(matches) != 1:
        raise ValueError("expected exactly one Unreleased section")
    start = matches[0].end()
    following = re.search(r"(?m)^## ", content[start:])
    end = start + following.start() if following else len(content)
    body = content[start:end].strip()
    if re.search(r"(?m)^## \[v?" + re.escape(version) + r"\] - ", content):
        raise ValueError("release section already exists")
    category = False
    entries = 0
    for line in body.splitlines():
        if line.startswith("### "):
            category = line in {"### " + value for value in
                               ("Added", "Changed", "Deprecated", "Removed", "Fixed", "Security")}
        elif re.match(r"^[*-]\s+\S", line):
            if not category:
                raise ValueError("release entries must use a supported category")
            entries += 1
    if not entries:
        raise ValueError("Unreleased must contain categorized changes")
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date().isoformat()
    path.write_text(content[:start] + f"\n\n## [{version}] - {today}\n\n" + body + "\n\n" + content[end:])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()
    try:
        prepare(Path("docs/releases/CHANGELOG.md"), args.version)
    except ValueError as error:
        parser.exit(1, str(error) + "\n")
