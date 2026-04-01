import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 채팅(등) 네트워크 이미지 디스크 캐시 — 재실행 후에도 URL 동일 시 로컬 파일 사용
class ChatImageCache {
  ChatImageCache._();
  static final ChatImageCache instance = ChatImageCache._();

  /// 이 크기(bytes) 초과 시 목록에서는 저해상 미리보기만 두고, 탭(또는 갤러리) 시 원본 다운로드
  static const int largeImageThresholdBytes = 450 * 1024;

  static final StreamController<String> _updated = StreamController<String>.broadcast();
  static Stream<String> get cacheUpdated => _updated.stream;

  Directory? _dir;

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    _dir = Directory('${base.path}/chat_image_cache');
    if (!await _dir!.exists()) {
      await _dir!.create(recursive: true);
    }
    return _dir!;
  }

  String _fileNameForUrl(String url) => md5.convert(utf8.encode(url.trim())).toString();

  /// 캐시에 있으면 파일, 없으면 null
  Future<File?> fileIfCached(String url) async {
    if (!_isHttp(url) || kIsWeb) return null;
    final dir = await _ensureDir();
    final f = File('${dir.path}/${_fileNameForUrl(url)}');
    if (await f.exists() && await f.length() > 0) return f;
    return null;
  }

  /// 원격 GET 후 디스크에 저장 (이미 있으면 스킵)
  Future<File> ensureDownloaded(String url) async {
    if (!_isHttp(url)) throw ArgumentError('not http(s) url');
    if (kIsWeb) {
      throw UnsupportedError('ChatImageCache disk only on mobile/desktop');
    }
    final hit = await fileIfCached(url);
    if (hit != null) return hit;

    final dir = await _ensureDir();
    final file = File('${dir.path}/${_fileNameForUrl(url)}');
    final uri = Uri.parse(url);
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw HttpException('HTTP ${resp.statusCode}', uri: uri);
      }
      final bytes = await consolidateHttpClientResponseBytes(resp);
      if (bytes.isEmpty) throw HttpException('empty body', uri: uri);
      await file.writeAsBytes(bytes, flush: true);
      _updated.add(url);
      return file;
    } finally {
      client.close(force: true);
    }
  }

  /// HEAD로 크기 추정 (실패 시 null → UI에서 ‘큰 이미지’ 쪽으로 안전하게 처리)
  Future<int?> fetchContentLength(String url) async {
    if (!_isHttp(url) || kIsWeb) return null;
    final client = HttpClient();
    try {
      final req = await client.headUrl(Uri.parse(url));
      final resp = await req.close();
      await resp.drain();
      final n = resp.contentLength;
      if (n >= 0) return n;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
    return null;
  }

  bool _isHttp(String s) {
    final t = s.trim();
    return t.startsWith('http://') || t.startsWith('https://');
  }
}
