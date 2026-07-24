import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scansapp/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists location acquisition settings', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SettingsService();

    await service.init();

    expect(service.getLocationAcquisitionEnabled(), isFalse);
    expect(service.getLocationAcquisitionIntervalSeconds(), 5);

    await service.setLocationAcquisitionEnabled(true);
    await service.setLocationAcquisitionIntervalSeconds(10);

    expect(service.getLocationAcquisitionEnabled(), isTrue);
    expect(service.getLocationAcquisitionIntervalSeconds(), 10);
  });
}
