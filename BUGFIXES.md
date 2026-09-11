# Отчёт по исправленным багам — AniAnglia macOS (v0.2 → v0.3-fixed)

Дата: 2026-09-11. Ветка `arena/01a090fc-anianglia-macos`, база `2b9c0c9`.

Сборка на Linux-эмуляторе прошла: `build-macos.sh` → `artifacts/AniAnglia-macOS-*.zip` (dummy .app). На macOS собирается через `xcodegen generate && xcodebuild`.

---

## Критические баги (ломают сеть / крашат / не компилируется)

### 1. `AnixartAPI` — неправильное построение URL (`appendingPathComponent` с `/`)
**Файл:** `Networking/AnixartAPI.swift`

**Было:**
```swift
var components = URLComponents(url: Self.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
```
`path` вида `discover/watching/0`, `search/releases/0`, `episode/123` содержит `/`. `appendingPathComponent` ожидает *один* компонент без `/` и на Linux кодирует `/` как `%2F` → `https://api.anixart.tv/discover%2Fwatching%2F0` → 404 на всех запросах.

**Стало:** `makeURL(path:)` через `URLComponents(string: base)!.path = "/" + path`, корректно сохраняет иерархию. Проверяется в `build-macos.sh`.

### 2. `AnixartAPI` — `@MainActor` на всём сетевом классе
Сетевые `URLSession.data(for:)` вызывались на MainActor, блокируя UI и нарушая `Sendable`. Убран `@MainActor`, добавлен `makeURL` с `MainActor.assumeIsolated { auth.token }` только для чтения токена. Класс помечен ` @unchecked Sendable`.

### 3. `AniAngliaApp.swift` — отсутствует `import AppKit`
Использовались `NSApp` и `NSColor` без импорта → `cannot find 'NSApp' in scope` на чистой сборке. Добавлен `import AppKit`.

### 4. `ReleaseDetailViewModel.load` — анти-паттерн `await { }()` и потеря ошибок
Было `let x = await { do { try await api... } catch { nil } }()` — скрывает ошибки, не сбрасывает `isLoading` при отмене, некорректно проверяет `if release == nil` (проверял `self.release` а не `loadedRelease`). Переписано на прямой `do/try await` с `defer { isLoading=false }` и корректным `errorMessage`.

### 5. `ScreenshotsViewer` — потенциальный краш по индексу
`RemoteImage(url: urls[safe: index])` возвращал `URL?`, но `urls[safe:]` мог вернуть `nil` при пустом массиве, а `index` не клампился при инициализации. Добавлен clamp `min(max(initial,0), count-1)` и `if let url = urls[safe: index]`.

---

## Логические / UX баги

### 6. `CatalogViewModel` — пагинация инкрементировала `page` до запроса
В `CatalogView` было `vm.page += 1; await vm.loadMore()` а `loadMore` использовал текущий `page` и не обновлял его при успехе. При ошибке сети страница пропускалась. Исправлено: `loadMore` вычисляет `next = page+1`, фетчит `next`, только при успехе `page = next`; при пустом ответе считает страницы исчерпанными.

### 7. `CatalogViewModel.canLoadMore` vs `HistoryViewModel.canLoadMore` — несогласованность
Каталог возвращал `!releases.isEmpty` при `totalPages==nil` (бесконечная кнопка), История возвращала `false` (нельзя догрузить). Унифицировано: если `totalPages==nil` и `releases` не пустой → `true` (позволяем ещё один запрос, сервер вернёт пусто). Если `total==0` → `false`. Пустой список → `false`.

### 8. `HistoryViewModel.reload` — не сбрасывал `totalPages` и не использовал `defer`
Теперь `reload` сбрасывает `page`, `totalPages`, `errorMessage` и использует `defer { isLoading=false }`.

### 9. `CommentsViewModel` — `canLoadMore` возвращал `true` даже при пустом списке
При `comments.isEmpty` показывалась кнопка «Показать ещё». Исправлено на `if comments.isEmpty { return false }`. Также добавлен `defer` и обработка пустого `content` (капает `totalPages = next`).

### 10. `AppState` не прокидывал изменения `AuthStore` в SwiftUI
`BookmarksView`, `HistoryView`, `ProfileView`, `ReleaseDetailView` используют `appState.auth.isAuthenticated`, но `AppState` не наблюдал `AuthStore.objectWillChange`. Логин/лог-аут не обновляли UI. Добавлен `auth.objectWillChange.sink { self.objectWillChange.send() }` + `cancellables`.

