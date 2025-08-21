class ChatMessage {
  final String id;
  final String issueId;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.issueId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] ?? '',
        issueId: json['issueId'] ?? '',
        senderId: json['senderId'] ?? '',
        content: json['content'] ?? '',
        type: MessageType.values.firstWhere((e) => e.toString() == 'MessageType.${json['type']}'),
        timestamp: DateTime.parse(json['timestamp']),
        isRead: json['isRead'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'issueId': issueId,
        'senderId': senderId,
        'content': content,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };
}

enum MessageType {
  text,
  image,
  file,
  system,
}
