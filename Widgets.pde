// ================================================================
// Widgets.pde — Small reusable GButton / GTextField / GToggle classes.
//
// Deliberately built with ZERO external libraries (no ControlP5, no
// G4P) — only core Processing (rect/text/mouse/key). This means the
// sketch runs the moment Processing 4 is installed, with nothing else
// to download first. If you later install ControlP5, these could be
// swapped for its widgets, but that's optional polish, not required.
//
// Click handling pattern: each screen's handleMouse() is called from
// the sketch-wide mousePressed() (Widgets.pde bottom), and calls
// .contains(mouseX, mouseY) on its own buttons to decide what fired.
// Text input pattern: exactly one GTextField can be "focused" at a
// time (clicking one focuses it, focuses nothing else) — keyPressed()
// (bottom of this file) routes typed characters, arrow/Home/End
// navigation, and Ctrl+A/C/X/V (select-all/copy/cut/paste, via the
// OS clipboard — see copyToClipboard()/getFromClipboard() below) to
// whichever field is currently focused. Click-drag inside a focused
// field extends a text selection (mouseDragged() at the bottom of
// this file); the same Ctrl+C/Ctrl+A also work on the Serial Monitor
// log itself when no field is focused (line-range select+copy — see
// SerialMonitorPanel.pde).
// ================================================================

import java.awt.Toolkit;
import java.awt.datatransfer.Clipboard;
import java.awt.datatransfer.StringSelection;
import java.awt.datatransfer.DataFlavor;
import java.awt.datatransfer.Transferable;

// ── System clipboard helpers — used by GTextField's Ctrl+C/X/V and the
//    Serial Monitor log's own Ctrl+C (SerialMonitorPanel.pde) ──────────
void copyToClipboard(String s) {
  if (s == null) return;
  try {
    Clipboard cb = Toolkit.getDefaultToolkit().getSystemClipboard();
    cb.setContents(new StringSelection(s), null);
  } catch (Exception e) {
    logLine("[gui] Clipboard copy failed: " + e.getMessage());
  }
}

String getFromClipboard() {
  try {
    Clipboard cb = Toolkit.getDefaultToolkit().getSystemClipboard();
    Transferable t = cb.getContents(null);
    if (t != null && t.isDataFlavorSupported(DataFlavor.stringFlavor)) {
      String s = (String) t.getTransferData(DataFlavor.stringFlavor);
      if (s == null || s.length() == 0) {
        logLine("[gui] Clipboard has no text to paste (copy something as text first).");
      }
      return s == null ? "" : s;
    }
    logLine("[gui] Clipboard doesn't contain text (nothing pasted).");
  } catch (Exception e) {
    logLine("[gui] Clipboard paste failed: " + e.getMessage());
  }
  return "";
}

// ── Button ──────────────────────────────────────────────────────
class GButton {
  float x, y, w, h;
  String label;
  color bg, fg;

  GButton(float x, float y, float w, float h, String label, color bg, color fg) {
    this.x = x; this.y = y; this.w = w; this.h = h;
    this.label = label; this.bg = bg; this.fg = fg;
  }

  // Buttons drawn in the main window (top menu bar, side menu, command
  // panel, serial monitor panel) use guiMouseX/guiMouseY — mouseX/mouseY
  // translated into content-space, which equals raw mouseX/mouseY unless
  // the window is maximized/resized larger than the GUI's fixed size and
  // the content is being letterboxed+centered (see updateGuiOffset(),
  // esp32_taxi_gui.pde).
  void draw() {
    draw(guiMouseX, guiMouseY);
  }

