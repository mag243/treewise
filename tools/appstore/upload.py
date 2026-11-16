#!/usr/bin/env python3
"""Uploads the iPad app's listing to App Store Connect (ADR 0118): listing.md's text and
the screenshots, to the version being prepared. Owner only: it needs the API key in
~/.config/treewise, and writes to the App Store listing.

    python3 tools/appstore/upload.py metadata --dry-run      # what would change, sending nothing
    python3 tools/appstore/upload.py metadata
    python3 tools/appstore/upload.py screenshots [--locale nl-NL]
    python3 tools/appstore/upload.py all

A dry run reads App Store Connect and prints every write it would make. Builds are
uploaded from Xcode; the version being prepared is the one in "Prepare for Submission".
"""

import argparse
import hashlib
import re
import struct
import sys
import time
from pathlib import Path

import asc
import listing

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "Treewise.xcodeproj" / "project.pbxproj"
BUNDLE_ID = "me.m-domain.treewise"
SCREENSHOTS = ROOT / "build" / "appstore" / "screenshots"
# The 13-inch iPad's slot, which takes 2064 × 2752 in either orientation.
DISPLAY_TYPE = "APP_IPAD_PRO_3GEN_129"
SCREENSHOT_SIZES = {(2064, 2752), (2752, 2064)}
# Apple shows at most ten screenshots per slot.
MAX_SCREENSHOTS = 10
EDITABLE = "PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED,REJECTED,METADATA_REJECTED,INVALID_BINARY"
PROCESSING_WAIT = 180
PROCESSING_POLL = 3

VERSION_FIELDS = ("description", "keywords", "promotionalText", "whatsNew", "supportUrl", "marketingUrl")
INFO_FIELDS = ("subtitle", "privacyPolicyUrl")


def marketing_version() -> str:
    versions = set(re.findall(r"MARKETING_VERSION = ([0-9.]+);", PROJECT.read_text(encoding="utf-8")))
    if len(versions) != 1:
        sys.exit(f"MARKETING_VERSION is not one version in the project: {sorted(versions)}")
    return versions.pop()


def resource(kind: str, identifier: str, attributes: dict | None = None, **relationships: tuple[str, str]) -> dict:
    """A JSON:API body for the resource `kind`, with `identifier` empty for a new one."""
    data: dict = {"type": kind}
    if identifier:
        data["id"] = identifier
    if attributes:
        data["attributes"] = attributes
    if relationships:
        data["relationships"] = {
            name: {"data": {"type": other, "id": other_id}} for name, (other, other_id) in relationships.items()
        }
    return {"data": data}


def state_of(info: dict) -> str | None:
    return info["attributes"].get("state") or info["attributes"].get("appStoreState")


class Listing:
    """The app's records in App Store Connect that the listing is written to."""

    def __init__(self, client: asc.Client):
        self.client = client
        apps = client.get("/v1/apps", {"filter[bundleId]": BUNDLE_ID})["data"]
        if not apps:
            sys.exit(f"No app with the bundle ID {BUNDLE_ID} in App Store Connect.")
        self.app_id = apps[0]["id"]
        self.primary_locale = apps[0]["attributes"].get("primaryLocale", listing.LOCALES[0])
        versions = client.get(
            f"/v1/apps/{self.app_id}/appStoreVersions",
            {"filter[platform]": "IOS", "filter[appStoreState]": EDITABLE},
        )["data"]
        if len(versions) != 1:
            sys.exit(f"Expected one version being prepared in App Store Connect, found {len(versions)}.")
        self.version = versions[0]
        infos = client.get(f"/v1/apps/{self.app_id}/appInfos")["data"]
        # The app info being edited; an app on sale also has the one that is live.
        live = {"READY_FOR_DISTRIBUTION", "READY_FOR_SALE", "REPLACED_WITH_NEW_INFO"}
        self.info = next(
            (info for info in infos if state_of(info) not in live),
            infos[0],
        )

    def localizations(self, relationship: str, kind: str, parent: tuple[str, str]) -> dict[str, dict]:
        """The localizations of the version or app info by locale, made for a missing locale."""
        path = f"/v1/{parent[0]}/{parent[1]}/{relationship}"
        found = {each["attributes"]["locale"]: each for each in self.client.get(path)["data"]}
        for locale in listing.LOCALES:
            if locale not in found:
                print(f"  add the locale {locale} ({kind})")
                made = self.client.write("POST", f"/v1/{kind}", resource(kind, "", {"locale": locale}, **{
                    "appStoreVersion" if parent[0] == "appStoreVersions" else "appInfo": parent
                }))
                found[locale] = made.get("data", {"id": f"<new {locale}>", "attributes": {}})
        return found

    def version_localizations(self) -> dict[str, dict]:
        return self.localizations(
            "appStoreVersionLocalizations", "appStoreVersionLocalizations", ("appStoreVersions", self.version["id"])
        )

    def info_localizations(self) -> dict[str, dict]:
        return self.localizations("appInfoLocalizations", "appInfoLocalizations", ("appInfos", self.info["id"]))


