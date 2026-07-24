import 'package:flutter_test/flutter_test.dart';
import 'package:scansapp/location.dart';

void main() {
  test('formats a valid RMC sentence from coordinates', () {
    final sentence = NmeaRmcFormatter.format(
      timestamp: DateTime.utc(2026, 7, 24, 12, 34, 56),
      latitude: 37.7749,
      longitude: -122.4194,
      speedKnots: 12.5,
      trackDegrees: 45.0,
    );

    expect(sentence, startsWith('\$GPRMC,'));
    expect(sentence, contains(',A,'));
    expect(sentence, matches(RegExp(r'^\$GPRMC,.*\*[0-9A-F]{2}$')));
  });
}
