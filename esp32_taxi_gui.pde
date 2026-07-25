// ================================================================
// esp32_taxi_gui.pde — PC-side control/visualization GUI for the
// esp32_display_taxi_meter firmware, built in Processing 4.
//
// See README.md in this folder for the full explanation. Short
// version: this window has three parts (matching the wireframe you
// drew) —
//   1. A top menu bar: COM port select, Connect/Disconnect, Settings
//   2. A "Serial Monitor" panel (left) — raw log + a command input,
//      functionally identical to PlatformIO's built-in Serial Monitor
//   3. A "Display" panel (right) — a same-ratio, scaled-up mirror of
//      the real 320x480 Waveshare screen, recreated with the exact
//      same colors (Theme.pde, from ui_theme.h) and screen layouts
//      (DashboardScreen/GPSScreen/MeterScreen/etc.) as the real
//      firmware's LVGL UI.
//
// EVERY button in the "Display" panel sends the SAME text commands
// the Serial Monitor panel would (see SerialManager.pde's
// sendCommand()) — so anything you can do by clicking, you can also
// do by typing, and vice versa, and both update the same reactive
// AppState (AppState.pde) that every screen draws from every frame.
//
// NO ESP32 FIRMWARE CHANGES were made for this GUI to work — see
// docs/TestFunctionalities/display-tax-calculations/85_...md §B.2/§B.7.
// ================================================================

// ── Window / layout constants ─────────────────────────────────
// THE RATIO QUESTION: the real Waveshare display is 320x480 px
// (portrait, a 2:3 ratio — 320/480 = 0.667). Your laptop screen is
// 1366x768 — much wider AND much taller in absolute pixels, but that
// doesn't mean showing the display "true to size" would look right:
// 320x480 real pixels is tiny relative to a 1366x768 screen's normal
// viewing distance/DPI. So instead of matching absolute size, this
// GUI matches the SHAPE (2:3 portrait ratio) and scales it up by
// DISPLAY_SCALE so it's comfortably readable, while still fitting the
// laptop screen with room to spare for the serial monitor panel next
// to it. Change DISPLAY_SCALE alone to resize the whole mirror
// up/down — every screen in DisplayPanel positions itself relative to
// DISPLAY_W/DISPLAY_H, not fixed pixel numbers, so this stays correct
// at any scale.
final float DISPLAY_SCALE = 1.3;                 // 1.3x the real 320x480
final int   DISPLAY_W = round(320 * DISPLAY_SCALE); // 416 — same 2:3 ratio as the real display
final int   DISPLAY_H = round(480 * DISPLAY_SCALE); // 624

final int MARGIN = 15;
final int TOPBAR_H = 46;
final int PANEL_GAP = 15;

// Left-to-right: [Side Menu] [Command Panel] [Serial Monitor] [Display]
// All four share the same height (PANEL_H) so the row lines up cleanly.
final int SIDE_MENU_W     = 150;  // command categories (gps/api/trip/etc.)
final int COMMAND_PANEL_W = 270;  // buttons/fields for whichever category is selected
final int SERIAL_PANEL_W  = 400;
final int PANEL_H = DISPLAY_H;    // 624 — every left-hand panel matches the Display panel's height

final int WIN_W = MARGIN + SIDE_MENU_W + PANEL_GAP + COMMAND_PANEL_W + PANEL_GAP
                + SERIAL_PANEL_W + PANEL_GAP + DISPLAY_W + MARGIN;                          // 1301
final int WIN_H = MARGIN + TOPBAR_H + PANEL_GAP + PANEL_H + MARGIN;                         // 715

void settings() {
  size(WIN_W, WIN_H);
}