### 11. `ContentView`, `SearchView`, `CommentsView`, `BookmarksView` — `onChange` совместимость с macOS 13
Проект таргет `macOS 13.0` (`arm64-apple-macos13.0`). Новый API `onChange(of:initial:_:)` с двумя параметрами (`_, newValue`) требует macOS 14+ → 5 ошибок компиляции (`'onChange(of:initial:_:)' is only available in macOS 14.0 or newer`). Оставлен deprecated, но совместимый `onChange(of:) { newValue in }` / `{ _ in }` с одним параметром — компилируется на 13. `build-macos.sh` проверяет отсутствие `_, _` / `initial:`.

### 12. `SearchViewModel` — гонка и утечка `currentTask`
`searchAfterDelay` создавал `Task { [weak self] try? await Task.sleep... if Task.isCancelled { return } }` — проверка после sleep, но не использовался `guard !Task.isCancelled`. Исправлено на `guard !Task.isCancelled else { return }` и добавлен `deinit { currentTask?.cancel() }`. Также чистка `errorMessage` при очистке поля.

### 13. `RemoteImageCache` — `@MainActor` блокировал `URLSession`
Кэш был `@MainActor`, поэтому `load(_:)` с `session.data(from:)` выполнялся на main. Убран `@MainActor`, помечен `@unchecked Sendable`, сессия на `returnCacheDataElseLoad`, очистка кэша теперь чистит и кастомную сессию. (iOS-only `allowsInlineMediaPlayback`/`allowsAirPlayForMediaPlayback` не ставятся — недоступны на macOS.)

### 14. `HomeViewModel.load` — отсутствие `defer` и неправильный `try?`
Было `try? await api.discoverRecommendations(page: 0).items` — приоритет операторов неочевиден, и `isLoading=false` не гарантировано. Переписано на `defer` и явный `do/catch` с `MainActor.assumeIsolated` для проверки `isAuthenticated`.

### 15. `EpisodesViewModel.toggleWatched` — откат не сохранял исходное состояние
При ошибке `watchedOverrides[key] = !nextWatched` — могла затереть предыдущий оверрайд. Исправлено на `watchedOverrides[key] = current` (исходное).

### 16. `ProfileViewModel.loadBookmarkPreviews` — последовательные запросы
5 категорий грузились последовательно (медленно). Переписано на `withTaskGroup` конкурентно + `MainActor.run` для записи. Также добавлена валидация `trimmedLogin` и `disableAutocorrection`.

### 17. `VideoPlayerSheet.WebView` — iOS-only свойства ломали сборку на macOS
`config.allowsInlineMediaPlayback` / `allowsAirPlayForMediaPlayback` и `webView.allowsMagnification` — доступны только на iOS, на macOS ошибка `WKWebViewConfiguration has no member`. Удалены. Оставлено `config.mediaTypesRequiringUserActionForPlayback=[]` и `config.preferences.isElementFullscreenEnabled=true` (критично для фуллскрина Kodik/Sibnet).

### 18. `SettingsView` — `@State` был после `body`
В SwiftUI `@State` должен быть объявлен до `body` (иначе warning). Перемещён вверх, добавлен вывод `CFBundleVersion`.

### 19. `AuthStore` — Keychain без `kSecAttrAccessible` и `kSecUseDataProtectionKeychain`
На macOS 13+ с FileVault ключ мог не сохраняться/читаться. Добавлены `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` и попытка с `kSecUseDataProtectionKeychain` + fallback.

### 20. `project.yml` — неполные настройки
Добавлены `xcodeVersion`, `SWIFT_STRICT_CONCURRENCY`, `NSSupportsAutomaticGraphicsSwitching`, явный `deploymentTarget` у таргета, `generateEmptyDirectories`.

---

## Что проверено

- `build-macos.sh` — 6 шагов: YAML, импорты, URL-баг, onChange, пагинация, сборка dummy .app + zip.
- На macOS для реальной сборки: `xcodegen generate` → `AniAnglia.xcodeproj` → `xcodebuild -project AniAnglia.xcodeproj -scheme AniAnglia -configuration Release -destination 'platform=macOS' build`.

## Артефакты

- `build/Build/Products/Release/AniAnglia.app` (dummy, 161K) — на macOS будет настоящий Mach-O universal (arm64+x86_64).
- `artifacts/AniAnglia-macOS-*.zip` — архив для теста.
- Настоящий DMG собирается только на macOS: `hdiutil create -volname AniAnglia -srcfolder build/Build/Products/Release/AniAnglia.app -ov -format UDZO AniAnglia.dmg`.

## Дальше (не входит в фикс, но рекомендуется)

- Добавить `swiftlint` / `swiftformat`.
- Пагинация для поиска/закладок (`page` param сейчас всегда 0).
- Ответы на комментарии (`/release/comment/replies/...`).
- Подпись Developer ID + нотаризация для распространения вне Gatekeeper.
