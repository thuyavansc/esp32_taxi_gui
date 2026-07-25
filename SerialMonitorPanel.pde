// ================================================================
// SerialMonitorPanel.pde — Left panel: raw log + command input.
//
// Functionally this REPLACES PlatformIO's own Serial Monitor (doc 85
// §B.6 — only one program can hold a COM port open at a time, so this
// panel's job is to be a complete substitute, not a supplement): every
// byte the ESP32 sends appears here, and anything typed here + Enter
// is sent exactly as if typed into a raw terminal. All of this
// session's existing commands (auth/setup/ref/duty/trip/session/mem/
// store/gps/api/sk/help) work here unchanged.
//
// Also provides: click-drag line selection + Ctrl+C copy over the log
// itself (logSelAnchorLine/logSelCurrentLine below — Ctrl+C/Ctrl+A
// routing lives in Widgets.pde's keyPressed() since that's the sketch's
// one shared key-event entry point), TXT/CSV session logging to a
// logs/ folder next to the sketch (startLogging()/stopLogging()), and
// an expand (⤢) button that opens SerialMonitorWindow.pde's detached,
// full-size Arduino-style serial monitor.
// ================================================================

GTextField serialInputField;
GButton btnSend;
GButton btnPaste; // your ask: paste MUST work, keyboard shortcut alone wasn't reliable — see esp32_taxi_gui.pde's right-click-to-paste too
GButton btnCopyLog; // your ask: copy from the log MUST work too, keyboard shortcut alone wasn't reliable either
GButton btnLogTxt, btnLogCsv, btnExpand;
int logScrollOffset = 0; // 0 = pinned to the newest line (auto-scroll)

int panelX, panelY, panelW, panelH; // set each draw() call, used by mouseWheel()

// ── Line-range selection over the log (click-drag to select, Ctrl+C to
//    copy — see Widgets.pde's keyPressed()). Indices are ABSOLUTE into
//    rawLog (not just the currently-visible window), so a selection
//    stays correct even if new lines arrive and shift what's on screen. ──
int logSelAnchorLine = -1;
int logSelCurrentLine = -1;
boolean logDragging = false;
boolean logSelectionStartedThisClick = false;
int logAreaX, logAreaY, logAreaW, logAreaH; // set each drawLog() call
final float LOG_LINE_H = 14;

boolean logHasSelection() { return logSelAnchorLine >= 0 && logSelCurrentLine >= 0; }
int logSelMinLine() { return min(logSelAnchorLine, logSelCurrentLine); }
int logSelMaxLine() { return max(logSelAnchorLine, logSelCurrentLine); }

String logSelectedText() {
  if (!logHasSelection()) return "";
  ArrayList<String> snap = snapshotLog(); // stable copy — see SerialManager.pde's RAW_LOG_LOCK comment
  StringBuilder sb = new StringBuilder();
  int a = logSelMinLine(), b = min(logSelMaxLine(), snap.size() - 1);
  for (int i = a; i <= b; i++) {
    if (sb.length() > 0) sb.append("\n");
    sb.append(snap.get(i));
  }
  return sb.toString();
}

// ── TXT/CSV session logging — your ask: "if click txt or csv the if
//    recording starting given those logs need to store". Saved to a
//    logs/ folder created next to the sketch (sketchPath(), same base
//    as Persistence.pde's settings file), one file per recording
//    session, named with the start date/time so multiple sessions never
//    collide or overwrite each other. ──
PrintWriter logFileWriter = null;
String activeLogFormat = null;     // "txt" | "csv" | null (not recording)
String activeLogFilePath = null;

void startLogging(String format) {
  stopLogging(); // only one active recording at a time — starting a new one stops any other
  String dir = sketchPath("logs");
  File dirF = new File(dir);
  if (!dirF.exists()) dirF.mkdirs();

  String ts = year() + nf(month(), 2) + nf(day(), 2) + "_" + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
  String filename = "serial_log_" + ts + "." + format;
  activeLogFilePath = dir + File.separator + filename;
  logFileWriter = createWriter(activeLogFilePath);
  if (format.equals("csv")) logFileWriter.println("timestamp,line");
  activeLogFormat = format;
  logLine("[gui] Logging started (" + format.toUpperCase() + ") → logs/" + filename);
}

