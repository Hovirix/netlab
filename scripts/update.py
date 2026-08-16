#!/usr/bin/env python3
from html.parser import HTMLParser
from pathlib import Path
from urllib.request import urlretrieve, urlopen
import re
import subprocess


CONFIG_FILE = Path("config/router.yaml")
DOWNLOADS_DIR = Path("build/downloads")
HOST_SUFFIX = "Linux-x86_64"


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
    with urlopen("https://downloads.openwrt.org/releases/", timeout=60) as response:
        parser.feed(response.read().decode("utf-8", errors="replace"))

    versions = []
    for link in parser.links:
        if re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", link):
            versions.append(tuple(int(part) for part in link.split(".")))

    if not versions:
        raise SystemExit("no OpenWrt release versions found")

    return ".".join(str(part) for part in max(versions))


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
    CONFIG_FILE.write_text(text)


def main():
    config = build_config()
    current_version = config["openwrt_version"]
    latest_version = latest_openwrt_version()

    if latest_version == current_version:
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

    DOWNLOADS_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Current OpenWrt: {current_version}")
    print(f"Latest OpenWrt:  {latest_version}")
    print(f"ImageBuilder:    {archive_url}")

    urlretrieve(archive_url, archive_path)
    imagebuilder_hash = subprocess.check_output(
        ["nix", "hash", "file", str(archive_path)], text=True
    ).strip()

    update_build_metadata(latest_version, imagebuilder_hash)

    print(
        "Updated config/router.yaml to OpenWrt "
        f"{latest_version} with ImageBuilder hash {imagebuilder_hash}"
    )


if __name__ == "__main__":
    main()
