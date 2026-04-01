import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/chat_image_cache.dart';
import 'timetable_image.dart';

enum _ChatNetPhase { checking, cached, previewOnly, downloading, error }

/// 네트워크 이미지: 디스크 캐시 우선. 큰 파일은 저해상 미리보기만 — 원본은 부모 onTap(갤러리 등)에서 [ChatImageCache.ensureDownloaded] 로 저장.
class ChatNetworkImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  /// true면 원본 전체 다운로드 후 표시(배차표 확대·갤러리용). false면 큰 파일은 저해상 미리보기.
  final bool fullQuality;

  const ChatNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fullQuality = false,
  });

  @override
  State<ChatNetworkImage> createState() => _ChatNetworkImageState();
}

class _ChatNetworkImageState extends State<ChatNetworkImage> {
  _ChatNetPhase _phase = _ChatNetPhase.checking;
  File? _cachedFile;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ChatImageCache.cacheUpdated.listen((u) {
      if (u == widget.url.trim()) _reloadFromCache();
    });
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant ChatNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.fullQuality != widget.fullQuality) {
      _phase = _ChatNetPhase.checking;
      _cachedFile = null;
      _bootstrap();
    }
  }

  Future<void> _reloadFromCache() async {
    final f = await ChatImageCache.instance.fileIfCached(widget.url);
    if (!mounted) return;
    if (f != null) {
      setState(() {
        _cachedFile = f;
        _phase = _ChatNetPhase.cached;
      });
    }
  }

  Future<void> _bootstrap() async {
    if (kIsWeb) {
      setState(() => _phase = _ChatNetPhase.cached);
      return;
    }
    final u = widget.url.trim();

    if (widget.fullQuality) {
      setState(() => _phase = _ChatNetPhase.downloading);
      try {
        final f = await ChatImageCache.instance.ensureDownloaded(u);
        if (!mounted) return;
        setState(() {
          _cachedFile = f;
          _phase = _ChatNetPhase.cached;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _phase = _ChatNetPhase.error);
      }
      return;
    }

    final hit = await ChatImageCache.instance.fileIfCached(u);
    if (!mounted) return;
    if (hit != null) {
      setState(() {
        _cachedFile = hit;
        _phase = _ChatNetPhase.cached;
      });
      return;
    }

    final len = await ChatImageCache.instance.fetchContentLength(u);
    if (!mounted) return;
    final big = len == null || len > ChatImageCache.largeImageThresholdBytes;

    if (!big) {
      setState(() => _phase = _ChatNetPhase.downloading);
      try {
        final f = await ChatImageCache.instance.ensureDownloaded(u);
        if (!mounted) return;
        setState(() {
          _cachedFile = f;
          _phase = _ChatNetPhase.cached;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _phase = _ChatNetPhase.error);
      }
      return;
    }

    setState(() => _phase = _ChatNetPhase.previewOnly);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  int? _decodeWidth(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final w = widget.width;
    if (w == null) return (360 * dpr).round();
    return (w.clamp(80, 420) * dpr).round();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        widget.url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => TimetableImage.imageErrorWidget,
      );
    }

    switch (_phase) {
      case _ChatNetPhase.checking:
      case _ChatNetPhase.downloading:
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        );
      case _ChatNetPhase.error:
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: TimetableImage.imageErrorWidget,
        );
      case _ChatNetPhase.cached:
        final f = _cachedFile;
        if (f == null) {
          return TimetableImage.imageErrorWidget;
        }
        return Image.file(
          f,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          filterQuality: widget.fullQuality ? FilterQuality.high : FilterQuality.medium,
          errorBuilder: (_, __, ___) => TimetableImage.imageErrorWidget,
        );
      case _ChatNetPhase.previewOnly:
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                widget.url,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
                cacheWidth: _decodeWidth(context),
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: const Color(0xFFE8E8E8),
                  child: Icon(Icons.image_outlined, color: Colors.grey.shade500, size: 40),
                ),
              ),
              Positioned(
                left: 4,
                right: 4,
                bottom: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.touch_app_outlined, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '탭하여 크게 보기 · 저장',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}
