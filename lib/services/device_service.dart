import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  // 🔑 고유 디바이스 식별자 생성
  Future<String> getDeviceFingerprint() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceData = '';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceData = '${androidInfo.id}_${androidInfo.model}_${androidInfo.brand}_${androidInfo.device}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceData = '${iosInfo.identifierForVendor}_${iosInfo.model}_${iosInfo.systemName}';
      }
    } catch (e) {
      print('디바이스 정보 가져오기 실패: $e');
      deviceData = 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
    }

    // SHA-256 해시로 암호화
    final bytes = utf8.encode(deviceData);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  // 📱 디바이스 기본 정보
  Future<Map<String, String>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    Map<String, String> info = {};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info = {
          'platform': 'Android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'version': androidInfo.version.release,
          'sdk': androidInfo.version.sdkInt.toString(),
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        info = {
          'platform': 'iOS',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'version': iosInfo.systemVersion,
        };
      }
    } catch (e) {
      info = {'platform': 'Unknown', 'error': e.toString()};
    }

    return info;
  }
}