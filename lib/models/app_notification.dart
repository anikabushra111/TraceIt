class AppNotification {
  final int id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic> data;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.readAt,
    required this.data,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m) {
    return AppNotification(
      id: (m['id'] as num).toInt(),
      type: (m['type'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      body: (m['body'] ?? '').toString(),
      createdAt: DateTime.parse(m['created_at'].toString()),
      readAt: m['read_at'] == null
          ? null
          : DateTime.parse(m['read_at'].toString()),
      data: (m['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  bool get isUnread => readAt == null;
}
