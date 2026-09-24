#!/usr/bin/env python3
"""Generate Homebrew Channel release artifacts for the regionchanger IPK.

Writes into ./release:
  org.webosbrew.regionchanger.manifest.json - app manifest (HBC DetailsPanel)
  repo.json                                   - repository index (HBC BrowserPanel)

All URLs are relative, so they resolve against whatever repository URL the
user adds in Homebrew Channel (see resolveURL() in frontend/baseurl.js).
"""
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
APP = "org.webosbrew.regionchanger"
VER = "1.0.2"
IPK = os.path.join(ROOT, f"{APP}_{VER}_all.ipk")
RELEASE = os.path.join(ROOT, "release")

DESC = (
    "Cambia la region / area option (contiArea2All) del TV escribiendo en "
    "NVRAM via com.webos.service.lowlevelstorage (sin necesidad de root). "
    "Presets: US, Europa, China, Brasil, Japon, Canada, Mexico, Argentina, "
    "o un codigo custom. Requiere un LG webOS TV rooteado."

)
SHORT = "Cambia la region del TV (contiArea2All) via lowlevelstorage NVRAM."
SOURCE_URL = os.environ.get("SOURCE_URL", "https://github.com/Acur4cy/regionchanger-repo")


def main():
    if not os.path.exists(IPK):
        sys.exit(f"missing {IPK} - run build.sh first")

    data = open(IPK, "rb").read()
    sha = hashlib.sha256(data).hexdigest()
    size = len(data)

    manifest = {
        "id": APP,
        "version": VER,
        "type": "web",
        "title": "Region Changer",
        "appDescription": DESC,
        "iconUri": "icons/icon.png",
        "sourceUrl": SOURCE_URL,
        "rootRequired": False,
        "ipkUrl": os.path.basename(IPK),
        "ipkHash": {"sha256": sha},
        "ipkSize": size,
    }

    os.makedirs(RELEASE, exist_ok=True)
    manifest_path = os.path.join(RELEASE, f"{APP}.manifest.json")
    repo_path = os.path.join(RELEASE, "repo.json")

    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
        f.write("\n")

    repo = {
        "paging": {
            "page": 1,
            "count": 1,
            "totalPages": 1,
            "total": 1,
        },
        "packages": [
            {
                "id": APP,
                "title": "Region Changer",
                "iconUri": "icons/icon.png",
                "manifest": manifest,
                "shortDescription": SHORT,
                "requirements": [],
                "pool": [],
            }
        ],
    }
    with open(repo_path, "w") as f:
        json.dump(repo, f, indent=2, ensure_ascii=False)
        f.write("\n")

    # bring the icons along for the served repo
    icons_src = os.path.join(
        ROOT, "pkg", "usr", "palm", "applications", APP)
    icons_dst = os.path.join(RELEASE, "icons")
    os.makedirs(icons_dst, exist_ok=True)
    for name in ("icon.png", "largeIcon.png"):
        src = os.path.join(icons_src, name)
        if os.path.exists(src):
            with open(src, "rb") as fi, open(os.path.join(icons_dst, name), "wb") as fo:
                fo.write(fi.read())

    with open(IPK, "rb") as fi, open(os.path.join(RELEASE, os.path.basename(IPK)), "wb") as fo:
        fo.write(fi.read())

    print(f"sha256: {sha}")
    print(f"size  : {size} bytes")
    print(f"wrote : {manifest_path}")
    print(f"wrote : {repo_path}")
    print(f"wrote : {RELEASE}/{os.path.basename(IPK)}")


if __name__ == "__main__":
    main()