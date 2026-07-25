// ================================================================
// SerialManager.pde — Port list/connect/send/receive + the line parser
//
// THE CORE IDEA (doc 85 §B.2): the ESP32 firmware was NOT changed for
// this GUI. Every command sent here (sendCommand("trip start John"))
// is the exact same text you'd type into a raw Serial Monitor, handled
// by the exact same process_command() dispatchers already in the
// firmware (auth_client.c, setup_client.c, reference_data.c,
// duty_client.c, trip_manager.c, session_store.c, diag.c). This file's
// job is: (1) send those strings, (2) read back the ESP32's existing
// ESP_LOGI/printf output, and (3) pattern-match known lines into
// AppState fields — pure GUI-side work, nothing firmware-side.
//
// If parsing ever feels fragile against a specific log line, the fix
// is either a small regex tweak here, or (later, optional) a
// machine-friendly output variant added to the firmware — see doc 85
// §B.2's closing paragraph. Not needed to get this working today.
// ================================================================

import processing.serial.*;
import java.util.regex.*;

Serial myPort;
String[] availablePorts = new String[0];
int selectedPortIndex = 0;

// rawLog is written from TWO different threads: Processing's Serial
// library calls serialEvent() (-> logLine()) on its OWN reader thread,
// not the sketch's main draw()/event thread — while draw() (and mouse/
// key handlers) read it on the main thread. A plain ArrayList isn't
// thread-safe for that: draw() would capture rawLog.size(), start
// looping rawLog.get(i), and if the reader thread added/trimmed the
// list mid-loop, an index valid a moment ago goes out of bounds — the
// exact "IndexOutOfBoundsException: Index 600 out of bounds for length
// 600" crash. RAW_LOG_LOCK guards every mutation (logLine() below) and
// every multi-step read (snapshotLog(), used everywhere the log is
// iterated/indexed — SerialMonitorPanel.pde, Widgets.pde's log Ctrl+C/A,
// SerialMonitorWindow.pde) so a read always sees one consistent,
// unchanging list, never one that's being mutated underneath it.
final Object RAW_LOG_LOCK = new Object();
ArrayList<String> rawLog = new ArrayList<String>();
final int MAX_LOG_LINES = 600; // rolling cap so the log ArrayList doesn't grow forever in a long session

// A stable point-in-time COPY, safe to iterate/index freely without any
// risk of the live rawLog changing underneath you mid-loop. Every read
// site that does more than a single one-off rawLog.get()/size() call
// should snapshot once at the top and use the snapshot for the rest of
// that function, rather than touching the live rawLog repeatedly.
ArrayList<String> snapshotLog() {
  synchronized (RAW_LOG_LOCK) {
    return new ArrayList<String>(rawLog);
  }
}

// COM6-COM16 are always offered as selectable options, whether or not
// Serial.list() currently auto-detects them — Windows COM numbering
// for USB-serial adapters (CP2102/CH340) is assigned somewhat
// unpredictably and can shift between replugs, and auto-detection can
// occasionally miss a port that IS actually present. Merged with
// whatever Serial.list() DOES find (a real device always wins a
// dropdown entry over a manual guess if both resolve to the same
// name), de-duplicated, sorted in COM-number order.
final int MANUAL_COM_RANGE_START = 6;
final int MANUAL_COM_RANGE_END   = 16;

void refreshPortList() {
  // Remember the currently-selected port BY NAME before rebuilding —
  // merging in newly-detected ports can change sort order (e.g. a
  // freshly-plugged-in COM3 sorts before COM6-12), which would
  // silently shift what an old INDEX pointed at. Re-resolving by name
  // after the rebuild keeps "what's actually selected" stable across
  // refreshes instead of just "whatever now sits at the old index."
  String previouslySelected = (availablePorts.length > 0 && selectedPortIndex < availablePorts.length)
    ? availablePorts[selectedPortIndex] : null;

  String[] detected = Serial.list();
  java.util.LinkedHashSet<String> merged = new java.util.LinkedHashSet<String>();
  if (detected != null) for (String p : detected) merged.add(p);
  for (int i = MANUAL_COM_RANGE_START; i <= MANUAL_COM_RANGE_END; i++) merged.add("COM" + i);

  availablePorts = merged.toArray(new String[0]);
  sortPortsNumerically(availablePorts);

  selectedPortIndex = 0;
  if (previouslySelected != null) {
    for (int i = 0; i < availablePorts.length; i++) {
      if (availablePorts[i].equals(previouslySelected)) { selectedPortIndex = i; break; }
    }
  }
}

