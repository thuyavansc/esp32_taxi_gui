// ================================================================
// SettingsScreen.pde — Mirrors main/display/ui_main.c's
// _create_settings() layout: brightness slider, contrast slider (real
// firmware marks contrast "test only" — same here, neither slider
// controls real PC hardware, there's no backlight to dim; kept for
// visual/structural parity per your ask), and the same 10-item
// scrollable info list, SAME exact strings, in the SAME order.
//
// ADDED: an 11th list entry, "Diagnostics", not on the real device —
// your ask: "additionally add diagnostics as list when click this
// diagnostic UI current we have in set need come same UI." Clicking
// it drills into the mem/store/ref-data panel from this session's
// earlier pass (same buttons, same live readouts, unchanged).
// ================================================================

GSlider sliderBrightness, sliderContrast;
GList settingsList;
int settingsSubScreen = -1; // -1 = main settings screen; 0 = Diagnostics drill-down

final String[] SETTINGS_ITEMS = {
  "WiFi: CONNECTED",
  "IP: 192.168.x.x",
  "GPS: NEO-6M",
  "Socket: iStartek",
  "Fare Rate: $2.50/km",
  "Flag Fall: $3.80",
  "Storage: SPIFFS 2.4MB",
  "Display: 3.5\" ST7796S",
  "Firmware: v1.0",
  "ESP-IDF: 5.x + LVGL 8.3",
  "→ Diagnostics (mem / store / ref data)",
};

GButton btnDiagBack, btnMem, btnStore, btnRefFetch, btnRefInfo, btnSessionInfo;

void initSettingsScreenMirror() {
  sliderBrightness = new GSlider(112, 36 + 34, 192, 8, C_SUCCESS);
  sliderContrast    = new GSlider(112, 96 + 34, 192, 8, C_ACCENT2);
  settingsList = new GList(8, 156, 304, 272, SETTINGS_ITEMS);
  settingsList.itemH = 34;

  btnDiagBack    = new GButton(0, 4, 56, 28, "< Back", C_BTN, C_TEXT);
  int y = 46;
  btnMem         = new GButton(8, y, 145, 30, "mem (RAM check)", C_BTN, C_TEXT);
  btnStore       = new GButton(167, y, 145, 30, "store (what's saved)", C_BTN, C_TEXT);
  y += 38;
  btnRefFetch    = new GButton(8, y, 145, 30, "ref fetch", C_BTN, C_TEXT);
  btnRefInfo     = new GButton(167, y, 145, 30, "ref info", C_BTN, C_TEXT);
  y += 38;
  btnSessionInfo = new GButton(8, y, 304, 30, "session info", C_BTN, C_TEXT);
}

void drawSettingsScreenMirror() {
  if (settingsSubScreen == 0) { drawDiagnosticsScreen(); return; }

  fill(C_ACCENT); noStroke(); rect(0, 0, 320, 32);
  fill(C_TEXT); textAlign(CENTER, CENTER); textSize(13);
  text("SETTINGS", 160, 16);

  // Brightness row
  drawMirrorCard(8, 36, 304, 54, C_DIVIDER, 1);
  textAlign(LEFT, CENTER); fill(C_TEXT2); textSize(12); text("Brightness", 16, 36 + 15);
  textAlign(RIGHT, CENTER); fill(C_TEXT);
  text(sliderBrightness.value + "%", 304, 36 + 15);
  sliderBrightness.draw();

  // Contrast row
  drawMirrorCard(8, 96, 304, 54, C_DIVIDER, 1);
  textAlign(LEFT, CENTER); fill(C_TEXT2); textSize(12); text("Contrast (test)", 16, 96 + 15);
  textAlign(RIGHT, CENTER); fill(C_TEXT);
  text(sliderContrast.value + "%", 304, 96 + 15);
  sliderContrast.draw();

  settingsList.draw(dispMouseLX, dispMouseLY);
}

