#!/bin/sh
# Assembles the webOS TV app .ipk in the exact layout ares-package produces
# (classic ar headers; webOS's pkgVerifier rejects GNU `ar -r` output with
# "-5: ipk verified failed").
set -e

cd "$(dirname "$0")"
exec python3 tools/build-ipk.py