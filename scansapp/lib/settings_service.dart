import 'package:shared_preferences/shared_preferences.dart';

/// Service class for managing application settings
class SettingsService {
  static const String _nameKey = 'device_name';
  static const String _ipAddressKey = 'device_ip_address';
  static const String _portKey = 'device_port';

  static const String _defaultName = 'Logger Device';
  static const String _defaultIpAddress = '230.0.0.0';
  static const int _defaultPort = 4446;

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

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await _prefs.remove(_nameKey);
    await _prefs.remove(_ipAddressKey);
    await _prefs.remove(_portKey);
  }
}
