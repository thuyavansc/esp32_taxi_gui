# esp32_taxi_gui — Processing 4 control/visualization GUI

A PC-side GUI for the `esp32_display_taxi_meter` firmware
(`TaxiMeter/TaxiMeter/TestFunctionalitiesV2/esp32_display_taxi_meter`), built per
`docs/TestFunctionalities/display-tax-calculations/85_...md` (GUI options analysis) and this
session's implementation passes. Built in **Processing 4**, with **zero external libraries** (no
ControlP5/G4P needed) and **zero ESP32 firmware changes**.

## How to run

1. Open Processing 4.
2. `File → Open...` → select this folder's `esp32_taxi_gui.pde`.
3. Click Run (▶). A ~1301×715 window opens.
4. Click the **COM box** (top-left) — a dropdown opens listing every detected port, **plus COM6
   through COM12 always offered as manual options** even if not currently auto-detected (Windows
   COM numbering for USB-serial adapters shifts around and auto-detection can miss a port that's
   genuinely present). **COM8 is the default** shown the very first time you open the GUI; click
   one.
   It's remembered (by name, in `gui_settings.txt` next to this sketch) and auto-selected again
   next time you open the GUI, matched against whatever ports are actually present at that time.
5. Click **Connect**.
   - If it fails to open: close PlatformIO's own Serial Monitor first — only one program can hold
     a COM port open at a time (see doc 85 §B.6). This GUI's serial monitor panel **replaces** it
     entirely, it doesn't need to run alongside it.
6. From here you have **three equivalent ways to control the device** — pick whichever fits what
   you're doing, they all drive the same firmware and update the same reactive state:
   - Type a command in the **serial monitor** panel's input box (exactly like the real Serial
     Monitor — every command from doc 83's testing guide works unchanged).
   - Click a category in the **side menu** (far left), then click/fill in a command in the
     **command panel** next to it — every real command the firmware understands, organized by
     prefix, with input fields for anything that takes a value.
   - Use the **Display** panel (right) — a visual mirror of the real device's screens, including a
     `TRIP` tab with real Setup→Login→Duty→Trip controls.

## Window layout (left to right)

```text
[ Side Menu ] [ Command Panel ] [ Serial Monitor ] [ Display ]
   150px          270px             400px            416px
```

All four share one height (624px, matching the Display panel — see the ratio note below).

## Why the Display panel looks the way it does — the ratio question

The real Waveshare display is 320×480 (portrait, a 2:3 ratio). This GUI's "Display" panel is
416×624 — the **same 2:3 ratio**, scaled ×1.3 so it's comfortably readable on a normal laptop
screen instead of shown at its true tiny physical size. Change one constant
(`DISPLAY_SCALE` in `esp32_taxi_gui.pde`) to resize the whole mirror — every screen positions
itself relative to that scale, nothing is hardcoded to the current size.

## The Side Menu + Command Panel

The side menu lists every command **category** this firmware actually has (`CommandCatalog.pde` —
Setup, Auth, Reference Data, Duty, Trip/Meter, Session/Reset, GPS, Trips API, iStartek Socket,
Diagnostics, Other). Selecting one shows every real command in that category in the command panel:
a plain button for commands with no argument (`mem`, `trip stop`, `duty on`, ...), or a label +
input field(s) + **Send** button for commands that take a value (`api get <id>`, `gps every <sec>
[cnt]`, `auth login <user> <pass>`). Nothing here is invented — every command and its exact syntax
was pulled directly from the firmware's own `process_command()` dispatchers (see doc 83 for the
full reference, or just browse the side menu itself — it's the same list).

## The Display panel's 5 tabs

