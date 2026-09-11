# AniAnglia for macOS

Неофициальный нативный клиент [Anixart](https://anixart.tv) для macOS.

## Стек
- **Swift 5.9 + SwiftUI** (NavigationSplitView, async/await)
- **Минимум macOS 13 Ventura** (Apple Silicon + Intel)
- **URLSession + Codable** — прямой доступ к `https://api.anixart.tv` без сторонних библиотек
- **WKWebView** — встроенные плееры Kodik / Sibnet / VK / YouTube
- **Keychain** — хранение токена авторизации

## Быстрая установка (ветка с исправлениями)

Скопируй в Терминал целиком — установщик сам поставит `xcodegen`, склонирует ветку `arena/01a090fc-anianglia-macos` и откроет проект:

```bash
brew install xcodegen
git clone https://github.com/owlclockl/AniAnglia-macOS.git
cd AniAnglia-macOS
git checkout arena/01a090fc-anianglia-macos
xcodegen generate
open AniAnglia.xcodeproj
```

Одна команда (скачает и запустит `install.sh`):

```bash
curl -fsSL https://raw.githubusercontent.com/owlclockl/AniAnglia-macOS/arena/01a090fc-anianglia-macos/install.sh | bash
```
Или если репозиторий уже склонирован:
```bash
chmod +x install.sh && ./install.sh
```

## Сборка

Проект генерируется через [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `AniAnglia.xcodeproj` не закоммичен.

```bash
brew install xcodegen
xcodegen generate
open AniAnglia.xcodeproj
```

## CI / DMG
GitHub Actions (`.github/workflows/build-dmg.yml`) на каждый push в `main` собирает ad-hoc подписанный `.dmg` и кладёт в артефакты.

Скачать последнюю сборку: [Actions → Build DMG → AniAnglia-macOS-DMG](https://github.com/deerbyy/AniAnglia-macOS/actions).

## Установка
- Скачай `.dmg` из артефактов
- Открой → перетащи `AniAnglia.app` в `/Applications`
- Первый запуск: ПКМ по иконке → «Открыть» (т.к. подпись ad-hoc, Gatekeeper попросит подтверждение).

## Связанные репозитории
- iOS-версия: [deerbyy/AniAnglia](https://github.com/deerbyy/AniAnglia)

## Статус (v0.1)
- [x] Базовый каркас + сайдбар
- [x] Главная (лента «Интересное»)
- [x] Поиск релизов
- [x] Экран релиза (постер, описание, видео-блоки, скриншоты)
- [x] Плеер видео в WKWebView
- [x] Просмотрщик скриншотов с навигацией
- [x] Авторизация (login + password → Keychain)
- [x] Закладки (5 категорий)
- [x] Профиль + статистика
- [x] Настройки

Дальше: фильтры каталога, комментарии, история просмотров, эпизоды/серии, экспорт списка.
