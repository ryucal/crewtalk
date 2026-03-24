import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' show File;

/// 배차 시간표 등 로컬 경로 / 네트워크 / data URL 이미지 표시
class TimetableImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;

  const TimetableImage({
    super.key,
    required this.source,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
  });

  static Widget _error() => const Icon(Icons.broken_image_outlined, color: Color(0xFFBBBBBB), size: 32);

  @override
  Widget build(BuildContext context) {
    final s = source.trim();
    if (s.isEmpty) {
      return _error();
    }

    if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('blob:')) {
      return Image.network(
        s,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _error(),
      );
    }

    if (s.startsWith('data:image')) {
      final i = s.indexOf(',');
      if (i > 0) {
        try {
          final bytes = base64Decode(s.substring(i + 1));
          return Image.memory(bytes, width: width, height: height, fit: fit);
        } catch (_) {}
      }
    }

    if (!kIsWeb) {
      try {
        return Image.file(
          File(s),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _error(),
        );
      } catch (_) {}
    }

    return _error();
  }
}