// "COM2" must sort before "COM10" — plain string sort would put them
// the other way around. Non-"COMx" entries (e.g. Mac/Linux device
// paths, if this ever runs there) sort after every COM entry, by name.
void sortPortsNumerically(String[] ports) {
  java.util.Arrays.sort(ports, new java.util.Comparator<String>() {
    public int compare(String a, String b) {
      Integer na = comPortNumber(a), nb = comPortNumber(b);
      if (na != null && nb != null) return na - nb;
      if (na != null) return -1;
      if (nb != null) return 1;
      return a.compareTo(b);
    }
  });
}

Integer comPortNumber(String port) {
  if (port == null || port.length() < 4 || !port.toUpperCase().startsWith("COM")) return null;
  try { return Integer.parseInt(port.substring(3)); } catch (NumberFormatException e) { return null; }
}

void cyclePortSelection() {
  if (availablePorts.length == 0) { refreshPortList(); return; }
  selectedPortIndex = (selectedPortIndex + 1) % availablePorts.length;
}

String currentPortLabel() {
  if (availablePorts.length == 0) return "(no ports found)";
  return availablePorts[selectedPortIndex];
}

void toggleConnect() {
  if (state.connected) {
    disconnectSerial();
  } else {
    connectSerial();
  }
}

void connectSerial() {
  if (availablePorts.length == 0) {
    logLine("[gui] No serial ports found — plug in the board, or click the port box to refresh.");
    return;
  }
  try {
    myPort = new Serial(this, availablePorts[selectedPortIndex], selectedBaud);
    myPort.bufferUntil('\n');
    state.connected = true;
    state.portName = availablePorts[selectedPortIndex];
    logLine("[gui] Connected to " + state.portName + " @ " + selectedBaud + " baud");
  } catch (Exception e) {
    logLine("[gui] FAILED to open " + availablePorts[selectedPortIndex] + " — " + e.getMessage());
    logLine("[gui] (Is PlatformIO's own Serial Monitor open on the same port? Only one program");
    logLine("[gui]  can hold a COM port at a time — close that first, see doc 85 §B.6)");
  }
}

void disconnectSerial() {
  if (myPort != null) {
    myPort.stop();
    myPort = null;
  }
  logLine("[gui] Disconnected from " + state.portName);
  state.resetOnDisconnect();
}

// Sends one command line exactly as if typed into a raw Serial Monitor.
void sendCommand(String cmd) {
  if (!state.connected || myPort == null) {
    logLine("[gui] Not connected — nothing sent: " + cmd);
    return;
  }
  myPort.write(cmd + "\n");
  logLine("> " + cmd); // echo what we sent, matching how a human typing it would see it
}

void logLine(String line) {
  synchronized (RAW_LOG_LOCK) {
    rawLog.add(line);
    while (rawLog.size() > MAX_LOG_LINES) rawLog.remove(0);
  }
  writeLogLineToFile(line); // no-op unless TXT/CSV recording is active — SerialMonitorPanel.pde
}

// ── Lightweight auto-poll — keeps the Dashboard/GPS/Meter screens
//    "reactive" without you having to keep retyping "trip info" —
//    just periodically re-sends the SAME read-only info commands a
//    human would type. Matches fare_calc's own 2s tick cadence for
//    trip info (doc 79 §3.1); GPS is polled less often since it also
//    self-logs periodically on its own (gps_client.c's idle loop).
//
//    "trip info" only fires while a trip is actually RUNNING — your
//    ask: "even we did not click ... start trip then why comes" — it
//    was polling unconditionally before, which is pointless spam (an
//    idle meter always reports the same all-zero snapshot) and was
//    burying real command output (e.g. 'setup network's result) under
//    a new block of noise every 2 seconds. "gps info" still polls
//    continuously since GPS position is meaningful even with no trip
//    active — autoPollEnabled (TopMenuBar.pde) is the master off
//    switch for BOTH if you want full manual control instead. ──
int lastTripPollMs = 0;
int lastGpsPollMs = 0;
final int TRIP_POLL_MS = 2000;
final int GPS_POLL_MS  = 5000;

