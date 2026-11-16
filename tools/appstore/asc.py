"""A small client for Apple's App Store Connect API, in Python's standard library (ADR 0118).

The API takes a JSON Web Token signed with ES256 by the team's API key. Python has no
elliptic-curve signing of its own, so `openssl` signs, and its DER signature is turned
into the raw r‖s pair a JWT carries.

The key lives outside the repositories: asc-key.p8 and asc-credentials.env, which sets
ASC_KEY_ID and ASC_ISSUER_ID, in ~/.config/treewise or the folder TREEWISE_ASC_DIR names.
"""

import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://api.appstoreconnect.apple.com"
# Apple accepts a token for at most 20 minutes; a fresh one is made well before.
TOKEN_LIFETIME = 15 * 60
TOKEN_RENEWAL = 10 * 60
TIMEOUT = 60
# The size of r and of s in an ES256 signature.
COORDINATE_SIZE = 32


def credentials_folder() -> Path:
    return Path(os.environ.get("TREEWISE_ASC_DIR", Path.home() / ".config" / "treewise"))


def load_credentials(folder: Path) -> tuple[str, str, Path]:
    """Returns the key's ID, the issuer's ID and the key file, or stops with what is missing."""
    key, env = folder / "asc-key.p8", folder / "asc-credentials.env"
    if not key.is_file() or not env.is_file():
        sys.exit(f"No App Store Connect API key in {folder}: asc-key.p8 and asc-credentials.env.")
    values = {}
    for line in env.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            name, value = line.split("=", 1)
            values[name.strip()] = value.strip().strip("\"'")
    if not values.get("ASC_KEY_ID") or not values.get("ASC_ISSUER_ID"):
        sys.exit(f"{env} must set ASC_KEY_ID and ASC_ISSUER_ID.")
    return values["ASC_KEY_ID"], values["ASC_ISSUER_ID"], key


def base64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def raw_signature(der: bytes) -> bytes:
    """Turns openssl's DER ECDSA signature, SEQUENCE { INTEGER r, INTEGER s }, into r‖s."""

    def integer(at: int) -> tuple[bytes, int]:
        if der[at] != 0x02:
            raise ValueError("not a DER integer")
        length = der[at + 1]
        value = der[at + 2 : at + 2 + length].lstrip(b"\x00")
        if len(value) > COORDINATE_SIZE:
            raise ValueError("integer too long for ES256")
        return value.rjust(COORDINATE_SIZE, b"\x00"), at + 2 + length

    if der[0] != 0x30:
        raise ValueError("not a DER sequence")
    # A sequence of two 32-byte integers is shorter than 128 bytes: its length is one byte.
    r, after = integer(2)
    s, _ = integer(after)
    return r + s


def token(key_id: str, issuer_id: str, key: Path, now: int | None = None) -> str:
    now = int(time.time()) if now is None else now
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    claims = {"iss": issuer_id, "iat": now, "exp": now + TOKEN_LIFETIME, "aud": "appstoreconnect-v1"}
    signing_input = ".".join(
        base64url(json.dumps(part, separators=(",", ":")).encode()) for part in (header, claims)
    )
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(key)],
        input=signing_input.encode(),
        capture_output=True,
        check=True,
    ).stdout
    return f"{signing_input}.{base64url(raw_signature(der))}"


class Client:
    """Reads from the API, and writes unless it is a dry run, which prints each write instead."""

    def __init__(self, credentials: tuple[str, str, Path], dry_run: bool):
        self.credentials = credentials
        self.dry_run = dry_run
        self._token = ""
        self._made = 0.0

    def _authorization(self) -> str:
        if not self._token or time.time() - self._made > TOKEN_RENEWAL:
            self._token = token(*self.credentials)
            self._made = time.time()
        return f"Bearer {self._token}"

    def _send(self, method: str, path: str, body: dict | None = None) -> dict:
        url = path if path.startswith("https://") else API + path
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(url, data=data, method=method)
        request.add_header("Authorization", self._authorization())
        if data is not None:
            request.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                content = response.read()
        except urllib.error.HTTPError as error:
            sys.exit(f"{method} {path}: {error.code}\n{error.read().decode(errors='replace')[:2000]}")
        return json.loads(content) if content else {}

    def get(self, path: str, query: dict[str, str] | None = None) -> dict:
        if query:
            path += "?" + urllib.parse.urlencode(query)
        return self._send("GET", path)

    def write(self, method: str, path: str, body: dict | None = None) -> dict:
        if self.dry_run:
            summary = json.dumps(body.get("data", {}).get("attributes", {}), ensure_ascii=False) if body else ""
            print(f"    [dry run] {method} {path} {summary[:160]}")
            return {}
        return self._send(method, path, body)

    def put_file_part(self, operation: dict, data: bytes) -> None:
        """Sends one part of a file to where an upload operation says, outside the API."""
        if self.dry_run:
            print(f"    [dry run] {operation['method']} {operation['length']} bytes")
            return
        part = data[operation["offset"] : operation["offset"] + operation["length"]]
        request = urllib.request.Request(operation["url"], data=part, method=operation["method"])
        for header in operation.get("requestHeaders", []):
            request.add_header(header["name"], header["value"])
        with urllib.request.urlopen(request, timeout=TIMEOUT):
            pass
