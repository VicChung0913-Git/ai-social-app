import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter/models/chat_room.dart';
import 'package:instagram_clone_flutter/resources/chat_methods.dart';
import 'package:instagram_clone_flutter/screens/chat_screen.dart';
import 'package:instagram_clone_flutter/screens/new_chat_screen.dart';
import 'package:instagram_clone_flutter/screens/create_group_screen.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';
import 'package:timeago/timeago.dart' as timeago;

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({Key? key}) : super(key: key);

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final ChatMethods _chatMethods = ChatMethods();
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;

  // Cache for user info to avoid repeated fetches
  final Map<String, Map<String, dynamic>> _userCache = {};

  Future<Map<String, dynamic>> _getCachedUserInfo(String uid) async {
    if (!_userCache.containsKey(uid)) {
      _userCache[uid] = await _chatMethods.getUserInfo(uid);
    }
    return _userCache[uid]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: lineGreenColor,
        title: const Text(
          'Chats',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreateGroupScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NewChatScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatMethods.getChatRooms(_currentUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a new chat with family!',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lineGreenColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const NewChatScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'New Chat',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              ChatRoom chatRoom =
                  ChatRoom.fromSnap(snapshot.data!.docs[index]);

              return _buildChatRoomTile(chatRoom);
            },
          );
        },
      ),
    );
  }

  Widget _buildChatRoomTile(ChatRoom chatRoom) {
    int unread = chatRoom.unreadCount[_currentUid] ?? 0;

    if (chatRoom.isGroup) {
      return _chatTile(
        chatRoom: chatRoom,
        displayName: chatRoom.name,
        photoUrl: chatRoom.chatRoomPic,
        unreadCount: unread,
      );
    }

    // For 1-1 chats, get the other user's info
    String otherUid =
        chatRoom.members.firstWhere((uid) => uid != _currentUid);

    return FutureBuilder<Map<String, dynamic>>(
      future: _getCachedUserInfo(otherUid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text('Loading...', style: TextStyle(color: Colors.white)),
          );
        }

        Map<String, dynamic> otherUser = snapshot.data!;

        return _chatTile(
          chatRoom: chatRoom,
          displayName: otherUser['username'] ?? 'Unknown',
          photoUrl: otherUser['photoUrl'] ?? '',
          unreadCount: unread,
        );
      },
    );
  }

  Widget _chatTile({
    required ChatRoom chatRoom,
    required String displayName,
    required String photoUrl,
    required int unreadCount,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatRoomId: chatRoom.chatRoomId,
              chatName: displayName,
              chatPhotoUrl: photoUrl,
              isGroup: chatRoom.isGroup,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[900]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[800],
              backgroundImage:
                  photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? Icon(
                      chatRoom.isGroup ? Icons.group : Icons.person,
                      color: Colors.white,
                      size: 28,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeago.format(chatRoom.lastMessageTime, locale: 'en_short'),
                        style: TextStyle(
                          color: unreadCount > 0
                              ? lineGreenColor
                              : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chatRoom.lastMessage.isEmpty
                              ? 'Start chatting!'
                              : chatRoom.lastMessage,
                          style: TextStyle(
                            color: unreadCount > 0
                                ? Colors.white70
                                : Colors.grey[600],
                            fontSize: 14,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: lineGreenColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount > 99
                                ? '99+'
                                : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
