/// 한국 표준시(UTC+9) 기준 달력 날짜 키 `YYYY-MM-DD`.
/// 기기 타임존과 무관하게 동일한 '한국 날짜'를 쓰기 위해 사용합니다.
String kstDateKeyNow() {
  final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
  return _ymdKey(kst.year, kst.month, kst.day);
}

String kstDateKeyFromYmd(int y, int m, int d) => _ymdKey(y, m, d);

String dateKeyFromDateTimeDateOnly(DateTime d) => _ymdKey(d.year, d.month, d.day);

/// 한국 달력의 '오늘'에 해당하는 [DateTime] (시간 0, 로컬 생성자만 사용 — 날짜 선택기 초기값용)
DateTime kstTodayDateOnly() {
  final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
  return DateTime(kst.year, kst.month, kst.day);
}

String _ymdKey(int y, int m, int d) =>
    '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
