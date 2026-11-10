#!/bin/bash
# Сборка Dictovka.dmg на этом Mac (бесплатно, без Apple Developer аккаунта).
# Запуск: двойной клик в Finder или `bash собрать-dmg.command` в Терминале.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
echo "== Dictovka: сборка .dmg в $ROOT"

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

# 5. Зависимости и сборка
bun install
bun run tauri build --bundles app,dmg --config src-tauri/tauri.dictovka.conf.json

# 6. Постоянная подпись (чтобы macOS не сбрасывала разрешения после каждой пересборки)
APP_SRC="src-tauri/target/release/bundle/macos/Dictovka.app"
IDENT="Dictovka Local Signing"
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
echo "Подписываю Dictovka сертификатом «${IDENT}»…"
echo "(если macOS спросит доступ к ключу для codesign — нажмите «Разрешать всегда»)"
codesign --force --options runtime --entitlements src-tauri/Entitlements.plist --sign "${IDENT}" "$APP_SRC"
codesign --verify --strict "$APP_SRC"
codesign -dr - "$APP_SRC" 2>&1 | tail -1

# 7. Пересобираем .dmg из подписанного приложения и копируем рядом
DMG="$(ls -t src-tauri/target/release/bundle/dmg/*.dmg | head -1)"
STAGE="$(mktemp -d)"
ditto "$APP_SRC" "$STAGE/Dictovka.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname Dictovka -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
mkdir -p "$ROOT/../готовый-dmg"
cp "$DMG" "$ROOT/../готовый-dmg/"
echo
echo "ГОТОВО: $(cd "$ROOT/../готовый-dmg" && pwd)/$(basename "$DMG")"

# 8. Установка в «Программы» и запуск (заменяет только прошлую сборку Dictovka)
APP_DST="/Applications/Dictovka.app"
if [ -d "$APP_SRC" ]; then
  osascript -e 'tell application id "ru.yurikashin.dictovka" to quit' >/dev/null 2>&1 || true
  sleep 2
  rm -rf "$APP_DST"
  ditto "$APP_SRC" "$APP_DST"
  touch "$APP_DST"   # чтобы Finder и Dock обновили иконку
  echo "Установлено: $APP_DST"
  open "$APP_DST"
fi
