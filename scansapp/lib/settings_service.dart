import 'package:shared_preferences/shared_preferences.dart';

/// Service class for managing application settings
class SettingsService {
  static const String _nameKey = 'device_name';
  static const String _ipAddressKey = 'device_ip_address';
  static const String _portKey = 'device_port';
  static const String _showCameraKey = 'show_camera';
  static const String _cameraGreyscaleKey = 'camera_greyscale';

  static const String _defaultName = 'Logger Device';
  static const String _defaultIpAddress = '230.0.0.0';
  static const int _defaultPort = 4446;
  static const bool _defaultShowCamera = true;
  static const bool _defaultCameraGreyscale = false;

  late SharedPreferences _prefs;

  /// Initialize the settings service and load preferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get the device name
  String getDeviceName() {
    return _prefs.getString(_nameKey) ?? _defaultName;
  }

  /// Set the device name
  Future<void> setDeviceName(String name) async {
    await _prefs.setString(_nameKey, name);
  }

  /// Get the IP address
  String getIpAddress() {
    return _prefs.getString(_ipAddressKey) ?? _defaultIpAddress;
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

  /// Return whether the camera preview should be shown
  bool getShowCamera() {
    return _prefs.getBool(_showCameraKey) ?? _defaultShowCamera;
  }

  /// Return whether camera frames should be converted to greyscale
  bool getCameraGreyscale() {
    return _prefs.getBool(_cameraGreyscaleKey) ?? _defaultCameraGreyscale;
  }

  /// Set whether the camera preview should be shown
  Future<void> setShowCamera(bool show) async {
    await _prefs.setBool(_showCameraKey, show);
  }

  /// Set whether camera frames should be converted to greyscale
  Future<void> setCameraGreyscale(bool greyscale) async {
    await _prefs.setBool(_cameraGreyscaleKey, greyscale);
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await _prefs.remove(_nameKey);
    await _prefs.remove(_ipAddressKey);
    await _prefs.remove(_portKey);
    await _prefs.remove(_showCameraKey);
    await _prefs.remove(_cameraGreyscaleKey);
  }
}
