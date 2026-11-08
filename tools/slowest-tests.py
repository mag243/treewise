#!/usr/bin/env python3
"""Prints the slowest tests from `xcresulttool get test-results tests` on stdin."""
import json
import sys

SHOWN = 10


def test_cases(node):
    """Yields every test case below `node`."""
    for child in node.get("children", []):
        if child.get("nodeType") == "Test Case":
            yield child
        else:
            yield from test_cases(child)


def main():
    cases = list(test_cases({"children": json.load(sys.stdin).get("testNodes", [])}))
    total = sum(case.get("durationInSeconds", 0) for case in cases)
    print(f"    {len(cases)} tests, {total:.0f}s; slowest:")
    for case in sorted(cases, key=lambda c: -c.get("durationInSeconds", 0))[:SHOWN]:
        print(f"    {case.get('durationInSeconds', 0):6.1f}s  {case.get('nodeIdentifier')}")


if __name__ == "__main__":
    main()
