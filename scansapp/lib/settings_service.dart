import 'package:shared_preferences/shared_preferences.dart';

/// Service class for managing application settings
class SettingsService {
  static const String _nameKey = 'device_name';
  static const String _ipAddressKey = 'device_ip_address';
  static const String _portKey = 'device_port';
  static const String _showCameraKey = 'show_camera';
  static const String _captureaudio = 'capture_audio';
  static const String _locationAcquisitionEnabledKey = 'location_acquisition_enabled';
  static const String _locationAcquisitionIntervalKey = 'location_acquisition_interval_seconds';

  static const String _defaultName = 'Logger Device';
  static const String _defaultIpAddress = '192.168.0.100';
  static const int _defaultPort = 1883;
  static const bool _defaultShowCamera = true;
  static const bool _defaultCaptureAudio = true;
  static const bool _defaultLocationAcquisitionEnabled = false;
  static const int _defaultLocationAcquisitionIntervalSeconds = 5;

  late SharedPreferences _prefs;

  /// Initialize the settings service and load preferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get the device name
  String getDeviceName() {
    String name = _prefs.getString(_nameKey) ?? _defaultName;
    name = name.trim();
    return name;
  }

  /// Set the device name
  Future<void> setDeviceName(String name) async {
    await _prefs.setString(_nameKey, name);
  }

  /// Get the IP address
  String getIpAddress() {
    return _prefs.getString(_ipAddressKey) ?? _defaultIpAddress;
  }

/// Get the sightings platform name, Primary or Tracker. 
  String getPlatform() {
    if (getDeviceName().toLowerCase().contains('tracker')) {
      return 'Tracker';
    } else {
      return 'Primary';
    }
  }

  /// Set the IP address
  Future<void> setIpAddress(String ipAddress) async {
    await _prefs.setString(_ipAddressKey, ipAddress);
  }

  /// Get the port number
  int getPort() {
    return _prefs.getInt(_portKey) ?? _defaultPort;
  }

  /// Set the port number
  Future<void> setPort(int port) async {
    await _prefs.setInt(_portKey, port);
  }

  bool getCaptureAudio() {
    return _prefs.getBool(_captureaudio) ?? _defaultCaptureAudio;
  }

  Future<void> setCaptureAudio(bool capture) async {
    await _prefs.setBool(_captureaudio, capture);
  }

  /// Return whether the camera preview should be shown
  bool getShowCamera() {
    return _prefs.getBool(_showCameraKey) ?? _defaultShowCamera;
  }

  /// Set whether the camera preview should be shown
  Future<void> setShowCamera(bool show) async {
    await _prefs.setBool(_showCameraKey, show);
  }

  bool getLocationAcquisitionEnabled() {
    return _prefs.getBool(_locationAcquisitionEnabledKey) ?? _defaultLocationAcquisitionEnabled;
  }

  Future<void> setLocationAcquisitionEnabled(bool enabled) async {
    await _prefs.setBool(_locationAcquisitionEnabledKey, enabled);
  }

  int getLocationAcquisitionIntervalSeconds() {
    return _prefs.getInt(_locationAcquisitionIntervalKey) ?? _defaultLocationAcquisitionIntervalSeconds;
  }

  Future<void> setLocationAcquisitionIntervalSeconds(int seconds) async {
    final sanitizedSeconds = seconds.clamp(1, 300);
    await _prefs.setInt(_locationAcquisitionIntervalKey, sanitizedSeconds);
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await _prefs.remove(_nameKey);
    await _prefs.remove(_ipAddressKey);
    await _prefs.remove(_portKey);
    await _prefs.remove(_showCameraKey);
    await _prefs.remove(_captureaudio);
    await _prefs.remove(_locationAcquisitionEnabledKey);
    await _prefs.remove(_locationAcquisitionIntervalKey);
  }
}