| Tab | What it shows |
| --- | --- |
| `DASH` | Mirrors the real Dashboard screen (speed/fare/distance cards) + a fare breakdown this session added |
| `GPS` | Mirrors the real GPS screen |
| `TRIP` | **New** — Setup→Login→Duty→Trip controls (doesn't exist on the real device yet, doc 81 §5) |
| `SET` | Mirrors the real Settings screen **exactly** — same brightness/contrast sliders (decorative here, no PC backlight to control, same as the real firmware's Contrast slider is explicitly "test only"), same 10-item info list, same strings, same order — **plus** an 11th list entry, "→ Diagnostics", not on the real device, which drills into the `mem`/`store`/`ref fetch` panel from this session's earlier pass |
| `TEST` | Mirrors the real Test Menu **exactly** — same 2 entries ("PAX A920Pro Meter UI", "Color Palette Viewer"), same drill-down-with-back-button navigation — **plus** a 3rd entry, "Quick Commands", not on the real device, for one-tap access to common `*info` commands |

### Inside `TEST`

- **PAX A920Pro Meter UI** — pixel-position mirror of `test_pax_meter.c` (near-black theme, header,
  taxi ID/status row, big fare display, fees/extras, tariff, START TRIP/END TRIP buttons, footer
  with device ID + date). Its buttons are **cosmetic-only**, exactly like the real screen — they
  don't call the real trip firmware. That's not a shortcut taken here; it's what the real device's
  own code does (`test_pax_meter.c`'s `_start_event`/`_end_event` only flip local labels). Real
  meter control lives on the `TRIP` tab.
- **Color Palette Viewer** — the same 24-color data set as `color_palette_data.h` (5 pure diagnostic
  colors + 19 real theme colors), same names, same hex values, grid + tap-to-see-detail, same as
  the real screen. **Not replicated:** the real screen's interactive color-wheel picker widget —
  lower value for a testing GUI, would roughly double this one screen's code.
- **Quick Commands** (added) — the shortcuts panel from this session's earlier pass.

## Folder / file structure

Processing requires every `.pde` file to live flat in one sketch folder (no subfolders for code —
a real IDE constraint, not a choice made here); organization instead comes from Processing's tab
system, one clearly-named file per concern:

| File | Responsibility |
| --- | --- |
| `esp32_taxi_gui.pde` | Window setup, layout constants (incl. the ratio math), top-level `draw()`/`mousePressed()`/`mouseWheel()` wiring |
| `Theme.pde` | Color palette — copied 1:1 from `main/display/ui_theme.h` |
| `Widgets.pde` | Reusable `GButton`/`GTextField`/`GToggle`/`GSlider`/`GList` classes + the card-drawing helper — zero external library |
| `Persistence.pde` | Tiny key=value settings file (currently just the last-used COM port) |
| `AppState.pde` | The single reactive state object every screen reads from |
| `SerialManager.pde` | Port list/connect/send/receive, the auto-poll timer, **and the line parser** that turns the firmware's existing log output into `AppState` fields |
| `CommandCatalog.pde` | The full real command list, by category, backing the side menu + command panel |
| `TopMenuBar.pde` | COM dropdown (with persistence) / Connect / Settings / status indicator |
| `SideMenu.pde` | Command category list |
| `CommandPanel.pde` | Buttons/fields for whichever category is selected |
| `SerialMonitorPanel.pde` | Raw log + command input — a full Serial Monitor replacement |
| `DisplayPanel.pde` | The Display panel's outer frame, the 320×480↔window coordinate conversion, and the 5-tab nav bar |
| `DashboardScreen.pde` / `GPSScreen.pde` | Mirror the real screens |
| `MeterScreen.pde` | The `TRIP` tab's real Setup/Login/Duty/Trip controls |
| `SettingsScreen.pde` | Mirrors the real Settings screen + the added Diagnostics drill-down |
| `TestMenuScreen.pde` | The `TEST` tab's menu list + drill-down routing |
| `PaxMeterScreen.pde` | The PAX A920Pro visual reference clone |
| `ColorPaletteScreen.pde` | The color palette grid + detail view |
| `TestScreen.pde` | The added "Quick Commands" drill-down |

## How the parsing works (and its one real limitation)

`SerialManager.pde`'s `parseLine()` pattern-matches the firmware's **existing, unmodified** log
output. Nothing on the ESP32 side was changed to make this possible (doc 85 §B.2/§B.7's "zero
firmware change" path) — these are regex matches against human-readable, pretty-printed log text,
not a formal machine protocol, written against the exact label strings in the firmware source as of
this session. If a log message's wording changes later, its pattern here needs a matching update.

## What's NOT implemented

- Server-side trip sync, toll detection (doc 81 §7 phases 5-6 — not built on the firmware side
  yet either, nothing for this GUI to reflect)
- Mid-trip Sedan/Maxi tariff-type switching UI (doc 79 §5 — firmware supports it via
  `reference_data_get_tariff_types()`, no GUI control calls it yet)
- The real Color Palette screen's interactive color-wheel picker (noted above)
- Any polish beyond function — this is a testing/development tool first
