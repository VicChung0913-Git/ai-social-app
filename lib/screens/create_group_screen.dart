import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter/resources/chat_methods.dart';
import 'package:instagram_clone_flutter/screens/chat_screen.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';
import 'package:instagram_clone_flutter/utils/utils.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ChatMethods _chatMethods = ChatMethods();
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;

  final List<Map<String, dynamic>> _selectedMembers = [];
  Uint8List? _groupPic;
  bool _isCreating = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _selectGroupPic() async {
    final ImagePicker picker = ImagePicker();
    XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => _groupPic = bytes);
    }
  }

  void _toggleMember(Map<String, dynamic> user) {
    setState(() {
      int existingIndex = _selectedMembers.indexWhere(
        (m) => m['uid'] == user['uid'],
      );
      if (existingIndex >= 0) {
        _selectedMembers.removeAt(existingIndex);
      } else {
        _selectedMembers.add(user);
      }
    });
  }

  bool _isMemberSelected(String uid) {
    return _selectedMembers.any((m) => m['uid'] == uid);
  }

  void _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      showSnackBar(context, 'Please enter a group name');
      return;
    }
    if (_selectedMembers.isEmpty) {
      showSnackBar(context, 'Please select at least one member');
      return;
    }

    setState(() => _isCreating = true);

    List<String> memberUids =
        _selectedMembers.map<String>((m) => m['uid'] as String).toList();
    memberUids.add(_currentUid); // Add creator

    String chatRoomId = await _chatMethods.createGroupChat(
      name: _groupNameController.text.trim(),
      createdBy: _currentUid,
      members: memberUids,
      groupPic: _groupPic,
    );

    setState(() => _isCreating = false);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatRoomId: chatRoomId,
            chatName: _groupNameController.text.trim(),
            chatPhotoUrl: '',
            isGroup: true,
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
          'Create Group',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          _isCreating
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _createGroup,
                  child: const Text(
                    'Create',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
      body: Column(
        children: [
          // Group info section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Row(
              children: [
                GestureDetector(
                  onTap: _selectGroupPic,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[700],
                    backgroundImage:
                        _groupPic != null ? MemoryImage(_groupPic!) : null,
                    child: _groupPic == null
                        ? const Icon(Icons.camera_alt,
                            color: Colors.white, size: 28)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _groupNameController,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'Group name',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: lineGreenColor),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: lineGreenColor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Selected members chips
          if (_selectedMembers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _selectedMembers.map((member) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      backgroundImage:
                          (member['photoUrl'] ?? '').isNotEmpty
                              ? NetworkImage(member['photoUrl'])
                              : null,
                      child: (member['photoUrl'] ?? '').isEmpty
                          ? const Icon(Icons.person,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                    label: Text(
                      member['username'] ?? 'Unknown',
                      style: const TextStyle(color: Colors.white),
                    ),
                    deleteIcon:
                        const Icon(Icons.close, size: 16, color: Colors.white),
                    onDeleted: () => _toggleMember(member),
                    backgroundColor: lineGreenColor.withOpacity(0.3),
                  );
                }).toList(),
              ),
            ),

          // Search
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search users to add...',
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

          // Members label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Members: ${_selectedMembers.length}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // User list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<QueryDocumentSnapshot> users =
                    snapshot.data!.docs.where((doc) {
                  Map<String, dynamic> data =
                      doc.data() as Map<String, dynamic>;
                  String uid = data['uid'] ?? '';
                  String username =
                      (data['username'] ?? '').toString().toLowerCase();
                  String searchQuery = _searchController.text.toLowerCase();

                  return uid != _currentUid &&
                      (searchQuery.isEmpty ||
                          username.contains(searchQuery));
                }).toList();

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> userData =
                        users[index].data() as Map<String, dynamic>;
                    bool isSelected =
                        _isMemberSelected(userData['uid'] ?? '');

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[800],
                        backgroundImage:
                            (userData['photoUrl'] ?? '').isNotEmpty
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
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleMember(userData),
                        activeColor: lineGreenColor,
                        checkColor: Colors.white,
                        side: BorderSide(color: Colors.grey[600]!),
                      ),
                      onTap: () => _toggleMember(userData),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
