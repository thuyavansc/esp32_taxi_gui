// ================================================================
// GPSScreen.pde — Mirrors main/display/gps_screen.c's layout and
// colors. Data source: AppState's gps* fields, kept current by
// SerialManager.pde's parser reading gps_client.c's periodic idle log
// line and "gps info"/"gps once" output.
//
// Note: the real device's GPS screen has a "SEND" button that fires
// an iStartek tracking packet (backend/socket_client.c, a DIFFERENT,
// currently-disabled feature — ENABLE_SOCKET=0 in config.h — unrelated
// to the taxi-meter business logic). Rather than guess at that
// module's exact command syntax and risk sending something wrong,
// this GUI's button sends "gps once" instead (definitely correct,
// documented in gps_client.h) and is labeled REFRESH to be honest
// about what it actually does.
// ================================================================

GButton btnGpsRefresh;

void initGPSScreen() {
  btnGpsRefresh = new GButton(60, 374, 200, 44, "REFRESH (gps once)", C_SUCCESS, C_BG);
}

void drawGPSScreen() {
  fill(C_ACCENT);
  noStroke();
  rect(0, 0, 320, 32);
  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(13);
  text("GPS STATUS", 160, 16);

  // Latitude
  drawMirrorCard(8, 42, 304, 60);
  textAlign(LEFT, TOP); fill(C_TEXT2); textSize(11); text("Latitude", 12, 44);
  fill(C_TEXT); textSize(16); textAlign(LEFT, BOTTOM);
  text(state.gpsHasFix ? (nf((float) state.gpsLat, 0, 6) + "°") : "NO FIX", 12, 42 + 56);

  // Longitude
  drawMirrorCard(8, 112, 304, 60);
  textAlign(LEFT, TOP); fill(C_TEXT2); textSize(11); text("Longitude", 12, 114);
  fill(C_TEXT); textSize(16); textAlign(LEFT, BOTTOM);
  text(state.gpsHasFix ? (nf((float) state.gpsLon, 0, 6) + "°") : "NO FIX", 12, 112 + 56);

  // Satellites
  drawMirrorCard(8, 184, 144, 75);
  textAlign(CENTER, TOP); fill(C_TEXT2); textSize(11); text("Satellites", 8 + 72, 186);
  fill(C_WARN); textSize(28); textAlign(CENTER, CENTER);
  text(str(state.gpsSatellites), 8 + 72, 184 + 75 / 2 + 6);

  // HDOP
  drawMirrorCard(168, 184, 144, 75);
  textAlign(CENTER, TOP); fill(C_TEXT2); textSize(11); text("HDOP", 168 + 72, 186);
  fill(C_SUCCESS); textSize(28); textAlign(CENTER, CENTER);
  text(nf((float) state.gpsHdop, 0, 1), 168 + 72, 184 + 75 / 2 + 6);

  // Speed
  drawMirrorCard(8, 267, 304, 80, C_ACCENT2, 1);
  textAlign(LEFT, TOP); fill(C_TEXT2); textSize(11); text("Speed", 12, 269);
  fill(C_TEXT); textSize(28); textAlign(LEFT, CENTER);
  text(state.gpsHasFix ? nf((float) state.gpsSpeed, 0, 1) : "--", 12, 267 + 80 / 2 + 6);
  fill(C_TEXT2); textSize(11); textAlign(RIGHT, CENTER);
  text("km/h", 300, 267 + 80 / 2 + 6);

  btnGpsRefresh.draw(dispMouseLX, dispMouseLY);
}

boolean handleGPSScreenClick(float lx, float ly) {
  if (btnGpsRefresh.contains(lx, ly)) {
    sendCommand("gps once");
    return true;
  }
  return true;
}
