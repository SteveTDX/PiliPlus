<div align="center">
    <img width="200" height="200" src="assets/images/logo/logo.png" alt="PiliPlus logo">
    <h1>PiliPlus</h1>
</div>

<div align="center">

[中文](README.md) | English

![GitHub repo size](https://img.shields.io/github/repo-size/bggRGjQaUbCoE/PiliPlus)
![GitHub Repo stars](https://img.shields.io/github/stars/bggRGjQaUbCoE/PiliPlus)
![GitHub all releases](https://img.shields.io/github/downloads/bggRGjQaUbCoE/PiliPlus/total)

</div>

<div align="center">
    <p>A third-party Bilibili client built with Flutter</p>

<img src="assets/screenshots/510shots_so.png" width="32%" alt="PiliPlus mobile screenshot" />
<img src="assets/screenshots/174shots_so.png" width="32%" alt="PiliPlus mobile screenshot" />
<img src="assets/screenshots/850shots_so.png" width="32%" alt="PiliPlus mobile screenshot" />
<br/>
<img src="assets/screenshots/main_screen.png" width="96%" alt="PiliPlus desktop screenshot" />
<br/>
</div>

<br/>

## Custom changes in this fork

This fork adds the following privacy-blocking, whitelist and playback-restriction features on top of upstream. They live under `Settings → Privacy settings`, ordered: Blocklist management → Whitelist management → Favorites-only playback → Blocked users → Block keywords → Password settings.

- [x] **Block keywords**: hide videos whose title/tags **contain** any keyword (literal substring match, no regex, to avoid injection risks)
- [x] **Blocked users**: hide all videos from any uploader whose name contains any keyword (e.g. adding "小潮" blocks uploader "小潮院长")
- [x] **Case-insensitive matching**: both text and keyword are lowercased before comparison, so keywords containing Latin letters (e.g. "小杨Johnson", "高斯Goh") match correctly (fixes mixed-case uploader names leaking through)
- [x] **Password settings**: once a password is set, Blocklist management, Blocked users and Block keywords all require it to enter
  - Digits + letters only; set an initial password on first use; changing it requires verifying the old one; both entries must match; leave blank to remove the password
- [x] Filtering covers **every user-video entry point**: feeds (both App and Web API), hot ranking, per-region ranking, related videos, and search results (video / user / live / article / bangumi / aggregated tabs)
- [x] Search results apply all three filters together: blocked users + block keywords + blocklist
- [x] Already-loaded lists are **re-filtered immediately** when keywords change — no pull-to-refresh needed
- [x] A delete icon appears on the right of every entry in Blocked users, Blocklist and Block keywords — click to remove (long-press removal still available)
- [x] Persistence matches the blocklist style (Hive local storage) with import/export support
- [x] Deliverables: Windows portable build and Android APK
- [x] **Whitelist management**: show videos only from uploader names on the whitelist; the blocklist still takes precedence (see below)
- [x] **Favorites-only playback**: once enabled, only videos in the signed-in account's favorites can be played (see below)

<br/>

## New modules: Whitelist management / Favorites-only playback

> Commits `124d788` → `451352a` → `6faeb8f` → `44621c5` → `86bc10d`, version `2.1.6`: 9 files changed, ~500 lines added.

### 1. Whitelist management

Entry: `Settings → Privacy settings → Whitelist management` (route `/whiteListPage`). The page mirrors the blocklist manager (add / remove / import / export). Entries are persisted in Hive under `LocalCacheKey.whiteUserNames`, with runtime state in `GlobalData().whiteUserNames`.

Filtering lives in `BlockUserFilter` (`lib/utils/block_user.dart`):

| Blocklist hit | Whitelist state | Result |
| --- | --- | --- |
| Yes | Any | **Hidden** (blocklist wins) |
| No | Empty | Shown (feature inactive) |
| No | Non-empty, name matched | Shown |
| No | Non-empty, not matched / no name field | Hidden |

- Case-insensitive literal substring matching on the **uploader name** — no regex, so keywords can never be evaluated as expressions.
- Handles every upstream name field: `owner.name`, `owner.uname`, `args.up_name`, `author`, `up_name`, `uname`; parsed video models use `owner.name`, exactly what the card displays.
- Applies to feeds (App/Web), hot ranking, per-region ranking, related videos, all search tabs and already-loaded lists.
- Changes call `refilterLoadedLists(reload: true)`: in-place re-filtering first, then `onRefresh` for lists still in memory. In-place filtering can only remove items, so **relaxing or clearing** the whitelist needs a reload to bring previously hidden videos back.

### 2. Favorites-only playback

Entry: `Settings → Privacy settings → Favorites-only playback`, a single switch (`SettingBoxKey.onlyFavPlayback`). When on, every video must pass the check before the player page opens.

The single choke point is `PageUtils.toVideoPage` in `lib/utils/page_utils.dart` (now `async`), covering feeds, hot/ranking, search, related videos, favorites, watch later, dynamics, bangumi/courses — every navigation that goes through it:

1. Resolve both `aid` and `bvid` with `IdUtils.av2bv / bv2av`, so callers passing only one still work.
2. `FavOnlyService.checkAllowed()` — **fail-closed**: not logged in, API failure, missing id or cache not ready all block playback, with a "video is not in your favorites" toast.
3. Favorites are fetched **lazily on the first video tap**; toggling the switch only invalidates the cache, so the settings page never shows a full-screen loading dialog.

Loading / cache strategy in `lib/utils/fav_only.dart`:

- `FavHttp.allFavFolders` lists all folders; each folder is paged serially with `userFavFolderDetail` (`ps=20`, following `has_more`), capped at 50 pages per folder to guard against a stuck `has_more`.
- Folders are fetched in **batches of 5 concurrent requests** to shorten the first-load wait without triggering API rate limits.
- Only `type == 2` video entries are collected (bangumi / articles / courses / collections excluded); both `aid` and `bvid` sets are cached.
- Cache has a **10-minute TTL** and is bound to the account `mid`: switching accounts invalidates it immediately and expiry triggers a refetch, so one account's favorites can never authorize another account's video and newly added favorites are not wrongly blocked.
- Duplicate concurrent loads are coalesced via `_loading`; the `SmartDialog` loading overlay is dismissed in `finally` before showing the toast.

### 3. Files touched

| File | Purpose |
| --- | --- |
| `lib/pages/whitelist/view.dart` | New whitelist page (CRUD, import/export) |
| `lib/pages/setting/models/privacy_settings.dart` | New entry, switch and password gate |
| `lib/router/app_pages.dart` | Registers `/whiteListPage` |
| `lib/utils/block_user.dart` | Combined blocklist/whitelist filtering, list re-filter and restore |
| `lib/utils/fav_only.dart` | New favorites loading, caching and allow-check |
| `lib/utils/page_utils.dart` | Pre-navigation interception at the shared playback entry |
| `lib/utils/storage_key.dart` | `LocalCacheKey.whiteUserNames`, `SettingBoxKey.onlyFavPlayback` |
| `lib/utils/storage_pref.dart` | Getters/setters for the new set and bool |
| `lib/utils/global_data.dart` | Runtime `whiteUserNames` / `onlyFavPlayback` |

<br/>

## Optimization process and verification

### Iterations

| Commit | Goal | Key changes |
| --- | --- | --- |
| `124d788` | Feature | Whitelist page, switch, favorites service and playback interception, reusing the existing block pipeline without touching individual pages |
| `451352a` | Robustness | `Success<T>` pattern matching instead of casts; null `response.list` / `data.medias` treated as empty; loading and toast handling moved into `finally` |
| `6faeb8f` | First-load performance | 5-way concurrent folder loading with serial paging inside each folder; account-bound cache with 10-minute TTL; per-folder page cap |
| `44621c5` | Recoverability | `reload: true` on whitelist changes fixes videos staying hidden after relaxing/clearing the whitelist; closed controllers skipped |
| `86bc10d` | Static analysis | Removed unused `_matchField`; back to zero warnings |

### Real-account verification

A real Bilibili account was used (QR login: `qrcode/generate` → `qrcode/poll`, states `86101 → 86090 → 0`) and only read-only endpoints were called. The QR code was rendered as solid-rect SVG plus a 600×600 PNG and self-checked with `jsQR`, fixing the "QR code could not be parsed" failure caused by scaled stroke-based SVG.

| Check | Result |
| --- | --- |
| Account | `mid 30561529` |
| Favorites scope | 26 folders / 40 paginated requests |
| Video entries | 510 `type == 2` items, 509 unique `aid` and 509 unique `bvid`, `missing_id = 0`, `missing_bvid = 0` |
| ID conversion | 510 `av2bv` / `bv2av` pairs, 0 mismatches |
| Concurrency | 5-way load finished in 3.36s, identical to serial, 0 `-412` rate-limit responses |
| Name fields | Hot `owner.name` 20/20, search `author` 20/20 resolved correctly |
| Whitelist | Keyword `汤山老王` on 20 hot items → 1 visible; with the same name on the blocklist → 0 |
| Favorites gate | Favorited `BV1W8xa6AEfH` → `true`, non-favorited hot `BV15sxS68EFq` → `false`, unknown id → `false` |

### Quality and build

- `flutter analyze --no-pub`: **0 errors, 0 warnings** (only the 40 pre-existing info lints remain).
- Deliverable: `PiliPlus-2.1.6-release.apk`, 66.1 MB / `69,259,830` bytes, with `libapp.so` for `arm64-v8a`, `armeabi-v7a` and `x86_64`; `apksigner verify` passes (v2 signature). No `key.properties` is configured, so release falls back to the debug certificate and installs directly; binaries are not committed.
- Local toolchain adaptations (machine-only, not committed): Flutter 3.47.8 / Dart 3.13.7, Gradle 9.5.0 + AGP 9, Android API 37, NDK 28.2.13676358, Android Studio JBR 21; MITM CA imported into the JBR truststore for the proxy, gradle wrapper and media_kit artifacts prefetched, local Maven coordinates used where `jitpack.io` was unreachable, and `core.longpaths` enabled to fix plugin sources missing on Windows.

SHA256: `0cb85d282f3ba1f4788e22c8cda86248d30bd23fbc9555bd0e4de48abfb5baaa`.

<br/>

## Download

Download a build from [Releases](https://github.com/bggRGjQaUbCoE/PiliPlus/releases), or clone the repository and build it locally.

## Disclaimer

PiliPlus is a personal project developed for educational purposes, intended only for learning and testing. Please delete it within 24 hours of downloading.
All APIs used were collected from the official website. This project does not provide any cracked content.

Credit to the original project: [guozhigq/pilipala](https://github.com/guozhigq/pilipala).
Credit to the upstream project: [orz12/PiliPalaX](https://github.com/orz12/PiliPalaX).
This repository makes more extensive changes. Thank you to the original authors for sharing their work as open source.

Thank you for using PiliPlus.

## Acknowledgements

- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [flutter_meedu_videoplayer](https://github.com/zezo357/flutter_meedu_videoplayer)
- [media-kit](https://github.com/media-kit/media-kit)
- [dio](https://pub.dev/packages/dio)
- And others

## Star History

<a href="https://star-history.dera.page/#bggRGjQaUbCoE/PiliPlus&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://star-history.dera.page/svg?repos=bggRGjQaUbCoE/PiliPlus&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://star-history.dera.page/svg?repos=bggRGjQaUbCoE/PiliPlus&type=Date" />
   <img alt="Star History Chart" src="https://star-history.dera.page/svg?repos=bggRGjQaUbCoE/PiliPlus&type=Date" />
 </picture>
</a>