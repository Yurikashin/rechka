#!/bin/bash
# Выкладывает собранную «Речку» в GitHub Releases, откуда её берёт install.sh.
# Запуск: из корня репозитория на Mac после `собрать-dmg.command`:
#   bash scripts/rechka-release.sh [путь-к-dmg]
# Нужен вход в GitHub через gh (gh auth login). Ничего не перезаписывает:
# каждый выпуск — новый тег, старые выпуски остаются.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="Yurikashin/rechka"
BRANCH="dictovka"

DMG="${1:-}"
if [ -z "$DMG" ]; then
  DMG="$(ls -t ../готовый-dmg/Rechka_*_aarch64.dmg 2>/dev/null | head -1 || true)"
fi
[ -n "$DMG" ] && [ -f "$DMG" ] || { echo "Не найден .dmg — сначала соберите: собрать-dmg.command"; exit 1; }

command -v gh >/dev/null 2>&1 || { echo "Нужен GitHub CLI (gh)."; exit 1; }
gh auth status -h github.com >/dev/null 2>&1 || gh auth login -h github.com -p https -w

VERSION="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' src-tauri/tauri.conf.json | head -1)"
STAMP="$(date +%Y%m%d-%H%M)"
TAG="v${VERSION}-${STAMP}"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "?")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$DMG" "$WORK/Rechka_aarch64.dmg"
# .command внутри zip сохраняет право на запуск при пересылке (Telegram, почта).
cp "install/Установить Речку.command" "$WORK/"
chmod +x "$WORK/Установить Речку.command"
(cd "$WORK" && ditto -c -k --sequesterRsrc --keepParent "Установить Речку.command" "Install-Rechka.zip")

NOTES="Речка ${VERSION}, сборка ${STAMP} (коммит ${COMMIT}). Mac на Apple Silicon (M1 и новее).

Установка одной строкой в Терминале:
\`\`\`
curl -fsSL https://raw.githubusercontent.com/${REPO}/${BRANCH}/install.sh | bash
\`\`\`
Или скачайте «Install-Rechka.zip», откройте «Установить Речку.command».
Первый раз: Системные настройки → Конфиденциальность и безопасность → «Всё равно открыть»."

echo "== Выпуск $TAG из $DMG"
gh release create "$TAG" \
  --repo "$REPO" \
  --target "$BRANCH" \
  --title "Речка ${VERSION} (${STAMP})" \
  --notes "$NOTES" \
  --latest \
  "$WORK/Rechka_aarch64.dmg" \
  "$WORK/Install-Rechka.zip"

echo
echo "ГОТОВО: https://github.com/$REPO/releases/tag/$TAG"
echo "Установка: curl -fsSL https://raw.githubusercontent.com/${REPO}/${BRANCH}/install.sh | bash"
