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
| GET | `/discover/watching/{page}` | Лента «Сейчас смотрят» |
| GET | `/discover/recommendations/{page}` | Персональные рекомендации |
| GET | `/release/{id}` | Один релиз |
| GET | `/release/random` | Случайный релиз |
| GET | `/video/release/{id}` | Видео-блоки релиза |
| POST | `/search/releases/{page}` | Поиск (form: query, searchBy=0) |
| POST | `/filter/{page}` | Каталог с фильтрами (JSON боди) |
| GET | `/episode/{releaseId}` | Список озвучек (`types`) |
| GET | `/episode/{releaseId}/{typeId}` | Список плееров (`sources`) |
| GET | `/episode/{releaseId}/{typeId}/{sourceId}` | Список серий |
| GET | `/profile/list/all/{profileId}/{cat}/{page}` | Закладки по категории (1–5) |
| GET | `/profile/list/add/{cat}/{releaseId}` | Добавить в категорию |
| GET | `/profile/list/delete/0/{releaseId}` | Убрать из закладок |
| GET | `/profile/{id}` | Профиль пользователя |
| POST | `/auth/signIn` | Авторизация (form: login, password) |

#### `/filter/{page}` JSON-боди (поля опциональные):
```json
{
  "sort": 3,                  // 0=обновлению, 1=оценка, 2=год, 3=популярность
  "category": 1,              // 1=сериал, 2=фильм, 3=OVA, 4=ONA, 5=спешл
  "status": 1,                // 1=вышел, 2=анонс, 3=онгоинг
  "start_year": 2015,
  "end_year": 2024,
  "country": "Япония",
  "genres": ["экшн", "фэнтези"],
  "is_genres_exclude_mode": false
}
```

### Эндпоинты, которые ещё не подключены, но точно есть
- `/release/comment/all/{releaseId}/{page}` — комменты к релизу
- `/episode/watch/{releaseId}/{sourceId}/{position}` (POST) — пометить серию просмотренной
- `/profile/preference/{type}` — настройки уведомлений профиля

Для полного списка (~150 эндпоинтов) можно посмотреть iOS-исходник:
- `https://github.com/deerbyy/AniAnglia/tree/main/AniAnglia/Libraries/aateam/libanixart/include/anixart` — там лежат C++ заголовки с DTO и URL.
- Или через `strings deerbyy/AniAnglia .../libanixart.a | grep '^/'`.

## Что уже сделано (v0.2 — текущий статус)

**Скелет (v0.1):**
- Каркас: SwiftUI, NavigationSplitView, сайдбар.
- API-клиент `AnixartAPI` (`Sources/AniAnglia/Networking/`), публичный `auth: AuthStore`, методы `get/post/postJSON`.
- Модели: `Release`, `Video`, `Profile`, `Episode/EpisodeType/EpisodeSource` (Codable, snake_case → camelCase via `.convertFromSnakeCase`).
- **НЕ добавляй** явные `CodingKey` override для snake_case-полей — стратегия работает против вас (вызывает двойное переименование).
- AuthStore с Keychain.
- CI workflow (`.github/workflows/build-dmg.yml`): **macos-15** (Xcode 16) → xcodegen → xcodebuild Release → hdiutil → `.dmg`.

**Экраны:**
- **Главная**: «Сейчас смотрят» (`/discover/watching/0`) + «Рекомендации» (если авторизован).
- **Каталог** (НОВОЕ): `CatalogView` с фильтрами сортировки/категории/статуса/года. Пагинация через «Показать ещё». POST `/filter/{page}`.
- **Поиск**: debounced, фокус на TextField автоматически (`@FocusState`).
- **Релиз**: постер + метаданные + видео-блоки + кадры. НОВОЕ: кнопки «Смотреть» и выпадающее меню закладок (5 категорий + «Убрать»).
- **Серии** (НОВОЕ): `EpisodesView` — пикер озвучек (`types`), пикер плееров (`sources`), список серий с бейджами «просмотрено». Плеер в sheet через WKWebView, http→https rewrite, схема-лесс URL `//...` обрабатывается.
- **Скриншоты**: полноэкранный просмотрщик с навигацией ←/→.
- **Закладки**: список по категориям (1–5), из экрана релиза добавляем/убираем.
- **Профиль**: статистика + login form.
- **Настройки** (`Cmd+,`): Основные (НОВОЕ: «Очистить кэш» работает — `RemoteImageCache.shared.clear()`), Воспроизведение, О программе.
- **Тулбар** (НОВОЕ): `⚡️ Случайный релиз` (Cmd+Shift+R) и `🔎 Поиск` (Cmd+K — фокус на вкладку с поиском).
- **Иконка** (НОВОЕ): своя иконка (пурпурный градиент + play-треугольник + «A»), все размеры 16—1024 в `Resources/Assets.xcassets/AppIcon.appiconset`.

## Что НЕ сделано (TODO)
- [ ] Комментарии и ответы к релизу (`/release/comment/all/...`)
- [ ] Отметка серии как просмотренной из UI (эндпоинт `/episode/watch/...` еще не подключен)
- [ ] История просмотров отдельным экраном
- [ ] Навигация по жанрам в Каталоге (сейчас `genres` не выведен в UI — нужен мультиселект с известными жанрами)
- [ ] Настоящая подпись + нотарификация для распространения вне Gatekeeper. Сейчас ad-hoc подпись (`-`), Gatekeeper при первом запуске ругается, но через ПКМ → Открыть запускается.
- [ ] Авто-пагинация в закладках/поиске (сейчас всегда page=0).

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
