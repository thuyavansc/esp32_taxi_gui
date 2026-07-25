// ================================================================
// MeterScreen.pde — The functional core: Setup → Login → Duty → Trip,
// the exact flow from docs 78/79. This screen doesn't exist on the
// real device yet (doc 81 §5 — no login/duty/trip UI built there
// yet) — it lives here until it does. Every control just calls
// sendCommand() with the SAME text the Serial Monitor panel accepts;
// nothing here is GUI-only logic (doc 85 §B.2/§B.7).
//
// Note on "trip start <name>": trip_manager.c's serial parser reads
// the customer name as a single whitespace-delimited token
// (sscanf "%31s") — a name with a space in it will only send the
// first word to the firmware. Not a GUI bug; a firmware parser
// limitation, unrelated to this session's GUI work.
// ================================================================

GTextField fldNetworkPasscode, fldVehicleNo;
GButton    btnResolveNetwork, btnResolveVehicle;

GTextField fldUsername, fldPassword;
GButton    btnLogin, btnLogout;

GToggle    toggleDuty;

GTextField fldCustomerName, fldExtras;
GButton    btnTripStart, btnTripStop, btnTripPause, btnTripResume, btnAddExtras;

void initMeterScreen() {
  int y = 40;
  fldNetworkPasscode = new GTextField(8, y, 150, 26, "Network passcode");
  btnResolveNetwork  = new GButton(164, y, 148, 26, "Resolve Network", C_BTN, C_TEXT);

  y += 32;
  fldVehicleNo      = new GTextField(8, y, 150, 26, "Vehicle No");
  btnResolveVehicle = new GButton(164, y, 148, 26, "Resolve Vehicle", C_BTN, C_TEXT);

  y += 40;
  fldUsername = new GTextField(8, y, 150, 26, "Username");
  fldPassword = new GTextField(164, y, 148, 26, "Password", true);

  y += 32;
  btnLogin  = new GButton(8, y, 148, 28, "Login", C_SUCCESS, C_BG);
  btnLogout = new GButton(164, y, 148, 28, "Logout", C_ERROR, C_TEXT);

  y += 44;
  toggleDuty = new GToggle(8, y, 304, 32, "ON DUTY (tap to go off)", "OFF DUTY (tap to go on)");

  y += 48;
  fldCustomerName = new GTextField(8, y, 304, 26, "Customer name (optional)");

  y += 34;
  btnTripStart  = new GButton(8, y, 148, 30, "START TRIP", C_SUCCESS, C_BG);
  btnTripStop   = new GButton(164, y, 148, 30, "STOP TRIP", C_ERROR, C_TEXT);

  y += 36;
  btnTripPause  = new GButton(8, y, 148, 28, "Pause", C_WARN, C_BG);
  btnTripResume = new GButton(164, y, 148, 28, "Resume", C_BTN, C_TEXT);

  y += 36;
  fldExtras   = new GTextField(8, y, 220, 28, "Extras $");
  btnAddExtras = new GButton(236, y, 76, 28, "Add", C_BTN, C_TEXT);

  // All of this screen's fields are drawn inside DisplayPanel's
  // scale(DISPLAY_SCALE) transform and clicked via lx/ly (the 320x480
  // logical space) — flag them so GTextField's drag-to-select
  // (mouseDragged(), Widgets.pde) reads dispMouseLX instead of raw
  // mouseX. See GTextField.logicalSpace's own comment for why.
  fldNetworkPasscode.logicalSpace = true;
  fldVehicleNo.logicalSpace = true;
  fldUsername.logicalSpace = true;
  fldPassword.logicalSpace = true;
  fldCustomerName.logicalSpace = true;
  fldExtras.logicalSpace = true;
}

void drawMeterScreen() {
  fill(C_ACCENT);
  noStroke();
  rect(0, 0, 320, 32);
  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(13);
  text("SETUP • LOGIN • DUTY • TRIP", 160, 16);

  toggleDuty.state = state.onDuty;

  fldNetworkPasscode.draw(); btnResolveNetwork.draw(dispMouseLX, dispMouseLY);
  fldVehicleNo.draw();       btnResolveVehicle.draw(dispMouseLX, dispMouseLY);

  fldUsername.draw(); fldPassword.draw();
  btnLogin.draw(dispMouseLX, dispMouseLY); btnLogout.draw(dispMouseLX, dispMouseLY);

  toggleDuty.draw();

  fldCustomerName.draw();
  btnTripStart.draw(dispMouseLX, dispMouseLY); btnTripStop.draw(dispMouseLX, dispMouseLY);
  btnTripPause.draw(dispMouseLX, dispMouseLY); btnTripResume.draw(dispMouseLX, dispMouseLY);
  fldExtras.draw(); btnAddExtras.draw(dispMouseLX, dispMouseLY);

  // Compact status readout at the very bottom of this screen's
  // content area (above the nav bar) — quick "what's actually true
  // right now" without switching screens, using the same fields
  // 'session info'/'trip info' populate.
  int sy = 400;
  textAlign(LEFT, TOP);
  textSize(10);
  fill(C_TEXT2);
  String line1 = "Net:" + (state.networkId > 0 ? state.networkId : "-") +
                 "  Veh:" + (state.vehicleId > 0 ? state.vehicleId : "-") +
                 "  Login:" + (state.loggedIn ? "YES" : "no");
  String line2 = "Tariffs:" + state.tariffCount + "  Trip#" + state.localTripId +
                 (state.tripRunning ? " RUNNING" : " stopped");
  text(line1, 8, sy);
  text(line2, 8, sy + 12);
}

