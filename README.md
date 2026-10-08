# Z-BookPlayer 🎧

A lightweight, native iOS audiobook player built with SwiftUI and AVFoundation designed to play audiobooks directly from iCloud Drive folders without needing a server.

## ✨ Features

- **Folder as a Book**: Simply tap **"+ Add Folder"** and select any iCloud Drive folder (e.g., `1% Lifesteal - Audio`, `HDT - Audio`). The app reads and indexes all audio files (`.mp3`, `.m4a`, `.m4b`, `.aac`, `.wav`).
- **Auto-Sync / Catch-up Detection**: Whenever your Mac script scrapes and generates new chapters into your iCloud Drive folder, pulling to refresh (or reopening the app) automatically detects and appends the new chapters while preserving your current listening progress.
- **Persistent iCloud Access**: Uses iOS security-scoped URL bookmarks to retain folder permissions across device reboots and app restarts without prompting.
- **Offline / Zero Server**: Directly streams audio from your local device / iCloud Drive cache. Works completely offline once iCloud downloads the files.
- **Full Player Controls**:
  - Smooth interactive scrubber with elapsed and total duration.
  - Skip buttons: **-15s** and **+30s**.
  - Previous / Next chapter navigation with automatic sequential playback.
  - Speed selector pills: `0.75x`, `1.0x`, `1.25x`, `1.5x`, `1.75x`, `2.0x`.
  - Sleep timer: `15m`, `30m`, `45m`, `60m`, and **End of Chapter** with a live countdown display.
- **Background & Lock Screen Integration**:
  - `AVAudioSession` background audio playback.
  - Full `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` integration (Lock screen scrubber, play/pause, skip -15s/+30s, and chapter controls).
- **Library & Progress Tracking**:
  - Track listening progress per chapter and overall book completion percentage.
  - Mark chapters as completed (`✓ Done`) or unplayed.
  - Filter by `All` vs `Unplayed` and instant search by chapter number or title.
  - Docked mini player for quick control while browsing your library.

---

## 🚀 How to Install on Your iPhone (Developer Mode)

You can run this directly on your iPhone using a free personal Apple ID without needing an Apple Developer program membership.

### 1. Enable Developer Mode on Your iPhone (iOS 16+)
1. On your iPhone, open **Settings** > **Privacy & Security**.
2. Scroll to the bottom and tap **Developer Mode**.
3. Toggle it **ON** and restart your iPhone when prompted.
4. After restarting, unlock your phone and tap **Turn On** to confirm.

### 2. Open the Project in Xcode
Open the project from Terminal or Finder:
```bash
open /Users/izep/code/izep/z-bookplayer/ZBookPlayer.xcodeproj
```

### 3. Configure Code Signing (1-time setup)
1. In Xcode's left sidebar, click the top-level **ZBookPlayer** project icon.
2. Select the **ZBookPlayer** target.
3. Open the **Signing & Capabilities** tab.
4. Under **Team**, select your personal Apple ID team (if you haven't added it yet, click **Add Account...** and sign in with your Apple ID).
5. Ensure **Bundle Identifier** is unique to you (e.g., `com.izep.zbookplayer`).

### 4. Connect Your iPhone & Run
1. Connect your iPhone to your Mac via USB cable (or enable Wi-Fi debugging).
2. In Xcode's top destination toolbar (where it shows device targets), select your connected iPhone.
3. Press **Run** (the Play button `▶` or `Cmd + R`).
4. Xcode will compile, code-sign, and install **Z-BookPlayer** directly onto your iPhone.

*(Note: The first time you sideload an app using a free Apple ID, iOS may prompt you on your iPhone under **Settings > General > VPN & Device Management** to "Trust" your developer certificate).*

---

## 📂 Using with the RR Podcast Pipeline

1. In the Royal Road podcast generator, run sync with `--icloud`:
   ```bash
   python main.py "https://www.royalroad.com/..." --icloud
   ```
2. On your iPhone:
   - Open **Z-BookPlayer**.
   - Tap **"+ Add Folder"**.
   - Browse to **iCloud Drive** and select the novel folder (e.g. `1% Lifesteal - Audio`).
   - Listen to any chapter!
3. When new chapters are generated later, simply pull down on the book view or bookshelf to refresh and detect the newly added chapters.

---

## 🛠 Project Structure

```
z-bookplayer/
├── ZBookPlayer.xcodeproj
└── ZBookPlayer/
    ├── ZBookPlayerApp.swift          # Main entry point (dark scheme configured)
    ├── Info.plist                    # Background audio modes
    ├── Assets.xcassets               # App icon & theme colors
    ├── Models/
    │   ├── Book.swift                # Book metadata, progress, and bookmark storage
    │   └── Chapter.swift             # Chapter sorting, title parsing, duration
    ├── Services/
    │   ├── AudioPlayer.swift         # AVPlayer, lock-screen controls, sleep timer
    │   └── LibraryManager.swift      # Security-scoped bookmarks & directory scanner
    └── Views/
        ├── BookshelfView.swift       # Library shelf, folder picker, pull-to-refresh
        ├── BookDetailView.swift      # Now playing card, scrubber, chapter list
        ├── MiniPlayerView.swift      # Docked bottom bar
        └── Components/
            ├── ScrubberBar.swift     # Custom scrubbing slider
            ├── SpeedPicker.swift     # Playback speed pills
            └── SleepTimerPicker.swift# Sleep timer menu & timer badge
```