void setup() {
  surface.setTitle("ESP32 TaxiMeter — Control & Display GUI");
  // Resizable so the OS maximize button works at all — see
  // updateGuiOffset()/draw() below for what "maximize" actually does
  // here (letterbox, not stretch — your ask: accidental clicks outside
  // the maximized window were landing on whatever app is behind it).
  surface.setResizable(true);
  initTheme();
  refreshPortList();
  initTopMenuBar();
  initSideMenu();
  initSerialMonitorPanel();
  initDisplayPanel();
  // Consolas, not Arial — the ESP32's own log output is full of
  // characters Arial doesn't have (═/─ box-drawing dividers, ✓, °, ¢, —),
  // which Processing renders as empty boxes and prints "Some characters
  // not available in the current font" for. Consolas is a monospace
  // programming/terminal font (ships with Windows) with full coverage of
  // all of those — same reason Arduino's own Serial Monitor and every
  // real terminal emulator uses a monospace font for exactly this kind
  // of output. Also just looks right for a log/console view.
  textFont(createFont("Consolas", 13, true));
}

// ── Maximize = letterbox, not stretch. The GUI's actual content is
//    laid out for a fixed WIN_W x WIN_H (every panel's math assumes
//    that exact size) — redoing that math to reflow at arbitrary sizes
//    would be a much bigger change for no real benefit here. Instead,
//    when the OS window is bigger than WIN_W x WIN_H (maximized, or
//    manually resized larger), the content is drawn at its normal fixed
//    size, centered, with the surrounding area filled in background
//    color — so a maximized window still claims the full screen (no
//    stray clicks landing on whatever's behind it, which is what you
//    hit by accident), it just doesn't stretch/distort the UI.
//
//    guiMouseX/guiMouseY are mouseX/mouseY translated into the SAME
//    content-space every panel's own coordinates are already written
//    in — every click/hover/scroll handler below uses these instead of
//    raw mouseX/mouseY (mirrors the exact pattern DisplayPanel.pde's
//    own dispMouseLX/dispMouseLY already uses one level down, for its
//    nested scale() transform). ──
float guiOffsetX = 0, guiOffsetY = 0;
float guiMouseX = 0, guiMouseY = 0;

void updateGuiOffset() {
  guiOffsetX = max(0, (width - WIN_W) / 2.0);
  guiOffsetY = max(0, (height - WIN_H) / 2.0);
  guiMouseX = mouseX - guiOffsetX;
  guiMouseY = mouseY - guiOffsetY;
}

void draw() {
  updateGuiOffset();

  background(GUI_CHROME_BG); // fills the FULL actual window, including any letterbox margin

  pushMatrix();
  translate(guiOffsetX, guiOffsetY);

  pollIfNeeded();

  drawTopMenuBar();

  int panelsY = MARGIN + TOPBAR_H + PANEL_GAP;
  drawSideMenu(MARGIN, panelsY, SIDE_MENU_W, PANEL_H);
  drawCommandPanel(MARGIN + SIDE_MENU_W + PANEL_GAP, panelsY, COMMAND_PANEL_W, PANEL_H);
  drawSerialMonitorPanel(MARGIN + SIDE_MENU_W + PANEL_GAP + COMMAND_PANEL_W + PANEL_GAP, panelsY, SERIAL_PANEL_W, PANEL_H);
  drawDisplayPanel(MARGIN + SIDE_MENU_W + PANEL_GAP + COMMAND_PANEL_W + PANEL_GAP + SERIAL_PANEL_W + PANEL_GAP, panelsY, DISPLAY_W, DISPLAY_H);

  // Drawn LAST so it renders on top of every panel above, not under them.
  drawComDropdownOverlayIfOpen();
  drawBaudDropdownOverlayIfOpen();

  popMatrix();
}

