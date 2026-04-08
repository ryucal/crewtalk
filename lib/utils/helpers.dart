import 'package:intl/intl.dart';

import '../models/user_model.dart';

/// Firestore 등에 저장할 발신자 식별자 (로그인 UID 우선)
String outgoingMessageUserId(UserModel u) =>
    u.firebaseUid ?? 'phone_${u.phone.replaceAll(RegExp(r'\D'), '')}';

String timeNow() {
  final now = DateTime.now();
  return DateFormat('HH:mm').format(now);
}

String dateToday() {
  final now = DateTime.now();
  return DateFormat('yyyy-MM-dd').format(now);
}

String formatDateLabel(String dateStr) {
  final d = DateTime.tryParse(dateStr);
  if (d == null) return dateStr;
  final days = ['일', '월', '화', '수', '목', '금', '토'];
  return '${d.year}년 ${d.month}월 ${d.day}일 ${days[d.weekday % 7]}요일';
}

String formatPhone(String v) {
  final num = v.replaceAll(RegExp(r'\D'), '');
  if (num.length <= 3) return num;
  if (num.length <= 7) return '${num.substring(0, 3)}-${num.substring(3)}';
  return '${num.substring(0, 3)}-${num.substring(3, 7)}-${num.substring(7, num.length.clamp(0, 11))}';
}

String formatCarNumber(String val) {
  final clean = val.replaceAll(RegExp(r'호$'), '').replaceAll(RegExp(r'\s+'), '');
  final match = RegExp(r'^([가-힣]{2})(\d{2})([가-힣]{1})(\d{4})').firstMatch(clean);
  if (match != null) {
    return '${match.group(1)} ${match.group(2)}${match.group(3)} ${match.group(4)}호';
  }
  return val;
}

bool isValidCarNumber(String val) {
  return RegExp(r'^[가-힣]{2}\s\d{2}[가-힣]{1}\s\d{4}호$').hasMatch(val.trim());
}

String shortDateTime(String? reportDateTime) {
  if (reportDateTime == null) return '';
  return reportDateTime.replaceFirstMapped(
    RegExp(r'^\d{4}-(\d{2})-(\d{2})'),
    (m) => '${int.parse(m.group(1)!)}-${int.parse(m.group(2)!)}',
  );
}

String todayLocalized() {
  final now = DateTime.now();
  final days = ['일', '월', '화', '수', '목', '금', '토'];
  return '${now.month}월 ${now.day}일 (${days[now.weekday % 7]})';
}