void pollIfNeeded() {
  if (!state.connected || !autoPollEnabled) return;
  int now = millis();
  if (state.tripRunning && now - lastTripPollMs >= TRIP_POLL_MS) {
    sendCommandSilently("trip info");
    lastTripPollMs = now;
  }
  if (now - lastGpsPollMs >= GPS_POLL_MS) {
    sendCommandSilently("gps info");
    lastGpsPollMs = now;
  }
}

// Same as sendCommand() but doesn't echo "> ..." into the log — these
// fire automatically every couple seconds and would otherwise flood
// the serial monitor panel with repeated identical lines.
void sendCommandSilently(String cmd) {
  if (!state.connected || myPort == null) return;
  myPort.write(cmd + "\n");
}

// Called automatically by Processing whenever a full line (up to '\n')
// has arrived, because of myPort.bufferUntil('\n') above.
//
// Reads RAW BYTES and decodes them as UTF-8 explicitly — readStringUntil()
// instead would decode using the JVM's platform default charset (Cp1252
// on this Windows setup), which mangles every multi-byte UTF-8 character
// the firmware sends (box-drawing dividers, checkmarks, degree/cent
// signs, em dashes) into garbled replacement characters, since those
// bytes would get reinterpreted one-byte-per-character instead of as
// the UTF-8 sequences they actually are.
void serialEvent(Serial p) {
  byte[] bytes = p.readBytesUntil('\n');
  if (bytes == null || bytes.length == 0) return;
  String raw;
  try {
    raw = new String(bytes, "UTF-8");
  } catch (Exception e) {
    raw = new String(bytes);
  }
  raw = raw.replace("\r", "").replace("\n", "");
  if (raw.length() == 0) return;

  // Parse FIRST, always — Dashboard/GPS/Meter screens need live AppState
  // data regardless of whether this line is shown in the log (see
  // shouldShowInLog(), same file) or filtered out.
  parseLine(raw);
  if (shouldShowInLog(raw)) logLine(raw);
}

// ── Pattern library — one per known ESP32 log line shape ─────────
// Each pattern matches the MESSAGE portion after ESP_LOG's "I (12345)
// tag: " prefix is stripped (or the raw printf line, for lines that
// don't use ESP_LOG at all, like reference_data.c's table dumps) —
// see stripLogPrefix() below.

Pattern P_LOG_PREFIX = Pattern.compile("^[IWE] \\(\\d+\\) [^:]+:\\s?");

// session_store.c / session_store_print()
Pattern P_DRIVER      = Pattern.compile("Driver:\\s*id=(-?\\d+) no=(\\S+) name=(.*)");
Pattern P_VEHICLE     = Pattern.compile("Vehicle:\\s*id=(-?\\d+) type_id=(-?\\d+) no=(\\S+)");
Pattern P_NETWORK_SS  = Pattern.compile("Network:\\s*id=(-?\\d+) company=(.*)");
Pattern P_TARIFF_TYPE = Pattern.compile("Tariff type:\\s*(\\S+)");
Pattern P_DUTY_STATUS = Pattern.compile("Duty status:\\s*(ON DUTY|OFF DUTY)");

// auth_client.c
Pattern P_LOGIN_OK   = Pattern.compile("LOGIN OK.*driver_id=(-?\\d+) vehicle_id=(-?\\d+) vehicle_type_id=(-?\\d+)");
Pattern P_LOGIN_FAIL = Pattern.compile("LOGIN FAILED");
Pattern P_DRIVER_NAME = Pattern.compile("Driver profile:\\s*(.*)");

// setup_client.c
Pattern P_NETWORK_OK = Pattern.compile("NETWORK OK.*network_id=(-?\\d+) company=\"([^\"]*)\"");
Pattern P_VEHICLE_OK = Pattern.compile("VEHICLE OK.*vehicle_id=(-?\\d+) vehicle_type_id=(-?\\d+)");
Pattern P_SETUP_INFO = Pattern.compile("network_id=(-?\\d+) vehicle_id=(-?\\d+) vehicle_type_id=(-?\\d+) vehicle_no=(\\S+)");

// duty_client.c
Pattern P_ON_DUTY_LINE  = Pattern.compile("^ON DUTY");
Pattern P_OFF_DUTY_LINE = Pattern.compile("^OFF DUTY");

