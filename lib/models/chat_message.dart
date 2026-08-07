enum ChatRole { user, assistant }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  final int id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      role: ChatRole.values.byName(json['role'] as String),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };
}
