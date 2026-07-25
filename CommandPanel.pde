// ================================================================
// CommandPanel.pde — Shows every command in the side menu's currently
// selected category as a row: a button for no-argument commands
// (mem, trip stop, ...), or a label + input field(s) + Send button
// for commands that take a value (api get <id>, gps every <sec>
// [cnt], auth login <user> <pass>) — your ask: "for those we need the
// input button... dropdown then send button."
//
// Row positions are recomputed every draw() call (immediate-mode
// style) — the click handler trusts whatever positions the most
// recent draw() call assigned to each row's widgets, which is always
// current by the time a click event arrives (standard Processing
// pattern, same as every other panel in this sketch).
// ================================================================

float commandPanelScroll = 0;
int cmdPanelX, cmdPanelY, cmdPanelW, cmdPanelH;

// Stacked layout, your ask: label on its own line, then each field FULL
// WIDTH on its own line below it, then the button on its own line —
// not label|field|Send all squeezed onto one ~94px-wide line like
// before, which left barely any room once the paste "V" icon
// (Widgets.pde) was added to every field.
//
// specContentHeight() is the card's own height (top padding + label +
// field(s) + button + bottom padding — every gap accounted for, unlike
// the first pass, which forgot the top padding and let the button spill
// CP_PAD past the card's bottom edge into the next row). specRowHeight()
// is contentHeight + CP_ROW_GAP — the full vertical space one command
// occupies including the visible gap to the next one — and is the ONLY
// one that should be used for ty += .../scroll totals, never
// specContentHeight() directly, or the gap gets lost/double-counted.
final float CP_PAD      = 6;   // top AND bottom inner padding within a card
final float CP_LABEL_H  = 16;
final float CP_FIELD_H  = 28;
final float CP_BTN_H    = 26;
final float CP_GAP      = 4;   // between label/field/field/button
final float CP_ROW_GAP  = 8;   // visible gap between one command's card and the next
final float CP_NOARGS_H = 36;  // content height for a plain button row (no fields)

float specContentHeight(CommandSpec spec) {
  if (!spec.hasArgs()) return CP_NOARGS_H;
  float h = CP_PAD + CP_LABEL_H + CP_GAP + CP_FIELD_H + CP_GAP;   // pad + label + field1
  if (spec.field2 != null) h += CP_FIELD_H + CP_GAP;               // + field2
  h += CP_BTN_H + CP_PAD;                                          // + button + bottom pad
  return h;
}

float specRowHeight(CommandSpec spec) {
  return specContentHeight(spec) + CP_ROW_GAP;
}

float categoryContentHeight(CommandCategory cat) {
  float h = 0;
  for (CommandSpec spec : cat.commands) h += specRowHeight(spec);
  return h;
}

