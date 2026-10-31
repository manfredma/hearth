#!/usr/bin/env python3
"""Read-only preflight for existing native release slots; run via Host Agent."""
import argparse
from pathlib import Path
import re
import sys


def check(root):
    root = root.absolute()
    try:
        if root.resolve(strict=True) != root or not root.is_dir():
            raise ValueError("runtime root must be a canonical directory")
        releases = root / "releases"
        if releases.is_symlink() or not releases.is_dir():
            raise ValueError("releases must be a real directory")
        for name in ("current", "rollback"):
            link = root / name
            if not link.is_symlink():
                if name == "current" or link.exists():
                    raise ValueError(name + " must be a release symlink")
                continue
            declared = link.readlink()
            if not declared.is_absolute():
                declared = root / declared
            target = link.resolve(strict=True)
            if (declared.absolute() != target or target.parent != releases
                    or not re.fullmatch(r"[0-9a-f]{40}", target.name)
                    or not target.is_dir()):
                raise ValueError(name + " must point directly to a canonical SHA release")
    except (OSError, RuntimeError) as error:
        raise ValueError("release slot is missing, inaccessible or cyclic") from error


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    try:
        check(args.root)
    except ValueError as error:
        print("Release slot preflight failed: " + str(error), file=sys.stderr)
        return 1
    print("Release slot preflight passed; no files changed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
