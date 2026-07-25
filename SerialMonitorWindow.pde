// ================================================================
// SerialMonitorWindow.pde — Detached, full-size Serial Monitor window,
// opened by the ⤢ expand button in SerialMonitorPanel.pde's header
// (your ask: "serial monitor need to be same as what we get in arduino
// same so we can see"). Reads/writes the SAME rawLog and sendCommand()
// as the main window's panel — this is just a bigger, dedicated view
// of the same live data, not a second connection.
//
// Written as a genuine second PApplet window (Processing 4's documented
// "multiple windows" pattern: a plain `class X extends PApplet` tab,
// launched via PApplet.runSketch() — see toggleSerialMonitorWindow() in
// esp32_taxi_gui.pde). Because this class is declared as a top-level
// tab, Processing nests it INSIDE the main sketch's own generated class,
// so it's a true Java inner class and can reference the main sketch's
// globals (rawLog, state, sendCommand(), copyToClipboard(), ...)
// directly, with no wiring needed.
// ================================================================

class SerialMonitorWindow extends PApplet {
  String inputBuf = "";
  int scrollOff = 0; // 0 = pinned to the newest line, same convention as logScrollOffset
  boolean ctrlDown2 = false;

  // Line-range selection, same idea as SerialMonitorPanel.pde's
  // logSelAnchorLine/logSelCurrentLine — kept separate so selecting
  // here doesn't disturb a selection in the main window's panel.
  int selAnchorLine = -1, selCurrentLine = -1;
  boolean dragging = false;

  int logX, logY, logW, logH;
  final float LINE_H = 16;

  float btnCopyX, btnCopyY, btnCopyW = 60, btnCopyH = 22;

  boolean hoverBtn(float bx, float by, float bw, float bh) {
    return mouseX >= bx && mouseX <= bx + bw && mouseY >= by && mouseY <= by + bh;
  }

  void settings() {
    size(900, 620);
  }

  void setup() {
    surface.setTitle("ESP32 TaxiMeter — Serial Monitor (Expanded)");
    surface.setResizable(true);
    // This is a SEPARATE PApplet instance with its own font state — the
    // main window's textFont() call (esp32_taxi_gui.pde's setup()) does
    // NOT carry over here, which is exactly why this window was showing
    // boxes for every ═/─/✓/°/¢ character even though the main panel
    // wasn't (once fixed there). Same Consolas fix, applied locally.
    textFont(createFont("Consolas", 13, true));
  }

  // PApplet.surface is not accessible from OUTSIDE this class (Java's
  // protected-field rule blocks access via a sibling-subclass reference
  // — the outer sketch class and this class both extend PApplet but
  // neither is a subclass of the other, so `serialWindow.surface...`
  // from the outer sketch fails to compile: "the field PApplet.surface
  // is not visible"). These two methods are the fix — plain access to
  // `surface` from WITHIN this class is always fine; the outer sketch
  // (toggleSerialMonitorWindow(), esp32_taxi_gui.pde) calls these
  // instead of touching .surface directly.
  void hideWindow() { surface.setVisible(false); }
  void showWindow() { surface.setVisible(true); }

  boolean hasSel() { return selAnchorLine >= 0 && selCurrentLine >= 0; }
  int selMin() { return min(selAnchorLine, selCurrentLine); }
  int selMax() { return max(selAnchorLine, selCurrentLine); }

