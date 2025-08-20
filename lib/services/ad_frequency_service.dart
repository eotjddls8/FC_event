import 'package:shared_preferences/shared_preferences.dart';

class AdFrequencyService {
  static const String _lastInterstitialAdKey = 'last_interstitial_ad_date';
  static const String _adCountTodayKey = 'ad_count_today';

  // 🔍 오늘 전면광고를 이미 봤는지 확인
  static Future<bool> shouldShowInterstitialAd() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayString = _formatDate(today);

      // 마지막 전면광고 본 날짜 가져오기
      final lastAdDate = prefs.getString(_lastInterstitialAdKey);

      print('오늘 날짜: $todayString');
      print('마지막 광고 날짜: $lastAdDate');

      // 오늘 처음이거나, 다른 날이면 광고 표시
      if (lastAdDate == null || lastAdDate != todayString) {
        print('전면광고 표시 가능 (오늘 첫 실행)');
        return true;
      }

      print('전면광고 스킵 (오늘 이미 봤음)');
      return false;
    } catch (e) {
      print('광고 빈도 체크 에러: $e');
      return true; // 에러 시 광고 표시 (안전장치)
    }
  }

  // 📝 전면광고 봤다고 기록
  static Future<void> recordInterstitialAdShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayString = _formatDate(today);

      // 오늘 날짜로 기록
      await prefs.setString(_lastInterstitialAdKey, todayString);

      // 오늘 광고 카운트 증가
      final currentCount = await getTodayAdCount();
      await prefs.setInt(_adCountTodayKey, currentCount + 1);

      print('전면광고 시청 기록됨: $todayString');
    } catch (e) {
      print('광고 시청 기록 에러: $e');
    }
  }

  // 📊 오늘 본 광고 수 가져오기
  static Future<int> getTodayAdCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayString = _formatDate(today);
      final lastAdDate = prefs.getString(_lastInterstitialAdKey);

      // 오늘이 아니면 카운트 리셋
      if (lastAdDate != todayString) {
        await prefs.setInt(_adCountTodayKey, 0);
        return 0;
      }

      return prefs.getInt(_adCountTodayKey) ?? 0;
    } catch (e) {
      print('광고 카운트 가져오기 에러: $e');
      return 0;
    }
  }

  // 🗑️ 광고 기록 리셋 (테스트용)
  static Future<void> resetAdHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastInterstitialAdKey);
      await prefs.remove(_adCountTodayKey);
      print('광고 기록 리셋됨');
    } catch (e) {
      print('광고 기록 리셋 에러: $e');
    }
  }

  // 📅 날짜 포맷팅 (YYYY-MM-DD)
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 📈 광고 통계 가져오기 (관리자용)
  static Future<Map<String, dynamic>> getAdStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastAdDate = prefs.getString(_lastInterstitialAdKey);
      final todayCount = await getTodayAdCount();

      return {
        'lastInterstitialDate': lastAdDate,
        'todayAdCount': todayCount,
        'canShowToday': await shouldShowInterstitialAd(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }
}