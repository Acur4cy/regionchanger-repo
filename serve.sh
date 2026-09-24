#!/bin/sh
# Serves the Homebrew Channel repository locally so the TV (in the same LAN)
# can install the Region Changer app from Homebrew Channel.
#
# Usage: ./serve.sh [port]           (default 8000)
#
# On the TV, in Homebrew Channel:
#   Settings -> Repositories -> Add  -> enter the "Repo URL" printed below.
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "${HERE}/release"

PORT="${1:-8000}"
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[ -z "$IP" ] && IP="<IP-de-esta-maquina>"

echo "=================================================================="
echo "  Repo URL:  http://${IP}:${PORT}/repo.json"
echo "=================================================================="
echo "En Homebrew Channel del TV: Ajustes -> Repositorios -> Anadir:"
echo "  pega la URL de arriba. Luego instala 'Region Changer' desde la lista."
echo "Sirviendo en el puerto ${PORT} (Ctrl+C para salir)..."
echo

exec python3 "${HERE}/serve.py" "${PORT}"