#!/bin/bash
# Выкладывает собранную «Речку» в GitHub Releases:
#   Rechka_aarch64.dmg     — для install.sh и ручной установки;
#   Rechka.app.tar.gz(.sig) + latest.json — для автообновления установленных Речек;
#   Install-Rechka.zip     — установщик двойным щелчком.
# Запуск из корня репозитория на Mac после `собрать-dmg.command`:
#   bash scripts/rechka-release.sh
# Нужен вход в GitHub через gh. Ничего не перезаписывает: каждый выпуск — новый тег.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="Yurikashin/rechka"
BRANCH="dictovka"
OUT="../готовый-dmg"
UPD="${OUT}/update"

[ -f "${UPD}/version.txt" ] && [ -f "${UPD}/Rechka.app.tar.gz" ] && [ -f "${UPD}/Rechka.app.tar.gz.sig" ] \
  || { echo "Нет пакета обновления в ${UPD} — сначала соберите: собрать-dmg.command"; exit 1; }
VERSION="$(tr -d '[:space:]' < "${UPD}/version.txt")"
DMG="${OUT}/Rechka_${VERSION}_aarch64.dmg"
[ -f "${DMG}" ] || { echo "Нет ${DMG} — пакет обновления и .dmg из разных сборок. Пересоберите."; exit 1; }

command -v gh >/dev/null 2>&1 || { echo "Нужен GitHub CLI (gh)."; exit 1; }
gh auth status -h github.com >/dev/null 2>&1 || gh auth login -h github.com -p https -w

TAG="v${VERSION}"
if gh release view "${TAG}" --repo "${REPO}" >/dev/null 2>&1; then
  echo "Выпуск ${TAG} уже есть. Соберите новую версию (собрать-dmg.command) и запустите снова."
  exit 1
fi
# RECHKA_COMMIT задаёт обёртка на Mac (в папке сборки история git может отставать).
COMMIT="${RECHKA_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo "?")}"
PUB_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SIGNATURE="$(tr -d '\n' < "${UPD}/Rechka.app.tar.gz.sig")"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cp "${DMG}" "${WORK}/Rechka_aarch64.dmg"
cp "${UPD}/Rechka.app.tar.gz" "${UPD}/Rechka.app.tar.gz.sig" "${WORK}/"
# .command внутри zip сохраняет право на запуск при пересылке (Telegram, почта).
cp "install/Установить Речку.command" "${WORK}/"
chmod +x "${WORK}/Установить Речку.command"
(cd "${WORK}" && ditto -c -k --norsrc --noextattr "Установить Речку.command" "Install-Rechka.zip")

# Манифест автообновления (формат Tauri updater). Подпись — base64, кавычек в ней нет.
cat > "${WORK}/latest.json" <<JSON
{
  "version": "${VERSION}",
  "notes": "Rechka ${VERSION} (${COMMIT})",
  "pub_date": "${PUB_DATE}",
  "platforms": {
    "darwin-aarch64": {
      "signature": "${SIGNATURE}",
      "url": "https://github.com/${REPO}/releases/download/${TAG}/Rechka.app.tar.gz"
    }
  }
}
JSON

NOTES="Речка ${VERSION} (коммит ${COMMIT}). Mac на Apple Silicon (M1 и новее).
Установленные Речки обновятся сами при следующем запуске.

Новая установка одной строкой в Терминале:
\`\`\`
curl -fsSL https://raw.githubusercontent.com/${REPO}/${BRANCH}/install.sh | bash
\`\`\`
Или скачайте «Install-Rechka.zip», откройте «Установить Речку.command».
Первый раз: Системные настройки → Конфиденциальность и безопасность → «Всё равно открыть»."

echo "== Выпуск ${TAG} из ${DMG}"
gh release create "${TAG}" \
  --repo "${REPO}" \
  --target "${BRANCH}" \
  --title "Речка ${VERSION}" \
  --notes "${NOTES}" \
  --latest \
  "${WORK}/Rechka_aarch64.dmg" \
  "${WORK}/Rechka.app.tar.gz" \
  "${WORK}/Rechka.app.tar.gz.sig" \
  "${WORK}/latest.json" \
  "${WORK}/Install-Rechka.zip"

echo
echo "ГОТОВО: https://github.com/${REPO}/releases/tag/${TAG}"
echo "Установленные Речки получат ${VERSION} при следующем запуске."
