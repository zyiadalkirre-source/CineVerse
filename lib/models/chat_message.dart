class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime createdAt;

  const ChatMessage({
    required this.id, required this.text, required this.isUser, required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'text': text, 'is_user': isUser, 'created_at': createdAt.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: (json['id'] ?? '').toString(),
    text: (json['text'] ?? '').toString(),
    isUser: json['is_user'] == true,
    createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}
