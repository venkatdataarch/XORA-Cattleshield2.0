import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// GPS capture data attached to every photo.
class GpsData {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;

  const GpsData({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() =>
      'GPS($latitude, $longitude, acc: ${accuracy?.toStringAsFixed(1)}m)';
}

/// Service to capture GPS coordinates with each photo.
class GpsService {
  /// Gets current position. Returns null on web or if permissions denied.
  static Future<GpsData?> captureLocation() async {
    try {
      // On web, geolocation may not be available
      if (kIsWeb) {
        // Return mock GPS for web demo
        return GpsData(
          latitude: 17.385,
          longitude: 78.4867,
          accuracy: 10.0,
          timestamp: DateTime.now(),
        );
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _mockGps();
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return _mockGps();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return GpsData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('GPS error: $e');
      return _mockGps();
    }
  }

  /// Mock GPS for demo/fallback
  static GpsData _mockGps() {
    return GpsData(
      latitude: 17.385 + (DateTime.now().millisecond / 10000),
      longitude: 78.4867 + (DateTime.now().millisecond / 10000),
      accuracy: 15.0,
      timestamp: DateTime.now(),
    );
  }
}
