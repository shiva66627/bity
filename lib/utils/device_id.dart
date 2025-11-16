import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';



class DeviceIdHelper {
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    // If already saved, return it
    String? savedId = prefs.getString("device_id");
    if (savedId != null) return savedId;

    final deviceInfo = DeviceInfoPlugin();
    String newId;

    try {
      // Android
      final info = await deviceInfo.androidInfo;
      newId = info.id; // unique device ID
    } catch (e) {
      // Fallback
      newId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    // Save locally
    prefs.setString("device_id", newId);

    return newId;
  }
}