void stopLogging() {
  if (logFileWriter == null) return;
  logFileWriter.flush();
  logFileWriter.close();
  String path = activeLogFilePath;
  logFileWriter = null;
  activeLogFormat = null;
  activeLogFilePath = null;
  logLine("[gui] Logging stopped → " + path);
}

void toggleLogging(String format) {
  if (activeLogFormat != null && activeLogFormat.equals(format)) stopLogging();
  else startLogging(format);
}

// Called from logLine() (SerialManager.pde) for every line, log or not —
// a no-op whenever activeLogFormat is null (not currently recording).
void writeLogLineToFile(String line) {
  if (logFileWriter == null) return;
  String ts = nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
  if (activeLogFormat.equals("csv")) {
    logFileWriter.println("\"" + ts + "\",\"" + line.replace("\"", "\"\"") + "\"");
  } else {
    logFileWriter.println("[" + ts + "] " + line);
  }
  logFileWriter.flush(); // flush every line so a crash/force-quit doesn't lose the tail
}

void initSerialMonitorPanel() {
  // Positions finalized in drawSerialMonitorPanel() once we know x/y for this frame;
  // constructed here with placeholder geometry, updated below.
  serialInputField = new GTextField(0, 0, 10, 10, "Type a command and press Enter…");
  serialInputField.showPasteIcon = false; // has its own adjacent Paste button (btnPaste) already — avoid a redundant second one
  btnSend = new GButton(0, 0, 60, 10, "Send", C_SUCCESS, C_BG);
  btnPaste = new GButton(0, 0, 55, 10, "Paste", C_BTN, C_TEXT);
  btnCopyLog = new GButton(0, 0, 44, 20, "Copy", C_BTN, C_TEXT);
  btnLogTxt = new GButton(0, 0, 36, 20, "TXT", C_BTN, C_TEXT);
  btnLogCsv = new GButton(0, 0, 36, 20, "CSV", C_BTN, C_TEXT);
  // Plain ASCII label, not a Unicode expand glyph — Processing warned
  // "some characters not available in the current font" for the ⤢
  // (U+2922) this used to be, an obscure math-symbol character basically
  // no font fully covers. Plain text has zero font-coverage risk.
  btnExpand = new GButton(0, 0, 40, 20, "Pop", C_BTN, C_TEXT);
}

void drawSerialMonitorPanel(int x, int y, int w, int h) {
  panelX = x; panelY = y; panelW = w; panelH = h;

  fill(C_TEST_BG);
  stroke(GUI_CHROME_BORDER);
  strokeWeight(1);
  rect(x, y, w, h, 6);
  noStroke();

  // Header
  fill(C_ACCENT);
  rect(x, y, w, 32, 6, 6, 0, 0);
  fill(C_TEXT);
  textAlign(LEFT, CENTER);
  textSize(14);
  text("SERIAL MONITOR", x + 10, y + 16);

  // Header-right controls: Copy + TXT/CSV recording toggle + expand-to-window
  int hy = y + 6;
  btnExpand.x = x + w - 8 - 40; btnExpand.y = hy; btnExpand.w = 40; btnExpand.h = 20;
  btnLogCsv.x = btnExpand.x - 6 - 36; btnLogCsv.y = hy; btnLogCsv.w = 36; btnLogCsv.h = 20;
  btnLogTxt.x = btnLogCsv.x - 6 - 36; btnLogTxt.y = hy; btnLogTxt.w = 36; btnLogTxt.h = 20;
  btnCopyLog.x = btnLogTxt.x - 6 - 44; btnCopyLog.y = hy; btnCopyLog.w = 44; btnCopyLog.h = 20;
  btnLogTxt.bg = ("txt".equals(activeLogFormat)) ? C_ERROR : C_BTN;
  btnLogCsv.bg = ("csv".equals(activeLogFormat)) ? C_ERROR : C_BTN;
  btnCopyLog.draw(guiMouseX, guiMouseY);
  btnLogTxt.draw(guiMouseX, guiMouseY);
  btnLogCsv.draw(guiMouseX, guiMouseY);
  btnExpand.draw(guiMouseX, guiMouseY);
  if (activeLogFormat != null) {
    // Recording indicator — a drawn dot, not a "●" text glyph (same
    // font-coverage reasoning as the Pop button's label above).
    fill(C_ERROR);
    noStroke();
    ellipse(btnCopyLog.x - 10, hy + 10, 7, 7);
    fill(C_ERROR);
    textAlign(RIGHT, CENTER);
    textSize(9);
    text("REC", btnCopyLog.x - 16, hy + 10);
  }

  // Input row geometry (bottom of panel) — Paste sits between the field
  // and Send so it's always visible without hunting for it (your ask:
  // pasting needs to just work, reliably, right now).
  int inputH = 36;
  int inputY = y + h - inputH - 8;
  int sendW = 64;
  int pasteW = 52;
  serialInputField.x = x + 8; serialInputField.y = inputY;
  serialInputField.w = w - 16 - pasteW - 6 - sendW - 6; serialInputField.h = inputH;
  btnPaste.x = serialInputField.x + serialInputField.w + 6; btnPaste.y = inputY; btnPaste.w = pasteW; btnPaste.h = inputH;
  btnSend.x = x + w - 8 - sendW; btnSend.y = inputY; btnSend.w = sendW; btnSend.h = inputH;

  // Log area: between header and input row
  int logX = x + 8, logY = y + 38;
  int logW = w - 16, logH = inputY - logY - 6;
  drawLog(logX, logY, logW, logH);

  serialInputField.draw();
  btnPaste.draw(guiMouseX, guiMouseY);
  btnSend.draw();
}

