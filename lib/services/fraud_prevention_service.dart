import 'package:cloud_firestore/cloud_firestore.dart';

class FraudPreventionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔒 디바이스 중복 응모 확인 (Subcollection 방식 적용)
  Future<bool> isDeviceAlreadyEntered(String deviceId, String eventId) async {
    try {
      // prizes/{eventId}/participants/{deviceId} 문서를 직접 조회
      final docRef = _firestore
          .collection('prizes')
          .doc(eventId)
          .collection('participants') // ⭐ prizes 서브컬렉션으로 변경
          .doc(deviceId); // ⭐ deviceId를 문서 ID로 가정

      final docSnapshot = await docRef.get();

      final alreadyEntered = docSnapshot.exists;
      if (alreadyEntered) {
        print('🔒 중복 방지: 이 기기는 이미 응모했습니다');
      }
      return alreadyEntered;
    } catch (e) {
      print('❌ 디바이스 중복 확인 실패: $e');
      return false;
    }
  }

  /// 🔒 짧은 시간 내 과도한 응모 확인 (로직 유지. 별도 컬렉션 'ad_views' 사용 권장)
  Future<bool> isTooManyEntriesRecently(String userId) async {
    // NOTE: 기존 lottery_participants 컬렉션이 없어진다면 이 로직은 작동하지 않습니다.
    // 이 로직은 사용자에게 응모 속도 제한을 걸기 위함이므로,
    // 'ad_views' 컬렉션을 활용하거나 별도의 'user_entries_log'를 만드는 것을 권장합니다.

    // 현재는 임시로 prizes/{prizeId}/participants에 참여한 기록을 쿼리할 수 없습니다.
    // 대신, 응모 시 'lottery_entries_log'와 같은 별도의 기록용 컬렉션에 추가하는 것이 좋습니다.
    // 여기서는 구조 변경의 핵심이 아니므로, 'ad_views'를 활용하도록 임시 수정합니다.
    try {
      final fiveMinutesAgo = DateTime.now().subtract(Duration(minutes: 5));

      final snapshot = await _firestore
          .collection('ad_views') // ⭐ ad_views 컬렉션을 활용
          .where('userId', isEqualTo: userId)
          .where('viewedAt', isGreaterThan: Timestamp.fromDate(fiveMinutesAgo))
          .count()
          .get();

      final count = snapshot.count ?? 0;
      // 5분 내 10회 이상 광고 시청(또는 응모) 시 의심
      final isSuspicious = count > 10;

      if (isSuspicious) {
        print('🔒 의심스러운 활동: 5분 내 $count회 응모/시청 감지');
      }
      return isSuspicious;
    } catch (e) {
      print('❌ 과도한 응모 확인 실패: $e');
      return false;
    }
  }

  /// 🔒 종합 부정 방지 체크
  Future<Map<String, dynamic>> performFraudCheck({
    required String userId,
    required String deviceId,
    required String eventId,
  }) async {
    // 1. 디바이스 중복 응모 체크
    final deviceAlreadyEntered = await isDeviceAlreadyEntered(deviceId, eventId);
    if (deviceAlreadyEntered) {
      return {
        'allowed': false,
        'reason': '이 기기로 이미 응모하셨습니다',
        'checkType': 'device_duplicate',
      };
    }

    // 2. 과도한 응모 체크
    final tooManyEntries = await isTooManyEntriesRecently(userId);
    if (tooManyEntries) {
      return {
        'allowed': false,
        'reason': '잠시 후 다시 시도해주세요',
        'checkType': 'rate_limit',
      };
    }

    // ✅ 모든 체크 통과
    return {
      'allowed': true,
      'reason': 'OK',
      'checkType': 'none',
    };
  }
}