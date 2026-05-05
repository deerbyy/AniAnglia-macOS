# AniAnglia-macOS

Native macOS client for the Anixart anime catalog. The app is SwiftUI-first, targets macOS 13 Ventura and newer, and uses pure Swift networking through `URLSession` and `Codable`.

## Features

- Home screen with "Интересное", "Смотрят сейчас", and random release carousels.
- Debounced search with pagination and genre/year/type filters.
- Release detail page with poster zoom, metadata, genres, expandable description, episodes, screenshots, video blocks, comments, and bookmark actions.
- Episode and trailer playback through `WKWebView` embed players.
- Login/password auth with token/profile id stored in Keychain.
- Anonymous browsing mode by default.
- Account-backed bookmark sync for Anixart favorites plus all five watch lists: "Смотрю", "В планах", "Просмотрено", "Отложено", "Брошено".
- Expanded Anixart account profile mapping: username/avatar, privacy flags, social links, list counts, favorites, watched episodes, comments, collections, videos, friends, rating score, and watched time.
- Profile screen and settings for appearance, data cache, playback defaults, help, and rules.

## Screenshots

Screenshots should be captured from the first full Xcode/CI run and added here with the release artifact. This workspace can compile the Swift sources, but the active developer directory is Command Line Tools rather than full Xcode, so the app cannot be launched locally from `xcodebuild` here.

## API Endpoints Used

- `POST /auth/signIn`
- `GET /discover/interesting`
- `GET /discover/watching/{page}`
- `GET /release/random`
- `POST /search/releases/{page}`
- `GET /filter/0`
- `GET /release/{release_id}`
- `GET /episode/{release_id}`
- `GET /episode/{release_id}/{source_id}/{episode_id}`
- `GET /video/release/{release_id}`
- `GET /release/comment/all/{release_id}/{page}`
- `GET /favorite/all/{page}`
- `GET /favorite/add/{release_id}`
- `GET /favorite/delete/{release_id}`
- `GET /profile/list/add/{list_id}/{release_id}`
- `GET /profile/list/delete/{list_id}/{release_id}`
- `GET /profile/list/all/{profile_id}/{list_id}/{page}`
- `GET /profile/{profile_id}`

All requests use `User-Agent: AnixartApp/9.0 beta-11-25052914 (Android 11; SDK 30; arm64-v8a)`.

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
