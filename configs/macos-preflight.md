# macOS pre-flight settings

Apply these before relying on the stack. Skipping any will cause weird bugs.

## System Settings → Desktop & Dock

- **Displays have separate Spaces** → ON
  - Required for SketchyBar on external monitors.
  - Contradicts AeroSpace default recommendation, but needed for bar to render cleanly.
- **Group windows by application** → OFF
- **Trackpad → More Gestures → "Swipe between full-screen applications"** → OFF
  - Disables Mission Control swipe.

## System Settings → Keyboard → Keyboard Shortcuts

- **Mission Control** — disable everything not used.
  - Prevents collision with AeroSpace `Hyper-*` bindings.
- **Spotlight** — change `Cmd-Space` to something unused.
  - Raycast takes `Alt-Space`.

## System Settings → Control Center

- **Automatically hide and show the menu bar** → "Always"
  - SketchyBar owns the top strip. Native bar revealed only on hover at top edge.

## Remove extra macOS Spaces

- Open Mission Control.
- Hover top edge.
- Delete every desktop except Desktop 1.
- AeroSpace ignores Spaces; extras just confuse it.

## Permissions

Grant Accessibility on first launch:

- AeroSpace
- Raycast
- Homerow

System Settings → Privacy & Security → Accessibility.

## Service start

If AeroSpace's `after-startup-command` does not auto-start borders + sketchybar:

```
# quit + relaunch AeroSpace (re-fires after-startup-command)
killall AeroSpace 2>/dev/null; open -a AeroSpace

# OR run manually
/opt/homebrew/bin/borders active_color=0xffe1e3e4 inactive_color=0xff494d64 width=5.0 style=round &
/opt/homebrew/bin/sketchybar &

# OR enable as background services (survive aerospace restart)
brew services start sketchybar
brew services start borders
```

`after-startup-command` only fires on AeroSpace launch — config reload does NOT re-run it.