  // Buttons drawn INSIDE DisplayPanel's scale(DISPLAY_SCALE) transform
  // must be hover-tested against LOGICAL (320x480-space) mouse
  // coordinates, not raw window mouseX/mouseY — see dispMouseLX/LY in
  // DisplayPanel.pde. Passing the wrong space here wouldn't break
  // clicking (handleDisplayPanelClick already converts correctly
  // before calling contains() for hit-testing), only the cosmetic
  // hover-fill highlight.
  void draw(float hoverX, float hoverY) {
    boolean hover = contains(hoverX, hoverY);
    fill(hover ? C_BTN_HOVER : bg);
    noStroke();
    rect(x, y, w, h, 6);
    fill(fg);
    textAlign(CENTER, CENTER);
    textSize(13);
    text(label, x + w / 2, y + h / 2 + 1);
  }

  boolean contains(float mx, float my) {
    return mx >= x && mx <= x + w && my >= y && my <= y + h;
  }
}

// ── Toggle (ON/OFF style — used for Duty status etc.) ────────────
class GToggle {
  float x, y, w, h;
  String onLabel, offLabel;
  boolean state = false;

  GToggle(float x, float y, float w, float h, String onLabel, String offLabel) {
    this.x = x; this.y = y; this.w = w; this.h = h;
    this.onLabel = onLabel; this.offLabel = offLabel;
  }

  // GToggle's fill doesn't depend on hover (only on/off state), so
  // there's no window-vs-logical mouse-space issue here the way
  // GButton has — kept as a single draw() for that reason.
  void draw() {
    fill(state ? C_SUCCESS : C_ERROR);
    noStroke();
    rect(x, y, w, h, 6);
    fill(state ? C_BG : C_TEXT);
    textAlign(CENTER, CENTER);
    textSize(13);
    text(state ? onLabel : offLabel, x + w / 2, y + h / 2 + 1);
  }

  boolean contains(float mx, float my) {
    return mx >= x && mx <= x + w && my >= y && my <= y + h;
  }
}

// ── Text field — click to focus, type to fill, backspace to erase.
//    Also supports: click-drag / Shift+arrow text selection, Left/Right/
//    Home/End cursor movement, and Ctrl+A/C/X/V (select-all/copy/cut/
//    paste via the OS clipboard) — see keyPressed()/mouseDragged() at
//    the bottom of this file, which route to whichever field is
//    currently `focusedField`. Your ask: typing long values (passwords,
//    passcodes, IDs) by hand is slow — paste needed to work everywhere. ──
class GTextField {
  float x, y, w, h;
  String text = "";
  String placeholder;
  boolean isPassword;
  boolean focused = false;

  // True for fields drawn inside DisplayPanel's scale(DISPLAY_SCALE)
  // transform (MeterScreen's fields) — tells mouseDragged() below which
  // mouse-coordinate space (dispMouseLX vs raw mouseX) applies to this
  // field's drag-to-select, same window-vs-logical distinction
  // GButton.draw(hoverX, hoverY) already documents above.
  boolean logicalSpace = false;

  int caret = 0;       // index into `text`, 0..text.length()
  int selAnchor = -1;  // -1 = no selection; else the fixed end of the active selection range

  GTextField(float x, float y, float w, float h, String placeholder) {
    this(x, y, w, h, placeholder, false);
  }

  GTextField(float x, float y, float w, float h, String placeholder, boolean isPassword) {
    this.x = x; this.y = y; this.w = w; this.h = h;
    this.placeholder = placeholder; this.isPassword = isPassword;
  }

  String maskedText() {
    StringBuilder sb = new StringBuilder();
    for (int i = 0; i < text.length(); i++) sb.append('*');
    return sb.toString();
  }

  String displayText() { return isPassword ? maskedText() : text; }

  // Small always-visible "V" strip at the field's right edge — a
  // guaranteed, keyboard-independent way to paste (your ask, repeated
  // several times: paste MUST just work, typing everything by hand isn't
  // an option). Right-click and Ctrl+V still work too (esp32_taxi_gui.pde
  // / Widgets.pde's keyPressed()), this is the third, most foolproof path.
  // Shrinks proportionally on narrow fields so it never eats more than
  // ~35% of a small field's width. showPasteIcon=false (set by
  // SerialMonitorPanel.pde for serialInputField) suppresses it entirely
  // for fields that already have their own adjacent Paste button.
  boolean showPasteIcon = true;
  float pasteIconW() { return showPasteIcon ? min(20, w * 0.35) : 0; }

