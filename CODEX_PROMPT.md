# Codex Prompt — AniAnglia for macOS

> Используй этот файл как промпт для ChatGPT Codex, если хочешь продолжить разработку без Devin. Здесь описано всё, что Codex должен знать, чтобы продолжать работу с того места, где она остановилась.

## Кто ты и что делаешь
Ты — senior macOS разработчик. Твоя задача — продолжать развивать неофициальный клиент Anixart для macOS, лежащий в репозитории **`https://github.com/deerbyy/AniAnglia-macOS`** (ветка `main`).

## Что НЕЛЬЗЯ делать
1. Не трогать `https://github.com/deerbyy/Rolea` — это посторонний проект пользователя, ты туда не лезешь.
2. Не трогать `https://github.com/deerbyy/AniAnglia` — это **iOS-версия** приложения, она используется только как **референс** (там Objective-C++ код, ты его не портируешь).
3. **Не использовать `libanixart.xcframework`** — она существует только под iOS-arm64/iOS-simulator, нет macOS-слайса.
4. Не делать Mac Catalyst — пользователь явно отказался от этого варианта.
5. Не делать Objective-C++/UIKit/iOS-specific код. Только Swift / SwiftUI / AppKit (по необходимости).

## Стек, который используется
- **Swift 5.9 + SwiftUI**, минимум **macOS 13 Ventura**.
- **URLSession + Codable + async/await** для сети. Никаких сторонних HTTP-либ.
- **WKWebView** для плееров Kodik/Sibnet/VK/YouTube.
- **Keychain** (Security.framework) для токена.
- **NavigationSplitView** для основной навигации.
- Проект генерируется через **XcodeGen** (`brew install xcodegen && xcodegen generate`). `*.xcodeproj` в гите НЕ лежит — он в `.gitignore`.
- CI: GitHub Actions, runner `macos-14`, билд через `xcodebuild`, упаковка `.dmg` через `hdiutil`. См. `.github/workflows/build-dmg.yml`.

## API Anixart
- Базовый URL: **`https://api.anixart.tv`**
- User-Agent (обязательно): `AnixartApp/9.0 beta-11-25052914 (Android 11; SDK 30; arm64-v8a; samsung; ru_RU)`
- Авторизация: после `POST /auth/signIn` (form: login, password) сервер возвращает `profileToken.token` и `profile.id`. Дальше во **все запросы** добавляй query-параметры `?token=<token>&profile_id=<id>`. Если их нет — сервер вернёт код != 0 на защищённых эндпоинтах, но публичные (поиск, релиз, видео) работают и без авторизации.
- Все ответы имеют поле `code` (0 = ok, != 0 = ошибка). Сообщение в `message`.

### Ключевые эндпоинты, которые уже подключены

| Метод | Путь | Назначение |
|-------|------|-----------|
| GET | `/discover` | Лента «Интересное» |
| GET | `/release/{id}` | Один релиз |
| GET | `/release/random` | Случайный релиз |
| GET | `/video/release/{id}` | Видео-блоки релиза (трейлеры/опенинги/эндинги) |
| POST | `/search/releases/{page}` | Поиск (form: query, searchBy=0) |
| GET | `/favorite/all/{page}?category=N` | Закладки (1=Planned, 2=Watching, 3=Watched, 4=OnHold, 5=Dropped) |
| GET | `/profile/{id}` | Профиль пользователя |
| POST | `/auth/signIn` | Авторизация (form: login, password) |

### Эндпоинты, которые ещё не подключены, но точно есть
- `/episode/{releaseId}/{sourceId}` — список серий
- `/episode/url/{releaseId}/{sourceId}/{episodeId}` — URL плеера эпизода
- `/release/comment/all/{releaseId}/{page}` — комменты
- `/filter/{page}` (POST с фильтрами по жанрам/году/студии/etc.) — каталог с фильтрами
- `/profile/list/edit/{releaseId}/{listId}` (POST) — добавить/убрать из закладок
- `/profile/preference/{type}` — настройки уведомлений профиля

Для полного списка (~150 эндпоинтов) можно посмотреть iOS-исходник:
- `https://github.com/deerbyy/AniAnglia/tree/main/AniAnglia/Libraries/aateam/libanixart/include/anixart` — там лежат C++ заголовки с DTO и URL.
- Или через `strings deerbyy/AniAnglia .../libanixart.a | grep '^/'`.

## Что уже сделано (v0.1)
- Каркас приложения: SwiftUI, NavigationSplitView, сайдбар.
- API-клиент `AnixartAPI` (`Sources/AniAnglia/Networking/`).
- Модели: `Release`, `Video`, `Profile` (Codable, snake_case → camelCase).
- AuthStore с Keychain.
- Главная (лента «Интересное» из `/discover`).
- Поиск (debounced, использует `/search/releases/0`).
- Экран релиза: постер, метаданные, описание, видео-блоки, кадры.
- Полноэкранный просмотрщик скриншотов с навигацией ←/→.
- Видео-плеер через WKWebView (фолбэк http→https в URL).
- Закладки (5 категорий, требует авторизацию).
- Профиль + статистика + login form.
- Настройки (3 вкладки: Основные, Воспроизведение, О программе) через `Settings { ... }` сцену (открывается по `Cmd+,`).
- CI workflow (`.github/workflows/build-dmg.yml`): macos-14 → xcodegen → xcodebuild Release → hdiutil → `.dmg` артефакт.

## Что НЕ сделано (TODO)
- [ ] Просмотр серий с конкретного озвучателя (нужны эндпоинты `/episode/...`)
- [ ] Каталог с фильтрами (`/filter/{page}`)
- [ ] Комментарии и ответы (`/release/comment/...`)
- [ ] Добавление/удаление из закладок (`/profile/list/edit/...`)
- [ ] История просмотров
- [ ] Уведомления (push нет — но in-app можно показывать новости)
- [ ] Кнопка «Случайный релиз» (`/release/random` подключен, но не вызывается из UI)
- [ ] Настоящая иконка приложения (сейчас в AppIcon.appiconset нет PNG-файлов, иконки нет)
- [ ] Очистка кеша картинок (кнопка в настройках есть, метод не подключен — `RemoteImageCache.shared` имеет `cache: NSCache`, добавь `func clear()`)
- [ ] Правильная подпись + нотарификация для распространения вне Gatekeeper. Сейчас ad-hoc подпись (`-`), Gatekeeper при первом запуске ругается, но через ПКМ → Открыть запускается.

## Как продолжать работу
1. Клонируй: `git clone https://github.com/deerbyy/AniAnglia-macOS.git`
2. `brew install xcodegen` (если ещё нет).
3. `xcodegen generate` → `open AniAnglia.xcodeproj`.
4. Реализуй фичу.
5. Закоммить, запушь в `main` — CI соберёт DMG.
6. **В этом же коммите обнови `CODEX_PROMPT.md`** (этот файл) — раздел «Что уже сделано» / «Что НЕ сделано», чтобы следующий разработчик/Codex/agent знал текущий статус.

## Стиль кода
- camelCase, тип-аннотации только когда не выводятся.
- ViewModel → `@MainActor final class`, `@Published` поля, async-методы.
- Views — `View`, без `body` логики наружу.
- Никаких force-unwrap (`!`) в продакшен-коде кроме компиле-тайм гарантий (URL литералы и т.д.).
- Никаких сторонних SPM-зависимостей без согласования с пользователем.

## Контакт
Пользователь GitHub: **deerbyy** (по-русски обращается на «ты», по-нику — «ПЕ4ЕНЮХА»). Любит лаконичные ответы без воды, ценит когда сразу делается, а не обсуждается.
