// ================================================================
// TopMenuBar.pde — COM port dropdown (remembers last selection across
// runs, via Persistence.pde), baud rate dropdown (same persistence
// pattern, defaults to 115200), Connect/Disconnect, Settings, status.
// ================================================================

GButton btnComPort;
GButton btnBaud;
GButton btnConnect;
GButton btnSettings;
GButton btnAutoPoll, btnShowGps, btnShowTrip;

// Your ask: "how we stop or control these [gps/trip auto-logs] ... only
// what logs comes". autoPollEnabled is the master switch for the
// periodic "trip info"/"gps info" auto-poll (SerialManager.pde's
// pollIfNeeded()) — off means NOTHING gets sent automatically, fully
// manual. showGpsLogs/showTripLogs independently control whether lines
// tagged "gps:"/"trip:" are shown in the log at all (SerialManager.pde's
// shouldShowInLog()) — useful even for a command you typed yourself,
// not just the auto-poll. All three persist across restarts, same as
// the COM port/baud rate.
//
// IMPORTANT (doc 142 §1.2, confirmed after a real user mix-up):
// showGpsLogs/showTripLogs are DISPLAY FILTERS ONLY — they never send
// anything to the device. The GPS/trip backends keep running exactly
// the same whether these are on or off; only what THIS GUI prints
// changes. Labeled "GPS Log:"/"TRIP Log:" (not just "GPS:"/"TRIP:") for
// exactly this reason. To actually stop a GPS backend, use the real
// device commands in the GPS category ("gps neo6m off"/"gps gnss off").
boolean autoPollEnabled = true;
boolean showGpsLogs = true;
boolean showTripLogs = true;

boolean comDropdownOpen = false;
GList comDropdownList;

boolean baudDropdownOpen = false;
GList baudDropdownList;

// Widely-available USB-serial baud rates — your ask: "configuration
// setting for baud rate also add in dropdown widely available baud
// rate as seem we need 115200 as set default". 115200 matches the
// firmware's own UART console speed (esp32dev's default monitor_speed).
final int[] BAUD_RATES = {9600, 19200, 38400, 57600, 74880, 115200, 230400, 460800, 921600};
final int DEFAULT_BAUD = 115200;
int selectedBaud = DEFAULT_BAUD;

void initTopMenuBar() {
  int x = MARGIN;
  int y = MARGIN;
  int h = TOPBAR_H;

  btnComPort = new GButton(x, y, 190, h, "", C_BTN, C_TEXT);
  x += 190 + 10;

  btnBaud = new GButton(x, y, 110, h, "", C_BTN, C_TEXT);
  x += 110 + 10;

  btnConnect = new GButton(x, y, 150, h, "Connect", C_SUCCESS, C_BG);
  x += 150 + 10;

  btnSettings = new GButton(x, y, 120, h, "Settings", C_BTN, C_TEXT);
  x += 120 + 16;

  btnAutoPoll = new GButton(x, y, 100, h, "", C_BTN, C_TEXT);
  x += 100 + 8;
  // Widened from 90 -> 116 (doc 142 §4.3) so the clarified "GPS Log:"/
  // "TRIP Log:" labels below fit without overflowing the button.
  btnShowGps = new GButton(x, y, 116, h, "", C_BTN, C_TEXT);
  x += 116 + 8;
  btnShowTrip = new GButton(x, y, 116, h, "", C_BTN, C_TEXT);

  autoPollEnabled = settingsGet("autoPoll", "1").equals("1");
  showGpsLogs = settingsGet("showGpsLogs", "1").equals("1");
  showTripLogs = settingsGet("showTripLogs", "1").equals("1");

  // Restore the last-selected port (doc 86 §8) — matched by NAME
  // against whatever ports are actually present right now, since
  // COMx numbers can shift between USB replug/reboots. If nothing was
  // ever saved (first run), or the saved port isn't in today's list,
  // fall back to COM8 as the default shown on open — your ask.
  String lastPort = settingsGet("lastPort", "");
  boolean matched = false;
  if (lastPort.length() > 0) {
    for (int i = 0; i < availablePorts.length; i++) {
      if (availablePorts[i].equals(lastPort)) { selectedPortIndex = i; matched = true; break; }
    }
  }
  if (!matched) {
    for (int i = 0; i < availablePorts.length; i++) {
      if (availablePorts[i].equals("COM8")) { selectedPortIndex = i; matched = true; break; }
    }
  }

  // Restore the last-used baud rate the same way — falls back to
  // DEFAULT_BAUD (115200) on first run or an unrecognized saved value.
  selectedBaud = int(settingsGet("lastBaud", str(DEFAULT_BAUD)));
  boolean validBaud = false;
  for (int b : BAUD_RATES) if (b == selectedBaud) { validBaud = true; break; }
  if (!validBaud) selectedBaud = DEFAULT_BAUD;
}

