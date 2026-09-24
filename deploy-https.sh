#!/bin/sh
# Publish the Homebrew Channel repository to GitHub over HTTPS, so the TV can
# add it in Homebrew Channel without LAN access. raw.githubusercontent.com and
# cdn.jsdelivr.net both serve HTTPS and Access-Control-Allow-Origin: * (the TV
# requires both).
#
# Usage (two modes):
#
#   A) AUTOMATIC (creates a new public repo with your token):
#        GH_TOKEN=ghp_xxxxxxxx ./deploy-https.sh <github-username> <new-repo-name>
#      Token: GitHub -> Settings -> Developer settings -> Personal access
#      tokens -> Tokens (classic), scope "repo". Only kept in this shell.
#
#   B) EXISTING EMPTY REPO (you already created it at github.com/new):
#        ./deploy-https.sh <user>/<repo>
#      Do NOT tick "Add a README" when creating it. Git will ask for your
#      GitHub username and (as password) a Personal Access Token on push.
#
# After it finishes, add this URL in Homebrew Channel -> Settings ->
# Repositories:
#
#     https://raw.githubusercontent.com/<user>/<repo>/main/repo.json
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
RELEASE="$HERE/release"

MODE="$1"

if [ -z "$MODE" ]; then
  echo "Usage:" >&2
  echo "  Auto:   GH_TOKEN=<token> $0 <github-username> <new-repo-name>" >&2
  echo "  Manual: $0 <user>/<existing-empty-repo>" >&2
  exit 1
fi

# ---- resolve target repo ----
if [ -n "$2" ]; then
  # mode A
  OWNER="$MODE"
  REPO="$2"
  case "$REPO" in
    */*) echo "In automatic mode give the repo NAME only (no owner/prefix)." >&2; exit 1 ;;
  esac
  PUSH_URL="https://github.com/${OWNER}/${REPO}.git"
else
  # mode B
  REPO_REF="$MODE"
  case "$REPO_REF" in
    */*) PUB="${REPO_REF%.git}" ;;
    *)   echo "In manual mode give <user>/<repo> (e.g. juan/repo)." >&2; exit 1 ;;
  esac
  OWNER="${PUB%%/*}"
  REPO="${PUB##*/}"
  PUSH_URL="https://github.com/${PUB}.git"
fi

[ -d "$RELEASE" ] || { echo "Missing release/ - run ./build.sh and tools/make-manifest.py first." >&2; exit 1; }

# ---- regenerate artifacts with the real source URL ----
echo "[*] Regenerando manifest/repo index con sourceUrl = $PUSH_URL ..."
( cd "$HERE" && SOURCE_URL="$PUSH_URL" python3 tools/make-manifest.py )

# ---- git init + commit ----
rm -rf "$RELEASE/.git"
cd "$RELEASE"

echo "[*] Preparando release/ y haciendo commit..."
git init -q
git -c user.name="regionchanger" -c user.email="regionchanger@localhost" add -A
git -c user.name="regionchanger" -c user.email="regionchanger@localhost" \
  commit -q -m "Region Changer repo (ipk + manifest + index)" || true

# ---- push ----
if [ -n "$GH_TOKEN" ]; then
  echo "[*] Creando repositorio publico ${OWNER}/${REPO} via API..."
  curl -sf -X POST "https://api.github.com/user/repos" \
    -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -d "{\"name\":\"$REPO\",\"public\":true,\"description\":\"Region Changer webOS Homebrew repository\"}" >/dev/null \
    || { echo "Fallo al crear el repo (revisa el token/scope 'repo')." >&2; exit 1; }

  echo "[*] Subiendo a branch 'main'..."
# use provider token auth without putting it in the remote URL or git config
  B64="$(printf 'x-access-token:%s' "$GH_TOKEN" | base64 | tr -d '\n')"
  git -c http.extraheader="Authorization: Basic ${B64}" push -q \
    "https://github.com/${OWNER}/${REPO}.git" HEAD:main || {
      echo "El push fallo. Si el repo ya existe usa el modo manual (sin GH_TOKEN)." >&2; exit 1; }
else
  echo "[*] Subiendo a $PUSH_URL ..."
  echo "    (Si git pide contraseña, usa tu token como password.)"
  git push -q "$PUSH_URL" HEAD:main
fi

# ---- verify ----
RAW="https://raw.githubusercontent.com/${OWNER}/${REPO}/main/repo.json"
CDN="https://cdn.jsdelivr.net/gh/${OWNER}/${REPO}@main/repo.json"
echo ""
echo "=== PUBLICADO ==="
echo "URL para Homebrew Channel:"
echo "  $RAW"
echo ""
echo "Alternativa via jsDelivr CDN (mas cacheado):"
echo "  $CDN"
echo ""
echo "[*] Verificando HTTPS + CORS..."
( curl -sI "$RAW" | grep -qi "access-control-allow-origin: \*" && echo "raw.githubusercontent: OK (HTTPS + CORS)" ) \
  || echo "Verificacion de headers fallo para raw"
echo "Detalles en el repo:  https://github.com/${OWNER}/${REPO}"