void drawLog(int x, int y, int w, int h) {
  logAreaX = x; logAreaY = y; logAreaW = w; logAreaH = h;

  pushMatrix();
  pushStyle();

  fill(GUI_LOG_BG);
  noStroke();
  rect(x, y, w, h, 4);

  textSize(11);
  textAlign(LEFT, TOP);
  fill(C_TEXT2);
  float lineH = LOG_LINE_H;
  int maxLines = floor(h / lineH);

  // Snapshot ONCE, iterate the snapshot only — rawLog itself can be
  // mutated by serialEvent() on a different thread at any moment (see
  // SerialManager.pde's RAW_LOG_LOCK comment); indexing the live list
  // across a whole loop like this is exactly what produced the
  // "IndexOutOfBoundsException: Index 600 out of bounds for length 600"
  // crash — a new line arriving mid-loop shifted every index underneath us.
  ArrayList<String> snap = snapshotLog();
  int total = snap.size();
  logScrollOffset = constrain(logScrollOffset, 0, max(0, total - maxLines));
  int endIdx = total - logScrollOffset;
  int startIdx = max(0, endIdx - maxLines);

  // Clip drawing to the log rect so long lines don't spill into other panels
  clip(x, y, w, h);
  float ty = y + 2;
  for (int i = startIdx; i < endIdx; i++) {
    if (logHasSelection() && i >= logSelMinLine() && i <= logSelMaxLine()) {
      fill(C_ACCENT2);
      noStroke();
      rect(x, ty, w, lineH);
    }
    String line = snap.get(i);
    color c = line.startsWith("> ") ? C_WARN : (line.startsWith("[gui]") ? C_ACCENT2 : C_TEXT2);
    fill(c);
    text(line, x + 4, ty, w - 8, lineH);
    ty += lineH;
  }
  noClip();

  // Scrollbar indicator (your ask: "unable to see the scroll bar that
  // indicator in the right side") — same visual language as GList's own
  // (Widgets.pde), but inverted: logScrollOffset=0 means "pinned to the
  // NEWEST line" (bottom), the opposite of GList's scrollPx=0="top of
  // content" — so the thumb sits at the BOTTOM when offset=0 and moves
  // UP as you scroll back into older history.
  int totalScrollable = max(0, total - maxLines);
  if (totalScrollable > 0) {
    float thumbH = max(20, h * ((float) maxLines / total));
    float progress = constrain((float) logScrollOffset / totalScrollable, 0, 1); // 0=newest/bottom, 1=oldest/top
    float thumbY = y + (h - thumbH) * (1.0 - progress);
    fill(C_ACCENT2);
    noStroke();
    rect(x + w - 5, thumbY, 4, thumbH, 2);
  }

  popStyle();
  popMatrix();
}

void submitSerialInput() {
  String cmd = serialInputField.text.trim();
  if (cmd.length() > 0) {
    sendCommand(cmd);
    serialInputField.text = "";
    serialInputField.caret = 0;
    serialInputField.clearSelection();
  }
  logScrollOffset = 0; // snap back to the newest line after sending
}