def changes(record: dict, wanted: dict[str, str], fields: tuple[str, ...]) -> dict[str, str]:
    current = record.get("attributes", {})
    return {field: wanted[field] for field in fields if field in wanted and (current.get(field) or "") != wanted[field]}


def upload_metadata(records: Listing, values: dict[str, dict[str, str]], version: str) -> None:
    client, current = records.client, records.version
    print("\n# The version")
    attributes = {}
    if current["attributes"].get("versionString") != version:
        attributes["versionString"] = version
    if current["attributes"].get("copyright") != values["copyright"][listing.LOCALES[0]]:
        attributes["copyright"] = values["copyright"][listing.LOCALES[0]]
    for name, value in attributes.items():
        print(f"  {name}: {current['attributes'].get(name)!r} → {value!r}")
    if attributes:
        client.write("PATCH", f"/v1/appStoreVersions/{current['id']}", resource("appStoreVersions", current["id"], attributes))
    else:
        print("  unchanged")
    for title, localizations, fields, kind in (
        ("The version's text", records.version_localizations, VERSION_FIELDS, "appStoreVersionLocalizations"),
        ("The app's info", records.info_localizations, INFO_FIELDS, "appInfoLocalizations"),
    ):
        print(f"\n# {title}")
        found = localizations()
        for locale in listing.LOCALES:
            wanted = {field: values[field][locale] for field in fields if values.get(field, {}).get(locale)}
            changed = changes(found[locale], wanted, fields)
            print(f"  {locale}: {', '.join(changed) or 'unchanged'}")
            if changed:
                record_id = found[locale]["id"]
                client.write("PATCH", f"/v1/{kind}/{record_id}", resource(kind, record_id, changed))


def png_size(path: Path) -> tuple[tuple[int, int], bool]:
    """Returns a PNG's width and height and whether it has an alpha channel."""
    header = path.read_bytes()[:33]
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        sys.exit(f"{path}: not a PNG")
    width, height, _, colour_type = struct.unpack(">IIBB", header[16:26])
    # Colour types 4 and 6 are grey and RGB with alpha, which App Store Connect refuses.
    return (width, height), colour_type in (4, 6)


def screenshots_of(locale: str, folder: Path) -> list[Path]:
    shots = sorted((folder / locale).glob("*.png"))
    problems = []
    for shot in shots:
        size, alpha = png_size(shot)
        if size not in SCREENSHOT_SIZES:
            problems.append(f"{shot.name}: {size[0]} × {size[1]}, not 2064 × 2752")
        if alpha:
            problems.append(f"{shot.name}: has an alpha channel")
    if len(shots) > MAX_SCREENSHOTS:
        problems.append(f"{len(shots)} screenshots, at most {MAX_SCREENSHOTS}")
    if problems:
        sys.exit(f"Screenshots for {locale}:\n  " + "\n  ".join(problems))
    return shots


