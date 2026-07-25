// ================================================================
// CommandCatalog.pde — The full, real list of serial commands this
// firmware understands, organized by category for the side menu +
// command panel. Every entry here is a REAL command from the
// firmware's own process_command() dispatchers (app_main.c, ram_test.c,
// gps_client.c + gps_backend_gnss.c/gps_backend_neo6m.c, rest_api_
// storage.c, session_store.c, setup_client.c, auth_client.c,
// reference_data.c, duty_client.c, trip_manager.c, diag.c, nvs_state.c,
// factory_reset.c, llm_runner.c, additional_work.c, ota_client.c,
// remote_config.c) — nothing invented, nothing guessed. Full reference
// with exact syntax + flags + flows: docs/TestFunctionalities/
// esp32s3_board/141_2026-07-25_serial_command_inventory_and_gui_gap_analysis.md
//
// socket_client.c ("sk ...") is NOT compiled into this firmware at all
// (see CMakeLists.txt's own comment on this) — there is deliberately no
// category for it here anymore; sending "sk ..." would just get
// "Unknown command" back from the device.
//
// Commands that take an argument get their own persistent GTextField
// (created once here, not recreated per frame) so you can type a
// value and hit the row's own Send button — e.g. "api get <id>" needs
// a trip ID, "trip extras <amount>" needs a dollar amount.
// ================================================================

class CommandSpec {
  String label;             // shown on the row
  String baseCmd;           // sent as-is if no args, or with args appended
  GTextField field1, field2; // null if that arg isn't used
  GButton actionBtn;

  CommandSpec(String label, String baseCmd) {
    this(label, baseCmd, null, null);
  }

  CommandSpec(String label, String baseCmd, String arg1Placeholder) {
    this(label, baseCmd, arg1Placeholder, null);
  }

  CommandSpec(String label, String baseCmd, String arg1Placeholder, String arg2Placeholder) {
    this.label = label;
    this.baseCmd = baseCmd;
    if (arg1Placeholder != null) field1 = new GTextField(0, 0, 10, 10, arg1Placeholder);
    if (arg2Placeholder != null) field2 = new GTextField(0, 0, 10, 10, arg2Placeholder);
    actionBtn = new GButton(0, 0, 10, 10, hasArgs() ? "Send" : label, C_BTN, C_TEXT);
  }

  boolean hasArgs() { return field1 != null; }

  void send() {
    String cmd = baseCmd;
    if (field1 != null && field1.text.trim().length() > 0) cmd += " " + field1.text.trim();
    if (field2 != null && field2.text.trim().length() > 0) cmd += " " + field2.text.trim();
    sendCommand(cmd);
  }
}

class CommandCategory {
  String name;
  CommandSpec[] commands;
  CommandCategory(String name, CommandSpec[] commands) { this.name = name; this.commands = commands; }
}

CommandCategory[] COMMAND_CATEGORIES;