boolean handleSerialMonitorClick(float mx, float my) {
  boolean clickedField = false;

  if (btnLogTxt.contains(mx, my)) { toggleLogging("txt"); return true; }
  if (btnLogCsv.contains(mx, my)) { toggleLogging("csv"); return true; }
  if (btnExpand.contains(mx, my)) { toggleSerialMonitorWindow(); return true; }
  if (btnCopyLog.contains(mx, my)) {
    // Copies the current line selection, or the WHOLE visible log if
    // nothing is selected — guaranteed to work regardless of Ctrl+C.
    String toCopy = logHasSelection() ? logSelectedText() : String.join("\n", snapshotLog());
    copyToClipboard(toCopy);
    logLine("[gui] Copied " + (logHasSelection() ? "selection" : "entire log") + " to clipboard.");
    return true;
  }
  if (btnPaste.contains(mx, my)) {
    serialInputField.focus(); // caret to end — makes sense to append a paste here even if the field wasn't already focused
    serialInputField.insertAtCaret(getFromClipboard());
    return true;
  }

  if (serialInputField.contains(mx, my)) {
    serialInputField.focus(mx);
    clickedField = true;
  }
  if (btnSend.contains(mx, my)) {
    submitSerialInput();
  }
  return clickedField || btnSend.contains(mx, my) ||
         (mx >= panelX && mx <= panelX + panelW && my >= panelY && my <= panelY + panelH);
}

// Converts a window-space y inside the log rect to an absolute rawLog
// index, using the same startIdx/maxLines math drawLog() uses to decide
// what's currently visible — so clicking a visible line selects THAT
// line, not some scroll-independent row number.
int logLineIndexForY(float my) {
  int total = snapshotLog().size(); // via the lock, not a raw rawLog.size() — see RAW_LOG_LOCK comment
  if (total == 0) return -1;
  int maxLines = floor(logAreaH / LOG_LINE_H);
  int endIdx = total - logScrollOffset;
  int startIdx = max(0, endIdx - maxLines);
  int row = (int) ((my - logAreaY - 2) / LOG_LINE_H);
  return constrain(startIdx + row, 0, total - 1);
}

// Starts a line-range selection drag if the click landed inside the log
// rect (called from the sketch-wide mousePressed(), esp32_taxi_gui.pde).
boolean handleSerialMonitorPress(float mx, float my) {
  if (mx < logAreaX || mx > logAreaX + logAreaW || my < logAreaY || my > logAreaY + logAreaH) return false;
  int idx = logLineIndexForY(my);
  if (idx < 0) return true; // inside the rect but log is empty — nothing to select
  logSelAnchorLine = idx;
  logSelCurrentLine = idx;
  logDragging = true;
  logSelectionStartedThisClick = true;
  return true;
}

// Called from the sketch-wide mouseDragged() (Widgets.pde).
void handleSerialMonitorDrag(float mx, float my) {
  if (!logDragging) return;
  logSelCurrentLine = logLineIndexForY(my);
}

// Called from the sketch-wide mouseReleased() (Widgets.pde).
void handleSerialMonitorRelease() {
  logDragging = false;
}

// Called from the sketch-wide mousePressed() (esp32_taxi_gui.pde), same
// "clear if this click wasn't the one that made the selection" pattern
// as clearFocusIfClickedOutside() for text fields.
void clearLogSelectionIfClickedOutside() {
  if (!logSelectionStartedThisClick) { logSelAnchorLine = -1; logSelCurrentLine = -1; }
}

// Called from the sketch-wide mouseWheel() dispatcher (esp32_taxi_gui.pde).
// Note the MINUS here, unlike GList's scrollPx += amount: logScrollOffset
// means "how far scrolled UP and away from the newest line" (0 = pinned
// to the bottom/latest), the opposite sense from GList's "how far
// scrolled DOWN from the top" — so the same wheel direction needs the
// opposite sign to feel the same (scroll up = see older lines = offset
// increases; scroll down = catch up toward the latest = offset decreases).
boolean handleSerialMonitorScroll(float mx, float my, float amount) {
  if (mx < panelX || mx > panelX + panelW || my < panelY || my > panelY + panelH) return false;
  logScrollOffset -= (int) amount;
  logScrollOffset = max(0, logScrollOffset);
  return true;
}
