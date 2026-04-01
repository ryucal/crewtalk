import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/chat_image_cache.dart';

/// 풀스크린 갤러리용: [PhotoViewGalleryPageOptions.customChild] 안에 두고,
/// 디스크 캐시 우선 · 없으면 원본 다운로드 후 [FileImage] (웹은 [NetworkImage])
class ChatGalleryPhoto extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;

  const ChatGalleryPhoto({
    super.key,
    required this.url,
    this.width,
    this.height,
  });

  @override
  State<ChatGalleryPhoto> createState() => _ChatGalleryPhotoState();
}

class _ChatGalleryPhotoState extends State<ChatGalleryPhoto> {
  late final Future<ImageProvider<Object>> _future;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _future = Future<ImageProvider<Object>>.value(NetworkImage(widget.url));
    } else {
      _future = ChatImageCache.instance.ensureDownloaded(widget.url).then((f) => FileImage(f));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider<Object>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white.withValues(alpha: 0.7), size: 56),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2.5),
            ),
          );
        }
        return Center(
          child: Image(
            image: snap.data!,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      },
    );
  }
}
