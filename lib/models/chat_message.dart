import 'chat_attachment.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.attachments = const [],
    this.replyToId,
    this.replyExcerpt,
  });

  final List<ChatAttachment> attachments;
  final int? replyToId;
  final String? replyExcerpt;
  final int id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final attachments = (json['attachments'] as List<dynamic>? ?? [])
        .map((e) => ChatAttachment.fromJson(e as Map<String, dynamic>))
        .toList();
    if (attachments.length > 3) throw const FormatException('Too many images');
    return ChatMessage(
      attachments: attachments,
      replyToId: json['replyToId'] as int?,
      replyExcerpt: json['replyExcerpt'] as String?,
      id: json['id'] as int,
      role: ChatRole.values.byName(json['role'] as String),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'replyToId': replyToId,
    'replyExcerpt': replyExcerpt,
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'id': id,
    'role': role.name,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };
}
