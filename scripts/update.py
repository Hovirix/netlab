#!/usr/bin/env python3
from html.parser import HTMLParser
from pathlib import Path
from urllib.request import urlopen
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import time


CONFIG_FILE = Path("config/router.yaml")
README_FILE = Path("README.md")
DOWNLOADS_DIR = Path("build/downloads")
RELEASE_NOTES_FILE = Path("build/openwrt-release-notes.md")
SIGNING_KEY = Path("keys/openwrt-build-system.asc")
HOST_SUFFIX = "Linux-x86_64"
DOWNLOAD_TIMEOUT_SECONDS = 60
DOWNLOAD_ATTEMPTS = 3
OPENWRT_RELEASES_URL = "https://api.github.com/repos/openwrt/openwrt/releases?per_page=100"
MAX_PR_BODY_BYTES = 60_000


class LinkParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag != "a":
            return
        href = dict(attrs).get("href", "")
        self.links.append(href.rstrip("/"))


def build_config():
    values = {
        key: subprocess.check_output(
            ["yq", "-r", f".build.{key}", str(CONFIG_FILE)], text=True
        ).strip()
        for key in ("openwrt_version", "target", "subtarget")
    }

    for key in ("openwrt_version", "target", "subtarget"):
        if values.get(key) in ("", "null"):
            raise SystemExit(f"missing build.{key} in config/router.yaml")

    return values


def latest_openwrt_version():
    parser = LinkParser()
    with urlopen(
        "https://downloads.openwrt.org/releases/", timeout=DOWNLOAD_TIMEOUT_SECONDS
    ) as response:
        parser.feed(response.read().decode("utf-8", errors="replace"))

    versions = []
    for link in parser.links:
        if re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", link):
            versions.append(tuple(int(part) for part in link.split(".")))

    if not versions:
        raise SystemExit("no OpenWrt release versions found")

    return ".".join(str(part) for part in max(versions))


def version_tuple(version):
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise SystemExit(f"invalid OpenWrt version: {version}")
    return tuple(int(part) for part in version.split("."))


def fetch_json(url):
    last_error = None
    for attempt in range(1, DOWNLOAD_ATTEMPTS + 1):
        try:
            with urlopen(url, timeout=DOWNLOAD_TIMEOUT_SECONDS) as response:
                return json.loads(response.read())
        except (OSError, json.JSONDecodeError) as error:
            last_error = error
            if attempt < DOWNLOAD_ATTEMPTS:
                time.sleep(attempt)
    raise SystemExit(f"failed to retrieve {url}: {last_error}")


def write_release_notes(current_version, latest_version):
    current = version_tuple(current_version)
    latest = version_tuple(latest_version)
    releases = []

    available_releases = fetch_json(OPENWRT_RELEASES_URL)
    if not isinstance(available_releases, list):
        raise SystemExit("OpenWrt GitHub releases returned an unexpected response")

    for release in available_releases:
        tag = release.get("tag_name", "")
        if not tag.startswith("v") or release.get("draft") or release.get("prerelease"):
            continue
        try:
            release_version = version_tuple(tag.removeprefix("v"))
        except SystemExit:
            continue
        if current < release_version <= latest:
            releases.append((release_version, release))

    releases.sort()
    if not releases or releases[-1][0] != latest:
        raise SystemExit(
            f"OpenWrt GitHub releases do not contain notes for {latest_version}"
        )

    sections = []
    for release_version, release in releases:
        version = ".".join(str(part) for part in release_version)
        series = ".".join(version.split(".")[:2])
        sections.extend(
            [
                "",
                f"## OpenWrt {version}",
                "",
                f"Released: {release['published_at']}",
                f"[GitHub release]({release['html_url']}) | "
                f"[Release notes](https://openwrt.org/releases/{series}/notes-{version}) | "
                f"[Full changelog](https://openwrt.org/releases/{series}/changelog-{version})",
                "",
                release.get("body", "").replace("\r\n", "\n").strip(),
            ]
        )

    body = "\n".join(sections).strip() + "\n"
    if len(body.encode()) > MAX_PR_BODY_BYTES:
        raise SystemExit(
            "OpenWrt release notes exceed GitHub's PR body limit; review the "
            "upstream releases before updating"
        )

    RELEASE_NOTES_FILE.parent.mkdir(parents=True, exist_ok=True)
    RELEASE_NOTES_FILE.write_text(body)


