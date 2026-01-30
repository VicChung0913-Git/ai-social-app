import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, system }

class Message {
  final String messageId;
  final String senderId;
  final String senderName;
  final String senderPhotoUrl;
  final String text;
  final String? imageUrl;
  final MessageType type;
  final DateTime timestamp;
  final List<String> readBy;

  const Message({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.senderPhotoUrl,
    required this.text,
    this.imageUrl,
    required this.type,
    required this.timestamp,
    required this.readBy,
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
      type: MessageType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: List<String>.from(data['readBy'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'text': text,
        'imageUrl': imageUrl,
        'type': type.name,
        'timestamp': Timestamp.fromDate(timestamp),
        'readBy': readBy,
      };
}
