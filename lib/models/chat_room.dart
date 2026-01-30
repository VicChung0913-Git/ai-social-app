import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String chatRoomId;
  final String name; // group name or empty for 1-1
  final String chatRoomPic; // group pic or empty for 1-1
  final List<String> members;
  final String lastMessage;
  final String lastMessageSender;
  final DateTime lastMessageTime;
  final bool isGroup;
  final String createdBy;
  final Map<String, int> unreadCount;

  const ChatRoom({
    required this.chatRoomId,
    required this.name,
    required this.chatRoomPic,
    required this.members,
    required this.lastMessage,
    required this.lastMessageSender,
    required this.lastMessageTime,
    required this.isGroup,
    required this.createdBy,
    required this.unreadCount,
  });

  static ChatRoom fromSnap(DocumentSnapshot snap) {
    var data = snap.data() as Map<String, dynamic>;

    return ChatRoom(
      chatRoomId: data['chatRoomId'] ?? '',
      name: data['name'] ?? '',
      chatRoomPic: data['chatRoomPic'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageSender: data['lastMessageSender'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      isGroup: data['isGroup'] ?? false,
      createdBy: data['createdBy'] ?? '',
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'chatRoomId': chatRoomId,
        'name': name,
        'chatRoomPic': chatRoomPic,
        'members': members,
        'lastMessage': lastMessage,
        'lastMessageSender': lastMessageSender,
        'lastMessageTime': Timestamp.fromDate(lastMessageTime),
        'isGroup': isGroup,
        'createdBy': createdBy,
        'unreadCount': unreadCount,
      };
}