  boolean containsPasteIcon(float mx, float my) {
    float iw = pasteIconW();
    return mx >= x + w - iw && mx <= x + w && my >= y && my <= y + h;
  }

  // Focuses (if not already) and pastes at the current caret — clicking
  // the icon on an unfocused field appends the whole clipboard (caret
  // goes to the end on focus()); clicking it again on an ALREADY-focused
  // field pastes wherever the cursor currently is.
  void pasteAtIcon() {
    if (!focused) focus();
    insertAtCaret(getFromClipboard());
  }

  void draw() {
    clampCaret();

    fill(C_BG2);
    stroke(focused ? C_ACCENT2 : C_DIVIDER);
    strokeWeight(focused ? 2 : 1);
    rect(x, y, w, h, 4);
    noStroke();

    float iw = pasteIconW();
    float textW = w - iw;

    textAlign(LEFT, CENTER);
    textSize(13);
    String shown = displayText();

    // NOT wrapped in clip()/noClip() — GTextField instances are often
    // drawn inside an ALREADY-active outer clip() region (e.g.
    // CommandPanel's scrollable list), and Processing's noClip() clears
    // clipping entirely rather than restoring whatever was active before
    // (no clip stack) — nesting our own here would cancel that outer
    // clip for every row drawn after this one in the same pass. Same
    // "good enough" tradeoff the pre-existing code already accepted.
    if (shown.length() == 0 && !focused) {
      fill(C_TEXT2);
      text(placeholder, x + 8, y + h / 2 + 1);
    } else {
      if (focused && hasSelection()) {
        float selX0 = x + 8 + textWidth(shown.substring(0, selMin()));
        float selX1 = x + 8 + textWidth(shown.substring(0, selMax()));
        fill(C_ACCENT2);
        noStroke();
        rect(selX0, y + 4, max(1, selX1 - selX0), h - 8);
      }
      fill(C_TEXT);
      // Simple clip: only show what fits (good enough for this GUI's field widths)
      text(shown, x + 8, y + h / 2 + 1);
    }

    // Blinking caret while focused, at the real caret index (not always the end)
    if (focused && (millis() / 500) % 2 == 0) {
      float caretX = x + 8 + textWidth(shown.substring(0, min(caret, shown.length())));
      stroke(C_TEXT);
      line(caretX, y + 6, caretX, y + h - 6);
      noStroke();
    }

    // Paste icon strip — "V" (Ctrl+V mnemonic), plain ASCII, zero
    // font-coverage risk (unlike a clipboard/paste Unicode glyph).
    if (showPasteIcon) {
      boolean iconHover = logicalSpace ? containsPasteIcon(dispMouseLX, dispMouseLY) : containsPasteIcon(guiMouseX, guiMouseY);
      fill(iconHover ? C_BTN_HOVER : C_ACCENT2);
      noStroke();
      rect(x + textW, y, iw, h, 0, 4, 4, 0);
      fill(C_TEXT);
      textAlign(CENTER, CENTER);
      textSize(11);
      text("V", x + textW + iw / 2, y + h / 2 + 1);
    }
  }

  // Excludes the paste-icon strip at the right edge (containsPasteIcon()
  // above) — callers check containsPasteIcon() FIRST, then this, so a
  // click on the icon pastes instead of just moving the caret there.
  boolean contains(float mx, float my) {
    return mx >= x && mx <= x + w - pasteIconW() && my >= y && my <= y + h;
  }

  // Maps a click x (in THIS field's own coordinate space — see
  // logicalSpace above) to the nearest character boundary.
  int caretIndexForX(float clickX) {
    String shown = displayText();
    textSize(13);
    float startX = x + 8;
    if (clickX <= startX) return 0;
    for (int i = 0; i < shown.length(); i++) {
      float wLeft  = textWidth(shown.substring(0, i));
      float wRight = textWidth(shown.substring(0, i + 1));
      float mid = startX + (wLeft + wRight) / 2.0;
      if (clickX < mid) return i;
    }
    return shown.length();
  }

