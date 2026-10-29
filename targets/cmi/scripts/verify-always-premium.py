#!/usr/bin/env python3
"""
Static verification of the ALWAYS_PREMIUM (Pro) build of Cryptomator for iOS.

There is no Swift/Xcode toolchain on this machine, so instead of compiling we
verify the two things that decide what the built app contains:

  1. the PBXProject level build configuration (which cascades to every app /
     extension target) carries SWIFT_ACTIVE_COMPILATION_CONDITIONS with
     ALWAYS_PREMIUM in both Debug and Release, and no target overrides it;
  2. for every `#if ALWAYS_PREMIUM` / `#if !ALWAYS_PREMIUM` region, the branch
     the Pro build keeps is well formed (balanced braces) and is the premium one.

SwiftPM note: CryptomatorCommon is a local package, whose targets are compiled
with their own settings; the app targets therefore define
`FullVersionCheckerKey.liveValue` themselves (see AppDelegate.swift).  Package
files are reported separately: both of their branches must be self-consistent,
which is what upstream CI relies on as well.

Usage: python3 Scripts/verify-always-premium.py [project-root]
Exit code 0 = all checks passed.
"""

import os
import re
import sys

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), ".."))
PBXPROJ = os.path.join(ROOT, "Cryptomator.xcodeproj", "project.pbxproj")
PROJECT_CONFIG_LIST = "4A5E5B242453119100BD6298"
SPM_ROOT = os.path.join(ROOT, "CryptomatorCommon")

DIRECTIVE = re.compile(r"^\s*#(if|elseif|else|endif)\b(.*)$")
SKIP_DIRS = {".git", "build", ".build", "DerivedData", "fastlane", "Scripts"}


def swift_files():
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            if name.endswith(".swift"):
                yield os.path.join(base, name)


def regions(path):
    """Return (condition, first_line, active_branch_or_None, lines) per ALWAYS_PREMIUM region."""
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()

    stack, found = [], []
    for idx, line in enumerate(lines, 1):
        m = DIRECTIVE.match(line)
        if not m:
            continue
        kind, rest = m.group(1), m.group(2).strip()
        if kind == "if":
            stack.append({"start": idx, "cond": rest, "branch_cond": rest, "branch_start": idx + 1, "branches": []})
        elif kind == "elseif" and stack:
            top = stack[-1]
            top["branches"].append((top["branch_cond"], top["branch_start"], idx - 1))
            top["branch_cond"], top["branch_start"] = rest, idx + 1
        elif kind == "else" and stack:
            top = stack[-1]
            top["branches"].append((top["branch_cond"], top["branch_start"], idx - 1))
            top["branch_cond"], top["branch_start"] = None, idx + 1  # plain #else
        elif kind == "endif" and stack:
            top = stack.pop()
            top["branches"].append((top["branch_cond"], top["branch_start"], idx - 1))
            if any(b[0] and "ALWAYS_PREMIUM" in b[0] for b in top["branches"]):
                found.append(top)

    if stack:
        raise SystemExit("unbalanced #if in %s (missing #endif)" % path)

    for top in found:
        active = None
        for cond, start, end in top["branches"]:
            normalized = (cond or "").replace(" ", "")
            if normalized == "ALWAYS_PREMIUM":
                active = (cond, start, end)
                break
            if normalized == "":
                # plain #else of an ALWAYS_PREMIUM / !ALWAYS_PREMIUM test
                first = (top["branches"][0][0] or "").replace(" ", "")
                if first in ("ALWAYS_PREMIUM", "!ALWAYS_PREMIUM"):
                    active = (cond, start, end)
                    break
        yield top, active, lines


def balanced(text):
    depth = 0
    for ch in text:
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth < 0:
                return False
    return depth == 0


def check_pbxproj():
    with open(PBXPROJ, encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(PROJECT_CONFIG_LIST + r' /\* Build configuration list for PBXProject "Cryptomator" \*/ = \{.*?buildConfigurations = \((.*?)\);', text, re.S)
    project_config_ids = re.findall(r"([0-9A-F]{24})", m.group(1))
    print("project-level configuration objects: %s" % ", ".join(project_config_ids))

    blocks = re.findall(
        r"\t\t([0-9A-F]{24}) /\* (Debug|Release) \*/ = \{\n\t\t\tisa = XCBuildConfiguration;(.*?)\n\t\t\tname = (Debug|Release);\n\t\t\};",
        text, re.S)

    ok = True
    for ident, cfg, body, _ in blocks:
        if ident not in project_config_ids:
            continue
        has = "ALWAYS_PREMIUM" in body and "SWIFT_ACTIVE_COMPILATION_CONDITIONS" in body
        value = re.search(r"SWIFT_ACTIVE_COMPILATION_CONDITIONS = (.*);", body)
        print("  %-7s %s : %s" % (cfg, ident, (value.group(1) if value else "MISSING")))
        ok = ok and has

    covered = len([b for b in blocks if b[0] in project_config_ids]) == len(project_config_ids)
    print("  cascade covers every target (project level, no overrides): %s" % covered)
    overrides = [b for b in blocks if b[0] not in project_config_ids and "SWIFT_ACTIVE_COMPILATION_CONDITIONS" in b[2]]
    if overrides:
        print("  !! target-level overrides: %s" % [b[0] for b in overrides])
    return ok and covered and not overrides


def main():
    print("== 1. build settings ==")
    ok = check_pbxproj()

    print("\n== 2. conditional compilation: branch kept by the Pro build ==")
    count, bad = 0, 0
    for path in sorted(swift_files()):
        rel = os.path.relpath(path, ROOT)
        for top, active, lines in regions(path):
            count += 1
            if active is None:
                first = (top["branches"][0][0] or "").replace(" ", "")
                if first == "!ALWAYS_PREMIUM":
                    print("  %-58s compiled out" % ("%s:%d" % (rel, top["start"])))
                    continue
                print("  !! %s:%d unresolved condition %r" % (rel, top["start"], top["branches"][0][0]))
                bad += 1
                continue
            _, start, end = active
            body = "\n".join(lines[start - 1:end])
            good = balanced(body)
            bad += 0 if good else 1
            pkg = " [SwiftPM]" if os.path.commonpath([os.path.abspath(path), SPM_ROOT]) == SPM_ROOT else ""
            print("  %-58s %-22s %s%s" % ("%s:%d" % (rel, top["start"]),
                                          "premium branch" if body.strip() else "empty branch",
                                          "ok" if good else "UNBALANCED", pkg))
            for line in [l.strip() for l in body.strip().splitlines() if l.strip()][:2]:
                print("      | %s" % line[:96])

    print("\n%d ALWAYS_PREMIUM regions inspected, %d problems" % (count, bad))
    ok = ok and bad == 0
    print("RESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
