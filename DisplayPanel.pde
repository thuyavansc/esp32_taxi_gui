// ================================================================
// DisplayPanel.pde — The right-hand "Display" panel: a same-2:3-ratio,
// scaled mirror of the real 320x480 Waveshare screen.
//
// KEY TRICK: everything inside this panel is drawn in the SAME 320x480
// logical coordinate space the real firmware's LVGL code uses (see
// main/display/ui_main.c) — a single scale(DISPLAY_SCALE) transform
// does the resizing. That means screen layouts here can copy
// coordinates straight out of ui_main.c/gps_screen.c almost verbatim,
// which is why DashboardScreen/GPSScreen look like the real thing
// without needing separate "GUI version" math.
//
// Nav bar mirrors the real device's 5-tab bottom bar (ui_widgets.c's
// ui_add_nav_bar) — DASH / GPS / TRIP / SET / TEST, same colors, same
// active-tab highlight. "TRIP" here shows the new Setup→Login→Duty→
// Trip flow (MeterScreen.pde) — the real device doesn't have this
// screen yet (doc 81 §5), this is where it lives until it does.
// ================================================================

int currentScreen = 0; // 0=Dashboard 1=GPS 2=Meter(Trip) 3=Settings 4=Test
final String[] NAV_LABELS = {"DASH", "GPS", "TRIP", "SET", "TEST"};

int dispPanelX, dispPanelY; // top-left of the panel in WINDOW space, for click-coordinate conversion

// Mouse position converted into the SAME 320x480 logical space every
// screen draws in — recomputed once per frame (drawDisplayPanel(),
// before the scale() transform below) so every screen's buttons can
// hover-highlight correctly against it instead of raw window
// mouseX/mouseY (see the comment on GButton.draw(hoverX, hoverY) in
// Widgets.pde for why that distinction matters).
float dispMouseLX, dispMouseLY;

void initDisplayPanel() {
  initDashboardScreen();
  initGPSScreen();
  initMeterScreen();
  initSettingsScreenMirror();
  initTestScreenMirror();
}

void drawDisplayPanel(int x, int y, int w, int h) {
  dispPanelX = x; dispPanelY = y;
  // guiMouseX/guiMouseY, not raw mouseX/mouseY — x/y here are already in
  // GUI content-space (drawDisplayPanel() is called from inside draw()'s
  // translate(guiOffsetX, guiOffsetY) block), so the mouse position needs
  // the same content-space translation to line up (see updateGuiOffset(),
  // esp32_taxi_gui.pde).
  dispMouseLX = (guiMouseX - x) / DISPLAY_SCALE;
  dispMouseLY = (guiMouseY - y) / DISPLAY_SCALE;

  // Phone-like bezel frame around the mirrored screen
  fill(20, 20, 20);
  stroke(GUI_CHROME_BORDER);
  strokeWeight(1);
  rect(x - 10, y - 10, w + 20, h + 20, 14);
  noStroke();

  pushMatrix();
  translate(x, y);
  scale(DISPLAY_SCALE);

  // Logical coordinate space is now exactly 0..320 (x) by 0..480 (y),
  // matching the real display 1:1 — everything below uses those units.
  noStroke();
  fill(C_BG);
  rect(0, 0, 320, 480);

  switch (currentScreen) {
    case 0: drawDashboardScreen(); break;
    case 1: drawGPSScreen(); break;
    case 2: drawMeterScreen(); break;
    case 3: drawSettingsScreenMirror(); updateSettingsSliderDrag(); break;
    default: drawTestScreenMirror(); break;
  }

  drawNavBar();

  popMatrix();
}

// Bottom 320x52 nav bar — logical coordinates, drawn last so it's always on top
void drawNavBar() {
  int navY = 480 - 52;
  fill(C_NAV_BG);
  noStroke();
  rect(0, navY, 320, 52);

  int bw = 62;
  for (int i = 0; i < 5; i++) {
    boolean active = (i == currentScreen);
    int bx = i * (bw + 2) + 2;
    fill(active ? C_NAV_ACT : C_BTN);
    rect(bx, navY + 3, bw, 46, 5);
    fill(active ? C_BG : C_TEXT);
    textAlign(CENTER, CENTER);
    textSize(11);
    text(NAV_LABELS[i], bx + bw / 2, navY + 3 + 23);
  }
}

// Converts a window-space click into this panel's 320x480 logical
// space, and dispatches to the nav bar or the current screen.
boolean handleDisplayPanelClick(float mx, float my) {
  float lx = (mx - dispPanelX) / DISPLAY_SCALE;
  float ly = (my - dispPanelY) / DISPLAY_SCALE;
  if (lx < 0 || lx > 320 || ly < 0 || ly > 480) return false;

  int navY = 480 - 52;
  if (ly >= navY) {
    int bw = 62;
    int tab = (int)(lx / (bw + 2));
    if (tab >= 0 && tab < 5) { currentScreen = tab; return true; }
    return true;
  }

  switch (currentScreen) {
    case 0: return handleDashboardScreenClick(lx, ly);
    case 1: return handleGPSScreenClick(lx, ly);
    case 2: return handleMeterScreenClick(lx, ly);
    case 3: return handleSettingsScreenMirrorClick(lx, ly);
    default: return handleTestScreenMirrorClick(lx, ly);
  }
}

// Same window-to-logical conversion as handleDisplayPanelClick(),
// for the sketch-wide mouseWheel() dispatcher — only Settings' list
// and the Test tab's menu list / color-palette grid actually scroll;
// Dashboard/GPS/Meter have nothing tall enough to need it.
boolean handleDisplayPanelScroll(float mx, float my, float amount) {
  float lx = (mx - dispPanelX) / DISPLAY_SCALE;
  float ly = (my - dispPanelY) / DISPLAY_SCALE;
  if (lx < 0 || lx > 320 || ly < 0 || ly > 480) return false;

  if (currentScreen == 3) return handleSettingsScreenMirrorScroll(lx, ly, amount);
  if (currentScreen == 4) {
    if (testSubScreen == -1) return handleTestScreenMirrorScroll(lx, ly, amount);
    if (testSubScreen == 1)  return handleColorPaletteScreenScroll(amount);
  }
  return false;
}
