/// Collision-resistant numeric IDs that remain JSON/JavaScript-safe.
/// The per-millisecond sequence avoids collisions from rapid UI/AI additions.
class IdGenerator {
  static int _lastMillisecond = 0;
  static int _sequence = 0;

  static int next() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now == _lastMillisecond) {
      _sequence = (_sequence + 1) % 1000;
    } else {
      _lastMillisecond = now;
      _sequence = 0;
    }
    return now * 1000 + _sequence;
  }
}
