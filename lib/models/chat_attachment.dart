class ChatAttachment {
  const ChatAttachment({required this.id, required this.size});
  final String id;
  final int size;
  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final size = json['size'] as int;
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id) ||
        size <= 0 ||
        size > 1024 * 1024) {
      throw const FormatException('Invalid image attachment');
    }
    return ChatAttachment(id: id, size: size);
  }
  Map<String, dynamic> toJson() => {'id': id, 'size': size};
}
