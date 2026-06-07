# AniAnglia-macOS

Native macOS client for the Anixart anime catalog. The app is SwiftUI-first, targets macOS 13 Ventura and newer, and uses pure Swift networking through `URLSession` and `Codable`.

## Features

- Home screen with "Рекомендации", "Обсуждают", "Сейчас смотрят", "Коллекции недели", and "Комментарии недели" sections.
- Debounced search with automatic pagination and Anixart search scopes: title, studio, director, author, and genre.
- Release detail page with poster zoom, metadata, genres, expandable description, searchable/filterable episodes, screenshots, searchable/sortable related collections, searchable video blocks, comments with expandable replies, clickable comment authors, own-comment editing/deletion, and bookmark actions.
- Public collections browser with search, Anixart sort modes, collection detail pages, searchable release lists, clickable collection authors, and account-synced favorite collections.
- Automatic infinite-scroll loading for search, catalog, collections, collection releases, and watch history, with manual "load more" fallback buttons.
- Episode and trailer playback through `WKWebView` embed players: YouTube is loaded with an explicit Anixart HTTP referrer, while Kodik/Libria iframe pages receive an Anixart origin.
- Login/password auth with token/profile id stored in local app preferences. CI artifacts are ad-hoc signed, so avoiding Keychain access prevents password dialogs after each newly installed build.
- Anonymous browsing mode by default.
- Account-backed bookmark sync for Anixart favorites, favorite collections, and all five watch lists: "Смотрю", "В планах", "Просмотрено", "Отложено", "Брошено"; release lists default to newest-added first and expose Anixart sort modes.
- Local search inside bookmarks and watch history across release titles, metadata, years, genres, and collection titles/descriptions.
- Expanded Anixart account profile mapping: username/avatar, privacy flags, social links, clickable public watch-list counts for other profiles, favorites, watched episodes, comments, collections, videos, searchable/paginated friends screen, searchable friend requests, rating score, and watched time.
- Profile screen and settings for appearance, data cache, playback defaults, help, and rules.

## Screenshots

Screenshots should be captured from the first full Xcode/CI run and added here with the release artifact. This workspace can compile the Swift sources, but the active developer directory is Command Line Tools rather than full Xcode, so the app cannot be launched locally from `xcodebuild` here.

## API Endpoints Used

- `POST /auth/signIn`
- `GET /discover/watching/{page}`
- `GET /discover/recommendations/{page}`
- `POST /discover/discussing`
- `POST /discover/comments`
- `GET /collection/all/{page}`
- `GET /collection/{collection_id}`
- `GET /collection/{collection_id}/releases/{page}`
- `GET /collection/all/release/{release_id}/{page}`
- `GET /collectionFavorite/all/{page}`
- `GET /collectionFavorite/add/{collection_id}`
- `GET /collectionFavorite/delete/{collection_id}`
- `GET /release/random`
- `POST /search/releases/{page}`
- `GET /filter/0`
- `GET /release/{release_id}`
- `GET /episode/{release_id}`
- `GET /episode/{release_id}/{source_id}/{episode_id}`
- `GET /video/release/{release_id}`
- `GET /release/comment/all/{release_id}/{page}`
- `GET /release/comment/replies/{comment_id}/{page}`
- `POST /release/comment/edit/{comment_id}`
- `GET /release/comment/delete/{comment_id}`
- `GET /favorite/all/{page}`
- `GET /favorite/add/{release_id}`
- `GET /favorite/delete/{release_id}`
- `GET /profile/list/add/{list_id}/{release_id}`
- `GET /profile/list/delete/{list_id}/{release_id}`
- `GET /profile/list/all/{profile_id}/{list_id}/{page}`
- `GET /profile/{profile_id}`
- `GET /profile/friend/all/{profile_id}/{page}`
- `GET /profile/friend/requests/{type}/{page}`
- `GET /profile/friend/requests/{type}/last`
- `GET /profile/friend/request/send/{profile_id}`
- `GET /profile/friend/request/remove/{profile_id}`
- `GET /profile/friend/request/hide/{profile_id}`

`POST /search/releases/{page}` uses a JSON body, for example `{"query":"naruto","searchBy":0}`.

All requests use `User-Agent: AnixartApp/9.0 beta-11-25052914 (Android 11; SDK 30; arm64-v8a; samsung; ru_RU)`.

## Build Locally

Install full Xcode, then select it:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Build and run:

```bash
./script/build_and_run.sh
```

Useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --debug
```

SwiftPM can also compile the sources:

```bash
swift build
```

Unit tests are XCTest-based and should be run with full Xcode:

```bash
xcodebuild test -project AniAnglia.xcodeproj -scheme AniAnglia-macOS -destination 'platform=macOS'
```

## Install From CI Artifact

Download `AniAnglia.dmg` from the GitHub Actions artifact, open it, and drag `AniAnglia.app` to Applications. Because the CI build uses ad-hoc signing, first launch may require `Ctrl` + click on the app, then `Open`.

## Not Included In MVP

- Mini-player window: the code keeps a `PlayerSession` abstraction, but the floating always-on-top window is left for a later release.
- VK/Google OAuth: first version supports only login/password and anonymous mode.
- Torrent downloads: intentionally excluded from the macOS MVP.
- Full DTO coverage for all Anixart endpoints: only fields required by the implemented screens are modeled.
