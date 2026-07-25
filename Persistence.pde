// ================================================================
// Persistence.pde — Tiny key=value settings file, saved next to the
// sketch (NOT inside data/ — sketchPath() targets the sketch folder
// itself, so this survives a "clean" of the data folder and is easy
// to find/delete by hand if you ever want to reset it).
//
// Currently just remembers the last-used COM port (your ask: "make
// sure what selected last time show next time open"). Structured as
// generic key=value pairs so more settings can be added later without
// a format change.
// ================================================================

final String SETTINGS_FILENAME = "gui_settings.txt";

String settingsGet(String key, String defaultValue) {
  String path = sketchPath(SETTINGS_FILENAME);
  File f = new File(path);
  if (!f.exists()) return defaultValue;

  String[] lines = loadStrings(path);
  if (lines == null) return defaultValue;

  for (String line : lines) {
    int eq = line.indexOf('=');
    if (eq <= 0) continue;
    String k = line.substring(0, eq);
    String v = line.substring(eq + 1);
    if (k.equals(key)) return v;
  }
  return defaultValue;
}

void settingsSet(String key, String value) {
  String path = sketchPath(SETTINGS_FILENAME);
  java.util.LinkedHashMap<String, String> map = new java.util.LinkedHashMap<String, String>();

  File f = new File(path);
  if (f.exists()) {
    String[] lines = loadStrings(path);
    if (lines != null) {
      for (String line : lines) {
        int eq = line.indexOf('=');
        if (eq <= 0) continue;
        map.put(line.substring(0, eq), line.substring(eq + 1));
      }
    }
  }
  map.put(key, value);

  String[] out = new String[map.size()];
  int i = 0;
  for (String k : map.keySet()) out[i++] = k + "=" + map.get(k);
  saveStrings(path, out);
}
