import 'package:flutter/services.dart';

/// 카카오맵 공유 시 함께 붙는 문구를 제거하고 `https://kko.to/...` 형태만 남깁니다.
class KakaoKkoUrlExtractingFormatter extends TextInputFormatter {
  KakaoKkoUrlExtractingFormatter();

  static final _kko = RegExp(r'https?://kko\.to/[^\s]+', caseSensitive: false);

  static String? extractKkoUrl(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final m = _kko.firstMatch(t);
    if (m == null) return null;
    var url = m.group(0)!;
    url = url.replaceAll(RegExp(r'[.,;:!?\)\]\}>"\u200b]+$'), '');
    return url;
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;
    final extracted = extractKkoUrl(t);
    if (extracted == null || extracted == t) return newValue;
    return TextEditingValue(
      text: extracted,
      selection: TextSelection.collapsed(offset: extracted.length),
    );
  }
}