  int selMin() { return selAnchor < 0 ? caret : min(selAnchor, caret); }
  int selMax() { return selAnchor < 0 ? caret : max(selAnchor, caret); }
  boolean hasSelection() { return selAnchor >= 0 && selAnchor != caret; }
  void clearSelection() { selAnchor = -1; }
  void selectAll() { selAnchor = 0; caret = text.length(); }

  // Defensive — clamps caret/selAnchor back into [0, text.length()]
  // whenever text is shorter than what they reference. Root cause of the
  // crash this guards against ("StringIndexOutOfBoundsException ... in
  // shown.substring(0, selMax())") was two of the caret-moving code
  // paths in keyPressed() below not keeping selAnchor in sync (fixed
  // there too) — but `.text` is also a public field some screens
  // (MeterScreen.pde's doAddExtras()) assign to directly, so this stays
  // as a second, independent line of defense against the same class of
  // bug recurring anywhere else.
  void clampCaret() {
    caret = constrain(caret, 0, text.length());
    if (selAnchor > text.length()) selAnchor = text.length();
  }

  void deleteSelection() {
    if (!hasSelection()) return;
    int a = selMin(), b = selMax();
    text = text.substring(0, a) + text.substring(b);
    caret = a;
    clearSelection();
  }

  // Inserts at the caret, replacing any active selection first — used
  // both by typed characters and by Ctrl+V paste. Printable-ASCII-only
  // and a 64-char cap, matching this field's existing typing limits.
  void insertAtCaret(String s) {
    if (hasSelection()) deleteSelection();
    if (s == null || s.length() == 0) return;
    StringBuilder clean = new StringBuilder();
    for (int i = 0; i < s.length(); i++) {
      char c = s.charAt(i);
      if (c >= 32 && c < 127) clean.append(c);
    }
    String toInsert = clean.toString();
    int room = max(0, 64 - text.length());
    if (toInsert.length() > room) toInsert = toInsert.substring(0, room);
    if (toInsert.length() == 0) return;
    text = text.substring(0, caret) + toInsert + text.substring(caret);
    caret += toInsert.length();
    // Root cause of a real crash (StringIndexOutOfBoundsException in
    // draw()'s selX1 line): when there was no active selection before
    // this insert, selAnchor already equalled the OLD caret — advancing
    // caret without also touching selAnchor left it stuck behind,
    // silently creating a 1-char "phantom selection" on every single
    // keystroke. Backspacing later could walk selAnchor past the
    // (now-shorter) text's actual length. Selection deletion above
    // already clears it when one WAS active; this covers the "wasn't
    // one" case, which was the gap.
    clearSelection();
  }

  // Click-to-focus + place the caret where the click landed (clickX in
  // this field's own coordinate space — pass mx for window-space
  // panels, dispMouseLX for MeterScreen's fields; see logicalSpace).
  void focus(float clickX) {
    if (focusedField != null && focusedField != this) focusedField.focused = false;
    focused = true;
    focusedField = this;
    fieldFocusedThisClick = true; // tells clearFocusIfClickedOutside() not to blur what we just set
    caret = caretIndexForX(clickX);
    selAnchor = caret;
  }

  // Programmatic focus with no click position — caret goes to the end,
  // no selection (used for any non-mouse-driven focus, if ever needed).
  void focus() {
    if (focusedField != null && focusedField != this) focusedField.focused = false;
    focused = true;
    focusedField = this;
    fieldFocusedThisClick = true;
    caret = text.length();
    clearSelection();
  }

  // Extends the current selection to a new drag position (same
  // coordinate-space rule as focus(clickX)/caretIndexForX above).
  void dragTo(float clickX) {
    if (selAnchor < 0) selAnchor = caret;
    caret = caretIndexForX(clickX);
  }
}