boolean handleMeterScreenClick(float lx, float ly) {
  // Paste-icon hits checked BEFORE .contains() (the icon strip is
  // excluded from .contains()'s own bounds) — your ask: paste needs to
  // just work in every one of these fields, not just be theoretically
  // possible via a keyboard shortcut.
  if (fldNetworkPasscode.containsPasteIcon(lx, ly)) { fldNetworkPasscode.pasteAtIcon(); return true; }
  if (fldVehicleNo.containsPasteIcon(lx, ly))       { fldVehicleNo.pasteAtIcon();       return true; }
  if (fldUsername.containsPasteIcon(lx, ly))        { fldUsername.pasteAtIcon();        return true; }
  if (fldPassword.containsPasteIcon(lx, ly))        { fldPassword.pasteAtIcon();        return true; }
  if (fldCustomerName.containsPasteIcon(lx, ly))    { fldCustomerName.pasteAtIcon();    return true; }
  if (fldExtras.containsPasteIcon(lx, ly))          { fldExtras.pasteAtIcon();          return true; }

  if (fldNetworkPasscode.contains(lx, ly)) { fldNetworkPasscode.focus(lx); return true; }
  if (fldVehicleNo.contains(lx, ly))       { fldVehicleNo.focus(lx);       return true; }
  if (fldUsername.contains(lx, ly))        { fldUsername.focus(lx);       return true; }
  if (fldPassword.contains(lx, ly))        { fldPassword.focus(lx);       return true; }
  if (fldCustomerName.contains(lx, ly))    { fldCustomerName.focus(lx);   return true; }
  if (fldExtras.contains(lx, ly))          { fldExtras.focus(lx);         return true; }

  if (btnResolveNetwork.contains(lx, ly)) { doResolveNetwork(); return true; }
  if (btnResolveVehicle.contains(lx, ly)) { doResolveVehicle(); return true; }
  if (btnLogin.contains(lx, ly))          { doLogin();          return true; }
  if (btnLogout.contains(lx, ly))         { sendCommand("auth logout"); return true; }
  if (toggleDuty.contains(lx, ly))        { sendCommand(state.onDuty ? "duty off" : "duty on"); return true; }
  if (btnTripStart.contains(lx, ly))      { doTripStart();      return true; }
  if (btnTripStop.contains(lx, ly))       { sendCommand("trip stop");   return true; }
  if (btnTripPause.contains(lx, ly))      { sendCommand("trip pause");  return true; }
  if (btnTripResume.contains(lx, ly))     { sendCommand("trip resume"); return true; }
  if (btnAddExtras.contains(lx, ly))      { doAddExtras();      return true; }

  return true; // clicked elsewhere on this screen — still consume it (avoid falling through to another screen)
}

void doResolveNetwork() {
  String p = fldNetworkPasscode.text.trim();
  sendCommand(p.length() > 0 ? ("setup network " + p) : "setup network");
}

void doResolveVehicle() {
  String v = fldVehicleNo.text.trim();
  sendCommand(v.length() > 0 ? ("setup vehicle " + v) : "setup vehicle");
}

void doLogin() {
  String u = fldUsername.text.trim();
  String pw = fldPassword.text.trim();
  if (u.length() > 0 && pw.length() > 0) {
    sendCommand("auth login " + u + " " + pw);
  } else {
    sendCommand("auth login"); // firmware falls back to config.h's test credentials
  }
}

void doTripStart() {
  String c = fldCustomerName.text.trim();
  sendCommand(c.length() > 0 ? ("trip start " + c) : "trip start");
}

void doAddExtras() {
  String v = fldExtras.text.trim();
  if (v.length() > 0) {
    sendCommand("trip extras " + v);
    fldExtras.text = "";
    // caret/selection must be reset in lockstep with clearing .text —
    // leaving them pointing past the new (empty) string's end is what
    // caused a real crash in GTextField.draw() (Widgets.pde) once fixed
    // at the root cause too, but this direct .text assignment bypasses
    // that fix entirely, so it needs its own reset.
    fldExtras.caret = 0;
    fldExtras.clearSelection();
  }
}

// Enter-key routing while a MeterScreen field is focused (Widgets.pde
// calls this via onFocusedFieldEnter() in the main sketch when the
// focused field isn't the serial monitor's own input).
void handleMeterScreenEnter() {
  if (focusedField == fldNetworkPasscode) doResolveNetwork();
  else if (focusedField == fldVehicleNo)  doResolveVehicle();
  else if (focusedField == fldUsername || focusedField == fldPassword) doLogin();
  else if (focusedField == fldCustomerName) doTripStart();
  else if (focusedField == fldExtras) doAddExtras();
}
