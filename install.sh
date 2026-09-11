#!/bin/bash
set -e
# AniAnglia macOS — установщик для ветки arena/01a090fc-anianglia-macos
# Использование: bash install.sh  или  chmod +x install.sh && ./install.sh
# Требуется: macOS 13+, Xcode из App Store, Homebrew

echo "=== AniAnglia macOS Installer ==="
echo "Ветка: arena/01a090fc-anianglia-macos"
echo ""

# 1. Проверка Xcode
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "✗ Xcode не найден. Установи Xcode из App Store и выполни: xcode-select --install"
  exit 1
fi
echo "✓ Xcode: $(xcodebuild -version | head -n1)"

# 2. Homebrew + xcodegen
if ! command -v brew >/dev/null 2>&1; then
  echo "→ Устанавливаю Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # для Apple Silicon
  if [ -f /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "→ Устанавливаю xcodegen..."
  brew install xcodegen
else
  echo "✓ xcodegen уже установлен: $(xcodegen --version 2>&1 | head -n1)"
fi

# 3. Клонирование (если уже в папке проекта — пропускаем)
if [ -d "AniAnglia-macOS/.git" ]; then
  echo "→ Репозиторий уже склонирован, обновляю..."
  cd AniAnglia-macOS
  git fetch origin
elif [ -f "project.yml" ] && [ -d "Sources/AniAnglia" ]; then
  echo "→ Уже внутри AniAnglia-macOS"
else
  echo "→ Клонирую https://github.com/owlclockl/AniAnglia-macOS.git ..."
  # удаляем пустую папку если была
  rm -rf AniAnglia-macOS 2>/dev/null || true
  git clone https://github.com/owlclockl/AniAnglia-macOS.git
  cd AniAnglia-macOS
fi

# 4. Переключение на нужную ветку
echo "→ Переключаюсь на arena/01a090fc-anianglia-macos..."
git fetch origin arena/01a090fc-anianglia-macos
git checkout arena/01a090fc-anianglia-macos
git pull --ff-only origin arena/01a090fc-anianglia-macos || true

# 5. Генерация проекта
echo "→ Генерирую AniAnglia.xcodeproj..."
xcodegen generate

# 6. Открытие
echo ""
echo "✓ Готово! Открываю проект..."
open AniAnglia.xcodeproj

echo ""
echo "=== Дальше в Xcode ==="
echo "1. Выбери сверху 'My Mac' как destination"
echo "2. Нажми Cmd+R для запуска или Cmd+B для сборки"
echo "3. Для релизного .app: Product → Archive"
echo ""
echo "Или собери из терминала:"
echo "  xcodebuild -project AniAnglia.xcodeproj -scheme AniAnglia -configuration Release -destination 'platform=macOS' build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual"