// reference_data.c
Pattern P_REF_INFO   = Pattern.compile("tariffs=(\\d+) fixed_rates=(\\d+) special_fares=(\\d+) holidays=(\\d+)");
Pattern P_REF_TARIFFS = Pattern.compile("^tariffs:\\s*(\\d+) rows loaded");
Pattern P_REF_FIXED   = Pattern.compile("^fixed_rates:\\s*(\\d+) rows loaded");
Pattern P_REF_SPECIAL = Pattern.compile("^special_fares:\\s*(\\d+) rows loaded");
Pattern P_REF_HOLIDAY = Pattern.compile("^public_holidays:\\s*(\\d+) rows loaded");

// gps_client.c
Pattern P_GPS_LAT   = Pattern.compile("Latitude:\\s*(-?[\\d.]+)");
Pattern P_GPS_LON   = Pattern.compile("Longitude:\\s*(-?[\\d.]+)");
Pattern P_GPS_ALT   = Pattern.compile("Altitude:\\s*(-?[\\d.]+) m");
Pattern P_GPS_SPD   = Pattern.compile("Speed:\\s*(-?[\\d.]+) km/h");
Pattern P_GPS_CRS   = Pattern.compile("Course:\\s*(-?[\\d.]+)");
Pattern P_GPS_SATS  = Pattern.compile("Satellites:\\s*(\\d+)");
Pattern P_GPS_HDOP  = Pattern.compile("HDOP:\\s*([\\d.]+)");
Pattern P_GPS_FIX   = Pattern.compile("^\\s*Fix:\\s*(YES|NO)");
Pattern P_GPS_IDLE_FIX   = Pattern.compile("GPS: fix OK \\| lat=(-?[\\d.]+) lon=(-?[\\d.]+) speed=(-?[\\d.]+)km/h sats=(\\d+) hdop=([\\d.]+)");
Pattern P_GPS_IDLE_NOFIX = Pattern.compile("GPS: no fix");

// trip_manager.c / _show_info()
Pattern P_TRIP_LOCAL_ID = Pattern.compile("Local trip id:\\s*(-?\\d+)");
Pattern P_TRIP_JOB_ID   = Pattern.compile("Server job id:\\s*(-?\\d+)");
Pattern P_TRIP_CUSTOMER = Pattern.compile("Customer:\\s*(.*)");
Pattern P_TRIP_RUNNING  = Pattern.compile("^\\s*Running:\\s*(yes|no)");
Pattern P_TRIP_TARIFF   = Pattern.compile("Tariff:\\s*#(-?\\d+) type=(\\S+)");
Pattern P_TRIP_GPSACT   = Pattern.compile("GPS active:\\s*(yes|no) \\| speed=(-?[\\d.]+) km/h");
Pattern P_TRIP_DIST     = Pattern.compile("^\\s*Distance:\\s*([\\d.]+) km");
Pattern P_TRIP_FLAGFALL = Pattern.compile("Flag fall:\\s*([\\d.]+)");
Pattern P_TRIP_DISTFARE = Pattern.compile("Distance fare:\\s*([\\d.]+)");
Pattern P_TRIP_TIMEFARE = Pattern.compile("^\\s*Time fare:\\s*([\\d.]+)");
Pattern P_TRIP_GPSINACT = Pattern.compile("GPS-inactive fare:\\s*([\\d.]+)");
Pattern P_TRIP_EXTRAS   = Pattern.compile("Extras:\\s*([\\d.]+)");
Pattern P_TRIP_SPECIAL  = Pattern.compile("Special fares:\\s*([\\d.]+)");
Pattern P_TRIP_TOTAL    = Pattern.compile("TOTAL:\\s*([\\d.]+)");
Pattern P_TRIP_STARTED  = Pattern.compile("TRIP #(-?\\d+) STARTED");
Pattern P_TRIP_STOPPED  = Pattern.compile("TRIP #(-?\\d+) STOPPED");

// diag.c
Pattern P_MEM_FREE    = Pattern.compile("Free heap NOW:\\s*(\\d+) KB");
Pattern P_MEM_LARGEST = Pattern.compile("Largest free block:\\s*(\\d+) KB");

