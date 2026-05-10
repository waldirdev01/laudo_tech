class CoordinateFormatter {
  static String? formatLatitude(double? latitude) {
    return _formatFromDecimal(
      latitude,
      positiveHemisphere: 'N',
      negativeHemisphere: 'S',
    );
  }

  static String? formatLongitude(double? longitude) {
    return _formatFromDecimal(
      longitude,
      positiveHemisphere: 'E',
      negativeHemisphere: 'W',
    );
  }

  static String? formatLatitudeFromSouthString(String? value) {
    return _formatFromString(value, forcedHemisphere: 'S');
  }

  static String? formatLongitudeFromWestString(String? value) {
    return _formatFromString(value, forcedHemisphere: 'W');
  }

  static String? formatPair({
    required String? latitude,
    required String? longitude,
  }) {
    if (latitude == null || longitude == null) return null;
    if (latitude.trim().isEmpty || longitude.trim().isEmpty) return null;
    return '$latitude $longitude';
  }

  static String? _formatFromString(
    String? value, {
    required String forcedHemisphere,
  }) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('°')) return trimmed;

    final normalized = trimmed.replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed == null) return trimmed;
    return _formatAbsolute(parsed.abs(), forcedHemisphere);
  }

  static String? _formatFromDecimal(
    double? value, {
    required String positiveHemisphere,
    required String negativeHemisphere,
  }) {
    if (value == null) return null;
    final hemisphere = value < 0 ? negativeHemisphere : positiveHemisphere;
    return _formatAbsolute(value.abs(), hemisphere);
  }

  static String _formatAbsolute(double absoluteValue, String hemisphere) {
    var totalTenths = (absoluteValue * 36000).round();

    var degrees = totalTenths ~/ 36000;
    totalTenths -= degrees * 36000;

    var minutes = totalTenths ~/ 600;
    totalTenths -= minutes * 600;

    var secondsWhole = totalTenths ~/ 10;
    var secondsTenth = totalTenths % 10;

    if (secondsWhole >= 60) {
      secondsWhole -= 60;
      minutes += 1;
    }
    if (minutes >= 60) {
      minutes -= 60;
      degrees += 1;
    }

    final seconds = '$secondsWhole.$secondsTenth';
    return '$degrees°${minutes.toString().padLeft(2, '0')}\'$seconds"$hemisphere';
  }
}