// ── Slider — mirrors the real Settings screen's brightness/contrast
//    lv_slider widgets visually (track + colored fill + round knob).
//    No hardware exists on the PC side for either control (there's no
//    physical backlight to dim) — kept visually accurate and
//    draggable for parity with the real screen, per your ask to
//    replicate "what we had previously in display code", but it's
//    decorative here, same as the real firmware's Contrast slider is
//    explicitly "test only" (main/display/ui_main.c's _contrast_event
//    comment says so directly). ──
class GSlider {
  float x, y, w, h;
  int value = 100; // 0-100
  color fillColor;
  boolean dragging = false;

  GSlider(float x, float y, float w, float h, color fillColor) {
    this.x = x; this.y = y; this.w = w; this.h = h; this.fillColor = fillColor;
  }

  void draw() {
    fill(C_BG2);
    noStroke();
    rect(x, y, w, h, h / 2);

    float fillW = w * (value / 100.0);
    fill(fillColor);
    rect(x, y, fillW, h, h / 2);

    float knobX = x + fillW;
    fill(C_TEXT);
    ellipse(knobX, y + h / 2, h + 6, h + 6);
  }

  boolean contains(float mx, float my) {
    // Generous vertical hit area (matches the knob's larger radius, not just the thin track)
    return mx >= x - 8 && mx <= x + w + 8 && my >= y - 8 && my <= y + h + 8;
  }

  void updateFromMouse(float mx) {
    value = (int) constrain(map(mx, x, x + w, 0, 100), 0, 100);
  }
}

// ── Scrollable list — used by the Test menu, Settings menu, and the
//    new command side-menu / command-detail panel. Mouse-wheel scrolls
//    when hovered; click selects a row (returned via lastClickedIndex,
//    -1 if the click missed every row). Works in BOTH window space
//    (side menu, command panel — called with mouseX/mouseY) and the
//    320x480 logical space inside DisplayPanel (Test/Settings screens
//    — called with dispMouseLX/dispMouseLY) — pass whichever hover/
//    click coordinates match the space you're drawing in. ──
class GList {
  float x, y, w, h;
  String[] items;
  float itemH = 34;
  float scrollPx = 0;
  int selected = -1;
  int lastClickedIndex = -1;

  GList(float x, float y, float w, float h, String[] items) {
    this.x = x; this.y = y; this.w = w; this.h = h;
    this.items = items;
  }

  float contentH() { return items.length * itemH; }
  float maxScroll() { return max(0, contentH() - h); }

  void draw(float hoverX, float hoverY) {
    fill(C_BG2);
    noStroke();
    rect(x, y, w, h, 4);

    scrollPx = constrain(scrollPx, 0, maxScroll());

    clip(x, y, w, h);
    float ty = y - scrollPx;
    for (int i = 0; i < items.length; i++) {
      boolean hoverRow = hoverX >= x && hoverX <= x + w && hoverY >= ty && hoverY <= ty + itemH;
      boolean selRow = (i == selected);
      if (selRow) { fill(C_NAV_ACT); noStroke(); rect(x, ty, w, itemH); }
      else if (hoverRow) { fill(C_BTN_HOVER); noStroke(); rect(x, ty, w, itemH); }

      fill(selRow ? C_BG : C_TEXT);
      textAlign(LEFT, CENTER);
      textSize(12);
      text(items[i], x + 10, ty + itemH / 2 + 1);

      stroke(C_DIVIDER); line(x, ty + itemH, x + w, ty + itemH); noStroke();
      ty += itemH;
    }
    noClip();

    // Simple scrollbar indicator when content overflows
    if (maxScroll() > 0) {
      float trackH = h;
      float thumbH = max(20, h * (h / contentH()));
      float thumbY = y + (trackH - thumbH) * (scrollPx / maxScroll());
      fill(C_ACCENT2);
      noStroke();
      rect(x + w - 4, thumbY, 4, thumbH, 2);
    }
  }

