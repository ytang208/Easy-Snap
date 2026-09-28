<p align="center">
  <img src="AppIcon.png" width="144" alt="Easy Snap app icon">
</p>

# Easy Snap

A small native Mac menu bar app that brings drag-to-edge window snapping to macOS Sonoma.

**[Download Easy Snap v0.1.1](https://github.com/ytang208/Easy-Snap/releases/download/v0.1.1/Easy-Snap.zip)** · [Release page](https://github.com/ytang208/Easy-Snap/releases/tag/v0.1.1) · [Report a problem](https://github.com/ytang208/Easy-Snap/issues)

> **Early preview:** Easy Snap is still being tested. The current download is for Apple Silicon Macs running macOS 14.0 or later. Development and testing have taken place on Sonoma 14.3; compatibility with other macOS versions has not been verified.

## What it does

Drag a window by its title bar to an edge of the display. A blue preview shows the proposed placement; release the mouse to apply it.

| Gesture | Result |
| --- | --- |
| Drag to the left or right edge | Fill that half of the display |
| Drag to the top edge | Fill the available desktop, without entering full screen |
| Drag to a corner | Fit into that quarter of the display, subject to the app's minimum size |
| Drag a snapped window away and release | Restore its previous size at the new location |
| Hold Option during a drag | Skip snapping and restoration for that drag |

Easy Snap respects the menu bar and Dock. It includes support for multiple displays, though physical multi-monitor testing is still pending.

Use the split-window icon in the menu bar to pause snapping, view help, or quit.

## Install

1. Download **Easy-Snap.zip** from the link above. GitHub's automatically generated **Source code** downloads are for building the app yourself.
2. Unzip it and move **Easy Snap.app** into your Applications folder.
3. Open Easy Snap.
4. Open **System Settings → Privacy & Security → Accessibility** and enable **Easy Snap**. If it is missing, use **+** to select the installed app.
5. Try dragging a window by its title bar to the left or right edge.

This preview is locally signed, but it is **not signed with an Apple Developer ID or notarized by Apple**. macOS may block the first launch. Only if you trust this download, use macOS's per-app opening controls under **Privacy & Security**. Do not disable Gatekeeper system-wide. Apple's [instructions for opening an app from an unidentified developer](https://support.apple.com/en-us/102445) explain the process.

The app does not start automatically at login. You can add it under **System Settings → General → Login Items** if desired.

## If snapping stops working

A warning triangle in the menu bar means Easy Snap cannot access Accessibility. Open its menu and choose **Repair permission after an update…**.

Because these preview builds are locally signed, updating or rebuilding the app can invalidate its previous permission. Toggling the existing entry may not be enough:

1. Quit Easy Snap.
2. In **System Settings → Privacy & Security → Accessibility**, select the old Easy Snap entry and remove it with **−**.
3. Use **+** to add the current installed copy of **Easy Snap.app**, then enable it.
4. Reopen Easy Snap.

Keep one installed copy to avoid approving a different copy by mistake. Also check that **Snapping enabled** is selected in the menu. The warning triangle changes back to the split-window icon when the app detects permission.

## App compatibility and limitations

- Some apps enforce minimum window sizes. Easy Snap cannot make a window smaller than its app allows. In testing, the ChatGPT window required at least 600 points of height, so it could not fit exactly into a quarter of a 1920 × 1080 display.
- Version 0.1.1 waits between resize and move requests and checks the resulting frame to accommodate apps that apply these changes asynchronously.
- Placement can take up to roughly 1.5 seconds while an app settles. Starting a new drag cancels pending placement.
- Full-screen windows, nonstandard dialogs, and windows that do not expose supported Accessibility controls are excluded.
- Restore history is held in memory for up to 100 windows and is cleared when Easy Snap quits.
- Restoration happens when the drag ends, not while the window is being dragged.
- The included binary and build script target Apple Silicon. An Intel build is not currently provided.

## Privacy

Easy Snap runs locally. Its source contains no networking, analytics, account system, or third-party dependencies.

It observes mouse gestures and uses macOS Accessibility APIs to identify, move, and resize windows. It does not record typed text or save window contents.

## Build from source

Requires an Apple Silicon Mac, macOS 14 or later, and Apple development tools with a Swift compiler that supports this source. The app was built with Swift 5.10.

Download the repository using **Code → Download ZIP**, or clone it:

```sh
git clone https://github.com/ytang208/Easy-Snap.git
cd Easy-Snap
bash build.command
```

The script compiles the app, adds its icon, applies a local ad-hoc signature, and runs the built-in geometry checks. The output is **Easy Snap.app** in the repository folder. It does not install the app or grant Accessibility permission.

| File | Purpose |
| --- | --- |
| `main.swift` | Menu bar UI, drag detection, preview, and snapping logic |
| `WindowAccess.swift` | Accessibility access and delayed window placement |
| `build.command` | Local build, signing, and geometry checks |
| `AppIcon.icns` | Packaged macOS icon |
| `AppIcon.png` | Original icon artwork |

## Testing status

- Built and geometry checks passed on Sonoma 14.3.
- The initial version passed nine simulated drag checks with a standard native window.
- The 0.1.1 placement code passed tests against the actual ChatGPT window for half-screen placement, a corner placement respecting its minimum height, and restoration.
- Full drag testing of the installed 0.1.1 app after renewing Accessibility permission remains pending. Multiple displays and a broad range of other apps have not yet been tested.

Please include your macOS version, affected app, screen arrangement, intended gesture, and what happened when [reporting a problem](https://github.com/ytang208/Easy-Snap/issues). Avoid including private conversation content in screenshots.

See [CHANGELOG.md](CHANGELOG.md) for version notes.
