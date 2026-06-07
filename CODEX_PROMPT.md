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
- **WKWebView** для плееров Kodik/Sibnet/Libria/VK/YouTube; YouTube грузится прямым запросом с HTTP `Referer: https://anixart.tv/`, iframe-плееры — через HTML wrapper с origin/referrer.
- **UserDefaults** для токена сессии: CI-сборки подписаны ad-hoc, и доступ к Keychain из каждой новой сборки вызывал диалоги пароля macOS.
- **NavigationSplitView** для основной навигации.
- Проект генерируется через **XcodeGen** (`brew install xcodegen && xcodegen generate`). `*.xcodeproj` в гите НЕ лежит — он в `.gitignore`.
- CI: GitHub Actions, runner `macos-15`, билд через `xcodebuild`, упаковка `.dmg` через `hdiutil`. См. `.github/workflows/build-dmg.yml`.

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
| POST | `/search/releases/{page}` | Поиск (JSON: query, searchBy=0..4) |
| POST | `/filter/{page}` | Каталог с фильтрами (JSON боди) |
| GET | `/episode/{releaseId}` | Список озвучек (`types`) |
| GET | `/episode/{releaseId}/{typeId}` | Список плееров (`sources`) |
| GET | `/episode/{releaseId}/{typeId}/{sourceId}` | Список серий |
| GET | `/profile/list/all/{profileId}/{cat}/{page}` | Закладки по категории (1–5) |
| GET | `/profile/list/add/{cat}/{releaseId}` | Добавить в категорию |
| GET | `/profile/list/delete/0/{releaseId}` | Убрать из закладок |
| GET | `/profile/{id}` | Профиль пользователя |
| POST | `/auth/signIn` | Авторизация (form: login, password) |
| GET | `/release/comment/all/{releaseId}/{page}?sort=N` | Комменты (sort: 0=новые, 1=старые, 2=топ) |
| GET | `/episode/watch/{releaseId}/{sourceId}/{position}` | Отметить серию просмотренной |
| GET | `/episode/unwatch/{releaseId}/{sourceId}/{position}` | Снять отметку просмотра |
| GET | `/history/{page}` | История просмотров (требует авторизацию) |
| POST | `/release/comment/add/{releaseId}` | Добавить комментарий (JSON: message, is_spoiler, parent_comment_id) |
| GET | `/release/comment/vote/{commentId}/{value}` | Лайк/дизлайк/снять (value: 1, -1, 0) |
| GET | `/release/vote/add/{releaseId}/{stars}` | Оценить релиз (1–5) |
| GET | `/release/vote/delete/{releaseId}` | Убрать оценку |

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
- `/profile/preference/{type}` — настройки уведомлений профиля
- Примечание: API Anixart **не имеет** эндпоинта `/notification/all` — уведомления реализованы только через пуш-уведомления.

Для полного списка (~150 эндпоинтов) можно посмотреть iOS-исходник:
- `https://github.com/deerbyy/AniAnglia/tree/main/AniAnglia/Libraries/aateam/libanixart/include/anixart` — там лежат C++ заголовки с DTO и URL.
- Или через `strings deerbyy/AniAnglia .../libanixart.a | grep '^/'`.

## Что уже сделано (v0.11 — текущий статус)

**Скелет (v0.1):**
- Каркас: SwiftUI, NavigationSplitView, сайдбар.
- API-клиент `AnixartAPI` (`Sources/AniAnglia/Networking/`), публичный `auth: AuthStore`, методы `get/post/postJSON`.
- Модели: `Release`, `Video`, `Profile`, `Episode/EpisodeType/EpisodeSource` (Codable, snake_case → camelCase via `.convertFromSnakeCase`).
- **НЕ добавляй** явные `CodingKey` override для snake_case-полей — стратегия работает против вас (вызывает двойное переименование).
- AuthStore с локальным хранилищем сессии без обращения к Keychain, чтобы ad-hoc CI-сборки не запрашивали пароль при запуске.
- CI workflow (`.github/workflows/build-dmg.yml`): **macos-15** (Xcode 16) → xcodegen → xcodebuild Release → hdiutil → `.dmg`.

