class AppNotification {
  final int id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  final Map<String, dynamic> data;
  String? get postId => data['post_id']?.toString();
  String? get claimId => data['claim_id']?.toString();

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.readAt,
    required this.data,
  });

  bool get isUnread => readAt == null;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: (map['id'] as num).toInt(),
      type: (map['type'] ?? 'unknown').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      createdAt: DateTime.parse(map['created_at'].toString()),
      readAt: map['read_at'] != null
          ? DateTime.parse(map['read_at'].toString())
          : null,
      data:
          (map['data'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }
}
