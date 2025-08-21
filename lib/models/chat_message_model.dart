class ChatMessage {
  final String id;
  final String? issueId;
  final String? privateChatId;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    this.issueId,
    this.privateChatId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] ?? '',
        issueId: json['issueId'],
        privateChatId: json['privateChatId'],
        senderId: json['senderId'] ?? '',
        content: json['content'] ?? '',
        type: MessageType.values.firstWhere((e) => e.toString() == 'MessageType.${json['type']}'),
        timestamp: DateTime.parse(json['timestamp']),
        isRead: json['isRead'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (issueId != null) 'issueId': issueId,
        if (privateChatId != null) 'privateChatId': privateChatId,
        'senderId': senderId,
        'content': content,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  bool get isPrivateChat => privateChatId != null;
  bool get isIssueChat => issueId != null;
}

enum MessageType {
  text,
  image,
  file,
  system,
}