  void draw() {
    background(20, 22, 26);

    int pad = 10;
    int headerH = 34;
    int inputH = 36;

    fill(C_ACCENT);
    noStroke();
    rect(0, 0, width, headerH);
    fill(C_TEXT);
    textAlign(LEFT, CENTER);
    textSize(13);
    String status = state.connected ? ("Connected: " + state.portName + " @ " + selectedBaud + " baud") : "Disconnected";
    text("SERIAL MONITOR (expanded) — " + status, pad, headerH / 2);

    btnCopyX = width - pad - btnCopyW; btnCopyY = (headerH - btnCopyH) / 2;

    logX = pad; logY = headerH + pad; logW = width - pad * 2; logH = height - headerH - inputH - pad * 3;

    fill(GUI_LOG_BG);
    noStroke();
    rect(logX, logY, logW, logH, 4);

    textSize(13);
    textAlign(LEFT, TOP);
    int maxLines = floor(logH / LINE_H);
    // Snapshot ONCE, iterate the snapshot only — rawLog is written from
    // the Serial reader thread at any moment (SerialManager.pde's
    // RAW_LOG_LOCK comment); this is the same fix as the main panel's
    // drawLog() for the "IndexOutOfBoundsException: Index 600 out of
    // bounds for length 600" crash.
    ArrayList<String> snap = snapshotLog();
    int total = snap.size();
    scrollOff = constrain(scrollOff, 0, max(0, total - maxLines));
    int endIdx = total - scrollOff;
    int startIdx = max(0, endIdx - maxLines);

    clip(logX, logY, logW, logH);
    float ty = logY + 2;
    for (int i = startIdx; i < endIdx; i++) {
      if (hasSel() && i >= selMin() && i <= selMax()) {
        fill(C_ACCENT2);
        noStroke();
        rect(logX, ty, logW, LINE_H);
      }
      String line = snap.get(i);
      color c = line.startsWith("> ") ? C_WARN : (line.startsWith("[gui]") ? C_ACCENT2 : C_TEXT2);
      fill(c);
      text(line, logX + 6, ty, logW - 12, LINE_H);
      ty += LINE_H;
    }
    noClip();

    // Scrollbar indicator — same convention as the main panel's
    // (SerialMonitorPanel.pde's drawLog()): thumb at the bottom when
    // scrollOff=0 (pinned to the newest line), moving up as you scroll
    // back into older history.
    int totalScrollable = max(0, total - maxLines);
    if (totalScrollable > 0) {
      float thumbH = max(20, logH * ((float) maxLines / total));
      float progress = constrain((float) scrollOff / totalScrollable, 0, 1);
      float thumbY = logY + (logH - thumbH) * (1.0 - progress);
      fill(C_ACCENT2);
      noStroke();
      rect(logX + logW - 5, thumbY, 4, thumbH, 2);
    }

    // Copy button — top-right of the header, guaranteed to work
    // regardless of Ctrl+C reliability: copies the current line
    // selection, or the WHOLE log if nothing is selected.
    fill(hoverBtn(btnCopyX, btnCopyY, btnCopyW, btnCopyH) ? C_BTN_HOVER : C_BTN);
    noStroke();
    rect(btnCopyX, btnCopyY, btnCopyW, btnCopyH, 4);
    fill(C_TEXT);
    textAlign(CENTER, CENTER);
    textSize(12);
    text("Copy", btnCopyX + btnCopyW / 2, btnCopyY + btnCopyH / 2 + 1);

    // Input row — same "type + Enter, or click Send" as the main panel
    int inputY = height - inputH - pad;
    int sendW = 80;
    fill(30, 32, 38);
    stroke(C_ACCENT2);
    strokeWeight(1);
    rect(pad, inputY, width - pad * 2 - sendW - 8, inputH, 4);
    noStroke();
    textAlign(LEFT, CENTER);
    textSize(13);
    if (inputBuf.length() == 0) {
      fill(C_TEXT2);
      text("Type a command and press Enter…", pad + 8, inputY + inputH / 2 + 1);
    } else {
      fill(C_TEXT);
      text(inputBuf, pad + 8, inputY + inputH / 2 + 1);
    }
    if ((millis() / 500) % 2 == 0) {
      float cx = pad + 8 + textWidth(inputBuf);
      stroke(C_TEXT);
      line(cx, inputY + 6, cx, inputY + inputH - 6);
      noStroke();
    }

    fill(C_SUCCESS);
    noStroke();
    rect(width - pad - sendW, inputY, sendW, inputH, 4);
    fill(C_BG);
    textAlign(CENTER, CENTER);
    textSize(13);
    text("Send", width - pad - sendW / 2, inputY + inputH / 2 + 1);
  }

  int lineIndexForY(float my) {
    int total = snapshotLog().size(); // via the lock, not a raw rawLog.size() — see RAW_LOG_LOCK comment
    if (total == 0) return -1;
    int maxLines = floor(logH / LINE_H);
    int endIdx = total - scrollOff;
    int startIdx = max(0, endIdx - maxLines);
    int row = (int) ((my - logY - 2) / LINE_H);
    return constrain(startIdx + row, 0, total - 1);
  }

  void submitInput() {
    String cmd = inputBuf.trim();
    if (cmd.length() > 0) {
      sendCommand(cmd);
      inputBuf = "";
    }
    scrollOff = 0;
  }

