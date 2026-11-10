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

# 6. Копируем результат рядом
DMG="$(ls -t src-tauri/target/release/bundle/dmg/*.dmg | head -1)"
mkdir -p "$ROOT/../готовый-dmg"
cp "$DMG" "$ROOT/../готовый-dmg/"
echo
echo "ГОТОВО: $(cd "$ROOT/../готовый-dmg" && pwd)/$(basename "$DMG")"
open "$ROOT/../готовый-dmg"
