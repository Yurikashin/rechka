#!/bin/bash
# Установка «Речки» на любой Mac с Apple Silicon (M1 и новее).
#   curl -fsSL https://raw.githubusercontent.com/Yurikashin/rechka/dictovka/install.sh | bash
#
# Скачивает последнюю версию с GitHub Releases, ставит в «Программы» и запускает.
# Файлы, скачанные через curl, macOS не помечает как «из интернета», поэтому
# ошибок «повреждено» / «не удаётся проверить» не будет.
set -euo pipefail

REPO="Yurikashin/rechka"
ASSET="Rechka_aarch64.dmg"
URL="https://github.com/${REPO}/releases/latest/download/${ASSET}"
BUNDLE_ID="ru.yurikashin.dictovka"
APP_NAME="Rechka.app"

say() { printf '\n== %s\n' "$*"; }
fail() { printf '\nОШИБКА: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "Речка работает только на macOS."
[ "$(uname -m)" = "arm64" ] || fail "Нужен Mac на Apple Silicon (M1 и новее). Этот Mac — $(uname -m)."

DEST_DIR="/Applications"
if [ ! -w "${DEST_DIR}" ]; then
  DEST_DIR="${HOME}/Applications"
  mkdir -p "${DEST_DIR}"
  say "Нет прав на запись в /Applications — ставлю в ${DEST_DIR}"
fi

WORK="$(mktemp -d)"
MOUNT="${WORK}/mnt"
cleanup() {
  hdiutil detach "${MOUNT}" -quiet >/dev/null 2>&1 || true
  rm -rf "${WORK}"
}
trap cleanup EXIT

say "Скачиваю Речку с GitHub…"
curl -fL --retry 3 --progress-bar -o "${WORK}/${ASSET}" "${URL}" \
  || fail "Не удалось скачать ${URL}. Проверьте интернет."

say "Открываю образ…"
mkdir -p "${MOUNT}"
hdiutil attach "${WORK}/${ASSET}" -nobrowse -readonly -quiet -mountpoint "${MOUNT}" \
  || fail "Не удалось открыть скачанный образ."
[ -d "${MOUNT}/${APP_NAME}" ] || fail "В образе нет ${APP_NAME}."

say "Закрываю запущенную Речку, если она открыта…"
osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true
sleep 1
pkill -f "/${APP_NAME}/Contents/MacOS/" >/dev/null 2>&1 || true

# Старая версия под прежним именем (Dictovka.app) с тем же идентификатором.
for old in "${DEST_DIR}/Dictovka.app" "${DEST_DIR}/${APP_NAME}"; do
  if [ -d "${old}" ]; then
    id="$(defaults read "${old}/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
    if [ "${id}" = "${BUNDLE_ID}" ]; then
      rm -rf "${old}" || fail "Не удалось удалить старую версию: ${old}"
    fi
  fi
done

say "Устанавливаю в ${DEST_DIR}…"
ditto "${MOUNT}/${APP_NAME}" "${DEST_DIR}/${APP_NAME}" || fail "Не удалось скопировать программу."
xattr -cr "${DEST_DIR}/${APP_NAME}" 2>/dev/null || true

say "Запускаю Речку…"
open "${DEST_DIR}/${APP_NAME}"

cat <<'EOF'

ГОТОВО. Речка установлена и запущена.
Дальше:
  1. Разрешите доступ к микрофону, когда macOS спросит.
  2. Системные настройки → Конфиденциальность и безопасность →
     Универсальный доступ → включите Rechka (нужно, чтобы вставлять текст).
  3. При первом запуске Речка скачает модель распознавания (нужен интернет).
Диктовка: зажмите клавишу из настроек Речки, говорите, отпустите.
Обновить Речку — запустите эту же установку ещё раз.
EOF
