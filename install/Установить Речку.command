#!/bin/bash
# Двойной щелчок — скачивает и устанавливает последнюю «Речку».
# Первый раз macOS спросит разрешение:
#   Системные настройки → Конфиденциальность и безопасность → «Всё равно открыть».
curl -fsSL https://raw.githubusercontent.com/Yurikashin/rechka/dictovka/install.sh | bash
echo
read -n 1 -s -r -p "Нажмите любую клавишу, чтобы закрыть окно…"
echo