void initCommandCatalog() {
  COMMAND_CATEGORIES = new CommandCategory[] {

    new CommandCategory("System (Help/Reboot/Info)", new CommandSpec[] {
      new CommandSpec("Help (all commands)", "help"),
      new CommandSpec("Reboot device", "reboot"),
      new CommandSpec("Get full info report", "getinfo"),
      new CommandSpec("Get version", "getversion"),
    }),

    new CommandCategory("WiFi / Internet", new CommandSpec[] {
      new CommandSpec("WiFi status (SSID/MAC/IP/RSSI)", "net info"),
      new CommandSpec("Internet test (real HTTPS check)", "net test"),
      new CommandSpec("Net help", "net help"),
    }),

    // ── AT command passthrough (modem, A7670E) ─────────────────────
    // Any line starting with "AT" is forwarded to the modem VERBATIM,
    // no wrapper — these rows are just convenience presets for the
    // real 3GPP TS 27.007 commands, sourced from this repo's own
    // esp_modem component (managed_components/espressif__modem_at) and
    // docs/TestFunctionalities/sms/76_..._sms_gsm_modem_fundamentals.md
    // — nothing invented. The free-text row below sends whatever you
    // type, unmodified, so anything not listed here still works.
    new CommandCategory("AT: Send Raw Command", new CommandSpec[] {
      new CommandSpec("Send raw AT command", "", "e.g. AT+CSQ"),
    }),

    new CommandCategory("AT: Status / Info", new CommandSpec[] {
      new CommandSpec("Module info", "ATI"),
      new CommandSpec("Manufacturer", "AT+CGMI"),
      new CommandSpec("Model", "AT+CGMM"),
      new CommandSpec("Firmware revision", "AT+CGMR"),
      new CommandSpec("IMEI / serial number", "AT+CGSN"),
      new CommandSpec("SIM ready?", "AT+CPIN?"),
    }),

    new CommandCategory("AT: Network / Signal", new CommandSpec[] {
      new CommandSpec("Signal quality (RSSI)", "AT+CSQ"),
      new CommandSpec("Network registration (2G/3G)", "AT+CREG?"),
      new CommandSpec("Network registration (LTE)", "AT+CEREG?"),
      new CommandSpec("Current operator / service provider", "AT+COPS?"),
      new CommandSpec("IMSI", "AT+CIMI"),
    }),

    new CommandCategory("AT: Internet / IP", new CommandSpec[] {
      new CommandSpec("GPRS/PDP attach status", "AT+CGATT?"),
      new CommandSpec("PDP context config (APN)", "AT+CGDCONT?"),
      new CommandSpec("Local IP address (PDP context 1)", "AT+CGPADDR=1"),
      new CommandSpec("PDP context activation status", "AT+CGACT?"),
    }),

    new CommandCategory("AT: SMS", new CommandSpec[] {
      new CommandSpec("Set text mode (required first)", "AT+CMGF=1"),
      new CommandSpec("Set GSM character set", "AT+CSCS=\"GSM\""),
      new CommandSpec("Own phone number", "AT+CNUM"),
      new CommandSpec("List all stored SMS", "AT+CMGL=\"ALL\""),
      new CommandSpec("SMS storage status", "AT+CPMS?"),
      // "Read SMS by index" (AT+CMGR=<n>) isn't a preset here — CommandSpec
      // always inserts a space before an argument ("AT+CMGR= 3"), and
      // AT+CMGR's syntax needs no space after "=". Use the Send Raw
      // Command row above and type "AT+CMGR=3" (no space) instead.
      // "Send SMS" isn't a preset here on purpose — AT+CMGS is a real
      // TWO-stage exchange (modem replies with a "> " prompt, THEN you
      // send the message body followed by Ctrl+Z/0x1A) that this
      // single-shot passthrough doesn't implement — see doc 141/142.
      // Use the Send Raw Command row for AT+CMGS="<number>" to see the
      // "> " prompt itself; completing the send needs a real feature,
      // not a preset button.
    }),

    new CommandCategory("AT: GNSS", new CommandSpec[] {
      new CommandSpec("GNSS power status", "AT+CGNSSPWR?"),
      new CommandSpec("GNSS fix info (native, 9 CSV fields)", "AT+CGNSSINFO"),
      new CommandSpec("GNSS fix info — one-shot lat/lon/speed/course", "AT+CGPSINFO"),
      new CommandSpec("NMEA output status", "AT+CGNSSTST?"),
      new CommandSpec("NMEA-to-UART routing status", "AT+CGNSSPORTSWITCH?"),
      new CommandSpec("A-GPS: enable XTRA (predicted ephemeris)", "AT+CGNSSCMD=10,1"),
      new CommandSpec("A-GPS: enable SUPL (standard OMA assist)", "AT+CGNSSCMD=20,1"),
      new CommandSpec("A-GPS: enable hot-still (fast reacquire)", "AT+CGNSSCMD=30,1"),
      new CommandSpec("A-GPS: SUPL server currently configured", "AT+SUPLSERVER?"),
    }),

    new CommandCategory("Setup (Network/Vehicle)", new CommandSpec[] {
      new CommandSpec("Resolve network", "setup network", "passcode"),
      new CommandSpec("Resolve vehicle", "setup vehicle", "vehicle no"),
      new CommandSpec("Setup info", "setup info"),
      new CommandSpec("Setup help", "setup help"),
    }),

    new CommandCategory("Auth (Login)", new CommandSpec[] {
      new CommandSpec("Login", "auth login", "username", "password"),
      new CommandSpec("Logout", "auth logout"),
      new CommandSpec("Auth info", "auth info"),
      new CommandSpec("Auth help", "auth help"),
    }),

    new CommandCategory("Reference Data", new CommandSpec[] {
      new CommandSpec("Fetch all (tariffs/rates/etc.)", "ref fetch"),
      new CommandSpec("List tariffs", "ref list tariffs"),
      new CommandSpec("List fixed rates", "ref list fixedrates"),
      new CommandSpec("List special fares", "ref list specialfares"),
      new CommandSpec("List holidays", "ref list holidays"),
      new CommandSpec("Ref info", "ref info"),
      new CommandSpec("Ref help", "ref help"),
    }),

    new CommandCategory("Duty", new CommandSpec[] {
      new CommandSpec("Go ON duty", "duty on"),
      new CommandSpec("Go OFF duty", "duty off"),
      new CommandSpec("Duty info", "duty info"),
    }),

    new CommandCategory("Trip / Meter", new CommandSpec[] {
      new CommandSpec("Start trip", "trip start", "customer (optional)"),
      new CommandSpec("Stop trip", "trip stop"),
      new CommandSpec("Pause meter", "trip pause"),
      new CommandSpec("Resume meter", "trip resume"),
      new CommandSpec("Add extras ($)", "trip extras", "dollars"),
      new CommandSpec("Trip info (live fare)", "trip info"),
      new CommandSpec("Trip help", "trip help"),
    }),

    new CommandCategory("Session (NVS) / Reset", new CommandSpec[] {
      new CommandSpec("Session info (what's stored)", "session info"),
      new CommandSpec("Session clear (reset/logout)", "session clear"),
    }),

    new CommandCategory("GPS (dispatcher: GNSS + NEO-6M + inject)", new CommandSpec[] {
      new CommandSpec("GPS info (active source + all backends)", "gps info"),
      new CommandSpec("Set active source", "gps source", "gnss|neo6m|inject"),
      new CommandSpec("Inject fix (lat lon speed [hdop] [sats])", "gps set", "lat", "lon speed [hdop] [sats]"),
      new CommandSpec("GNSS: enable", "gps gnss on"),
      new CommandSpec("GNSS: disable", "gps gnss off"),
      new CommandSpec("GNSS: info", "gps gnss info"),
      new CommandSpec("GNSS: trigger A-GPS fetch", "gps gnss agps"),
      new CommandSpec("NEO-6M: enable", "gps neo6m on"),
      new CommandSpec("NEO-6M: disable", "gps neo6m off"),
      new CommandSpec("NEO-6M: info", "gps neo6m info"),
      new CommandSpec("NEO-6M: start continuous read", "gps neo6m start"),
      new CommandSpec("NEO-6M: stop", "gps neo6m stop"),
      new CommandSpec("NEO-6M: read once", "gps neo6m once"),
      new CommandSpec("NEO-6M: read every (interval mode)", "gps neo6m every"),
    }),

    new CommandCategory("Trips API (fetch/store trip JSON)", new CommandSpec[] {
      new CommandSpec("Fetch trip by ID", "api get", "trip id"),
      new CommandSpec("Read stored trip", "api read", "trip id"),
      new CommandSpec("List stored trips", "api list"),
      new CommandSpec("Delete trip by ID", "api delete", "trip id"),
      new CommandSpec("Delete ALL stored trips", "api delete all"),
      new CommandSpec("API info", "api info"),
      new CommandSpec("API help", "api help"),
    }),

    new CommandCategory("RAM", new CommandSpec[] {
      new CommandSpec("RAM info (live, no allocation)", "ram info"),
      new CommandSpec("Test SRAM", "ram test sram"),
      new CommandSpec("Test PSRAM", "ram test psram"),
      new CommandSpec("Test download (network -> PSRAM)", "ram test download"),
      new CommandSpec("Test ALL", "ram test all"),
    }),

    new CommandCategory("Diagnostics", new CommandSpec[] {
      new CommandSpec("mem (RAM check)", "mem"),
      new CommandSpec("store (what's saved)", "store"),
      new CommandSpec("diag help", "diag help"),
    }),

    new CommandCategory("NVS (Provisioning)", new CommandSpec[] {
      new CommandSpec("NVS status", "nvs status"),
      new CommandSpec("Set company id", "nvs company", "company id"),
      new CommandSpec("Set product name", "nvs product", "product name"),
    }),

    new CommandCategory("Factory Reset (2-step)", new CommandSpec[] {
      new CommandSpec("Step 1: Arm ('factory reset')", "factory reset"),
      new CommandSpec("Step 2: Confirm passcode (next line)", "", "passcode"),
    }),

    new CommandCategory("LLM (TinyLlama-260K)", new CommandSpec[] {
      new CommandSpec("Run prompt", "llm run", "prompt"),
      new CommandSpec("Run prompt with step count", "llm run", "steps", "prompt"),
      new CommandSpec("LLM help", "llm help"),
    }),

    new CommandCategory("SMS / Additional Work", new CommandSpec[] {
      new CommandSpec("SMS: reboot", "sms reboot"),
      new CommandSpec("SMS: custom command", "sms", "command text"),
    }),

    new CommandCategory("OTA (disabled in this build)", new CommandSpec[] {
      new CommandSpec("OTA check", "ota check"),
      new CommandSpec("OTA status", "ota status"),
    }),

    new CommandCategory("Remote Config (disabled in this build)", new CommandSpec[] {
      new CommandSpec("Config status", "config status"),
      new CommandSpec("Config check (force fetch)", "config check"),
    }),
  };
}