// ── Global input dispatch — every panel gets a look at each click;
//    each panel's own handle*Click() internally ignores clicks outside
//    its own bounds, so calling all three unconditionally is safe.
//    fieldFocusedThisClick + clearFocusIfClickedOutside() (Widgets.pde)
//    handle blurring a text field when you click something that isn't
//    one (a button, empty space) — see the comment there for why this
//    needs its own explicit flag rather than reusing a "was anything
//    clicked" boolean. ──
void mousePressed() {
  updateGuiOffset();

  // Right-click = paste, exclusively — a keyboard-independent fallback
  // since Ctrl+V (Widgets.pde's keyPressed()) turned out not to be
  // reliable on your setup. Handled BEFORE the normal left-click
  // dispatch chain below and returns immediately, so a right-click
  // never also triggers whatever button/field would normally be under
  // it (those handlers don't distinguish mouse buttons on their own).
  if (mouseButton == RIGHT) {
    if (focusedField != null) {
      float px = focusedField.logicalSpace ? dispMouseLX : guiMouseX;
      float py = focusedField.logicalSpace ? dispMouseLY : guiMouseY;
      if (focusedField.contains(px, py)) focusedField.insertAtCaret(getFromClipboard());
    }
    return;
  }

  fieldFocusedThisClick = false;
  logSelectionStartedThisClick = false;
  handleTopMenuBarClick(guiMouseX, guiMouseY);
  handleSideMenuClick(guiMouseX, guiMouseY);
  handleCommandPanelClick(guiMouseX, guiMouseY);
  handleSerialMonitorClick(guiMouseX, guiMouseY);
  handleSerialMonitorPress(guiMouseX, guiMouseY);
  handleDisplayPanelClick(guiMouseX, guiMouseY);
  clearFocusIfClickedOutside();
  clearLogSelectionIfClickedOutside();
}

// ── Global scroll dispatch — same "each panel checks its own bounds,
//    first match wins" pattern as mousePressed() above. The COM
//    dropdown, when open, gets first refusal so scrolling a long port
//    list doesn't also scroll whatever's underneath it. ──
void mouseWheel(processing.event.MouseEvent event) {
  updateGuiOffset();
  // Two DIFFERENT units on purpose: GList-backed lists (side menu,
  // command panel, dropdowns) scroll in PIXELS (scrollPx), so 24px/notch
  // feels right there. The Serial Monitor log scrolls in LINE COUNT
  // (logScrollOffset — see SerialMonitorPanel.pde), not pixels — reusing
  // the same 24-per-notch value there meant every wheel notch jumped 24
  // whole LINES (the entire visible log, in one tick), which is what was
  // making it feel jerky/wrong. logAmount matches the expanded window's
  // own SerialMonitorWindow.pde (already correctly 3 lines/notch).
  float amount = event.getCount() * 24;     // pixel-based lists
  float logAmount = event.getCount() * 3;   // line-based log

  if (comDropdownOpen) {
    if (comDropdownList != null) comDropdownList.handleScroll(guiMouseX, guiMouseY, amount);
    return;
  }
  if (baudDropdownOpen) {
    if (baudDropdownList != null) baudDropdownList.handleScroll(guiMouseX, guiMouseY, amount);
    return;
  }

  if (handleSideMenuScroll(guiMouseX, guiMouseY, amount)) return;
  if (handleCommandPanelScroll(guiMouseX, guiMouseY, amount)) return;
  if (handleSerialMonitorScroll(guiMouseX, guiMouseY, logAmount)) return;
  handleDisplayPanelScroll(guiMouseX, guiMouseY, amount);
}

// Enter-to-submit routing — which action Enter triggers depends on
// which text field currently has focus. Widgets.pde calls this.
void onFocusedFieldEnter() {
  if (focusedField == serialInputField) {
    submitSerialInput();
  } else if (!handleCommandPanelEnter()) {
    handleMeterScreenEnter();
  }
}

// ── Detached Serial Monitor window (your ask: "expand icon... open
//    another window that serial monitor need to be same as what we get
//    in arduino") — SerialMonitorWindow.pde defines the secondary
//    PApplet; this just owns the single instance and shows/hides it
//    instead of recreating it on every toggle. ──
SerialMonitorWindow serialWindow = null;
boolean serialWindowOpen = false;

void toggleSerialMonitorWindow() {
  if (serialWindow == null) {
    serialWindow = new SerialMonitorWindow();
    PApplet.runSketch(new String[]{"ESP32 TaxiMeter — Serial Monitor (Expanded)"}, serialWindow);
    serialWindowOpen = true;
  } else if (serialWindowOpen) {
    serialWindow.hideWindow(); // not .surface.setVisible() directly — see SerialMonitorWindow.pde's comment
    serialWindowOpen = false;
  } else {
    serialWindow.showWindow();
    serialWindowOpen = true;
  }
}
