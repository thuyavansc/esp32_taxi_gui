// ================================================================
// SideMenu.pde — Far-left command category list (your ask: "very
// left we will have like side menu... gps command api call trip
// storage and reset likewise"). Selecting a category shows its
// commands in CommandPanel.pde, immediately to its right.
// ================================================================

int selectedCategory = 0;
GList sideMenuList;

int sideMenuX, sideMenuY, sideMenuW, sideMenuH; // for scroll-routing

void initSideMenu() {
  initCommandCatalog();
  String[] names = new String[COMMAND_CATEGORIES.length];
  for (int i = 0; i < COMMAND_CATEGORIES.length; i++) names[i] = COMMAND_CATEGORIES[i].name;
  sideMenuList = new GList(0, 0, 10, 10, names); // real geometry set in drawSideMenu()
  sideMenuList.itemH = 40;
  sideMenuList.selected = selectedCategory;
}

void drawSideMenu(int x, int y, int w, int h) {
  sideMenuX = x; sideMenuY = y; sideMenuW = w; sideMenuH = h;

  fill(C_TEST_BG);
  stroke(GUI_CHROME_BORDER);
  strokeWeight(1);
  rect(x, y, w, h, 6);
  noStroke();

  fill(C_ACCENT);
  rect(x, y, w, 32, 6, 6, 0, 0);
  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(13);
  text("COMMANDS", x + w / 2, y + 16);

  sideMenuList.x = x + 4; sideMenuList.y = y + 38;
  sideMenuList.w = w - 8; sideMenuList.h = h - 44;
  sideMenuList.selected = selectedCategory;
  sideMenuList.draw(guiMouseX, guiMouseY);
}

boolean handleSideMenuClick(float mx, float my) {
  if (sideMenuList.handleClick(mx, my)) {
    if (sideMenuList.lastClickedIndex >= 0) {
      selectedCategory = sideMenuList.lastClickedIndex;
      commandPanelScroll = 0; // land at the top of the newly-selected category
    }
    return true;
  }
  return mx >= sideMenuX && mx <= sideMenuX + sideMenuW && my >= sideMenuY && my <= sideMenuY + sideMenuH;
}

boolean handleSideMenuScroll(float mx, float my, float amount) {
  return sideMenuList.handleScroll(mx, my, amount);
}