String stripLogPrefix(String line) {
  Matcher m = P_LOG_PREFIX.matcher(line);
  return m.find() ? line.substring(m.end()) : line;
}

// ── Log category filter — your ask: "how we stop or control these
//    ... only what logs comes, or even in gps command we can stop
//    showing serial monitor". showGpsLogs/showTripLogs (TopMenuBar.pde,
//    persisted like the COM port/baud) hide lines TAGGED "gps"/"trip"
//    from the visible log + TXT/CSV recording — the underlying command
//    still runs and AppState still updates live (parseLine() always
//    runs first, in serialEvent(), regardless of this filter), only the
//    raw log text is suppressed. ──
Pattern P_LOG_TAG = Pattern.compile("^[IWE] \\(\\d+\\) ([^:]+):");

boolean shouldShowInLog(String raw) {
  Matcher m = P_LOG_TAG.matcher(raw);
  if (!m.find()) return true; // not an ESP_LOG-tagged line (GUI's own "> "/"[gui]" lines) — always show
  String tag = m.group(1);
  if (tag.equals("gps") && !showGpsLogs) return false;
  if (tag.equals("trip") && !showTripLogs) return false;
  return true;
}

void parseLine(String rawLine) {
  String line = stripLogPrefix(rawLine);
  Matcher m;

  m = P_DRIVER.matcher(line);
  if (m.find()) { state.driverId = Long.parseLong(m.group(1)); state.driverName = m.group(3).trim(); }

  m = P_VEHICLE.matcher(line);
  if (m.find()) { state.vehicleId = Long.parseLong(m.group(1)); state.vehicleTypeId = Long.parseLong(m.group(2)); state.vehicleNo = m.group(3); }

  m = P_NETWORK_SS.matcher(line);
  if (m.find()) { state.networkId = Long.parseLong(m.group(1)); state.companyName = m.group(2).trim(); }

  m = P_TARIFF_TYPE.matcher(line);
  if (m.find()) state.tariffType = m.group(1);

  m = P_DUTY_STATUS.matcher(line);
  if (m.find()) state.onDuty = m.group(1).equals("ON DUTY");

  m = P_LOGIN_OK.matcher(line);
  if (m.find()) {
    state.loggedIn = true;
    state.driverId = Long.parseLong(m.group(1));
    state.vehicleId = Long.parseLong(m.group(2));
    state.vehicleTypeId = Long.parseLong(m.group(3));
  }
  if (P_LOGIN_FAIL.matcher(line).find()) state.loggedIn = false;

  m = P_DRIVER_NAME.matcher(line);
  if (m.find() && m.group(1).trim().length() > 0) state.driverName = m.group(1).trim();

  m = P_NETWORK_OK.matcher(line);
  if (m.find()) { state.networkId = Long.parseLong(m.group(1)); state.companyName = m.group(2); }

  m = P_VEHICLE_OK.matcher(line);
  if (m.find()) { state.vehicleId = Long.parseLong(m.group(1)); state.vehicleTypeId = Long.parseLong(m.group(2)); }

  m = P_SETUP_INFO.matcher(line);
  if (m.find()) {
    state.networkId = Long.parseLong(m.group(1));
    state.vehicleId = Long.parseLong(m.group(2));
    state.vehicleTypeId = Long.parseLong(m.group(3));
    state.vehicleNo = m.group(4);
  }

  if (P_ON_DUTY_LINE.matcher(line).find())  state.onDuty = true;
  if (P_OFF_DUTY_LINE.matcher(line).find()) state.onDuty = false;

  m = P_REF_INFO.matcher(line);
  if (m.find()) {
    state.tariffCount = Integer.parseInt(m.group(1));
    state.fixedRateCount = Integer.parseInt(m.group(2));
    state.specialFareCount = Integer.parseInt(m.group(3));
    state.holidayCount = Integer.parseInt(m.group(4));
  }
  m = P_REF_TARIFFS.matcher(line); if (m.find()) state.tariffCount = Integer.parseInt(m.group(1));
  m = P_REF_FIXED.matcher(line);   if (m.find()) state.fixedRateCount = Integer.parseInt(m.group(1));
  m = P_REF_SPECIAL.matcher(line); if (m.find()) state.specialFareCount = Integer.parseInt(m.group(1));
  m = P_REF_HOLIDAY.matcher(line); if (m.find()) state.holidayCount = Integer.parseInt(m.group(1));

  m = P_GPS_LAT.matcher(line);  if (m.find()) state.gpsLat = Double.parseDouble(m.group(1));
  m = P_GPS_LON.matcher(line);  if (m.find()) state.gpsLon = Double.parseDouble(m.group(1));
  m = P_GPS_ALT.matcher(line);  if (m.find()) state.gpsAlt = Double.parseDouble(m.group(1));
  m = P_GPS_SPD.matcher(line);  if (m.find()) state.gpsSpeed = Double.parseDouble(m.group(1));
  m = P_GPS_CRS.matcher(line);  if (m.find()) state.gpsCourse = Double.parseDouble(m.group(1));
  m = P_GPS_SATS.matcher(line); if (m.find()) state.gpsSatellites = Integer.parseInt(m.group(1));
  m = P_GPS_HDOP.matcher(line); if (m.find()) state.gpsHdop = Double.parseDouble(m.group(1));
  m = P_GPS_FIX.matcher(line);  if (m.find()) state.gpsHasFix = m.group(1).equals("YES");

  m = P_GPS_IDLE_FIX.matcher(line);
  if (m.find()) {
    state.gpsHasFix = true;
    state.gpsLat = Double.parseDouble(m.group(1));
    state.gpsLon = Double.parseDouble(m.group(2));
    state.gpsSpeed = Double.parseDouble(m.group(3));
    state.gpsSatellites = Integer.parseInt(m.group(4));
    state.gpsHdop = Double.parseDouble(m.group(5));
  }
  if (P_GPS_IDLE_NOFIX.matcher(line).find()) state.gpsHasFix = false;

  m = P_TRIP_LOCAL_ID.matcher(line); if (m.find()) state.localTripId = Long.parseLong(m.group(1));
  m = P_TRIP_JOB_ID.matcher(line);   if (m.find()) state.serverJobId = Long.parseLong(m.group(1));
  m = P_TRIP_CUSTOMER.matcher(line);
  if (m.find()) { String c = m.group(1).trim(); if (!c.equals("(none)")) state.customerName = c; }
  m = P_TRIP_RUNNING.matcher(line);  if (m.find()) state.tripRunning = m.group(1).equals("yes");
  m = P_TRIP_TARIFF.matcher(line);   if (m.find()) state.tariffType = m.group(2);
  m = P_TRIP_GPSACT.matcher(line);
  if (m.find()) { state.fareGpsActive = m.group(1).equals("yes"); state.speedKmh = Double.parseDouble(m.group(2)); }
  m = P_TRIP_DIST.matcher(line);     if (m.find()) state.distanceKm = Double.parseDouble(m.group(1));
  m = P_TRIP_FLAGFALL.matcher(line); if (m.find()) state.flagFallCents = Double.parseDouble(m.group(1));
  m = P_TRIP_DISTFARE.matcher(line); if (m.find()) state.distanceFareCents = Double.parseDouble(m.group(1));
  m = P_TRIP_TIMEFARE.matcher(line); if (m.find()) state.timeFareCents = Double.parseDouble(m.group(1));
  m = P_TRIP_GPSINACT.matcher(line); if (m.find()) state.gpsInactiveFareCents = Double.parseDouble(m.group(1));
  m = P_TRIP_EXTRAS.matcher(line);   if (m.find()) state.extrasCents = Double.parseDouble(m.group(1));
  m = P_TRIP_SPECIAL.matcher(line);  if (m.find()) state.specialFaresCents = Double.parseDouble(m.group(1));
  m = P_TRIP_TOTAL.matcher(line);    if (m.find()) state.totalFareCents = Double.parseDouble(m.group(1));

  m = P_TRIP_STARTED.matcher(line);
  if (m.find()) { state.tripRunning = true; state.tripPaused = false; state.localTripId = Long.parseLong(m.group(1)); }
  m = P_TRIP_STOPPED.matcher(line);
  if (m.find()) { state.tripRunning = false; }

  m = P_MEM_FREE.matcher(line);    if (m.find()) state.freeHeapKB = Integer.parseInt(m.group(1));
  m = P_MEM_LARGEST.matcher(line); if (m.find()) state.largestBlockKB = Integer.parseInt(m.group(1));
}