String[] baudLabels() {
  String[] out = new String[BAUD_RATES.length];
  for (int i = 0; i < BAUD_RATES.length; i++) out[i] = str(BAUD_RATES[i]);
  return out;
}

void drawTopMenuBar() {
  btnComPort.label = "COM: " + currentPortLabel() + (comDropdownOpen ? " ^" : " v");
  btnComPort.bg = state.connected ? C_ACCENT2 : C_BTN;
  btnComPort.draw();

  btnBaud.label = selectedBaud + (baudDropdownOpen ? " ^" : " v");
  btnBaud.bg = state.connected ? C_ACCENT2 : C_BTN;
  btnBaud.draw();

  btnConnect.label = state.connected ? "Disconnect" : "Connect";
  btnConnect.bg = state.connected ? C_ERROR : C_SUCCESS;
  btnConnect.fg = state.connected ? C_TEXT : C_BG;
  btnConnect.draw();

  btnSettings.draw();

  btnAutoPoll.label = "Poll: " + (autoPollEnabled ? "ON" : "OFF");
  btnAutoPoll.bg = autoPollEnabled ? C_SUCCESS : C_ERROR;
  btnAutoPoll.fg = autoPollEnabled ? C_BG : C_TEXT;
  btnAutoPoll.draw();

  // Labels say "Log:" explicitly (doc 142 §4.3) — these buttons only
  // show/hide lines in THIS GUI's own log panel; they never reach the
  // device. Old plain "GPS: ON/OFF" label read like a real device
  // toggle and caused exactly that confusion — see doc 142 §1.2.
  btnShowGps.label = "GPS Log:" + (showGpsLogs ? "ON" : "OFF");
  btnShowGps.bg = showGpsLogs ? C_BTN : C_ERROR;
  btnShowGps.draw();

  btnShowTrip.label = "TRIP Log:" + (showTripLogs ? "ON" : "OFF");
  btnShowTrip.bg = showTripLogs ? C_BTN : C_ERROR;
  btnShowTrip.draw();

  int statusW = 170;
  int statusX = WIN_W - MARGIN - statusW;
  fill(GUI_CHROME_BG);
  stroke(state.connected ? C_SUCCESS : C_ERROR);
  strokeWeight(2);
  rect(statusX, MARGIN, statusW, TOPBAR_H, 6);
  noStroke();
  fill(state.connected ? C_SUCCESS : C_ERROR);
  ellipse(statusX + 18, MARGIN + TOPBAR_H / 2, 10, 10);
  fill(C_TEXT);
  textAlign(LEFT, CENTER);
  textSize(13);
  text(state.connected ? "Connected" : "Disconnected", statusX + 30, MARGIN + TOPBAR_H / 2 + 1);
}

// Drawn separately, LAST, from the main sketch's draw() — so the
// dropdown overlay renders on top of the serial monitor / display
// panels instead of being drawn-over by them.
void drawComDropdownOverlayIfOpen() {
  if (!comDropdownOpen) return;

  float ddY = MARGIN + TOPBAR_H + 2;
  float ddH = min(200, max(40, availablePorts.length * 30));
  if (comDropdownList == null || comDropdownList.items.length != availablePorts.length) {
    comDropdownList = new GList(MARGIN, ddY, 190, ddH, availablePorts);
    comDropdownList.itemH = 30;
  }
  comDropdownList.x = MARGIN; comDropdownList.y = ddY; comDropdownList.w = 190; comDropdownList.h = ddH;
  comDropdownList.selected = selectedPortIndex;

  stroke(GUI_CHROME_BORDER);
  strokeWeight(1);
  comDropdownList.draw(guiMouseX, guiMouseY);
  noStroke();
}

