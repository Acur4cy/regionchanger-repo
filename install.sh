#!/bin/sh
# Copies the built .ipk to the LG webOS TV and installs it through
# com.webos.appInstallService/dev/install (works on rooted TV / dev mode).
#
# Usage:
#   ./install.sh <tv-ip> [ssh-port] [ssh-user]
#
# Examples:
#   ./install.sh 192.168.1.50                 # dev mode (prisoner @ 9922)
#   ./install.sh 192.168.1.50 22 root         # rooted TV sshd (Homebrew Channel)
#
# Optional: SSH_KEY=/path/to/key ./install.sh ...
set -e

HOST="${1:-}"
PORT="${2:-9922}"
USER="${3:-prisoner}"  # "root" on rooted sshd
KEY="${SSH_KEY:-}"

IPK=$(ls org.webosbrew.regionchanger_*_all.ipk 2>/dev/null | head -1 || true)
if [ -z "$IPK" ]; then
  echo "The ipk is missing - run ./build.sh first." >&2
  exit 1
fi
if [ -z "$HOST" ]; then
  echo "Usage: $0 <tv-ip> [ssh-port] [ssh-user]" >&2
  exit 1
fi

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SSH_OPTS="$SSH_OPTS -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa"
[ -n "$KEY" ] && SSH_OPTS="$SSH_OPTS -i $KEY"

echo "[*] Copying $IPK to $USER@$HOST (port $PORT)..."
# /tmp may be unwritable for prisoner on newer webOS; /media/developer/temp
# always works on dev-mode TVs.
scp $SSH_OPTS -P "$PORT" "$IPK" "${USER}@${HOST}:/media/developer/temp/regionchanger.ipk" \
  || scp $SSH_OPTS -P "$PORT" "$IPK" "${USER}@${HOST}:/tmp/regionchanger.ipk"

echo "[*] Installing..."
ssh $SSH_OPTS -p "$PORT" "${USER}@${HOST}" \
  "luna-send-pub -i 'luna://com.webos.appInstallService/dev/install' '{\"id\":\"org.webosbrew.regionchanger\",\"ipkUrl\":\"/media/developer/temp/regionchanger.ipk\",\"subscribe\":true}'" \
  || ssh $SSH_OPTS -p "$PORT" "${USER}@${HOST}" \
  "luna-send-pub -i 'luna://com.webos.appInstallService/dev/install' '{\"id\":\"org.webosbrew.regionchanger\",\"ipkUrl\":\"/tmp/regionchanger.ipk\",\"subscribe\":true}'"

echo "[*] Done. Look for \"Region Changer\" in the app launcher."
echo ""
echo "    IMPORTANT: save your CURRENT area option BEFORE changing it."
echo "    1. In the app press \"Leer region actual\" and note the value, or"
echo "    2. run the included script over SSH:"
echo "       ./bin/change_region.sh read"
echo "    Roll back later with: ./bin/change_region.sh <your-original-area>"