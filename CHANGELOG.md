# Changelog

## 0.1.1 — Preview

- Wait between Accessibility resize and move requests, then verify the resulting frame. This addresses incorrect ChatGPT placement caused by immediately issuing multiple requests.
- Retry placement at most three times while a window settles.
- Keep minimum-size windows within the available desktop where possible, preserving right and bottom alignment for corner placements.
- Show a warning icon when Accessibility permission is unavailable.
- Add permission-repair instructions and reinstall mouse monitoring when the app detects a permission grant.
- Cancel pending placement when a new drag begins, Option is used, snapping is paused, or displays change.
- Include the Easy Snap app icon.

### Validation and known limits

Build and geometry checks passed on Sonoma 14.3. The placement code passed checks against the actual ChatGPT window for half-screen placement, bottom-right placement respecting its 600-point minimum height, and restoration. Full gesture testing of the installed update after renewing Accessibility permission is still pending.

This Apple Silicon preview is locally signed and not Apple-notarized. Updating may require removing and re-adding its Accessibility entry. Exact quarter-screen placement is not possible when an app enforces a larger minimum window size.

## 0.1.0 — Initial local preview

- Menu bar app with left/right halves, top-edge fill, and corner quarters.
- Placement preview, restore-on-release behavior, and Option-key bypass.
- Pause and quit controls.
- Display-aware coordinate conversion and respect for menu bar and Dock space.

The initial version passed nine simulated drag checks with a standard native test window on one display.