  // Returns true (and sets lastClickedIndex) if the click landed
  // inside this list; caller checks lastClickedIndex for which row.
  boolean handleClick(float mx, float my) {
    lastClickedIndex = -1;
    if (mx < x || mx > x + w || my < y || my > y + h) return false;
    int idx = (int) ((my - y + scrollPx) / itemH);
    if (idx >= 0 && idx < items.length) {
      lastClickedIndex = idx;
      selected = idx;
    }
    return true;
  }

  boolean handleScroll(float mx, float my, float amount) {
    if (mx < x || mx > x + w || my < y || my > y + h) return false;
    scrollPx = constrain(scrollPx + amount, 0, maxScroll());
    return true;
  }
}

// ── Card helper — mirrors ui_widgets.c's ui_card() exactly (8px
//    radius, C_CARD background) for use inside the 320x480 logical
//    space every Display-panel screen draws in. ──
void drawMirrorCard(float x, float y, float w, float h) {
  drawMirrorCard(x, y, w, h, C_CARD, 0);
}

void drawMirrorCard(float x, float y, float w, float h, color borderColor, float borderWeight) {
  noStroke();
  fill(C_CARD);
  rect(x, y, w, h, 8);
  if (borderWeight > 0) {
    noFill();
    stroke(borderColor);
    strokeWeight(borderWeight);
    rect(x, y, w, h, 8);
    noStroke();
  }
}

// ── Global focus-routing state (shared by every screen) ──────────
GTextField focusedField = null;

// Set true by GTextField.focus() when a field is actually clicked
// this mouse-press; reset false at the start of every mousePressed().
// This — not "was the click consumed at all" — is the correct signal
// for whether to keep the current focus: clicking a BUTTON also
// "consumes" the click but should still blur whatever field was
// focused, which a consumed-based check would have missed.
boolean fieldFocusedThisClick = false;

// Called once at the END of the sketch's own mousePressed() (after
// every panel has had a chance to call .focus() on a field) — if
// nothing was focused this click, blur whatever was focused before,
// so stray typing doesn't land in a field you can no longer see.
void clearFocusIfClickedOutside() {
  if (!fieldFocusedThisClick && focusedField != null) {
    focusedField.focused = false;
    focusedField = null;
  }
}

// Held-modifier tracking — Processing has no direct "is Ctrl down right
// now" query in the simple key/keyCode API, so this is the standard
// idiom: CONTROL/SHIFT generate their OWN keyPressed()/keyReleased()
// events (key == CODED) which flip these booleans; a following key event
// for the actual letter/arrow arrives as a SEPARATE call while the
// modifier is still held down.
boolean ctrlDown = false;
boolean shiftDown = false;

