/// 전화번호 → Firebase Auth용 가짜 이메일 (`010...@crew.co.kr`)
class PhoneAuthUtils {
  PhoneAuthUtils._();

  static final RegExp _nonDigit = RegExp(r'\D');

  static String digitsOnly(String input) => input.replaceAll(_nonDigit, '');

  /// 10자리 이상이면 유효한 것으로 간주 (010xxxxxxxx)
  static bool isValidKoreanMobileDigits(String digits) => digits.length >= 10 && digits.length <= 11;

  static String syntheticEmailFromDigits(String digits) {
    if (digits.isEmpty) return '';
    return '$digits@crew.co.kr';
  }

  /// 표시용 010-1234-5678
  static String formatDisplay(String digits) {
    final d = digitsOnly(digits);
    if (d.length <= 3) return d;
    if (d.length <= 7) return '${d.substring(0, 3)}-${d.substring(3)}';
    final end = d.length.clamp(0, 11);
    return '${d.substring(0, 3)}-${d.substring(3, 7)}-${d.substring(7, end)}';
  }
}
