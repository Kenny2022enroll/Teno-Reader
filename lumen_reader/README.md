# Lumen Reader

A cross-platform (iOS / macOS / Android / Windows / Linux) reading app with
an **Apple Human Interface Guidelines (HIG)** inspired design language.

![Platforms](https://img.shields.io/badge/platform-iOS%20|%20macOS%20|%20Android%20|%20Windows%20|%20Linux-blue)
![Flutter](https://img.shields.io/badge/flutter-3.22%2B-skyblue)
![Dart](https://img.shields.io/badge/dart-3.3%2B-blue)

---

## ✨ Key Features

| Area | Implementation |
|---|---|
| **Shelf management** | Grid cover view, search, pin, long-press actions, import via picker |
| **Multi-format** | EPUB / PDF / TXT parsing with metadata extraction |
| **Reading modes** | Light / Dark / Sepia / Paper — follow-system supported |
| **Typography** | Font size 12–28, line-height, paragraph spacing, font family |
| **Highlights & notes** | Multi-color highlights, bookmark, per-reading annotations |
| **Sync** | End-to-end encrypted (AES-256-CBC) opportunistic multi-device sync |
| **Accessibility** | TTS narration, dynamic type, reduced-motion, large text |
| **Performance** | Lazy chapter rendering, incremental progress save (≤5 s throttle) |
| **Privacy** | Zero-knowledge server: ciphertext-only storage, device-scoped keys |

## 🎨 Design System

Lumen mirrors Apple's HIG while gracefully adapting on other platforms.

- **Colors**: HIG semantic tokens (label / secondary / tertiary / separator /
  system fills) exposed via `AppPalette` in [app_palette.dart](lib/core/theme/app_palette.dart).
- **Typography**: SF Pro-style metric scale (`AppTypography`).
- **Motion**: Apple-curves (`easeOutCubic`), page transitions adapt per
  platform (iOS/macOS → `CupertinoPageTransitionsBuilder`; others →
  `ZoomPageTransitionsBuilder`).
- **Tokens**: `AppSpacing`, `AppRadius`, `AppMotion` — single source of truth.
- **Adaptive platform widgets**: Material icons on Android/Windows/Linux;
  HIG-shaped segmented controls / bottom sheets on iOS/macOS.

## 🏗️ Architecture

```
lib/
├── app/                       # App bootstrap, router
├── core/
│   ├── theme/                 # Design tokens + ThemeData factory
│   ├── storage/               # Hive adapters + secure storage
│   └── sync/                  # E2EE sync service
└── features/
    ├── reader/
    │   ├── domain/            # Entities + repository contracts
    │   └── infrastructure/    # Hive-backed repos, EPUB/PDF parsers
    ├── shelf/                 # Home shelf grid
    └── settings/              # Settings + privacy
```

**Patterns**: Feature-first directories, Riverpod state management,
`Entity` / `Repository` / `Service` layering.

## 🚀 Getting Started

```bash
# 1. Install dependencies
flutter pub get

# 2. Generate code (adapters are hand-written; no build_runner required)
#    Optional: flutter pub run build_runner build

# 3. Run
flutter run -d ios            # iOS
flutter run -d macos          # macOS
flutter run -d android        # Android
flutter run -d windows       # Windows
flutter run -d linux          # Linux
```

## 🔐 Privacy & Sync

- Local data persists in **Hive** (on-device, cleartext, opt-in encryption
  available via `encrypt` package).
- Sync tokens and master keys live in `FlutterSecureStorage`.
- When the user enables sync, payloads are **AES-256-CBC encrypted** before
  leaving the device; the server stores only ciphertext blobs keyed by an
  anonymous install ID.

## 🧩 Extending

- **Add a new format**: implement a parser that returns `BookInfo` from
  `BookRepositoryImpl._extractMetadata`.
- **Add a highlight action**: extend `SelectionArea.onSelectionChanged` in
  [reader_page.dart](lib/features/reader/presentation/pages/reader_page.dart).
- **Add a sync provider**: swap `SyncService._dio` for your backend while
  keeping the encryption layer intact.

## 📄 License

MIT — for evaluation / reference use.
