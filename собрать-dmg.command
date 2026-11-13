#!/bin/bash
# Сборка Речки (Rechka.dmg) на этом Mac (бесплатно, без Apple Developer аккаунта).
# Запуск: двойной клик в Finder или `bash собрать-dmg.command` в Терминале.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
echo "== Речка: сборка .dmg в $ROOT"

# 1. Xcode Command Line Tools
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Нужны Xcode Command Line Tools. Открываю установщик — после установки запустите скрипт снова."
  xcode-select --install || true
  exit 1
fi

# 2. Rust
if ! command -v cargo >/dev/null 2>&1; then
  if [ -f "$HOME/.cargo/env" ]; then source "$HOME/.cargo/env"; fi
fi
if ! command -v cargo >/dev/null 2>&1; then
  echo "Устанавливаю Rust (rustup)…"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
  source "$HOME/.cargo/env"
fi

# 3. Bun
export PATH="$HOME/.bun/bin:$PATH"
if ! command -v bun >/dev/null 2>&1; then
  echo "Устанавливаю Bun…"
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
fi

# 4. CMake (нужен для сборки движка распознавания transcribe-cpp/ggml)
if ! command -v cmake >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install cmake
  else
    echo "Устанавливаю CMake через pip…"
    python3 -m pip install --user cmake
    export PATH="$(python3 -m site --user-base)/bin:$PATH"
  fi
fi

echo "Версии: $(cargo --version) | bun $(bun --version) | $(cmake --version | head -1)"

# 5. Зависимости, версия сборки, ключ обновлений и сборка
bun install
# Каждая сборка получает свой номер: 0.10.<ГГДДДЧЧММ> (год, день года, время).
# По нему установленные Речки понимают, что вышло обновление.
BASE_VERSION="$(sed -n 's/.*"version": *"\([0-9]*\.[0-9]*\)\..*/\1/p' src-tauri/tauri.conf.json | head -1)"
BUILD_VERSION="${BASE_VERSION}.$(date +%y%j%H%M | sed 's/^0*//')"
export RECHKA_BUILD_VERSION="${BUILD_VERSION}"
# Ключ подписи обновлений: создаётся один раз и хранится только на этом Mac.
# ПОТЕРЯ КЛЮЧА = установленные Речки перестанут принимать обновления. Сделайте копию ~/.rechka.
KEY_DIR="${HOME}/.rechka"
KEY="${KEY_DIR}/updater.key"
if [ ! -f "${KEY}" ]; then
  echo "Создаю ключ подписи обновлений (один раз): ${KEY}"
  mkdir -p "${KEY_DIR}"
  chmod 700 "${KEY_DIR}"
  bun run tauri signer generate --ci -p "" -w "${KEY}"
fi
PUBKEY="$(tr -d '\n' < "${KEY}.pub")"
OVERRIDE="{\"version\":\"${BUILD_VERSION}\",\"plugins\":{\"updater\":{\"pubkey\":\"${PUBKEY}\"}}}"
echo "Версия сборки: ${BUILD_VERSION}"
bun run tauri build --bundles app,dmg --config src-tauri/tauri.rechka.conf.json --config "${OVERRIDE}"

# 6. Постоянная подпись (чтобы macOS не сбрасывала разрешения после каждой пересборки)
APP_SRC="src-tauri/target/release/bundle/macos/Rechka.app"
IDENT="Dictovka Local Signing"   # имя сертификата не менять: от него зависят выданные разрешения macOS
if ! security find-certificate -c "${IDENT}" >/dev/null 2>&1; then
  echo "Создаю локальный сертификат подписи «${IDENT}» (один раз)…"
  T="$(mktemp -d)"
  cat > "$T/cfg" <<CFG
[req]
distinguished_name = dn
prompt = no
[dn]
CN = ${IDENT}
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CFG
  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$T/key.pem" -out "$T/cert.pem" -config "$T/cfg" -extensions ext 2>/dev/null
  /usr/bin/openssl pkcs12 -export -inkey "$T/key.pem" -in "$T/cert.pem" \
    -name "${IDENT}" -out "$T/id.p12" -passout pass:dictovka
  security import "$T/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P dictovka -T /usr/bin/codesign
  rm -rf "$T"
fi
echo "Подписываю Речку сертификатом «${IDENT}»…"
echo "(если macOS спросит доступ к ключу для codesign — нажмите «Разрешать всегда»)"
# Подписываем чистую копию вне iCloud: метки iCloud/Finder мешают codesign
SIGN_DIR="$(mktemp -d)"
ditto --norsrc --noextattr --noqtn "$APP_SRC" "$SIGN_DIR/Rechka.app"
xattr -cr "$SIGN_DIR/Rechka.app"
APP_SRC="$SIGN_DIR/Rechka.app"
codesign --force --options runtime --entitlements src-tauri/Entitlements.plist --sign "${IDENT}" "$APP_SRC"
codesign --verify --strict "$APP_SRC"
codesign -dr - "$APP_SRC" 2>&1 | tail -1

# 6b. Пакет обновления: подписанная Речка в .tar.gz + подпись ключом обновлений
UPD_DIR="${ROOT}/../готовый-dmg/update"
rm -rf "${UPD_DIR}"
mkdir -p "${UPD_DIR}"
COPYFILE_DISABLE=1 tar -czf "${UPD_DIR}/Rechka.app.tar.gz" -C "${SIGN_DIR}" Rechka.app
TAURI_SIGNING_PRIVATE_KEY_PASSWORD="" bun run tauri signer sign -f "${KEY}" -p "" "${UPD_DIR}/Rechka.app.tar.gz"
echo "${BUILD_VERSION}" > "${UPD_DIR}/version.txt"
echo "Пакет обновления: ${UPD_DIR}"

# 7. Пересобираем .dmg из подписанного приложения и копируем рядом
DMG="$(ls -t src-tauri/target/release/bundle/dmg/*.dmg | head -1)"
STAGE="$(mktemp -d)"
ditto "$APP_SRC" "$STAGE/Rechka.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname Rechka -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
mkdir -p "$ROOT/../готовый-dmg"
cp "$DMG" "$ROOT/../готовый-dmg/"
echo
echo "ГОТОВО: $(cd "$ROOT/../готовый-dmg" && pwd)/$(basename "$DMG")"

# 8. Установка в «Программы» и запуск (заменяет только прошлую сборку этого же приложения)
APP_DST="/Applications/Rechka.app"
OLD_APP="/Applications/Dictovka.app"   # прежнее имя той же программы
if [ -d "$APP_SRC" ]; then
  if [ -d "$OLD_APP" ] && [ "$(defaults read "$OLD_APP/Contents/Info" CFBundleIdentifier 2>/dev/null)" = "ru.yurikashin.dictovka" ]; then
    osascript -e 'tell application id "ru.yurikashin.dictovka" to quit' >/dev/null 2>&1 || true
    sleep 1
    rm -rf "$OLD_APP"
    echo "Удалена прежняя версия: $OLD_APP"
  fi
  osascript -e 'tell application id "ru.yurikashin.dictovka" to quit' >/dev/null 2>&1 || true
  sleep 2
  rm -rf "$APP_DST"
  ditto "$APP_SRC" "$APP_DST"
  touch "$APP_DST"   # чтобы Finder и Dock обновили иконку
  echo "Установлено: $APP_DST"
  open "$APP_DST"
fi
