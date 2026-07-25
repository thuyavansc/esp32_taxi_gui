// ================================================================
// TestScreen.pde — "Quick Commands", the 3rd Test Menu entry (this
// session's addition, not on the real device). One-tap access to the
// read-only "info" commands, so you don't have to retype them while
// testing. Uses the same ui_back_header() look (320x36 bar, "< Back"
// button) as the real Color Palette Viewer screen for its own
// drill-down, so all three Test Menu entries feel consistent.
// ================================================================

GButton btnQcBack;
GButton btnHelp, btnGpsInfo, btnSetupInfo, btnAuthInfo, btnDutyInfo, btnTripInfo;
GButton btnRamInfo, btnReboot, btnNetInfo, btnNetTest;

void initQuickCommandsScreen() {
  btnQcBack = new GButton(0, 4, 56, 28, "< Back", C_BTN, C_TEXT);

  int y = 50;
  int w = 145, h = 30, gap = 8;
  btnHelp      = new GButton(8, y, w, h, "help", C_BTN, C_TEXT);
  btnGpsInfo   = new GButton(8 + w + gap, y, w, h, "gps info", C_BTN, C_TEXT);
  y += h + gap;
  btnSetupInfo = new GButton(8, y, w, h, "setup info", C_BTN, C_TEXT);
  btnAuthInfo  = new GButton(8 + w + gap, y, w, h, "auth info", C_BTN, C_TEXT);
  y += h + gap;
  btnDutyInfo  = new GButton(8, y, w, h, "duty info", C_BTN, C_TEXT);
  btnTripInfo  = new GButton(8 + w + gap, y, w, h, "trip info", C_BTN, C_TEXT);
  y += h + gap;
  btnRamInfo   = new GButton(8, y, w, h, "ram info", C_BTN, C_TEXT);
  btnReboot    = new GButton(8 + w + gap, y, w, h, "reboot", C_BTN, C_TEXT);
  y += h + gap;
  btnNetInfo   = new GButton(8, y, w, h, "net info", C_BTN, C_TEXT);
  btnNetTest   = new GButton(8 + w + gap, y, w, h, "net test", C_BTN, C_TEXT);
}

void drawQuickCommandsScreen() {
  fill(C_ACCENT);
  noStroke();
  rect(0, 0, 320, 36);
  btnQcBack.draw(dispMouseLX, dispMouseLY);
  fill(C_TEXT);
  textAlign(RIGHT, CENTER);
  textSize(13);
  text("QUICK COMMANDS", 316, 18);

  btnHelp.draw(dispMouseLX, dispMouseLY); btnGpsInfo.draw(dispMouseLX, dispMouseLY);
  btnSetupInfo.draw(dispMouseLX, dispMouseLY); btnAuthInfo.draw(dispMouseLX, dispMouseLY);
  btnDutyInfo.draw(dispMouseLX, dispMouseLY); btnTripInfo.draw(dispMouseLX, dispMouseLY);
  btnRamInfo.draw(dispMouseLX, dispMouseLY); btnReboot.draw(dispMouseLX, dispMouseLY);
  btnNetInfo.draw(dispMouseLX, dispMouseLY); btnNetTest.draw(dispMouseLX, dispMouseLY);

  textAlign(LEFT, TOP);
  textSize(10);
  fill(C_TEXT2);
  text("These buttons just save you retyping common commands (from\n" +
       "the side menu's full catalog) while testing. 'reboot' resets\n" +
       "the device immediately, no confirmation. 'net test' makes a\n" +
       "real HTTPS call to confirm the device actually has internet.",
       10, 240, 300, 100);
}

boolean handleQuickCommandsScreenClick(float lx, float ly) {
  if (btnQcBack.contains(lx, ly))    { testMenuReturn(); return true; }
  if (btnHelp.contains(lx, ly))      { sendCommand("help"); return true; }
  if (btnGpsInfo.contains(lx, ly))   { sendCommand("gps info"); return true; }
  if (btnSetupInfo.contains(lx, ly)) { sendCommand("setup info"); return true; }
  if (btnAuthInfo.contains(lx, ly))  { sendCommand("auth info"); return true; }
  if (btnDutyInfo.contains(lx, ly))  { sendCommand("duty info"); return true; }
  if (btnTripInfo.contains(lx, ly))  { sendCommand("trip info"); return true; }
  if (btnRamInfo.contains(lx, ly))   { sendCommand("ram info"); return true; }
  if (btnReboot.contains(lx, ly))    { sendCommand("reboot"); return true; }
  if (btnNetInfo.contains(lx, ly))   { sendCommand("net info"); return true; }
  if (btnNetTest.contains(lx, ly))   { sendCommand("net test"); return true; }
  return true;
}
