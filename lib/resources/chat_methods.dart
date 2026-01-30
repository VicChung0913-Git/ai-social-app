import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:instagram_clone_flutter/models/chat_room.dart';
import 'package:instagram_clone_flutter/models/message.dart';
import 'package:instagram_clone_flutter/resources/storage_methods.dart';
import 'package:uuid/uuid.dart';

class ChatMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a 1-1 chat room (or return existing one)
  Future<String> getOrCreateDirectChat({
    required String currentUid,
    required String otherUid,
  }) async {
    String chatRoomId = _generateDirectChatId(currentUid, otherUid);

    DocumentSnapshot doc =
        await _firestore.collection('chatRooms').doc(chatRoomId).get();

    if (!doc.exists) {
      ChatRoom chatRoom = ChatRoom(
        chatRoomId: chatRoomId,
        name: '',
        chatRoomPic: '',
        members: [currentUid, otherUid],
        lastMessage: '',
        lastMessageSender: '',
        lastMessageTime: DateTime.now(),
        isGroup: false,
        createdBy: currentUid,
        unreadCount: {currentUid: 0, otherUid: 0},
      );

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .set(chatRoom.toJson());
    }

    return chatRoomId;
  }

  // Create a group chat room
  Future<String> createGroupChat({
    required String name,
    required String createdBy,
    required List<String> members,
    Uint8List? groupPic,
  }) async {
    String chatRoomId = const Uuid().v1();
    String chatRoomPicUrl = '';

    if (groupPic != null) {
      chatRoomPicUrl = await StorageMethods()
          .uploadImageToStorage('chatRoomPics', groupPic, false);
    }

    Map<String, int> unreadCount = {};
    for (String uid in members) {
      unreadCount[uid] = 0;
    }

    ChatRoom chatRoom = ChatRoom(
      chatRoomId: chatRoomId,
      name: name,
      chatRoomPic: chatRoomPicUrl,
      members: members,
      lastMessage: '$name group created',
      lastMessageSender: createdBy,
      lastMessageTime: DateTime.now(),
      isGroup: true,
      createdBy: createdBy,
      unreadCount: unreadCount,
    );

    await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .set(chatRoom.toJson());

    await sendMessage(
      chatRoomId: chatRoomId,
      senderId: createdBy,
      senderName: 'System',
      senderPhotoUrl: '',
      text: 'Group "$name" created',
      type: MessageType.system,
    );

    return chatRoomId;
  }

  // Send a text message
  Future<String> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String senderName,
    required String senderPhotoUrl,
    required String text,
    MessageType type = MessageType.text,
  }) async {
    try {
      String messageId = const Uuid().v1();

      Message message = Message(
        messageId: messageId,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        text: text,
        type: type,
        timestamp: DateTime.now(),
        readBy: [senderId],
      );

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set(message.toJson());

      // Update chat room with last message info
      await _updateChatRoomLastMessage(
        chatRoomId: chatRoomId,
        senderId: senderId,
        lastMessage: type == MessageType.image ? '📷 Photo' : text,
      );

      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  // Send an image message
  Future<String> sendImageMessage({
    required String chatRoomId,
    required String senderId,
    required String senderName,
    required String senderPhotoUrl,
    required Uint8List imageFile,
  }) async {
    try {
      String imageUrl = await StorageMethods()
          .uploadImageToStorage('chatImages', imageFile, true);

      String messageId = const Uuid().v1();

      Message message = Message(
        messageId: messageId,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        text: '',
        imageUrl: imageUrl,
        type: MessageType.image,
        timestamp: DateTime.now(),
        readBy: [senderId],
      );

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set(message.toJson());

      await _updateChatRoomLastMessage(
        chatRoomId: chatRoomId,
        senderId: senderId,
        lastMessage: '📷 Photo',
      );

      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  // Send a sticker message
  Future<String> sendStickerMessage({
    required String chatRoomId,
    required String senderId,
    required String senderName,
    required String senderPhotoUrl,
    required String stickerEmoji,
    required String stickerPackId,
  }) async {
    try {
      String messageId = const Uuid().v1();

      Message message = Message(
        messageId: messageId,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        text: '',
        stickerEmoji: stickerEmoji,
        stickerPackId: stickerPackId,
        type: MessageType.sticker,
        timestamp: DateTime.now(),
        readBy: [senderId],
      );

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set(message.toJson());

      await _updateChatRoomLastMessage(
        chatRoomId: chatRoomId,
        senderId: senderId,
        lastMessage: '[Sticker] $stickerEmoji',
      );

      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  // Recall a message (within 15 minutes)
  Future<String> recallMessage({
    required String chatRoomId,
    required String messageId,
    required String senderId,
  }) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!doc.exists) return 'Message not found';

      Message message = Message.fromSnap(doc);

      // Only sender can recall
      if (message.senderId != senderId) {
        return 'You can only recall your own messages';
      }

      // Check 15-minute window
      if (!message.canRecall) {
        return 'Message can only be recalled within 15 minutes';
      }

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isRecalled': true,
        'recalledAt': Timestamp.fromDate(DateTime.now()),
        'text': '',
        'imageUrl': null,
        'stickerEmoji': null,
      });

      // Update last message if this was the last message
      DocumentSnapshot chatRoomDoc =
          await _firestore.collection('chatRooms').doc(chatRoomId).get();
      Map<String, dynamic> chatData =
          chatRoomDoc.data() as Map<String, dynamic>;
      if (chatData['lastMessage'] == message.text ||
          chatData['lastMessage'] == '📷 Photo') {
        await _firestore
            .collection('chatRooms')
            .doc(chatRoomId)
            .update({'lastMessage': 'Message recalled'});
      }

      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  // Delete a message (only for self, removes from view)
  Future<void> deleteMessage(String chatRoomId, String messageId) async {
    await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  // Delete message for self only (soft delete via adding uid to deletedFor array)
  Future<void> deleteMessageForMe({
    required String chatRoomId,
    required String messageId,
    required String uid,
  }) async {
    await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedFor': FieldValue.arrayUnion([uid]),
    });
  }

  // Helper to update chat room last message and unread counts
  Future<void> _updateChatRoomLastMessage({
    required String chatRoomId,
    required String senderId,
    required String lastMessage,
  }) async {
    DocumentSnapshot chatRoomDoc =
        await _firestore.collection('chatRooms').doc(chatRoomId).get();
    Map<String, dynamic> data = chatRoomDoc.data() as Map<String, dynamic>;
    List<String> members = List<String>.from(data['members'] ?? []);

    Map<String, dynamic> updateData = {
      'lastMessage': lastMessage,
      'lastMessageSender': senderId,
      'lastMessageTime': Timestamp.fromDate(DateTime.now()),
    };

    for (String uid in members) {
      if (uid != senderId) {
        updateData['unreadCount.$uid'] = FieldValue.increment(1);
      }
    }

    await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .update(updateData);
  }

  // Get chat rooms for current user
  Stream<QuerySnapshot> getChatRooms(String uid) {
    return _firestore
        .collection('chatRooms')
        .where('members', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  // Get messages for a chat room
  Stream<QuerySnapshot> getMessages(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Mark messages as read
  Future<void> markAsRead(String chatRoomId, String uid) async {
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'unreadCount.$uid': 0,
    });
  }

  // Get user info by uid
  Future<Map<String, dynamic>> getUserInfo(String uid) async {
    DocumentSnapshot doc =
        await _firestore.collection('users').doc(uid).get();
    return doc.data() as Map<String, dynamic>;
  }

  // Add member to group
  Future<void> addMemberToGroup(String chatRoomId, String uid) async {
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'members': FieldValue.arrayUnion([uid]),
      'unreadCount.$uid': 0,
    });
  }

  // Leave group
  Future<void> leaveGroup(String chatRoomId, String uid) async {
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'members': FieldValue.arrayRemove([uid]),
    });
  }

  // Generate deterministic chat room ID for direct chats
  String _generateDirectChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}
