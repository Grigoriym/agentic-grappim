#!/usr/bin/env python3
"""Rank packages in a Kover XML report by missed branches, with the project's own exclude
rules re-applied.

Why this exists: a report's class universe is whatever compiler output happens to exist on disk
(Kover's report task ends its file collection in `.existing()`), and root aggregation in a
multi-module (especially KMP) build includes every module's *total* variant, which includes the
Android library target where one exists. So an Android build or a KSP/annotation-processor
re-run leaves classes behind that a later `koverXmlReport` counts, and the total class count can
vary run to run on the same source. Re-applying the project's own exclusion rules here makes a
ranking usable whichever compilations happened to have run.

This is *not* about Kover failing to apply its own `excludes` — it applies them faithfully. What
varies between runs is the denominator (which classes exist on disk), not the filtering logic.

Usage:
    ./gradlew koverXmlReport
    python3 kover-rank.py build/reports/kover/report.xml --excludes-file kover-excludes.txt

`--excludes-file` points at a small project-local text file mirroring the root `build.gradle.kts`
Kover `excludes {}` block — see `kover-excludes.txt.example` next to this script for the format
and the SKILL.md's Step 1 for why this lives in a data file instead of being parsed out of the
Gradle script directly (real-world `excludes {}` blocks generate their suffix list through a
local helper function rather than a flat list of string literals, which defeats simple parsing).
Keep the file in sync with `excludes {}` by hand — copy it over whenever that block changes.
"""

import argparse
import collections
import xml.etree.ElementTree as ET


def load_excludes(path: str) -> tuple[list[str], list[str]]:
    """Returns (class_suffixes, package_prefixes) from a simple text file: one pattern per
    line, `#` starts a comment, a `package:` prefix marks a package-prefix pattern, everything
    else is a class-suffix pattern (Kover's `**.*Foo` written as just `Foo`)."""
    class_suffixes, packages = [], []
    with open(path) as f:
        for line in f:
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            if line.startswith("package:"):
                packages.append(line[len("package:"):])
            else:
                class_suffixes.append(line)
    return class_suffixes, packages


def is_excluded(package: str, class_name: str, class_suffixes: list[str], packages: list[str]) -> bool:
    # Kover turns `packages("a.b")` into the class pattern `a.b.*`, and its `*` matches dots too
    # (`#` is its non-dot wildcard) — so a listed package covers all of its subpackages. Match by
    # prefix, not equality: equality-matching here has previously let subpackages slip through a
    # ranking that the real gate excludes.
    if any(package == p or package.startswith(p + ".") for p in packages):
        return True
    # Kover's suffix match is on the outer class, so strip the `Foo$Bar` nesting first.
    base = class_name.split("/")[-1].split("$")[0]
    return any(base.endswith(s) or base.endswith(s + "Kt") for s in class_suffixes)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("report", nargs="?", default="build/reports/kover/report.xml")
    ap.add_argument("--excludes-file", required=True)
    ap.add_argument("--top", type=int, default=25)
    args = ap.parse_args()

    class_suffixes, packages = load_excludes(args.excludes_file)

    root = ET.parse(args.report).getroot()
    rows = collections.defaultdict(lambda: [0, 0, 0, 0])  # branch cov/total, line cov/total
    kept = 0
    for package in root.findall("package"):
        name = package.get("name").replace("/", ".")
        for clazz in package.findall("class"):
            if is_excluded(name, clazz.get("name"), class_suffixes, packages):
                continue
            kept += 1
            row = rows[name]
            for counter in clazz.findall("counter"):
                covered = int(counter.get("covered"))
                total = covered + int(counter.get("missed"))
                if counter.get("type") == "BRANCH":
                    row[0] += covered
                    row[1] += total
                elif counter.get("type") == "LINE":
                    row[2] += covered
                    row[3] += total

    branch = (sum(r[0] for r in rows.values()), sum(r[1] for r in rows.values()))
    line = (sum(r[2] for r in rows.values()), sum(r[3] for r in rows.values()))
    print(f"classes kept: {kept}  (raw report had {len(root.findall('.//class'))})")
    print(f"BRANCH {branch[0]}/{branch[1]} {100 * branch[0] / branch[1]:.2f}%   "
          f"LINE {line[0]}/{line[1]} {100 * line[0] / line[1]:.2f}%\n")
    print(f"{'package':66} {'missedB':>8} {'branch':>13} {'line':>13}")
    for name, r in sorted(rows.items(), key=lambda kv: -(kv[1][1] - kv[1][0]))[:args.top]:
        print(f"{name:66} {r[1] - r[0]:8} {r[0]:5}/{r[1]:<7} {r[2]:5}/{r[3]:<7}")


if __name__ == "__main__":
    main()