void keyPressed() {
  if (key == CODED) {
    if (keyCode == CONTROL) ctrlDown = true;
    if (keyCode == SHIFT) shiftDown = true;
  }

  // Serial Monitor log copy/select-all — works even with no text field
  // focused (clicking into the log itself never focuses a field, see
  // clearFocusIfClickedOutside()). Field-focused Ctrl+C/A below takes
  // priority whenever a field IS focused.
  if (focusedField == null && key != CODED && ctrlDown) {
    if (key == 'c' || key == 'C') {
      if (logHasSelection()) copyToClipboard(logSelectedText());
      return;
    }
    if (key == 'a' || key == 'A') {
      int n = snapshotLog().size(); // one consistent read, not two separate rawLog.size() calls — see RAW_LOG_LOCK comment
      if (n > 0) { logSelAnchorLine = 0; logSelCurrentLine = n - 1; }
      return;
    }
  }

  if (focusedField == null) return;
  GTextField f = focusedField;

  if (key == CODED) {
    if (keyCode == LEFT) {
      if (shiftDown) { if (f.selAnchor < 0) f.selAnchor = f.caret; f.caret = max(0, f.caret - 1); }
      else { f.caret = f.hasSelection() ? f.selMin() : max(0, f.caret - 1); f.clearSelection(); }
    } else if (keyCode == RIGHT) {
      if (shiftDown) { if (f.selAnchor < 0) f.selAnchor = f.caret; f.caret = min(f.text.length(), f.caret + 1); }
      else { f.caret = f.hasSelection() ? f.selMax() : min(f.text.length(), f.caret + 1); f.clearSelection(); }
    } else if (keyCode == java.awt.event.KeyEvent.VK_HOME) {
      if (shiftDown) { if (f.selAnchor < 0) f.selAnchor = f.caret; f.caret = 0; }
      else { f.caret = 0; f.clearSelection(); }
    } else if (keyCode == java.awt.event.KeyEvent.VK_END) {
      if (shiftDown) { if (f.selAnchor < 0) f.selAnchor = f.caret; f.caret = f.text.length(); }
      else { f.caret = f.text.length(); f.clearSelection(); }
    }
    return;
  }

  if (ctrlDown && (key == 'a' || key == 'A')) { f.selectAll(); return; }
  if (ctrlDown && (key == 'c' || key == 'C')) {
    if (f.hasSelection()) copyToClipboard(f.text.substring(f.selMin(), f.selMax()));
    return;
  }
  if (ctrlDown && (key == 'x' || key == 'X')) {
    if (f.hasSelection()) { copyToClipboard(f.text.substring(f.selMin(), f.selMax())); f.deleteSelection(); }
    return;
  }
  if (ctrlDown && (key == 'v' || key == 'V')) { f.insertAtCaret(getFromClipboard()); return; }

  if (key == BACKSPACE) {
    if (f.hasSelection()) f.deleteSelection();
    // clearSelection() here too — same reason as insertAtCaret()'s own
    // comment: no active selection meant selAnchor already equalled the
    // OLD caret; decrementing caret without it left selAnchor one
    // character BEHIND the new caret, i.e. a phantom 1-char selection
    // appearing after every single backspace. This is the exact path
    // that produced the "StringIndexOutOfBoundsException ... selMax()"
    // crash on repeated backspacing (e.g. clearing a field before
    // "trip stop").
    else if (f.caret > 0) { f.text = f.text.substring(0, f.caret - 1) + f.text.substring(f.caret); f.caret--; f.clearSelection(); }
  } else if (key == DELETE) {
    if (f.hasSelection()) f.deleteSelection();
    else if (f.caret < f.text.length()) { f.text = f.text.substring(0, f.caret) + f.text.substring(f.caret + 1); f.clearSelection(); }
  } else if (key == ENTER || key == RETURN) {
    onFocusedFieldEnter(); // defined in whichever screen wants Enter-to-submit behavior
  } else if (key == TAB || key == ESC) {
    // ignore — don't insert a literal character for these
  } else if (key >= 32 && key < 127) { // printable ASCII only
    f.insertAtCaret(String.valueOf(key));
  }
}

void keyReleased() {
  if (key == CODED) {
    if (keyCode == CONTROL) ctrlDown = false;
    if (keyCode == SHIFT) shiftDown = false;
  }
}

// Click-drag text selection inside whichever field is currently
// focused — mousePressed() (via GTextField.focus(clickX)) sets the
// selection anchor, this extends `caret` as the drag continues. Also
// drives the Serial Monitor log's own line-range drag-select
// (handleSerialMonitorDrag(), SerialMonitorPanel.pde) — both can be
// live at once harmlessly since exactly one of "a field is focused" /
// "the log has an active drag" applies at a time in practice (clicking
// the log always blurs any focused field first, see
// clearFocusIfClickedOutside()).
void mouseDragged() {
  updateGuiOffset();
  handleSerialMonitorDrag(guiMouseX, guiMouseY);
  if (focusedField != null) {
    float px = focusedField.logicalSpace ? dispMouseLX : guiMouseX;
    focusedField.dragTo(px);
  }
}

void mouseReleased() {
  handleSerialMonitorRelease();
}
