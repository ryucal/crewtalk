import 'package:flutter_riverpod/flutter_riverpod.dart';

/// GPS 추적 활성화 여부 (전역 상태)
final gpsActiveProvider = StateProvider<bool>((ref) => false);

/// 현재 운행 정보 요약 (알림 표시 등에 활용)
class GpsRunInfo {
  final String name;
  final String car;
  final String route;
  final String subRoute;
  final int count;

  const GpsRunInfo({
    required this.name,
    required this.car,
    required this.route,
    required this.subRoute,
    required this.count,
  });
}

/// 현재 운행 메타데이터 Provider
final gpsRunInfoProvider = StateProvider<GpsRunInfo?>((ref) => null);
