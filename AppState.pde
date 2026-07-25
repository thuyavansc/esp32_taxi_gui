// ================================================================
// AppState.pde — The single source of truth every screen reads from.
//
// SerialManager.pde's line parser is the ONLY thing that writes to
// these fields (as real lines arrive from the ESP32). Every screen's
// draw() function just reads the current values every frame — since
// Processing's draw() re-runs continuously (60fps by default), any
// change here is reflected on screen within one frame, which is what
// "reactive GUI" means in this codebase: no manual "refresh" step,
// the display is always showing the latest known state.
//
// This mirrors doc 79's session_store.c / fare_calc.c fields closely
// on purpose — same names, same meaning, so cross-referencing the
// firmware source and this GUI is straightforward.
// ================================================================

class AppState {
  // ── Connection ──
  boolean connected = false;
  String  portName = "";

  // ── Session (mirrors session_store.c) ──
  boolean loggedIn = false;
  long    networkId = 0;
  String  companyName = "";
  long    vehicleId = 0;
  long    vehicleTypeId = 0;
  String  vehicleNo = "";
  long    driverId = 0;
  String  driverName = "";
  String  tariffType = "";
  boolean onDuty = false;

  // ── Reference data (mirrors reference_data.c) ──
  int tariffCount = 0;
  int fixedRateCount = 0;
  int specialFareCount = 0;
  int holidayCount = 0;

  // ── GPS (mirrors gps_client.c's gps_data_t) ──
  boolean gpsHasFix = false;
  double  gpsLat = 0, gpsLon = 0, gpsAlt = 0;
  double  gpsSpeed = 0, gpsCourse = 0, gpsHdop = 0;
  int     gpsSatellites = 0;

  // ── Active trip / live fare (mirrors fare_calc.c's snapshot) ──
  boolean tripRunning = false;
  boolean tripPaused = false;
  long    localTripId = 0;
  long    serverJobId = 0;
  String  customerName = "";
  double  distanceKm = 0;
  double  speedKmh = 0;
  boolean fareGpsActive = false;
  double  flagFallCents = 0;
  double  distanceFareCents = 0;
  double  timeFareCents = 0;
  double  gpsInactiveFareCents = 0;
  double  extrasCents = 0;
  double  specialFaresCents = 0;
  double  totalFareCents = 0;

  // ── RAM/storage diagnostics (mirrors diag.c) ──
  int freeHeapKB = -1;
  int largestBlockKB = -1;

  // Reset everything session-related back to defaults — called when
  // the port disconnects, so the GUI doesn't keep showing stale data
  // from a previous device/session.
  void resetOnDisconnect() {
    connected = false;
    // Deliberately NOT resetting session/trip/gps fields — the last
    // known values stay visible (greyed out by each screen's own
    // "disconnected" styling) rather than snapping to zero, since
    // that's usually more useful when you reconnect the same device.
  }
}

AppState state = new AppState();
