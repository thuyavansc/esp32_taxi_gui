// ================================================================
// Theme.pde — Color palette, EXACTLY mirrored from the real ESP32
// firmware's main/display/ui_theme.h (Cerulean/Teal theme), so this
// GUI's "Display" panel looks like the same device, not a reskin.
//
// Each color below has the source hex from ui_theme.h in a comment —
// if that file ever changes, update these to match.
// ================================================================

color C_BG, C_BG2, C_CARD;
color C_NAV_BG, C_BTN, C_BTN_HOVER;
color C_ACCENT, C_ACCENT2, C_MID;
color C_NAV_ACT, C_SUCCESS, C_WARN, C_ERROR;
color C_TEXT, C_TEXT2, C_DIVIDER;
color C_TEST_BG, C_TEST_CARD, C_TEST_HDR;

// Colors that only exist in this GUI (not on the real device) — for
// the parts of the window the ESP32 doesn't have an opinion about
// (top menu bar, serial monitor panel chrome).
color GUI_CHROME_BG, GUI_CHROME_BORDER, GUI_LOG_BG;

void initTheme() {
  C_BG        = color(0x05, 0x2C, 0x36); // Jet Black
  C_BG2       = color(0x11, 0x31, 0x3A); // Jet Black 2
  C_CARD      = color(0x07, 0x3F, 0x4A); // Dark Teal 2

  C_NAV_BG    = color(0x02, 0x57, 0x73); // Dark Teal
  C_BTN       = color(0x09, 0x5B, 0x78); // Baltic Blue
  C_BTN_HOVER = color(0x16, 0x6B, 0x87); // Cerulean

  C_ACCENT    = color(0x16, 0x6B, 0x87); // Cerulean
  C_ACCENT2   = color(0x29, 0x75, 0x91); // Cerulean 2
  C_MID       = color(0x09, 0x5B, 0x78); // Baltic Blue

  C_NAV_ACT   = color(0x00, 0xC9, 0x7A); // Active Green
  C_SUCCESS   = color(0x00, 0xC9, 0x7A);
  C_WARN      = color(0xFF, 0x9F, 0x40); // Warm Orange
  C_ERROR     = color(0xE0, 0x50, 0x50); // Alert Red

  C_TEXT      = color(0xF0, 0xF4, 0xF5); // Bright White
  C_TEXT2     = color(0xA8, 0xD8, 0xE8); // Light Cyan
  C_DIVIDER   = color(0x0D, 0x45, 0x55);

  C_TEST_BG   = color(0x1A, 0x1A, 0x1A);
  C_TEST_CARD = color(0x24, 0x24, 0x24);
  C_TEST_HDR  = color(0x2A, 0x2A, 0x2A);

  // GUI-only chrome — kept close to the same family so the whole
  // window reads as one app, not two different themes glued together.
  GUI_CHROME_BG     = color(0x08, 0x1B, 0x21);
  GUI_CHROME_BORDER = color(0x0D, 0x45, 0x55);
  GUI_LOG_BG        = color(0x02, 0x14, 0x18);
}
