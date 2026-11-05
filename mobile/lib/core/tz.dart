import 'package:timezone/data/latest.dart' as tzdata; // full database: future DST rules matter, 10y data would not cover them
import 'package:timezone/timezone.dart' as tz;

/// Business-timezone helpers.
///
/// UI models keep "wall-clock" times: a plain [DateTime] (no zone attached) whose fields are what a clock in the BUSINESS timezone
/// shows. That way staff see the same times wherever their phone is. Instants sent to / received from the API are UTC.
bool _ready = false;

tz.Location locationOf(String zone) {
  if (!_ready) {
    tzdata.initializeTimeZones();
    _ready = true;
  }
  try {
    return tz.getLocation(zone);
  } catch (_) {
    return tz.UTC; // unknown zone id: degrade to UTC rather than crash
  }
}

/// UTC instant -> wall clock in [zone].
DateTime wallFromInstant(DateTime instant, String zone) {
  final t = tz.TZDateTime.from(instant.toUtc(), locationOf(zone));
  return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
}

/// Wall clock in [zone] -> UTC instant.
DateTime instantFromWall(DateTime wall, String zone) =>
    tz.TZDateTime(locationOf(zone), wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second).toUtc();

DateTime nowWall(String zone) => wallFromInstant(DateTime.now().toUtc(), zone);

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// Start of the NEXT calendar day (safe across DST changes, unlike adding 24h).
DateTime nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);
