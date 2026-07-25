// ================================================================
// PaxMeterScreen.pde — Mirrors main/display/test/test_pax_meter.c
// coordinate-for-coordinate (near-black C_TEST_BG theme, not the main
// teal theme — this screen has always looked different on purpose,
// it's a clone of a real commercial PAX A920Pro meter's UI for visual
// reference).
//
// DELIBERATE: on the real device, this screen's START TRIP/END TRIP
// buttons are PURELY COSMETIC — they only flip local labels
// (test_pax_meter.c's _start_event/_end_event), they never call the
// real trip_manager.c functions. This replica keeps that exact
// behavior for fidelity — it does NOT send "trip start"/"trip stop"
// commands. Real meter control lives on the TRIP tab (MeterScreen.pde),
// which IS wired to the real firmware; duplicating that here under a
// button that behaves differently on the real device would be
// misleading, not helpful.
// ================================================================

GButton btnPaxBack, btnPaxLamp, btnPaxStart, btnPaxEnd;

String paxStatusText = "NOT FOR HIRE";
color  paxStatusColor;
String paxMeterText = "METER READY";
String paxFareText = "0.00";

void initPaxMeterScreen() {
  btnPaxBack  = new GButton(0, 5, 56, 26, "< Back", C_BTN, C_TEXT);
  btnPaxLamp  = new GButton(0, 0, 52, 26, "⚙", C_BTN, C_TEXT2); // gear glyph, mirrors LV_SYMBOL_SETTINGS
  btnPaxStart = new GButton(4, 362, 156, 46, "START TRIP", C_SUCCESS, C_BG);
  btnPaxEnd   = new GButton(160, 362, 156, 46, "END TRIP", C_BG2, C_TEXT2);
  paxStatusColor = C_WARN; // initTheme() has already run by the time initDisplayPanel() calls this
}

void drawPaxMeterScreen() {
  fill(C_TEST_BG);
  noStroke();
  rect(0, 0, 320, 480);

  // Header
  fill(C_TEST_HDR);
  rect(0, 0, 320, 36);
  textAlign(LEFT, CENTER); fill(C_TEXT); textSize(13);
  text("≡ Meter", 8, 18);
  btnPaxBack.x = 320 - 30 - 28; btnPaxBack.y = 5;
  btnPaxBack.draw(dispMouseLX, dispMouseLY);
  textAlign(RIGHT, CENTER); fill(C_TEXT2); textSize(13);
  text("…", 312, 18);

  // Taxi ID + Status row
  fill(C_TEST_BG); noStroke(); rect(0, 36, 320, 44);
  stroke(C_DIVIDER); line(0, 80, 320, 80); noStroke();
  textAlign(LEFT, TOP); fill(C_TEXT2); textSize(10); text("Taxi ID", 8, 40);
  fill(C_TEXT); textSize(13); textAlign(LEFT, BOTTOM); text("T9522", 8, 78);
  fill(C_TEXT2); textAlign(LEFT, TOP); textSize(10); text("Status", 78, 40);
  fill(paxStatusColor); textSize(13); textAlign(LEFT, BOTTOM); text(paxStatusText, 78, 78);
  btnPaxLamp.x = 320 - 8 - 52; btnPaxLamp.y = 36 + 9;
  btnPaxLamp.draw(dispMouseLX, dispMouseLY);

  // Main fare section
  fill(C_TEST_BG); noStroke(); rect(0, 80, 320, 120);
  stroke(C_DIVIDER); line(0, 200, 320, 200); noStroke();
  textAlign(LEFT, TOP); fill(C_TEXT); textSize(14); text("$", 8, 84);
  textAlign(RIGHT, TOP); fill(C_TEXT); textSize(38);
  text(paxFareText, 312, 92);
  textAlign(RIGHT, BOTTOM); fill(C_TEXT2); textSize(13); text(paxMeterText, 312, 196);

  // Fees & Extras section
  fill(C_TEST_BG); noStroke(); rect(0, 200, 320, 90);
  stroke(C_DIVIDER); line(0, 290, 320, 290); noStroke();
  textAlign(LEFT, TOP); fill(C_TEXT); textSize(14); text("$", 8, 208);
  fill(C_TEXT2); textAlign(LEFT, BOTTOM); textSize(10); text("INCL.", 8, 286);
  textAlign(RIGHT, TOP); fill(C_TEXT); textSize(22); text("0.00", 312, 208);
  fill(C_TEXT2); textAlign(RIGHT, BOTTOM); textSize(10); text("FEES & EXTRAS", 312, 286);

  // Tariff section
  fill(C_TEST_BG); noStroke(); rect(0, 290, 320, 68);
  stroke(C_DIVIDER); line(0, 358, 320, 358); noStroke();
  textAlign(LEFT, TOP); fill(C_TEXT); textSize(22); text("00", 8, 296);
  fill(C_TEXT2); textAlign(LEFT, BOTTOM); textSize(10); text("TARIFF", 8, 356);

  // Action buttons
  btnPaxStart.draw(dispMouseLX, dispMouseLY);
  btnPaxEnd.draw(dispMouseLX, dispMouseLY);

  // Footer
  fill(C_TEST_BG); noStroke(); rect(0, 408, 320, 20);
  textAlign(LEFT, CENTER); fill(C_TEXT2); textSize(10); text("00B25703", 8, 418);
  textAlign(RIGHT, CENTER);
  text(nf(day(), 2) + "/" + nf(month(), 2) + "/" + year(), 312, 418);
}

boolean handlePaxMeterScreenClick(float lx, float ly) {
  if (btnPaxBack.contains(lx, ly)) { testMenuReturn(); return true; }
  if (btnPaxLamp.contains(lx, ly)) { logLine("[gui] Lamp toggle tapped (cosmetic — matches the real screen)"); return true; }
  if (btnPaxStart.contains(lx, ly)) {
    paxStatusText = "ON TRIP"; paxStatusColor = C_SUCCESS; paxMeterText = "RUNNING";
    return true;
  }
  if (btnPaxEnd.contains(lx, ly)) {
    paxStatusText = "NOT FOR HIRE"; paxStatusColor = C_WARN; paxMeterText = "METER READY"; paxFareText = "0.00";
    return true;
  }
  return true;
}