  // Copies the current selection, or the ENTIRE log if nothing is
  // selected — a button, not a keyboard shortcut, so it works regardless
  // of any Ctrl+C reliability issue on your setup.
  void copySelectionOrAll() {
    ArrayList<String> snap = snapshotLog(); // stable copy — see RAW_LOG_LOCK comment
    StringBuilder sb = new StringBuilder();
    int a = hasSel() ? selMin() : 0;
    int b = hasSel() ? min(selMax(), snap.size() - 1) : snap.size() - 1;
    for (int i = a; i <= b; i++) {
      if (sb.length() > 0) sb.append("\n");
      sb.append(snap.get(i));
    }
    copyToClipboard(sb.toString());
  }

  void mousePressed() {
    if (hoverBtn(btnCopyX, btnCopyY, btnCopyW, btnCopyH)) {
      copySelectionOrAll();
      return;
    }
    if (mouseX >= logX && mouseX <= logX + logW && mouseY >= logY && mouseY <= logY + logH) {
      int idx = lineIndexForY(mouseY);
      if (idx >= 0) { selAnchorLine = idx; selCurrentLine = idx; dragging = true; }
      return;
    }
    dragging = false;

    int pad = 10, inputH = 36, sendW = 80;
    int inputY = height - inputH - pad;
    if (mouseX >= width - pad - sendW && mouseX <= width - pad && mouseY >= inputY && mouseY <= inputY + inputH) {
      submitInput();
    } else {
      // Clicking anywhere else (not the log, not Send) clears the log
      // selection, same "click outside clears it" rule as the main panel.
      selAnchorLine = -1; selCurrentLine = -1;
    }
  }

  void mouseDragged() {
    if (dragging) selCurrentLine = lineIndexForY(mouseY);
  }

  void mouseReleased() {
    dragging = false;
  }

  void mouseWheel(processing.event.MouseEvent event) {
    scrollOff -= event.getCount() * 3;
    scrollOff = max(0, scrollOff);
  }

  void keyPressed() {
    if (key == CODED && keyCode == CONTROL) { ctrlDown2 = true; return; }

    if (ctrlDown2 && (key == 'c' || key == 'C')) {
      if (hasSel()) {
        ArrayList<String> snap = snapshotLog(); // stable copy — see RAW_LOG_LOCK comment
        StringBuilder sb = new StringBuilder();
        int b = min(selMax(), snap.size() - 1);
        for (int i = selMin(); i <= b; i++) {
          if (sb.length() > 0) sb.append("\n");
          sb.append(snap.get(i));
        }
        copyToClipboard(sb.toString());
      }
      return;
    }
    if (ctrlDown2 && (key == 'a' || key == 'A')) {
      int n = snapshotLog().size(); // one consistent read — see RAW_LOG_LOCK comment
      if (n > 0) { selAnchorLine = 0; selCurrentLine = n - 1; }
      return;
    }
    if (ctrlDown2 && (key == 'v' || key == 'V')) {
      String p = getFromClipboard();
      StringBuilder clean = new StringBuilder();
      for (int i = 0; i < p.length(); i++) {
        char c = p.charAt(i);
        if (c >= 32 && c < 127) clean.append(c);
      }
      if (inputBuf.length() < 200) inputBuf += clean.toString();
      return;
    }

    if (key == BACKSPACE) {
      if (inputBuf.length() > 0) inputBuf = inputBuf.substring(0, inputBuf.length() - 1);
    } else if (key == ENTER || key == RETURN) {
      submitInput();
    } else if (key == TAB || key == ESC) {
      // ignore
    } else if (key >= 32 && key < 127) {
      if (inputBuf.length() < 200) inputBuf += key;
    }
  }

  void keyReleased() {
    if (key == CODED && keyCode == CONTROL) ctrlDown2 = false;
  }

  // Default PApplet.exit() terminates the WHOLE application (both
  // windows) when this window's OS close button is clicked — a known
  // Processing multi-window gotcha. Override it to just hide this
  // window instead; the main window's ⤢ button reopens it via
  // surface.setVisible(true) (toggleSerialMonitorWindow()), no need to
  // recreate the PApplet.
  void exit() {
    hideWindow();
    serialWindowOpen = false;
  }
}