**Экраны:**
- **Главная**: «Сейчас смотрят» (`/discover/watching/0`) + «Рекомендации» (если авторизован).
- **Каталог** (НОВОЕ): `CatalogView` с фильтрами сортировки/категории/статуса/года. Автодогрузка следующей страницы при прокрутке к последней карточке + ручная fallback-кнопка «Показать ещё». POST `/filter/{page}`.
- **Поиск**: debounced, фокус на TextField автоматически (`@FocusState`), автодогрузка следующей страницы при прокрутке к последней карточке, дедупликация результатов.
- **Релиз**: постер + метаданные + видео-блоки + кадры. НОВОЕ: кнопки «Смотреть» и выпадающее меню закладок (5 категорий + «Убрать»). НОВОЕ v0.16: блок «В коллекциях» умеет менять `CollectionSort`, искать по загруженным коллекциям, показывать счётчик `отфильтровано/всего` и догружать следующие страницы `/collection/all/release/{releaseId}/{page}`. НОВОЕ v0.17: блок «Видео» получил поиск по названию/хостингу/url, фильтр категории и счётчик `отфильтровано/всего`.
- **Серии** (НОВОЕ): `EpisodesView` — пикер озвучек (`types`), пикер плееров (`sources`), список серий с бейджами «просмотрено». НОВОЕ v0.15: поиск по сериям/host, фильтр «Все / Не просмотрено / Просмотрено», счётчик `отфильтровано/всего`, счётчик просмотренных и кнопка «Продолжить» на первую непросмотренную серию. Плеер в sheet через WKWebView; YouTube открывается прямым embed-запросом с Referer, Kodik/Libria — iframe-wrapper’ом, схема-лесс URL `//...` обрабатывается.
- **Скриншоты**: полноэкранный просмотрщик с навигацией ←/→.
- **Закладки**: список по категориям (1–5), из экрана релиза добавляем/убираем.
- **Профиль**: статистика + login form. НОВОЕ v0.18: у чужого профиля плитки пяти списков открывают публичный `ProfileListView` по `/profile/list/all/{profileId}/{cat}/{page}` с сортировкой Anixart, локальным поиском, пагинацией и переходами в релизы.
- **Настройки** (`Cmd+,`): Основные (НОВОЕ: «Очистить кэш» работает — `RemoteImageCache.shared.clear()`), Воспроизведение, О программе.
- **Тулбар** (НОВОЕ): `⚡️ Случайный релиз` (Cmd+Shift+R) и `🔎 Поиск` (Cmd+K — фокус на вкладку с поиском).
- **Иконка** (v0.2): своя иконка (пурпурный градиент + play-треугольник + «A»), все размеры 16—1024 в `Resources/Assets.xcassets/AppIcon.appiconset`.
- **Исправление краша Swift Concurrency (v0.3)**: `async let` + `defer` вызывал фатальный `swift_task_dealloc → asyncLet_finish_after_task_completion`. Рефактор на простой последовательный `try await` в `HomeView.load()` и `ReleaseDetailView.load()`. **НИКОГДА** не используй `async let` вместе с `defer` в @MainActor контексте.
- **Глобальный вход (v0.3)**: `Features/Account/AccountToolbar.swift` — кнопка в тулбаре справа. Когда не вошёл — «Войти» вызывает sheet `LoginSheet`. Когда вошёл — показывает аватар + логин с меню «Открыть профиль / Выйти». Читаемые ошибки логина (code 2/3/4/5).
- **Комментарии (v0.4)**: `Features/Release/CommentsView.swift` встроен в `ReleaseDetailView`. Сортировка топ/новые/старые, ленивая пагинация, раскрытие спойлеров.
- **Навигация по авторам комментариев (v0.12)**: `Common/CommentAuthorLink.swift` даёт кликабельный аватар/логин автора с переходом на `ProfileRoute`. Подключено в комментариях релиза и «Комментариях недели» на главной; у комментариев недели ссылка на релиз/коллекцию теперь отдельная, чтобы не было вложенных `NavigationLink`.
- **Ответы на комментарии (v0.7)**: у комментариев есть раскрываемая ветка ответов через `/release/comment/replies/{id}/{page}`, догрузка следующих страниц, reply composer с `parent_comment_id` и спойлер-флагом, голосование работает и для ответов.
- **Управление своими комментариями (v0.7)**: для комментариев текущего профиля показывается меню `Редактировать / Удалить`; редактирование идёт через `/release/comment/edit/{id}` с `message` и `is_spoiler`, удаление — через `/release/comment/delete/{id}`. Локальный список обновляется без полной перезагрузки.
- **Друзья профиля (v0.8)**: `GET /profile/friend/all/{profileId}/{page}`, `ProfilesResponse`, `ProfileRoute`. В профиле отображается горизонтальный список друзей с аватаром/online/status, кнопкой догрузки страниц и переходом на профиль друга. У чужого профиля счётчики списков открывают публичные списки этого профиля, а не локальные закладки текущего аккаунта.
- **Заявки в друзья (v0.11)**: `GET /profile/friend/requests/{type}/{page}`, `/last`, `request/send`, `request/remove`, `request/hide`. В своём профиле есть сегменты входящие/исходящие, пагинация, принять/отклонить/скрыть входящую и отменить исходящую заявку; на чужом профиле есть кнопка «Добавить в друзья». Типы запросов: входящие `0`, исходящие `1`.
- **Поиск по друзьям/заявкам (v0.12)**: `Profile.matchesProfileQuery(_:)`, локальные поля поиска в секциях друзей и заявок. Фильтр ищет по id, логину, статусу, соцссылкам и ролям среди уже загруженных страниц, пагинация «Ещё» остаётся доступной.
- **Улучшения коллекций (v0.13)**: в `CollectionDetailView` автор коллекции стал ссылкой на `ProfileRoute`; у списка релизов коллекции появился локальный поиск через `Release.matchesLibraryQuery`, счётчик отфильтровано/всего и пустое состояние без сброса пагинации.
- **Поиск и сортировка коллекций (v0.14)**: `CollectionsView` получил локальный поиск по загруженным коллекциям через `AnixartCollection.matchesLibraryQuery`, счётчик отфильтровано/всего, пустое состояние с кнопкой догрузки и picker `CollectionSort` для публичного режима (`/collection/all/{page}`).
- **История просмотров (v0.4)**: новый таб в сайдбаре (`SidebarItem.history`), `Features/History/HistoryView.swift`. Требует авторизацию (`/history/{page}`).
- **Автодогрузка длинных списков (v0.9)**: Search, Catalog, Collections, CollectionDetail и History вызывают `loadMoreIfNeeded` на последней карточке и показывают нижний spinner во время догрузки. Закладки не требуют отдельной автодогрузки в UI: `BookmarkSyncStore` уже забирает все страницы аккаунта для избранного, избранных коллекций и 5 категорий списков.
- **Локальный поиск в библиотеке (v0.10)**: `BookmarksView` и `HistoryView` получили поисковые поля. Фильтрация идёт через `Release.matchesLibraryQuery` и `AnixartCollection.matchesLibraryQuery`: русское/оригинальное/альтернативное название, год, страна, студия, режиссёр, автор, описание, жанры, статус/категория; у коллекций — название, описание, автор и даты.
- **Отметка серии просмотренной (v0.4)**: кнопка-галочка в `EpisodeRow`. Оптимистичный апдейт с откатом при ошибке. Авто-пометка при закрытии плеера.
- **Мультиселект жанров (v0.5)**: `Features/Catalog/GenresPickerButton.swift` — popover с чекбоксами на 45 жанров из `Models/AnixartGenres.swift` (извлечены из iOS-источника `LibanixartApi.mm`). Переключатель «Исключить выбранные» (`is_genres_exclude_mode`).
- **Отправка комментариев + лайки (v0.5)**: композер в `CommentsView` с TextEditor и спойлер-флагом. Под каждым комментарием — кнопки thumbs up/down (`/release/comment/vote/{id}/{value}`).
- **Оценка релиза звёздами (v0.5)**: 5 звёзд на `ReleaseDetailView` (только для авторизованных). Тап по той же звезде убирает оценку. `Release.yourVote` добавлен в модель.
- **Фикс сайдбара (v0.6)**: в предыдущей версии кнопки сайдбара не отвечали из-за `Section` + Optional binding. Теперь `List(SidebarItem.allCases, id: \.self, selection: $selection)` — это стабильный паттерн на macOS. **НЕ** используй `.tag(Optional(item))` + `Section` — съедает тапы.
- **Полный экран Профиля (v0.6)**: аватар + логин + статус + дата регистрации + кнопки Обновить/Выйти. Сетка статистики кликабельна. Дальше 5 секций-превью (по всем категориям закладок) — горизонтальный скролл с до 8 карточками плюс кнопка «Все →» переходит на вкладку Закладки с нужной категорией.
- **Централизованный navigationDestination (v0.6)**: `navigationDestination(for: Release.self)` вынесен на коронь NavigationStack в ContentView — из любого вложенного экрана (в т.ч. из Профиля) можно писать `NavigationLink(value: release)`. Дублирующие `navigationDestination(for: Release.self)` из дочерних вью удалены.
- **AppState.selectSidebar / openRelease (v0.6)**: новые helpers для навигации между вкладками с опциями (например «открыть Закладки с категорией 'Brosheno'»).

## Что НЕ сделано (TODO)
- [ ] Настройки профиля (изменение логина/пароля, аватара).
- [ ] Настоящая подпись + нотарификация для распространения вне Gatekeeper.

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
