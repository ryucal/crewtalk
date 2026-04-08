/// 전역 배차표 슬롯 노출 (모든 채팅방 공통). Firestore `config/timetable_visibility`.
class TimetableDaySlots {
  /// 채팅 헤더 [배차표1] 버튼 노출 여부 (이미지가 있을 때)
  final bool slot1Visible;
  final bool slot2Visible;

  const TimetableDaySlots({
    required this.slot1Visible,
    required this.slot2Visible,
  });

  Map<String, dynamic> toMap() => {
        'slot1': slot1Visible,
        'slot2': slot2Visible,
      };

  static TimetableDaySlots fromMap(Map<String, dynamic> m) {
    return TimetableDaySlots(
      slot1Visible: m['slot1'] as bool? ?? true,
      slot2Visible: m['slot2'] as bool? ?? true,
    );
  }
}

/// `byDate` 맵: 키 `YYYY-MM-DD` (KST), 값 슬롯별 노출.
/// 키가 없는 날짜는 규칙 없음 → 이미지 있으면 둘 다 노출(기존 동작).
typedef GlobalTimetableByDate = Map<String, TimetableDaySlots>;

GlobalTimetableByDate globalTimetableFromFirestore(Map<String, dynamic>? data) {
  if (data == null) return {};
  final raw = data['byDate'];
  if (raw is! Map) return {};
  final out = <String, TimetableDaySlots>{};
  for (final e in raw.entries) {
    final key = e.key.toString();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) continue;
    final v = e.value;
    if (v is! Map) continue;
    out[key] = TimetableDaySlots.fromMap(Map<String, dynamic>.from(v));
  }
  return out;
}

/// KST 날짜 키에 대한 규칙이 없으면 기존 동작(이미지 있으면 노출).
bool globalTimetableHeaderSlotVisible({
  required GlobalTimetableByDate byDate,
  required String kstTodayKey,
  required int slot,
  required bool roomHasTimetableImages,
}) {
  if (!roomHasTimetableImages) return false;
  final rule = byDate[kstTodayKey];
  if (rule == null) return true;
  return slot == 1 ? rule.slot1Visible : rule.slot2Visible;
}