void drawDiagnosticsScreen() {
  fill(C_ACCENT); noStroke(); rect(0, 0, 320, 36);
  btnDiagBack.draw(dispMouseLX, dispMouseLY);
  fill(C_TEXT); textAlign(RIGHT, CENTER); textSize(13);
  text("DIAGNOSTICS", 312, 18);

  btnMem.draw(dispMouseLX, dispMouseLY); btnStore.draw(dispMouseLX, dispMouseLY);
  btnRefFetch.draw(dispMouseLX, dispMouseLY); btnRefInfo.draw(dispMouseLX, dispMouseLY);
  btnSessionInfo.draw(dispMouseLX, dispMouseLY);

  int y = 166;
  drawMirrorCard(8, y, 304, 90);
  textAlign(LEFT, TOP); textSize(11);
  fill(C_TEXT2); text("Free heap now", 16, y + 10);
  fill(state.freeHeapKB >= 0 && state.freeHeapKB < 20 ? C_ERROR : C_TEXT);
  textSize(16);
  text(state.freeHeapKB >= 0 ? (state.freeHeapKB + " KB") : "— (click 'mem')", 16, y + 26);
  fill(C_TEXT2); textSize(11); text("Largest free block", 16, y + 52);
  fill(state.largestBlockKB >= 0 && state.largestBlockKB < 20 ? C_ERROR : C_TEXT);
  textSize(16);
  text(state.largestBlockKB >= 0 ? (state.largestBlockKB + " KB") : "—", 16, y + 68);

  y += 100;
  drawMirrorCard(8, y, 304, 70);
  textAlign(LEFT, TOP); textSize(11); fill(C_TEXT2);
  text("Reference data loaded", 16, y + 8);
  fill(C_TEXT); textSize(13);
  text("Tariffs:" + state.tariffCount + "  FixedRates:" + state.fixedRateCount, 16, y + 26);
  text("SpecialFares:" + state.specialFareCount + "  Holidays:" + state.holidayCount, 16, y + 44);
}

boolean handleSettingsScreenMirrorClick(float lx, float ly) {
  if (settingsSubScreen == 0) {
    if (btnDiagBack.contains(lx, ly))    { settingsSubScreen = -1; return true; }
    if (btnMem.contains(lx, ly))         { sendCommand("mem"); return true; }
    if (btnStore.contains(lx, ly))       { sendCommand("store"); return true; }
    if (btnRefFetch.contains(lx, ly))    { sendCommand("ref fetch"); return true; }
    if (btnRefInfo.contains(lx, ly))     { sendCommand("ref info"); return true; }
    if (btnSessionInfo.contains(lx, ly)) { sendCommand("session info"); return true; }
    return true;
  }

  if (sliderBrightness.contains(lx, ly)) { sliderBrightness.dragging = true; sliderBrightness.updateFromMouse(lx); return true; }
  if (sliderContrast.contains(lx, ly))   { sliderContrast.dragging = true;   sliderContrast.updateFromMouse(lx);   return true; }

  if (settingsList.handleClick(lx, ly)) {
    if (settingsList.lastClickedIndex == SETTINGS_ITEMS.length - 1) {
      settingsSubScreen = 0; // the "→ Diagnostics" row
    } else if (settingsList.lastClickedIndex >= 0) {
      logLine("[gui] Settings item tapped (inert on the real device too — ui_main.c's _click_event just logs)");
    }
    return true;
  }
  return true;
}

// Called every frame from DisplayPanel while a mouse button is held,
// so dragging a slider tracks smoothly instead of only updating on
// the initial click (mousePressed fires once, not continuously).
void updateSettingsSliderDrag() {
  if (mousePressed) {
    if (sliderBrightness.dragging) sliderBrightness.updateFromMouse(dispMouseLX);
    if (sliderContrast.dragging)   sliderContrast.updateFromMouse(dispMouseLX);
  } else {
    sliderBrightness.dragging = false;
    sliderContrast.dragging = false;
  }
}

boolean handleSettingsScreenMirrorScroll(float mx, float my, float amount) {
  if (settingsSubScreen == 0) return false;
  return settingsList.handleScroll(mx, my, amount);
}
