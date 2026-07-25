// ================================================================
// CommandCatalog.pde — The full, real list of serial commands this
// firmware understands, organized by category for the side menu +
// command panel. Every entry here is a REAL command from the
// firmware's own process_command() dispatchers (auth_client.c,
// setup_client.c, reference_data.c, duty_client.c, trip_manager.c,
// session_store.c, diag.c, gps_client.c, rest_api_storage.c,
// socket_client.c) — nothing invented, nothing guessed.
//
// Commands that take an argument get their own persistent GTextField
// (created once here, not recreated per frame) so you can type a
// value and hit the row's own Send button — e.g. "api get <id>" needs
// a trip ID, "gps every <sec> [cnt]" needs an interval.
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

    new CommandCategory("GPS", new CommandSpec[] {
      new CommandSpec("Start continuous read", "gps start"),
      new CommandSpec("Stop", "gps stop"),
      new CommandSpec("Read once", "gps once"),
      new CommandSpec("Read every N sec", "gps every", "seconds", "count (optional)"),
      new CommandSpec("GPS info", "gps info"),
    }),

    new CommandCategory("Trips API (legacy fetch)", new CommandSpec[] {
      new CommandSpec("Fetch trip by ID", "api get", "trip id"),
      new CommandSpec("Read stored trip", "api read", "trip id"),
      new CommandSpec("List stored trips", "api list"),
      new CommandSpec("Delete trip by ID", "api delete", "trip id"),
      new CommandSpec("Delete ALL stored trips", "api delete all"),
      new CommandSpec("API info", "api info"),
      new CommandSpec("API help", "api help"),
    }),

    new CommandCategory("iStartek Socket (sk)", new CommandSpec[] {
      new CommandSpec("Start auto-send", "sk start", "interval sec (optional)", "count (optional)"),
      new CommandSpec("Stop", "sk stop"),
      new CommandSpec("Send once", "sk once", "dummy/real (optional)"),
      new CommandSpec("Send every N sec", "sk every", "interval sec (optional)", "count (optional)"),
      new CommandSpec("SK info", "sk info"),
    }),

    new CommandCategory("Diagnostics", new CommandSpec[] {
      new CommandSpec("mem (RAM check)", "mem"),
      new CommandSpec("store (what's saved)", "store"),
    }),

    new CommandCategory("Other", new CommandSpec[] {
      new CommandSpec("help (all prefixes)", "help"),
    }),
  };
}
