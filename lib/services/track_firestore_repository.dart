import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_repository.dart';

/// GPS 운행 기록 — `tracks/{trackId}` + 서브컬렉션 `points/{autoId}`
class TrackFirestoreRepository {
  TrackFirestoreRepository._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static bool get _ok => AuthRepository.firebaseAvailable;

  /// 운행 시작 문서 생성. 실패 시 null.
  static Future<String?> createActiveTrack({
    required String ownerUid,
    required String name,
    required String car,
    required String company,
    required String driverId,
    required int roomId,
    required String route,
    required String subRoute,
    required int count,
  }) async {
    if (!_ok) return null;
    try {
      final trackId = '${ownerUid}_${DateTime.now().millisecondsSinceEpoch}';
      await _db.collection('tracks').doc(trackId).set({
        'ownerUid': ownerUid,
        'name': name,
        'car': car,
        'company': company,
        'driverId': driverId,
        'roomId': roomId,
        'route': route,
        'subRoute': subRoute,
        'count': count,
        'startedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
      return trackId;
    } catch (e, st) {
      if (kDebugMode) debugPrint('TrackFirestoreRepository.createActiveTrack: $e\n$st');
      return null;
    }
  }

  /// 포인트 배치 쓰기 (한 번에 최대 450건). 실패 시 false (호출측에서 버퍼 복원 등).
  static Future<bool> appendPoints(String trackId, List<Map<String, dynamic>> points) async {
    if (!_ok || points.isEmpty) return true;
    try {
      final trackRef = _db.collection('tracks').doc(trackId);
      var batch = _db.batch();
      var n = 0;
      double safeD(dynamic v, [double fallback = 0]) {
        if (v is num) {
          final d = v.toDouble();
          return d.isFinite ? d : fallback;
        }
        return fallback;
      }

      for (final p in points) {
        final docRef = trackRef.collection('points').doc();
        final ts = p['ts'];
        final pointData = <String, dynamic>{
          'lat': safeD(p['lat']),
          'lng': safeD(p['lng']),
          'accuracy': safeD(p['accuracy']),
          'heading': safeD(p['heading']),
          'speed': safeD(p['speed']),
          'ts': ts is int ? ts : int.tryParse('$ts') ?? DateTime.now().millisecondsSinceEpoch,
        };
        // 버퍼에 들어 있는 노선·세부노선·인원 등 (콘솔/분석용)
        final sr = p['subRoute'];
        if (sr != null && '$sr'.trim().isNotEmpty) {
          pointData['subRoute'] = '$sr'.trim();
        }
        final rt = p['route'];
        if (rt != null && '$rt'.trim().isNotEmpty) {
          pointData['route'] = '$rt'.trim();
        }
        final nm = p['name'];
        if (nm != null && '$nm'.trim().isNotEmpty) {
          pointData['name'] = '$nm'.trim();
        }
        final cnt = p['count'];
        if (cnt is int) {
          pointData['count'] = cnt;
        } else if (cnt is num) {
          pointData['count'] = cnt.toInt();
        }
        batch.set(docRef, pointData);
        n++;
        if (n >= 450) {
          await batch.commit();
          batch = _db.batch();
          n = 0;
        }
      }
      if (n > 0) await batch.commit();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('TrackFirestoreRepository.appendPoints: $e\n$st');
      return false;
    }
  }

  static Future<void> finalizeTrack(
    String trackId, {
    required String stopReason,
    int pointsCollected = 0,
    int pointsFlushed = 0,
    int flushErrors = 0,
  }) async {
    if (!_ok) return;
    try {
      await _db.collection('tracks').doc(trackId).update({
        'isActive': false,
        'endedAt': FieldValue.serverTimestamp(),
        'stopReason': stopReason,
        'pointsCollected': pointsCollected,
        'pointsFlushed': pointsFlushed,
        'flushErrors': flushErrors,
      });
    } catch (e, st) {
      if (kDebugMode) debugPrint('TrackFirestoreRepository.finalizeTrack: $e\n$st');
    }
  }
}
