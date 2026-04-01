class CalendarItem {
  final String id;
  final String date;
  final String kind;
  final String? startTime;
  final String? endDate;
  final String? color;
  final String title;
  /// 일정을 등록한 사용자 표시 이름 (Firestore `createdByName`)
  final String? createdByName;

  const CalendarItem({
    required this.id,
    required this.date,
    required this.kind,
    this.startTime,
    this.endDate,
    this.color,
    required this.title,
    this.createdByName,
  });

  bool get isTodo => kind == 'todo';
  bool get isRangeSchedule => endDate != null && endDate!.isNotEmpty && endDate != date;

  static String _coerceStr(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    return v.toString();
  }

  /// 웹·앱 공통: 작성자 표시명 (필드명이 프로젝트마다 다를 수 있음)
  static String? _coerceCreatorName(Map<String, dynamic> m) {
    const keys = [
      'createdByName',
      'authorName',
      'author',
      'writer',
      'writerName',
      'createdBy',
      'registrantName',
    ];
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  factory CalendarItem.fromMap(Map<String, dynamic> m) {
    String? optStr(dynamic v) {
      if (v == null) return null;
      final s = v is String ? v : v.toString();
      return s.isEmpty ? null : s;
    }

    final kindRaw = _coerceStr(m['kind']);
    return CalendarItem(
      id: _coerceStr(m['id']),
      date: _coerceStr(m['date']),
      kind: kindRaw.isEmpty ? 'schedule' : kindRaw,
      startTime: optStr(m['startTime']),
      endDate: optStr(m['endDate']),
      color: optStr(m['color']),
      title: _coerceStr(m['title']),
      createdByName: _coerceCreatorName(m),
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'id': id,
      'date': date,
      'kind': kind,
      'title': title,
    };
    if (startTime != null && startTime!.isNotEmpty) m['startTime'] = startTime;
    if (endDate != null && endDate!.isNotEmpty) m['endDate'] = endDate;
    if (color != null && color!.isNotEmpty) m['color'] = color;
    if (createdByName != null && createdByName!.isNotEmpty) {
      m['createdByName'] = createdByName;
    }
    return m;
  }

  DateTime? get dateTime {
    final parts = date.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final mo = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || mo == null || d == null) return null;
    if (startTime != null && startTime!.contains(':')) {
      final tp = startTime!.split(':');
      final h = int.tryParse(tp[0]) ?? 0;
      final mi = int.tryParse(tp[1]) ?? 0;
      return DateTime(y, mo, d, h, mi);
    }
    return DateTime(y, mo, d);
  }
}
