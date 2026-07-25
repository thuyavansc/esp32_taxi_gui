// ================================================================
// DashboardScreen.pde — Mirrors main/display/ui_main.c's
// _create_dashboard() layout coordinate-for-coordinate (same 320x480
// logical space, same card sizes/positions, same colors) so this
// reads as "the same screen," not a reinterpretation.
//
// Data source: AppState's trip fields, kept current by
// SerialManager.pde's parser reading trip_manager.c's "trip info"
// output (either typed manually or sent by MeterScreen's buttons).
// ================================================================

void initDashboardScreen() {
  // No persistent widgets needed — this screen is read-only display,
  // matching the real device (fare/speed/distance are shown, not
  // edited, on the Dashboard screen itself).
}

void drawDashboardScreen() {
  // Status bar
  fill(C_ACCENT);
  noStroke();
  rect(0, 0, 320, 32);
  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(13);
  String statusText = !state.connected ? "NOT CONNECTED"
                     : state.tripRunning ? ("TRIP #" + state.localTripId + (state.tripPaused ? " (PAUSED)" : " — RUNNING"))
                     : (state.onDuty ? "ON DUTY — READY" : "OFF DUTY");
  text(statusText, 160, 16);

  // Speed card
  drawMirrorCard(20, 40, 280, 115, C_ACCENT2, 2);
  textAlign(CENTER, TOP);
  fill(C_TEXT2); textSize(11); text("km/h", 160, 42);
  fill(C_TEXT); textSize(28);
  text(nf((float) state.speedKmh, 0, 1), 160, 78);
  fill(C_TEXT2); textSize(11);
  textAlign(CENTER, BOTTOM);
  text("SPEED", 160, 153);

  // Fare card
  drawMirrorCard(20, 165, 280, 85, C_SUCCESS, 1);
  textAlign(LEFT, TOP);
  fill(C_TEXT2); textSize(11); text("FARE", 24, 169);
  fill(C_WARN); textSize(20);
  textAlign(LEFT, CENTER);
  text("$", 24, 165 + 85 / 2 + 4);
  fill(C_TEXT); textSize(28);
  textAlign(RIGHT, CENTER);
  text(nf((float) (state.totalFareCents / 100.0), 0, 2), 292, 165 + 85 / 2 + 4);

  // DIST / TIME / WIFI bottom cards
  int cardY = 262, cardH = 72;
  drawMirrorCard(8, cardY, 94, cardH);
  textAlign(CENTER, TOP); fill(C_TEXT2); textSize(11); text("DIST", 8 + 47, cardY + 4);
  fill(C_TEXT); textSize(16); textAlign(CENTER, CENTER);
  text(nf((float) state.distanceKm, 0, 2), 8 + 47, cardY + cardH / 2 + 4);
  fill(C_TEXT2); textSize(10); textAlign(CENTER, BOTTOM); text("km", 8 + 47, cardY + cardH - 4);

  drawMirrorCard(113, cardY, 94, cardH);
  textAlign(CENTER, TOP); fill(C_TEXT2); textSize(11); text("TARIFF", 113 + 47, cardY + 4);
  fill(C_TEXT); textSize(14); textAlign(CENTER, CENTER);
  text(state.tariffType.length() > 0 ? state.tariffType : "--", 113 + 47, cardY + cardH / 2 + 4);

  drawMirrorCard(218, cardY, 94, cardH);
  textAlign(CENTER, TOP); fill(C_TEXT2); textSize(11); text("GPS", 218 + 47, cardY + 4);
  fill(state.gpsHasFix ? C_SUCCESS : C_ERROR); textSize(14); textAlign(CENTER, CENTER);
  text(state.gpsHasFix ? "FIX" : "NO FIX", 218 + 47, cardY + cardH / 2 + 4);

  // Fare breakdown mini-panel (this session's addition — the real
  // on-device Dashboard doesn't have room for this, but it's exactly
  // trip_manager.c's "trip info" breakdown, useful while testing).
  // Bounded to end well before the nav bar at y=428 (480-52) — every
  // row below is sized to fit inside by..by+86.
  int by = 336;
  drawMirrorCard(20, by, 280, 86);
  textSize(10);
  textAlign(LEFT, TOP);
  fill(C_TEXT2); text("Flag fall", 28, by + 6);
  fill(C_TEXT); textAlign(RIGHT, TOP); text(centsStr(state.flagFallCents), 292, by + 6);
  textAlign(LEFT, TOP);
  fill(C_TEXT2); text("Distance fare", 28, by + 19);
  fill(C_TEXT); textAlign(RIGHT, TOP); text(centsStr(state.distanceFareCents), 292, by + 19);
  textAlign(LEFT, TOP);
  fill(C_TEXT2); text("Time fare", 28, by + 32);
  fill(C_TEXT); textAlign(RIGHT, TOP); text(centsStr(state.timeFareCents), 292, by + 32);
  textAlign(LEFT, TOP);
  fill(C_TEXT2); text("Extras + special", 28, by + 45);
  fill(C_TEXT); textAlign(RIGHT, TOP); text(centsStr(state.extrasCents + state.specialFaresCents), 292, by + 45);
  stroke(C_DIVIDER); line(28, by + 60, 292, by + 60); noStroke();
  fill(C_WARN); textSize(12); textAlign(LEFT, TOP); text("TOTAL", 28, by + 66);
  fill(C_TEXT); textAlign(RIGHT, TOP); text("$" + nf((float)(state.totalFareCents / 100.0), 0, 2), 292, by + 66);
}

String centsStr(double cents) {
  return nf((float) cents, 0, 2) + "¢";
}

boolean handleDashboardScreenClick(float lx, float ly) {
  return true; // read-only screen — consume the click, no action
}
