// ================================================================
// TestMenuScreen.pde — Mirrors main/display/test/test_menu.c EXACTLY:
// same 2 real entries ("PAX A920Pro Meter UI", "Color Palette Viewer"),
// same drill-down-with-back-button navigation, same list-row geometry
// (296x48 cards, numbered, chevron). A 3rd entry, "Quick Commands", is
// added for the shortcuts panel from this session's earlier pass —
// your ask: "additionally you created quick command right that also
// add as a list menu."
//
// ONE deliberate deviation from the real firmware: the real PAX Meter
// screen has NO bottom nav bar (it only has its own in-header "< Back"
// button, main/display/test/test_pax_meter.c's own design). This GUI
// keeps the bottom DASH/GPS/TRIP/SET/TEST nav bar visible on every
// screen including this one, since jumping straight to another
// top-level tab is more useful here than it would be on the real
// device (which doesn't need it — the physical device has no "GUI
// convenience" concern, a driver isn't tapping through test screens
// mid-shift). The screen's own "< Back" button still works exactly
// like the real one, returning to this menu list.
// ================================================================

int testSubScreen = -1; // -1 = the menu list itself; 0/1/2 = drilled into an entry

GList testMenuList;
final String[] TEST_MENU_ITEMS = {
  "01  PAX A920Pro Meter UI",
  "02  Color Palette Viewer",
  "03  Quick Commands",
};

void initTestScreenMirror() {
  testMenuList = new GList(8, 62, 304, 366, TEST_MENU_ITEMS); // ends at y=428, right at the nav bar
  testMenuList.itemH = 48;
  initPaxMeterScreen();
  initColorPaletteScreen();
  initQuickCommandsScreen();
}

void drawTestScreenMirror() {
  if (testSubScreen == 0) { drawPaxMeterScreen(); return; }
  if (testSubScreen == 1) { drawColorPaletteScreen(); return; }
  if (testSubScreen == 2) { drawQuickCommandsScreen(); return; }

  // The menu list itself
  fill(C_ACCENT);
  noStroke();
  rect(0, 0, 320, 32);
  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(13);
  text("TEST MENU", 160, 16);

  textAlign(CENTER, TOP);
  textSize(11);
  fill(C_TEXT2);
  text(TEST_MENU_ITEMS.length + " test UIs available", 160, 40);

  testMenuList.draw(dispMouseLX, dispMouseLY);
}

boolean handleTestScreenMirrorClick(float lx, float ly) {
  if (testSubScreen == 0) return handlePaxMeterScreenClick(lx, ly);
  if (testSubScreen == 1) return handleColorPaletteScreenClick(lx, ly);
  if (testSubScreen == 2) return handleQuickCommandsScreenClick(lx, ly);

  if (testMenuList.handleClick(lx, ly)) {
    if (testMenuList.lastClickedIndex >= 0) {
      testSubScreen = testMenuList.lastClickedIndex;
      testMenuList.selected = -1; // don't leave a stale highlighted row when we come back
    }
    return true;
  }
  return true;
}

boolean handleTestScreenMirrorScroll(float mx, float my, float amount) {
  if (testSubScreen != -1) return false;
  return testMenuList.handleScroll(mx, my, amount);
}

// Shared by every drilled-down sub-screen's own back button
void testMenuReturn() {
  testSubScreen = -1;
}
