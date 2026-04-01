/// 채팅방 사이드 메뉴 — 카카오맵 공유 URL + 표시 라벨 (방당 여러 개)
class RoomKakaoNavLink {
  final String id;
  final String label;
  final String kakaoShareUrl;

  const RoomKakaoNavLink({
    required this.id,
    required this.label,
    required this.kakaoShareUrl,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'kakaoShareUrl': kakaoShareUrl,
      };

  static RoomKakaoNavLink? tryFromMap(Map<String, dynamic> m) {
    final id = (m['id'] as String?)?.trim() ?? '';
    final label = (m['label'] as String?)?.trim() ?? '';
    final url = (m['kakaoShareUrl'] as String?)?.trim() ??
        (m['url'] as String?)?.trim() ??
        '';
    if (id.isEmpty || label.isEmpty || url.isEmpty) return null;
    return RoomKakaoNavLink(id: id, label: label, kakaoShareUrl: url);
  }

  RoomKakaoNavLink copyWith({
    String? id,
    String? label,
    String? kakaoShareUrl,
  }) {
    return RoomKakaoNavLink(
      id: id ?? this.id,
      label: label ?? this.label,
      kakaoShareUrl: kakaoShareUrl ?? this.kakaoShareUrl,
    );
  }
}
