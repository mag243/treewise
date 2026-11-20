"""The steps of the iPad's UI review at which the app did not come to rest.

XCUITest waits a minute for the app to idle before each step and goes on without it, saying
"App animations complete notification not received". Each such wait means the app kept
drawing or working with nothing to do, as a view written to on every read does; the walk
still passes, only slower, so it is found here. Waits on screens listed in allowed-ipad.txt
with the check `notIdle` are left out: iPadOS 27 never reports an app idle while a context
menu is open (ADR 0115).

Usage: python3 -I idle.py <allowed.txt> <log> ...
Prints each wait as `log: before <screen>: <step>` and exits 1 when there is one.
"""

import re
import sys
from pathlib import Path

WAIT = "App animations complete notification not received"
STEP = re.compile(r"t =\s+[0-9.]+s (\S.*)$")
SHOT = re.compile(r"Added attachment named 'uireview-([^']+?)(\.findings)?'")
VARIANT = re.compile(r"-(light|dark)$")


def allowed_screens(path: Path) -> set[str]:
    screens = set()
    for line in path.read_text().splitlines():
        parts = [part.strip() for part in line.split("#", 1)[0].split("|")]
        if len(parts) == 3 and parts[1] == "notIdle":
            screens.add(parts[0])
    return screens


def waits(log: Path, allowed: set[str]) -> list[str]:
    """Each wait, named by the screen its step led to: the next screenshot taken."""
    found, pending, step = [], [], ""
    for line in log.read_text(errors="replace").splitlines():
        if shot := SHOT.search(line):
            screen = VARIANT.sub("", shot.group(1))
            if screen not in allowed:
                found += [f"{log.name}: before {screen}: {waited}" for waited in pending]
            pending = []
        elif WAIT in line:
            pending.append(step)
        elif match := STEP.search(line):
            step = match.group(1)
    found += [f"{log.name}: at the end: {waited}" for waited in pending]
    return found


def main() -> int:
    allowed = allowed_screens(Path(sys.argv[1]))
    found = [wait for log in sys.argv[2:] for wait in waits(Path(log), allowed)]
    for wait in found:
        print(wait)
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