def upload_screenshot(client: asc.Client, set_id: str, shot: Path, locale: str) -> None:
    data = shot.read_bytes()
    name = f"{locale}-{shot.name}"
    reserved = client.write("POST", "/v1/appScreenshots", resource(
        "appScreenshots", "", {"fileName": name, "fileSize": len(data)}, appScreenshotSet=("appScreenshotSets", set_id)
    ))
    if client.dry_run:
        return
    shot_id = reserved["data"]["id"]
    for operation in reserved["data"]["attributes"].get("uploadOperations", []):
        client.put_file_part(operation, data)
    client.write("PATCH", f"/v1/appScreenshots/{shot_id}", resource(
        "appScreenshots", shot_id, {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}
    ))
    # The next upload waits until Apple has processed this one; screenshots uploaded while
    # an earlier one was still processing went missing from the set in velo-points.
    deadline = time.time() + PROCESSING_WAIT
    while time.time() < deadline:
        state = (client.get(f"/v1/appScreenshots/{shot_id}")["data"]["attributes"].get("assetDeliveryState") or {})
        if state.get("state") == "COMPLETE":
            print(f"    ✓ {name}")
            return
        if state.get("state") == "FAILED":
            sys.exit(f"App Store Connect could not process {name}: {state.get('errors')}")
        time.sleep(PROCESSING_POLL)
    sys.exit(f"{name} was not processed within {PROCESSING_WAIT} seconds.")


def upload_screenshots(credentials: tuple, dry_run: bool, locales: list[str], folder: Path) -> None:
    shots = {locale: screenshots_of(locale, folder) for locale in locales}
    print("\n# Screenshots")
    first = Listing(asc.Client(credentials, dry_run))
    # The primary locale last: in velo-points, its screenshots went missing when another
    # locale's were uploaded after them.
    order = sorted(locales, key=lambda locale: locale == first.primary_locale)
    for locale in order:
        if not shots[locale]:
            print(f"  {locale}: no screenshots in {folder / locale}, left as it is")
            continue
        # A fresh client and fresh records for each locale, as velo-points found that one
        # session uploading several locales put screenshots in the wrong locale.
        client = asc.Client(credentials, dry_run)
        localization = Listing(client).version_localizations()[locale]
        # A locale added in a dry run has no record yet, nor screenshot sets.
        new = localization["id"].startswith("<")
        sets = [] if new else client.get(f"/v1/appStoreVersionLocalizations/{localization['id']}/appScreenshotSets")["data"]
        # The filter on the display type is not to be trusted, so the sets are chosen here.
        sets = [each for each in sets if each["attributes"].get("screenshotDisplayType") == DISPLAY_TYPE]
        print(f"  {locale}: {len(shots[locale])} screenshots")
        if sets:
            set_id = sets[0]["id"]
            for old in client.get(f"/v1/appScreenshotSets/{set_id}/appScreenshots")["data"]:
                client.write("DELETE", f"/v1/appScreenshots/{old['id']}")
        else:
            made = client.write("POST", "/v1/appScreenshotSets", resource(
                "appScreenshotSets", "", {"screenshotDisplayType": DISPLAY_TYPE},
                appStoreVersionLocalization=("appStoreVersionLocalizations", localization["id"]),
            ))
            set_id = made.get("data", {}).get("id", "<new set>")
        for shot in shots[locale]:
            upload_screenshot(client, set_id, shot, locale)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("what", choices=("metadata", "screenshots", "all"))
    parser.add_argument("--dry-run", action="store_true", help="read App Store Connect and print the writes")
    parser.add_argument("--locale", choices=listing.LOCALES, help="only this locale's screenshots")
    parser.add_argument("--screenshots", type=Path, default=SCREENSHOTS, help="a folder per locale of PNGs")
    arguments = parser.parse_args()

    values = listing.read()
    problems = listing.check(values)
    if problems:
        sys.exit("listing.md is not ready:\n  " + "\n  ".join(problems))
    version = marketing_version()
    credentials = asc.load_credentials(asc.credentials_folder())
    client = asc.Client(credentials, arguments.dry_run)
    records = Listing(client)
    shown = records.version["attributes"]
    state = shown.get("appVersionState") or shown.get("appStoreState")
    dry_run = " — dry run" if arguments.dry_run else ""
    print(f"Treewise {version} → App Store Connect version {shown.get('versionString')} ({state}){dry_run}")
    if arguments.what in ("metadata", "all"):
        upload_metadata(records, values, version)
    if arguments.what in ("screenshots", "all"):
        locales = [arguments.locale] if arguments.locale else list(listing.LOCALES)
        upload_screenshots(credentials, arguments.dry_run, locales, arguments.screenshots)
    return 0


if __name__ == "__main__":
    sys.exit(main())