// Same overlay pattern as the COM dropdown, positioned under btnBaud.
void drawBaudDropdownOverlayIfOpen() {
  if (!baudDropdownOpen) return;

  float ddX = btnBaud.x;
  float ddY = MARGIN + TOPBAR_H + 2;
  float ddH = min(200, max(40, BAUD_RATES.length * 26));
  if (baudDropdownList == null) {
    baudDropdownList = new GList(ddX, ddY, 110, ddH, baudLabels());
    baudDropdownList.itemH = 26;
  }
  baudDropdownList.x = ddX; baudDropdownList.y = ddY; baudDropdownList.w = 110; baudDropdownList.h = ddH;
  int sel = 0;
  for (int i = 0; i < BAUD_RATES.length; i++) if (BAUD_RATES[i] == selectedBaud) { sel = i; break; }
  baudDropdownList.selected = sel;

  stroke(GUI_CHROME_BORDER);
  strokeWeight(1);
  baudDropdownList.draw(guiMouseX, guiMouseY);
  noStroke();
}

boolean handleTopMenuBarClick(float mx, float my) {
  // Dropdowns open — check rows first. Clicking a row, or the dropdown's
  // own trigger button again, closes it and consumes the click. Clicking
  // ANYWHERE else (e.g. the OTHER dropdown's trigger) also closes it but
  // falls through, so switching straight from one dropdown to the other
  // takes one click, not two.
  if (comDropdownOpen) {
    boolean hitList = comDropdownList != null && comDropdownList.handleClick(mx, my);
    if (hitList && comDropdownList.lastClickedIndex >= 0) {
      selectedPortIndex = comDropdownList.lastClickedIndex;
      settingsSet("lastPort", currentPortLabel());
      logLine("[gui] Selected port: " + currentPortLabel());
    }
    comDropdownOpen = false;
    if (hitList || btnComPort.contains(mx, my)) return true;
  }
  if (baudDropdownOpen) {
    boolean hitList = baudDropdownList != null && baudDropdownList.handleClick(mx, my);
    if (hitList && baudDropdownList.lastClickedIndex >= 0) {
      selectedBaud = BAUD_RATES[baudDropdownList.lastClickedIndex];
      settingsSet("lastBaud", str(selectedBaud));
      logLine("[gui] Selected baud rate: " + selectedBaud);
    }
    baudDropdownOpen = false;
    if (hitList || btnBaud.contains(mx, my)) return true;
  }

  if (btnComPort.contains(mx, my)) {
    if (state.connected) {
      logLine("[gui] Disconnect first before changing ports.");
    } else {
      refreshPortList();
      comDropdownOpen = true;
    }
    return true;
  }
  if (btnBaud.contains(mx, my)) {
    if (state.connected) {
      logLine("[gui] Disconnect first before changing the baud rate.");
    } else {
      baudDropdownOpen = true;
    }
    return true;
  }
  if (btnConnect.contains(mx, my)) {
    toggleConnect();
    if (state.connected) settingsSet("lastPort", state.portName);
    return true;
  }
  if (btnSettings.contains(mx, my)) {
    logLine("[gui] Top-bar Settings is a placeholder — see the Display panel's SET tab for real diagnostics.");
    return true;
  }
  if (btnAutoPoll.contains(mx, my)) {
    autoPollEnabled = !autoPollEnabled;
    settingsSet("autoPoll", autoPollEnabled ? "1" : "0");
    logLine("[gui] Auto-poll (trip info / gps info) " + (autoPollEnabled ? "ENABLED" : "DISABLED — nothing sent automatically now"));
    return true;
  }
  if (btnShowGps.contains(mx, my)) {
    showGpsLogs = !showGpsLogs;
    settingsSet("showGpsLogs", showGpsLogs ? "1" : "0");
    logLine("[gui] GPS log lines " + (showGpsLogs ? "SHOWN" : "HIDDEN") +
            " in THIS GUI panel only — the device's GPS backends keep running" +
            " either way. Use the GPS category's 'gps neo6m off'/'gps gnss off'" +
            " to actually stop them (doc 142).");
    return true;
  }
  if (btnShowTrip.contains(mx, my)) {
    showTripLogs = !showTripLogs;
    settingsSet("showTripLogs", showTripLogs ? "1" : "0");
    logLine("[gui] TRIP log lines " + (showTripLogs ? "SHOWN" : "HIDDEN") + " (trip data still updates live either way)");
    return true;
  }
  return false;
}
