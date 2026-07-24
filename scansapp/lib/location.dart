import 'package:geolocator/geolocator.dart';

/// Formats a location point as a standard NMEA 0183 RMC sentence.
class NmeaRmcFormatter {
  static String format({
    required DateTime timestamp,
    required double latitude,
    required double longitude,
    double? speedKnots,
    double? trackDegrees,
    String status = 'A',
    String mode = 'A',
  }) {
    final utcTimestamp = timestamp.toUtc();
    final time = _formatTime(utcTimestamp);
    final date = _formatDate(utcTimestamp);
    final lat = _formatCoordinate(latitude, isLongitude: false);
    final lon = _formatCoordinate(longitude, isLongitude: true);
    final speed = (speedKnots ?? 0.0).toStringAsFixed(2);
    final track = (trackDegrees ?? 0.0).toStringAsFixed(2);

    final sentenceBody =
        'GPRMC,$time,$status,${lat.value},${lat.hemisphere},${lon.value},${lon.hemisphere},$speed,$track,$date,0.0,E,$mode';
    final checksum = _calculateChecksum(sentenceBody);
    return '\$$sentenceBody*$checksum';
  }

  static String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}${timestamp.second.toString().padLeft(2, '0')}';
  }

  static String _formatDate(DateTime timestamp) {
    return '${timestamp.day.toString().padLeft(2, '0')}${timestamp.month.toString().padLeft(2, '0')}${timestamp.year.toString().substring(2)}';
  }

  static _CoordinateParts _formatCoordinate(double value, {required bool isLongitude}) {
    final absValue = value.abs();
    final degrees = absValue.floor();
    final minutes = (absValue - degrees) * 60.0;
    final direction = value >= 0
        ? (isLongitude ? 'E' : 'N')
        : (isLongitude ? 'W' : 'S');
    final degreesText = degrees.toString().padLeft(isLongitude ? 3 : 2, '0');
    return _CoordinateParts(
      value: '$degreesText${minutes.toStringAsFixed(4)}',
      hemisphere: direction,
    );
  }

  static String _calculateChecksum(String sentenceBody) {
    var checksum = 0;
    for (final unit in sentenceBody.codeUnits) {
      checksum ^= unit;
    }
    return checksum.toRadixString(16).toUpperCase().padLeft(2, '0');
  }
}

class _CoordinateParts {
  const _CoordinateParts({required this.value, required this.hemisphere});

  final String value;
  final String hemisphere;
}

/// Reads the current device location and converts it into a valid RMC sentence.
class NmeaLocationService {
  Future<String> getCurrentRmcSentence({
    DateTime? timestamp,
    LocationAccuracy accuracy = LocationAccuracy.best,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Location services are disabled.');
    }

    await _ensureLocationPermission();

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: accuracy,
    );

    final speedKnots = position.speed.isFinite && position.speed >= 0
        ? position.speed * 1.94384449
        : 0.0;
    final trackDegrees = position.heading.isFinite && position.heading >= 0
        ? position.heading
        : 0.0;

    return NmeaRmcFormatter.format(
      timestamp: timestamp ?? DateTime.now().toUtc(),
      latitude: position.latitude,
      longitude: position.longitude,
      speedKnots: speedKnots,
      trackDegrees: trackDegrees,
    );
  }

  Future<LocationPermission> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is permanently denied.');
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw StateError('Location permission was not granted.');
    }

    return permission;
  }
}
