import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, system, sticker }

class Message {
  final String messageId;
  final String senderId;
  final String senderName;
  final String senderPhotoUrl;
  final String text;
  final String? imageUrl;
  final String? stickerEmoji;
  final String? stickerPackId;
  final MessageType type;
  final DateTime timestamp;
  final List<String> readBy;
  final bool isRecalled;
  final DateTime? recalledAt;

  const Message({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.senderPhotoUrl,
    required this.text,
    this.imageUrl,
    this.stickerEmoji,
    this.stickerPackId,
    required this.type,
    required this.timestamp,
    required this.readBy,
    this.isRecalled = false,
    this.recalledAt,
  });

  static Message fromSnap(DocumentSnapshot snap) {
    var data = snap.data() as Map<String, dynamic>;

    return Message(
      messageId: data['messageId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderPhotoUrl: data['senderPhotoUrl'] ?? '',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      stickerEmoji: data['stickerEmoji'],
      stickerPackId: data['stickerPackId'],
      type: MessageType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: List<String>.from(data['readBy'] ?? []),
      isRecalled: data['isRecalled'] ?? false,
      recalledAt: (data['recalledAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'text': text,
        'imageUrl': imageUrl,
        'stickerEmoji': stickerEmoji,
        'stickerPackId': stickerPackId,
        'type': type.name,
        'timestamp': Timestamp.fromDate(timestamp),
        'readBy': readBy,
        'isRecalled': isRecalled,
        'recalledAt':
            recalledAt != null ? Timestamp.fromDate(recalledAt!) : null,
      };

  // Check if message can be recalled (within 15 minutes)
  bool get canRecall {
    return DateTime.now().difference(timestamp).inMinutes < 15;
  }
}
