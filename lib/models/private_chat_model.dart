import './chat_message_model.dart';

class PrivateChat {
  final String id;
  final String participant1Id;
  final String participant2Id;
  final String participant1Name;
  final String participant2Name;
  final String participant1Role;
  final String participant2Role;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final int unreadCount1;
  final int unreadCount2;
  final ChatMessage? lastMessage;
  final bool isActive;
  final String? linkedIssueId;
  final DateTime? closedAt;

  PrivateChat({
    required this.id,
    required this.participant1Id,
    required this.participant2Id,
    required this.participant1Name,
    required this.participant2Name,
    required this.participant1Role,
    required this.participant2Role,
    required this.createdAt,
    required this.lastMessageAt,
    this.unreadCount1 = 0,
    this.unreadCount2 = 0,
    this.lastMessage,
    this.isActive = true,
    this.linkedIssueId,
    this.closedAt,
  });

  factory PrivateChat.fromJson(Map<String, dynamic> json) => PrivateChat(
        id: json['id'] ?? '',
        participant1Id: json['participant1Id'] ?? '',
        participant2Id: json['participant2Id'] ?? '',
        participant1Name: json['participant1Name'] ?? '',
        participant2Name: json['participant2Name'] ?? '',
        participant1Role: json['participant1Role'] ?? '',
        participant2Role: json['participant2Role'] ?? '',
        createdAt: DateTime.parse(json['createdAt']),
        lastMessageAt: DateTime.parse(json['lastMessageAt']),
        unreadCount1: json['unreadCount1'] ?? 0,
        unreadCount2: json['unreadCount2'] ?? 0,
        lastMessage: json['lastMessage'] != null 
            ? ChatMessage.fromJson(json['lastMessage']) 
            : null,
        isActive: json['isActive'] ?? true,
        linkedIssueId: json['linkedIssueId'],
        closedAt: json['closedAt'] != null ? DateTime.parse(json['closedAt']) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'participant1Id': participant1Id,
        'participant2Id': participant2Id,
        'participant1Name': participant1Name,
        'participant2Name': participant2Name,
        'participant1Role': participant1Role,
        'participant2Role': participant2Role,
        'createdAt': createdAt.toIso8601String(),
        'lastMessageAt': lastMessageAt.toIso8601String(),
        'unreadCount1': unreadCount1,
        'unreadCount2': unreadCount2,
        'lastMessage': lastMessage?.toJson(),
        'isActive': isActive,
        'linkedIssueId': linkedIssueId,
        'closedAt': closedAt?.toIso8601String(),
      };

  String getOtherParticipantId(String currentUserId) {
    return participant1Id == currentUserId ? participant2Id : participant1Id;
  }

  String getOtherParticipantName(String currentUserId) {
    return participant1Id == currentUserId ? participant2Name : participant1Name;
  }

  String getOtherParticipantRole(String currentUserId) {
    return participant1Id == currentUserId ? participant2Role : participant1Role;
  }

  int getUnreadCount(String currentUserId) {
    return participant1Id == currentUserId ? unreadCount1 : unreadCount2;
  }

  PrivateChat copyWith({
    String? id,
    String? participant1Id,
    String? participant2Id,
    String? participant1Name,
    String? participant2Name,
    String? participant1Role,
    String? participant2Role,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    int? unreadCount1,
    int? unreadCount2,
    ChatMessage? lastMessage,
    bool? isActive,
    String? linkedIssueId,
    DateTime? closedAt,
  }) {
    return PrivateChat(
      id: id ?? this.id,
      participant1Id: participant1Id ?? this.participant1Id,
      participant2Id: participant2Id ?? this.participant2Id,
      participant1Name: participant1Name ?? this.participant1Name,
      participant2Name: participant2Name ?? this.participant2Name,
      participant1Role: participant1Role ?? this.participant1Role,
      participant2Role: participant2Role ?? this.participant2Role,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount1: unreadCount1 ?? this.unreadCount1,
      unreadCount2: unreadCount2 ?? this.unreadCount2,
      lastMessage: lastMessage ?? this.lastMessage,
      isActive: isActive ?? this.isActive,
      linkedIssueId: linkedIssueId ?? this.linkedIssueId,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}
