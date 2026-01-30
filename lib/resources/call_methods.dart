import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instagram_clone_flutter/models/call.dart';
import 'package:instagram_clone_flutter/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class CallMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Agora App ID - replace with your actual App ID from console.agora.io
  static const String agoraAppId = 'YOUR_AGORA_APP_ID';

  // Initiate a call
  Future<Call> initiateCall({
    required String callerId,
    required String callerName,
    required String callerPhotoUrl,
    required String receiverId,
    required String receiverName,
    required String receiverPhotoUrl,
    required String chatRoomId,
    required CallType type,
  }) async {
    String callId = const Uuid().v1();
    String channelId = 'call_$callId';

    Call call = Call(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerPhotoUrl: callerPhotoUrl,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverPhotoUrl: receiverPhotoUrl,
      chatRoomId: chatRoomId,
      type: type,
      status: CallStatus.ringing,
      channelId: channelId,
      startTime: DateTime.now(),
      isGroupCall: false,
      participants: [callerId, receiverId],
    );

    // Store call in Firestore
    await _firestore.collection('calls').doc(callId).set(call.toJson());

    // Store active call reference for both users
    await _firestore.collection('users').doc(callerId).update({
      'activeCallId': callId,
    });
    await _firestore.collection('users').doc(receiverId).update({
      'activeCallId': callId,
    });

    // Send notification to receiver
    NotificationService().showCallNotification(
      callerName: callerName,
      callId: callId,
      isVideo: type == CallType.video,
    );

    return call;
  }

  // Answer call
  Future<void> answerCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': CallStatus.active.name,
    });
  }

  // End call
  Future<void> endCall(String callId) async {
    DocumentSnapshot doc =
        await _firestore.collection('calls').doc(callId).get();

    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.ended.name,
        'endTime': Timestamp.fromDate(DateTime.now()),
      });

      // Clear active call for both users
      String callerId = data['callerId'] ?? '';
      String receiverId = data['receiverId'] ?? '';

      if (callerId.isNotEmpty) {
        await _firestore.collection('users').doc(callerId).update({
          'activeCallId': FieldValue.delete(),
        });
      }
      if (receiverId.isNotEmpty) {
        await _firestore.collection('users').doc(receiverId).update({
          'activeCallId': FieldValue.delete(),
        });
      }

      // Cancel notification
      NotificationService().cancelCallNotification(callId);
    }
  }

  // Decline call
  Future<void> declineCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': CallStatus.declined.name,
      'endTime': Timestamp.fromDate(DateTime.now()),
    });

    DocumentSnapshot doc =
        await _firestore.collection('calls').doc(callId).get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String callerId = data['callerId'] ?? '';
      String receiverId = data['receiverId'] ?? '';

      if (callerId.isNotEmpty) {
        await _firestore.collection('users').doc(callerId).update({
          'activeCallId': FieldValue.delete(),
        });
      }
      if (receiverId.isNotEmpty) {
        await _firestore.collection('users').doc(receiverId).update({
          'activeCallId': FieldValue.delete(),
        });
      }
    }

    NotificationService().cancelCallNotification(callId);
  }

  // Listen for incoming calls
  Stream<DocumentSnapshot> listenForCalls(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // Get call document stream
  Stream<DocumentSnapshot> getCallStream(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots();
  }

  // Get call details
  Future<Call?> getCall(String callId) async {
    DocumentSnapshot doc =
        await _firestore.collection('calls').doc(callId).get();
    if (doc.exists) {
      return Call.fromSnap(doc);
    }
    return null;
  }

  // Get call history for a chat room
  Stream<QuerySnapshot> getCallHistory(String chatRoomId) {
    return _firestore
        .collection('calls')
        .where('chatRoomId', isEqualTo: chatRoomId)
        .orderBy('startTime', descending: true)
        .limit(20)
        .snapshots();
  }
}