def download(url, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    last_error = None
    for attempt in range(1, DOWNLOAD_ATTEMPTS + 1):
        try:
            with urlopen(url, timeout=DOWNLOAD_TIMEOUT_SECONDS) as response:
                with path.open("wb") as output:
                    shutil.copyfileobj(response, output)
            return
        except OSError as error:
            last_error = error
            path.unlink(missing_ok=True)
            if attempt < DOWNLOAD_ATTEMPTS:
                time.sleep(attempt)
    raise SystemExit(f"failed to download {url}: {last_error}")


def verify_signed_checksums(base_url, archive, checksums_path, signature_path):
    if not SIGNING_KEY.is_file():
        raise SystemExit(f"missing pinned OpenWrt signing key: {SIGNING_KEY}")

    download(f"{base_url}/sha256sums", checksums_path)
    download(f"{base_url}/sha256sums.asc", signature_path)

    with tempfile.TemporaryDirectory() as gpg_home:
        subprocess.run(
            ["gpg", "--batch", "--homedir", gpg_home, "--import", str(SIGNING_KEY)],
            check=True,
        )
        subprocess.run(
            [
                "gpgv",
                "--homedir",
                gpg_home,
                "--keyring",
                f"{gpg_home}/pubring.kbx",
                str(signature_path),
                str(checksums_path),
            ],
            check=True,
        )

    for line in checksums_path.read_text().splitlines():
        checksum, separator, filename = line.partition(" *")
        if separator and filename == archive and re.fullmatch(r"[0-9a-f]{64}", checksum):
            return checksum
    raise SystemExit(f"signed sha256sums does not contain {archive}")


def verify_archive_checksum(archive_path, expected_checksum):
    with archive_path.open("rb") as archive_file:
        digest = hashlib.file_digest(archive_file, "sha256").hexdigest()
    if digest != expected_checksum:
        archive_path.unlink(missing_ok=True)
        raise SystemExit(f"checksum mismatch for {archive_path.name}")


def update_build_metadata(version, imagebuilder_hash):
    text = CONFIG_FILE.read_text()

    def replace(key, value):
        new_text, count = re.subn(
            rf"^  {key}: .*$", rf"  {key}: {value}", text, count=1, flags=re.M
        )
        if count != 1:
            raise SystemExit(f"missing build.{key} in config/router.yaml")
        return new_text

    text = replace("openwrt_version", version)
    text = replace("imagebuilder_hash", imagebuilder_hash)

    readme_text = README_FILE.read_text()
    readme_text, count = re.subn(
        r"(\[!\[OpenWrt\]\(https://img\.shields\.io/badge/OpenWrt-)"
        r"[0-9]+\.[0-9]+\.[0-9]+"
        r"(-blue\?logo=openwrt\)\]\(https://downloads\.openwrt\.org/releases/)"
        r"[0-9]+\.[0-9]+\.[0-9]+"
        r"(/\))",
        rf"\g<1>{version}\g<2>{version}\g<3>",
        readme_text,
        count=1,
    )
    if count != 1:
        raise SystemExit("missing OpenWrt badge in README.md")

    CONFIG_FILE.write_text(text)
    README_FILE.write_text(readme_text)


def main():
    config = build_config()
    current_version = config["openwrt_version"]
    latest_version = latest_openwrt_version()

    if latest_version == current_version:
        RELEASE_NOTES_FILE.parent.mkdir(parents=True, exist_ok=True)
        RELEASE_NOTES_FILE.write_text(
            f"# OpenWrt Update\n\nOpenWrt is already current at `{current_version}`.\n"
        )
        print(f"OpenWrt is already current: {current_version}")
        return

    imagebuilder = (
        f"openwrt-imagebuilder-{latest_version}-"
        f"{config['target']}-{config['subtarget']}.{HOST_SUFFIX}"
    )
    archive = f"{imagebuilder}.tar.zst"
    base_url = (
        f"https://downloads.openwrt.org/releases/{latest_version}/targets/"
        f"{config['target']}/{config['subtarget']}"
    )
    archive_url = f"{base_url}/{archive}"
    archive_path = DOWNLOADS_DIR / archive
    checksums_path = DOWNLOADS_DIR / f"{archive}.sha256sums"
    signature_path = DOWNLOADS_DIR / f"{archive}.sha256sums.asc"

    DOWNLOADS_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Current OpenWrt: {current_version}")
    print(f"Latest OpenWrt:  {latest_version}")
    print(f"ImageBuilder:    {archive_url}")

    expected_checksum = verify_signed_checksums(
        base_url, archive, checksums_path, signature_path
    )
    download(archive_url, archive_path)
    verify_archive_checksum(archive_path, expected_checksum)
    imagebuilder_hash = subprocess.check_output(
        ["nix", "hash", "file", str(archive_path)], text=True
    ).strip()

    update_build_metadata(latest_version, imagebuilder_hash)
    write_release_notes(current_version, latest_version)

    print(
        "Updated config/router.yaml to OpenWrt "
        f"{latest_version} with ImageBuilder hash {imagebuilder_hash}"
    )


if __name__ == "__main__":
    main()
