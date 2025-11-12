import 'package:cloud_firestore/cloud_firestore.dart';

/// 서버 시간 검증 및 동기화를 담당하는 서비스
///
/// 시간 조작 방지를 위해 Firebase 서버 타임스탬프를 사용하여
/// 클라이언트와 서버 시간의 차이를 검증합니다.
class TimeValidationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Firebase 서버의 현재 시간을 가져옵니다
  ///
  /// 임시 문서를 생성하여 서버 타임스탬프를 받아온 후 삭제합니다.
  ///
  /// Returns: 서버의 현재 DateTime
  /// Throws: Firebase 통신 실패 시 예외 발생, 이 경우 로컬 시간 반환
  static Future<DateTime> getServerTime() async {
    try {
      final tempDocRef = _firestore.collection('temp').doc();
      await tempDocRef.set({
        'timestamp': FieldValue.serverTimestamp(),
        'purpose': 'time_validation',
      });

      final docSnapshot = await tempDocRef.get();
      final timestamp = docSnapshot.data()!['timestamp'] as Timestamp;
      await tempDocRef.delete();

      return timestamp.toDate();
    } catch (e) {
      print('⚠️ 서버 시간 획득 실패: $e');
      return DateTime.now(); // 폴백: 로컬 시간 반환
    }
  }

  /// 서버 시간과 클라이언트 시간의 차이를 검증합니다
  ///
  /// 5분 이상 차이가 나면 false를 반환하여 시간 조작을 감지합니다.
  ///
  /// Returns:
  /// - true: 시간이 동기화되어 있음 (차이 5분 이내)
  /// - false: 시간 차이가 너무 커서 시간 조작 의심
  static Future<ValidationResult> validateTime() async {
    try {
      final serverTime = await getServerTime();
      final clientTime = DateTime.now();
      final timeDifference = serverTime.difference(clientTime).abs();

      if (timeDifference.inMinutes > 5) {
        return ValidationResult(
          isValid: false,
          errorType: TimeValidationError.outOfSync,
          message: '시간 동기화 필요\n정확한 보상을 위해 기기 시간을 자동 설정으로 변경해주세요.',
        );
      }

      return ValidationResult(
        isValid: true,
        serverTime: serverTime,
        clientTime: clientTime,
        timeDifference: timeDifference,
      );
    } catch (e) {
      print('⚠️ 시간 검증 실패: $e');
      return ValidationResult(
        isValid: false,
        errorType: TimeValidationError.networkError,
        message: '시간 검증 실패\n네트워크 상태를 확인하고 다시 시도해주세요.',
      );
    }
  }

  /// DateTime을 'YYYY-MM-DD' 형식의 문자열로 변환합니다
  ///
  /// [date]: 변환할 DateTime 객체
  /// Returns: 'YYYY-MM-DD' 형식의 날짜 문자열
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 오늘 날짜를 'YYYY-MM-DD' 형식으로 반환합니다 (서버 시간 기준)
  ///
  /// Returns: 서버 기준 오늘 날짜 문자열
  static Future<String> getTodayDateString() async {
    final serverTime = await getServerTime();
    return formatDate(serverTime);
  }

  /// 두 날짜 문자열이 같은 날인지 비교합니다
  ///
  /// [dateString1]: 'YYYY-MM-DD' 형식의 날짜 문자열
  /// [dateString2]: 'YYYY-MM-DD' 형식의 날짜 문자열
  /// Returns: 같은 날이면 true
  static bool isSameDate(String dateString1, String dateString2) {
    return dateString1 == dateString2;
  }
}

/// 시간 검증 결과를 담는 클래스
class ValidationResult {
  final bool isValid;
  final DateTime? serverTime;
  final DateTime? clientTime;
  final Duration? timeDifference;
  final TimeValidationError? errorType;
  final String? message;

  ValidationResult({
    required this.isValid,
    this.serverTime,
    this.clientTime,
    this.timeDifference,
    this.errorType,
    this.message,
  });

  /// 검증 성공 여부
  bool get isSuccess => isValid;

  /// 검증 실패 여부
  bool get isFailure => !isValid;
}

/// 시간 검증 실패 유형
enum TimeValidationError {
  /// 시간이 동기화되지 않음 (5분 이상 차이)
  outOfSync,

  /// 네트워크 오류로 서버 시간을 가져올 수 없음
  networkError,
}