void drawCommandPanel(int x, int y, int w, int h) {
  cmdPanelX = x; cmdPanelY = y; cmdPanelW = w; cmdPanelH = h;

  fill(C_TEST_BG);
  stroke(GUI_CHROME_BORDER);
  strokeWeight(1);
  rect(x, y, w, h, 6);
  noStroke();

  fill(C_ACCENT);
  rect(x, y, w, 32, 6, 6, 0, 0);
  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(12);
  CommandCategory cat = COMMAND_CATEGORIES[selectedCategory];
  text(cat.name, x + w / 2, y + 16);

  int contentY = y + 38, contentH = h - 44;
  float maxScroll = max(0, categoryContentHeight(cat) - contentH);
  commandPanelScroll = constrain(commandPanelScroll, 0, maxScroll);

  clip(x, contentY, w, contentH);
  float ty = contentY - commandPanelScroll;
  float rowW = w - 16;
  float rowX = x + 8;

  for (CommandSpec spec : cat.commands) {
    float cardH = specContentHeight(spec); // named cardH, not contentH — that name's already taken above (the scroll area's own height)

    fill(C_BG2); noStroke();
    rect(rowX, ty, rowW, cardH, 4);

    if (!spec.hasArgs()) {
      spec.actionBtn.x = rowX; spec.actionBtn.y = ty; spec.actionBtn.w = rowW; spec.actionBtn.h = cardH;
      spec.actionBtn.draw(guiMouseX, guiMouseY);
    } else {
      // Stacked: label, then each field FULL WIDTH on its own line,
      // then the button full width — every field gets the panel's
      // entire usable width instead of splitting it three ways.
      // iy starts CP_PAD below ty and every step below matches
      // specContentHeight()'s own math exactly, so the button always
      // ends CP_PAD above the card's bottom edge, never past it.
      float innerX = rowX + 8;
      float innerW = rowW - 16;
      float iy = ty + CP_PAD;

      fill(C_TEXT2); textAlign(LEFT, TOP); textSize(10);
      text(spec.label, innerX, iy);
      iy += CP_LABEL_H + CP_GAP;

      spec.field1.x = innerX; spec.field1.y = iy; spec.field1.w = innerW; spec.field1.h = CP_FIELD_H;
      spec.field1.draw();
      iy += CP_FIELD_H + CP_GAP;

      if (spec.field2 != null) {
        spec.field2.x = innerX; spec.field2.y = iy; spec.field2.w = innerW; spec.field2.h = CP_FIELD_H;
        spec.field2.draw();
        iy += CP_FIELD_H + CP_GAP;
      }

      spec.actionBtn.x = innerX; spec.actionBtn.y = iy; spec.actionBtn.w = innerW; spec.actionBtn.h = CP_BTN_H;
      spec.actionBtn.draw(guiMouseX, guiMouseY);
    }

    ty += specRowHeight(spec); // = contentH + CP_ROW_GAP — the visible gap to the next card
  }
  noClip();

  if (maxScroll > 0) {
    float thumbH = max(20, contentH * (contentH / (contentH + maxScroll)));
    float thumbY = contentY + (contentH - thumbH) * (commandPanelScroll / maxScroll);
    fill(C_ACCENT2); noStroke();
    rect(x + w - 5, thumbY, 4, thumbH, 2);
  }
}

boolean handleCommandPanelClick(float mx, float my) {
  if (mx < cmdPanelX || mx > cmdPanelX + cmdPanelW || my < cmdPanelY || my > cmdPanelY + cmdPanelH) return false;

  CommandCategory cat = COMMAND_CATEGORIES[selectedCategory];
  for (CommandSpec spec : cat.commands) {
    // Paste-icon hits first — every "api get <id>"/"auth login <user>
    // <pass>"/etc. field gets the same guaranteed-working paste as
    // MeterScreen's fields.
    if (spec.field1 != null && spec.field1.containsPasteIcon(mx, my)) { spec.field1.pasteAtIcon(); return true; }
    if (spec.field2 != null && spec.field2.containsPasteIcon(mx, my)) { spec.field2.pasteAtIcon(); return true; }
    if (spec.field1 != null && spec.field1.contains(mx, my)) { spec.field1.focus(mx); return true; }
    if (spec.field2 != null && spec.field2.contains(mx, my)) { spec.field2.focus(mx); return true; }
    if (spec.actionBtn.contains(mx, my)) { spec.send(); return true; }
  }
  return true; // clicked somewhere in the panel that isn't a widget (e.g. between rows) — still consume it
}

boolean handleCommandPanelScroll(float mx, float my, float amount) {
  if (mx < cmdPanelX || mx > cmdPanelX + cmdPanelW || my < cmdPanelY || my > cmdPanelY + cmdPanelH) return false;
  commandPanelScroll += amount;
  return true;
}

// Enter-key routing for whichever CommandSpec field is currently
// focused (checked from handleMeterScreenEnter()'s fallback chain —
// see esp32_taxi_gui.pde's onFocusedFieldEnter()).
boolean handleCommandPanelEnter() {
  CommandCategory cat = COMMAND_CATEGORIES[selectedCategory];
  for (CommandSpec spec : cat.commands) {
    if (focusedField == spec.field1 || focusedField == spec.field2) {
      spec.send();
      return true;
    }
  }
  return false;
}
