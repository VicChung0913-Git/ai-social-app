import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter/resources/chat_methods.dart';
import 'package:instagram_clone_flutter/screens/chat_screen.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({Key? key}) : super(key: key);

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatMethods _chatMethods = ChatMethods();
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startChat(Map<String, dynamic> userData) async {
    setState(() => _isLoading = true);

    String chatRoomId = await _chatMethods.getOrCreateDirectChat(
      currentUid: _currentUid,
      otherUid: userData['uid'],
    );

    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatRoomId: chatRoomId,
            chatName: userData['username'] ?? 'Unknown',
            chatPhotoUrl: userData['photoUrl'] ?? '',
            isGroup: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: lineGreenColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Chat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(12),
            color: mobileBackgroundColor,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Text('No users found',
                style: TextStyle(color: Colors.white)),
          );
        }

        // Filter out current user and apply search
        List<QueryDocumentSnapshot> users = snapshot.data!.docs.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String uid = data['uid'] ?? '';
          String username = (data['username'] ?? '').toString().toLowerCase();
          String searchQuery = _searchController.text.toLowerCase();

          return uid != _currentUid &&
              (searchQuery.isEmpty || username.contains(searchQuery));
        }).toList();

        if (users.isEmpty) {
          return Center(
            child: Text(
              'No users found',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            Map<String, dynamic> userData =
                users[index].data() as Map<String, dynamic>;

            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[800],
                backgroundImage: (userData['photoUrl'] ?? '').isNotEmpty
                    ? NetworkImage(userData['photoUrl'])
                    : null,
                child: (userData['photoUrl'] ?? '').isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              title: Text(
                userData['username'] ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                userData['bio'] ?? '',
                style: TextStyle(color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(Icons.chat, color: lineGreenColor),
              onTap: () => _startChat(userData),
            );
          },
        );
      },
    );
  }
}
