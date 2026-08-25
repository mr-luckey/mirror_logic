/// Per-placement request pacing for AdMob.
///
/// A burst waterfall (every unit in one go) produces many failed requests and
/// almost no impressions — the pattern AdMob treats as invalid traffic. This
/// keeps **one in-flight request**, sticks to a unit that fills, and only
/// rotates after a real no-fill, with backoff between attempts.
class AdPlacementLoadState {
  AdPlacementLoadState(this.unitIds);

  final List<String> unitIds;

  int _index = 0;
  int _missesThisCycle = 0;
  Duration _backoff = Duration.zero;
  DateTime? _nextAllowedAt;

  /// Floor between any two requests for the same slot (AdMob refresh minimum).
  static const Duration minRequestGap = Duration(seconds: 30);

  static const Duration initialCycleBackoff = Duration(seconds: 30);
  static const Duration maxBackoff = Duration(minutes: 5);

  /// Gap after a single unit misses, before the next id is tried.
  static const Duration nextUnitGap = Duration(seconds: 10);

  String get currentUnitId => unitIds[_index];

  int get index => _index;

  Duration get backoff => _backoff;

  Duration get delayUntilAllowed {
    final next = _nextAllowedAt;
    if (next == null) return Duration.zero;
    final left = next.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> waitUntilAllowed() async {
    final delay = delayUntilAllowed;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  void onFilled() {
    _missesThisCycle = 0;
    _backoff = Duration.zero;
    _nextAllowedAt = null;
  }

  void onEmpty() {
    _index = (_index + 1) % unitIds.length;
    _missesThisCycle++;
    if (_missesThisCycle >= unitIds.length) {
      _missesThisCycle = 0;
      _backoff = _backoff == Duration.zero
          ? initialCycleBackoff
          : _capped(_backoff * 2);
      _nextAllowedAt = DateTime.now().add(_backoff);
    } else {
      _nextAllowedAt = DateTime.now().add(nextUnitGap);
    }
  }

  /// Network / SDK down: do not burn the next unit.
  void onSkipped() {
    _nextAllowedAt = DateTime.now().add(nextUnitGap);
  }

  static Duration _capped(Duration value) =>
      value > maxBackoff ? maxBackoff : value;
}
