// ================================================================
// ColorPaletteScreen.pde — Mirrors main/display/test/color_palette/
// color_palette_ui.c's swatch grid + detail drill-down, using the
// SAME 24-color data set (color_palette_data.h's PALETTE_COLORS[]) —
// 5 pure diagnostic colors + the 19 real theme colors, exact names,
// exact hex values.
//
// NOT replicated: the real screen's interactive color-wheel picker
// (an LVGL lv_colorwheel widget below the grid, for testing arbitrary
// colors) — lower value for a testing GUI than the swatch grid/detail
// view, and it would roughly double this file's size. Flagged here
// rather than silently dropped.
// ================================================================

class PaletteEntry {
  String name, varName, hex;
  color c;
  PaletteEntry(String name, String varName, String hex, int rgb) {
    this.name = name; this.varName = varName; this.hex = hex;
    this.c = color((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);
  }
}

PaletteEntry[] PALETTE_COLORS;
int paletteDetailIndex = -1; // -1 = grid view
float paletteScrollPx = 0;

GButton btnPaletteBack;

void initColorPaletteScreen() {
  btnPaletteBack = new GButton(0, 4, 56, 28, "< Back", C_BTN, C_TEXT);

  PALETTE_COLORS = new PaletteEntry[] {
    new PaletteEntry("Pure Red",   "-",  "#FF0000", 0xFF0000),
    new PaletteEntry("Pure Green", "-",  "#00FF00", 0x00FF00),
    new PaletteEntry("Pure Blue",  "-",  "#0000FF", 0x0000FF),
    new PaletteEntry("Pure White", "-",  "#FFFFFF", 0xFFFFFF),
    new PaletteEntry("Pure Black", "-",  "#000000", 0x000000),

    new PaletteEntry("Jet Black",              "C_BG",        "#052C36", 0x052C36),
    new PaletteEntry("Jet Black 2",            "C_BG2",       "#11313A", 0x11313A),
    new PaletteEntry("Dark Teal 2",            "C_CARD",      "#073F4A", 0x073F4A),
    new PaletteEntry("Dark Teal",              "C_NAV_BG",    "#025773", 0x025773),
    new PaletteEntry("Baltic Blue",            "C_BTN",       "#095B78", 0x095B78),
    new PaletteEntry("Cerulean",               "C_BTN_HOVER", "#166B87", 0x166B87),
    new PaletteEntry("Cerulean (Accent)",      "C_ACCENT",    "#166B87", 0x166B87),
    new PaletteEntry("Cerulean 2",             "C_ACCENT2",   "#297591", 0x297591),
    new PaletteEntry("Baltic Blue (Mid)",      "C_MID",       "#095B78", 0x095B78),
    new PaletteEntry("Active Green",           "C_NAV_ACT",   "#00C97A", 0x00C97A),
    new PaletteEntry("Active Green (Success)", "C_SUCCESS",   "#00C97A", 0x00C97A),
    new PaletteEntry("Warm Orange",            "C_WARN",      "#FF9F40", 0xFF9F40),
    new PaletteEntry("Alert Red",              "C_ERROR",     "#E05050", 0xE05050),
    new PaletteEntry("Bright White",           "C_TEXT",      "#F0F4F5", 0xF0F4F5),
    new PaletteEntry("Light Cyan",             "C_TEXT2",     "#A8D8E8", 0xA8D8E8),
    new PaletteEntry("Divider",                "C_DIVIDER",   "#0D4555", 0x0D4555),
    new PaletteEntry("Test BG",                "C_TEST_BG",   "#1A1A1A", 0x1A1A1A),
    new PaletteEntry("Test Card",              "C_TEST_CARD", "#242424", 0x242424),
    new PaletteEntry("Test Header",            "C_TEST_HDR",  "#2A2A2A", 0x2A2A2A),
  };
}

final int PAL_CARD_W = 140, PAL_CARD_H = 92, PAL_GAP = 8;
final int PAL_GRID_Y = 64, PAL_GRID_H = 480 - PAL_GRID_Y - 52; // stop above the nav bar (matches every other screen's bound)

void drawColorPaletteScreen() {
  if (paletteDetailIndex >= 0) { drawPaletteDetail(); return; }

  fill(C_ACCENT); noStroke(); rect(0, 0, 320, 36);
  btnPaletteBack.draw(dispMouseLX, dispMouseLY);
  fill(C_TEXT); textAlign(RIGHT, CENTER); textSize(13);
  text("COLOR PALETTES", 312, 18);

  fill(C_TEXT2); textAlign(CENTER, TOP); textSize(11);
  text(PALETTE_COLORS.length + " colors (5 pure + theme)", 160, 44);

  int maxScroll = max(0, ceil(PALETTE_COLORS.length / 2.0) * (PAL_CARD_H + PAL_GAP) - PAL_GRID_H);
  paletteScrollPx = constrain(paletteScrollPx, 0, maxScroll);

  clip(0, PAL_GRID_Y, 320, PAL_GRID_H);
  for (int i = 0; i < PALETTE_COLORS.length; i++) {
    int col = i % 2, row = i / 2;
    float cx = 8 + col * (PAL_CARD_W + PAL_GAP);
    float cy = PAL_GRID_Y + row * (PAL_CARD_H + PAL_GAP) - paletteScrollPx;
    if (cy + PAL_CARD_H < PAL_GRID_Y || cy > PAL_GRID_Y + PAL_GRID_H) continue; // off-screen, skip drawing

    boolean hover = dispMouseLX >= cx && dispMouseLX <= cx + PAL_CARD_W && dispMouseLY >= cy && dispMouseLY <= cy + PAL_CARD_H;
    fill(hover ? C_BTN_HOVER : C_BG2); noStroke();
    rect(cx, cy, PAL_CARD_W, PAL_CARD_H, 8);

    fill(PALETTE_COLORS[i].c);
    stroke(C_DIVIDER); strokeWeight(1);
    rect(cx + 5, cy + 2, PAL_CARD_W - 10, 44, 4);
    noStroke();

    fill(C_TEXT); textAlign(CENTER, BOTTOM); textSize(10);
    text(PALETTE_COLORS[i].name, cx + PAL_CARD_W / 2, cy + PAL_CARD_H - 14);
    fill(C_TEXT2);
    text(PALETTE_COLORS[i].hex, cx + PAL_CARD_W / 2, cy + PAL_CARD_H - 2);
  }
  noClip();

  if (maxScroll > 0) {
    float thumbH = max(20, PAL_GRID_H * (PAL_GRID_H / (float)(maxScroll + PAL_GRID_H)));
    float thumbY = PAL_GRID_Y + (PAL_GRID_H - thumbH) * (paletteScrollPx / maxScroll);
    fill(C_ACCENT2); noStroke();
    rect(316, thumbY, 4, thumbH, 2);
  }
}

void drawPaletteDetail() {
  PaletteEntry e = PALETTE_COLORS[paletteDetailIndex];
  boolean lightBg = brightness(e.c) > 140;
  color contrastColor = lightBg ? C_BG : C_TEXT;

  fill(C_ACCENT); noStroke(); rect(0, 0, 320, 36);
  btnPaletteBack.draw(dispMouseLX, dispMouseLY);
  fill(C_TEXT); textAlign(RIGHT, CENTER); textSize(13);
  text(e.name, 312, 18);

  fill(e.c); noStroke();
  stroke(C_DIVIDER); strokeWeight(1);
  rect(10, 46, 300, 360, 10);
  noStroke();

  fill(contrastColor); textAlign(CENTER, CENTER); textSize(26);
  text(e.name, 160, 226 - 14);
  textSize(15);
  text(e.hex + (e.varName.equals("-") ? "" : ("  (" + e.varName + ")")), 160, 226 + 20);
}

boolean handleColorPaletteScreenClick(float lx, float ly) {
  if (btnPaletteBack.contains(lx, ly)) {
    if (paletteDetailIndex >= 0) paletteDetailIndex = -1; else testMenuReturn();
    return true;
  }
  if (paletteDetailIndex >= 0) return true; // nothing else clickable in detail view

  if (ly < PAL_GRID_Y || ly > PAL_GRID_Y + PAL_GRID_H) return true;
  for (int i = 0; i < PALETTE_COLORS.length; i++) {
    int col = i % 2, row = i / 2;
    float cx = 8 + col * (PAL_CARD_W + PAL_GAP);
    float cy = PAL_GRID_Y + row * (PAL_CARD_H + PAL_GAP) - paletteScrollPx;
    if (lx >= cx && lx <= cx + PAL_CARD_W && ly >= cy && ly <= cy + PAL_CARD_H) {
      paletteDetailIndex = i;
      break;
    }
  }
  return true;
}

boolean handleColorPaletteScreenScroll(float amount) {
  if (paletteDetailIndex >= 0) return false;
  paletteScrollPx += amount;
  return true;
}
