import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceInfoHelper {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// 기기 고유 ID 가져오기
  static Future<String> getDeviceId() async {
    try {
      if (kIsWeb) {
        return 'web_${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id; // Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios';
      } else {
        return 'unknown_platform';
      }
    } catch (e) {
      print('❌ 디바이스 ID 가져오기 실패: $e');
      return 'error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}