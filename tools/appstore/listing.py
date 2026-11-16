#!/usr/bin/env python3
"""The iPad app's App Store listing in listing.md (ADR 0118): reading it and checking it.

    python3 tools/appstore/listing.py check   # every field and locale, against Apple's limits
    python3 tools/appstore/listing.py show    # the values per locale, with their lengths

The uploader imports `read` and `check`; this file sends nothing anywhere.
"""

import re
import sys
from dataclasses import dataclass
from pathlib import Path

LISTING = Path(__file__).with_name("listing.md")
APP_NAME = "Treewise"
# The primary locale is App Store Connect's (English (U.S.)), the others follow the app's.
LOCALES = ("en-US", "nl-NL", "de-DE")
SHARED = "all"


@dataclass(frozen=True)
class Field:
    title: str
    limit: int | None
    localized: bool


# Apple's limits, in characters.
FIELDS = {
    "subtitle": Field("Subtitle", 30, True),
    "promotionalText": Field("Promotional text", 170, True),
    "description": Field("Description", 4000, True),
    "keywords": Field("Keywords", 100, True),
    "whatsNew": Field("What's new", 4000, True),
    "supportUrl": Field("Support URL", None, False),
    "marketingUrl": Field("Marketing URL", None, False),
    "privacyPolicyUrl": Field("Privacy policy URL", None, False),
    "copyright": Field("Copyright", None, False),
}
# What's new is refused on an app's first version, so it may be left out.
OPTIONAL = {"whatsNew"}
URL_FIELDS = {"supportUrl", "marketingUrl", "privacyPolicyUrl"}

HEADING = re.compile(r"^(#{2,3}) (.+?)\s*$")
FENCE = "```"


def read(path: Path = LISTING) -> dict[str, dict[str, str]]:
    """Returns {field key: {locale: value}}; a shared value is under every locale."""
    by_title = {field.title: key for key, field in FIELDS.items()}
    values: dict[str, dict[str, str]] = {}
    key = locale = None
    block: list[str] | None = None
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if block is not None:
            if line.strip() == FENCE:
                if key is None or locale is None:
                    raise ValueError(f"{path.name}:{number}: a value outside a field and locale")
                text = "\n".join(block).strip()
                for each in LOCALES if locale == SHARED else (locale,):
                    values.setdefault(key, {})[each] = text
                block = None
            else:
                block.append(line)
        elif line.strip() == FENCE:
            block = []
        elif match := HEADING.match(line):
            level, title = match.groups()
            if level == "##":
                if title not in by_title:
                    raise ValueError(f"{path.name}:{number}: unknown field “{title}”")
                key, locale = by_title[title], None
            else:
                if title != SHARED and title not in LOCALES:
                    raise ValueError(f"{path.name}:{number}: unknown locale “{title}”")
                locale = title
    if block is not None:
        raise ValueError(f"{path.name}: a value without its closing fence")
    return values


def words(text: str) -> set[str]:
    return {word.casefold() for word in re.findall(r"\w+", text)}


def check(values: dict[str, dict[str, str]]) -> list[str]:
    """Returns what is wrong with the listing, empty when it may be uploaded."""
    problems = []
    for key, field in FIELDS.items():
        for locale in LOCALES:
            value = values.get(key, {}).get(locale)
            where = f"{field.title} ({locale})"
            if not value:
                if key not in OPTIONAL:
                    problems.append(f"{where}: missing")
                continue
            if field.limit is not None and len(value) > field.limit:
                problems.append(f"{where}: {len(value)} characters, at most {field.limit}")
            if key in URL_FIELDS and not value.startswith("https://"):
                problems.append(f"{where}: not an https URL")
    for locale in LOCALES:
        keywords = values.get("keywords", {}).get(locale, "")
        terms = keywords.split(",") if keywords else []
        if any(term != term.strip() or not term for term in terms):
            problems.append(f"Keywords ({locale}): spaces or an empty term between the commas")
        searched = words(APP_NAME) | words(values.get("subtitle", {}).get(locale, ""))
        repeated = sorted(words(keywords) & searched)
        if repeated:
            problems.append(f"Keywords ({locale}): already in the name or subtitle: {', '.join(repeated)}")
    return problems


def main(arguments: list[str]) -> int:
    command = arguments[0] if arguments else "check"
    values = read()
    if command == "show":
        for key, field in FIELDS.items():
            for locale in LOCALES:
                value = values.get(key, {}).get(locale, "")
                limit = f"/{field.limit}" if field.limit else ""
                print(f"{field.title} ({locale}, {len(value)}{limit}): {value.splitlines()[0] if value else '—'}")
        return 0
    if command == "check":
        problems = check(values)
        for problem in problems:
            print(f"✗ {problem}", file=sys.stderr)
        if not problems:
            print(f"✓ {LISTING.name}: {len(LOCALES)} locales within Apple's limits")
        return 1 if problems else 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
