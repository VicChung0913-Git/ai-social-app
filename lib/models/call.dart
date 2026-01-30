import 'package:cloud_firestore/cloud_firestore.dart';

enum CallStatus { ringing, active, ended, missed, declined }

enum CallType { voice, video }

class Call {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerPhotoUrl;
  final String receiverId;
  final String receiverName;
  final String receiverPhotoUrl;
  final String chatRoomId;
  final CallType type;
  final CallStatus status;
  final String channelId;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isGroupCall;
  final List<String> participants;

  const Call({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerPhotoUrl,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPhotoUrl,
    required this.chatRoomId,
    required this.type,
    required this.status,
    required this.channelId,
    required this.startTime,
    this.endTime,
    required this.isGroupCall,
    required this.participants,
  });

  static Call fromSnap(DocumentSnapshot snap) {
    var data = snap.data() as Map<String, dynamic>;
    return Call(
      callId: data['callId'] ?? '',
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? '',
      callerPhotoUrl: data['callerPhotoUrl'] ?? '',
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? '',
      receiverPhotoUrl: data['receiverPhotoUrl'] ?? '',
      chatRoomId: data['chatRoomId'] ?? '',
      type: CallType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'voice'),
        orElse: () => CallType.voice,
      ),
      status: CallStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'ringing'),
        orElse: () => CallStatus.ringing,
      ),
      channelId: data['channelId'] ?? '',
      startTime:
          (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      isGroupCall: data['isGroupCall'] ?? false,
      participants: List<String>.from(data['participants'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callerPhotoUrl': callerPhotoUrl,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'receiverPhotoUrl': receiverPhotoUrl,
        'chatRoomId': chatRoomId,
        'type': type.name,
        'status': status.name,
        'channelId': channelId,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
        'isGroupCall': isGroupCall,
        'participants': participants,
      };
}
