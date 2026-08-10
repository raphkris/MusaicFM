## MusaicFM - a iTunes Like Screen Saver for Spotify and Last.fm

MusaicFM is a macOS screen saver based on the idea of the iTunes screen saver. It displays Artworks based on your Spotify or Last.fm profile data.

MusaicFM is completely open source, so feel free to contribute to its development!

## Installation

### Homebrew

```
$ brew install musaicfm
```

### Manual

1. [Click here to Download](https://github.com/docterd/MusaicFM/releases/latest/download/MusaicFM.saver.zip)
2. Unzip the downloaded file.
3. Open **MusaicFM.saver** and confirm installation.

## Setting MusaicFM as Your Screen Saver

1. Open **System Settings → Wallpaper → Screen Saver…** (on older macOS: System Preferences → Desktop & Screen Saver)
2. Choose MusaicFM and click **Options…** to select your settings or login.

![Screenshot](screenshot.png)

### macOS Tahoe (26) and missing Options

Apple’s legacy screen saver host on Tahoe can hide or break the in-Settings **Options** button for third-party `.saver` bundles. MusaicFM includes workarounds for the Tahoe ghost-instance / `isPreview` bugs, but if Options is still missing you can configure MusaicFM with the companion app:

1. Open `MusaicFM.xcodeproj` in Xcode
2. Select the **MusaicFMPreferences** scheme
3. Run it (`Cmd+R`), configure Spotify / Last.fm, then quit

Saving from MusaicFMPreferences mirrors settings into the `legacyScreenSaver` container automatically.
