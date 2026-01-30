import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter/models/call.dart';
import 'package:instagram_clone_flutter/models/message.dart';
import 'package:instagram_clone_flutter/providers/user_provider.dart';
import 'package:instagram_clone_flutter/resources/call_methods.dart';
import 'package:instagram_clone_flutter/resources/chat_methods.dart';
import 'package:instagram_clone_flutter/screens/video_call_screen.dart';
import 'package:instagram_clone_flutter/screens/voice_call_screen.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';
import 'package:instagram_clone_flutter/utils/utils.dart';
import 'package:instagram_clone_flutter/widgets/sticker_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String chatName;
  final String chatPhotoUrl;
  final bool isGroup;

  const ChatScreen({
    Key? key,
    required this.chatRoomId,
    required this.chatName,
    required this.chatPhotoUrl,
    required this.isGroup,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatMethods _chatMethods = ChatMethods();
  final CallMethods _callMethods = CallMethods();
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _showEmojiPicker = false;
  bool _showStickerPicker = false;

  @override
  void initState() {
    super.initState();
    _chatMethods.markAsRead(widget.chatRoomId, _currentUid);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final user = Provider.of<UserProvider>(context, listen: false).getUser;

    String res = await _chatMethods.sendMessage(
      chatRoomId: widget.chatRoomId,
      senderId: _currentUid,
      senderName: user.username,
      senderPhotoUrl: user.photoUrl,
      text: _messageController.text.trim(),
    );

    _messageController.clear();
    setState(() => _isSending = false);

    if (res != 'success' && mounted) {
      showSnackBar(context, res);
    }
  }

  void _sendImage() async {
    final ImagePicker picker = ImagePicker();
    XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isSending = true);

    final bytes = await image.readAsBytes();
    final user = Provider.of<UserProvider>(context, listen: false).getUser;

    String res = await _chatMethods.sendImageMessage(
      chatRoomId: widget.chatRoomId,
      senderId: _currentUid,
      senderName: user.username,
      senderPhotoUrl: user.photoUrl,
      imageFile: bytes,
    );

    setState(() => _isSending = false);

    if (res != 'success' && mounted) {
      showSnackBar(context, res);
    }
  }

  void _sendSticker(String sticker, String packId) async {
    setState(() {
      _showStickerPicker = false;
    });

    final user = Provider.of<UserProvider>(context, listen: false).getUser;

    String res = await _chatMethods.sendStickerMessage(
      chatRoomId: widget.chatRoomId,
      senderId: _currentUid,
      senderName: user.username,
      senderPhotoUrl: user.photoUrl,
      stickerEmoji: sticker,
      stickerPackId: packId,
    );

    if (res != 'success' && mounted) {
      showSnackBar(context, res);
    }
  }

  void _recallMessage(Message message) async {
    if (!message.canRecall) {
      showSnackBar(context, 'Can only recall within 15 minutes');
      return;
    }

    String res = await _chatMethods.recallMessage(
      chatRoomId: widget.chatRoomId,
      messageId: message.messageId,
      senderId: _currentUid,
    );

    if (mounted) {
      showSnackBar(
        context,
        res == 'success' ? 'Message recalled' : res,
      );
    }
  }

  void _deleteMessageForMe(Message message) async {
    await _chatMethods.deleteMessageForMe(
      chatRoomId: widget.chatRoomId,
      messageId: message.messageId,
      uid: _currentUid,
    );

    if (mounted) {
      showSnackBar(context, 'Message deleted');
    }
  }

  void _showMessageOptions(Message message) {
    bool isMe = message.senderId == _currentUid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isMe && message.canRecall)
              ListTile(
                leading: const Icon(Icons.undo, color: Colors.orange),
                title: const Text('Recall Message',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  'Available for ${15 - DateTime.now().difference(message.timestamp).inMinutes} more minutes',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _recallMessage(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete for Me',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessageForMe(message);
              },
            ),
            if (isMe)
              ListTile(
                leading:
                    const Icon(Icons.delete_forever, color: Colors.redAccent),
                title: const Text('Delete for Everyone',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _chatMethods.deleteMessage(
                      widget.chatRoomId, message.messageId);
                  showSnackBar(context, 'Message deleted for everyone');
                },
              ),
            if (message.type == MessageType.text)
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.white70),
                title: const Text('Copy Text',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  showSnackBar(context, 'Text copied');
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _startVoiceCall() async {
    if (widget.isGroup) {
      showSnackBar(context, 'Group calls coming soon!');
      return;
    }

    final user = Provider.of<UserProvider>(context, listen: false).getUser;

    // Get the other user's info
    DocumentSnapshot chatDoc = await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .get();
    Map<String, dynamic> chatData = chatDoc.data() as Map<String, dynamic>;
    List<String> members = List<String>.from(chatData['members'] ?? []);
    String otherUid = members.firstWhere((uid) => uid != _currentUid);
    Map<String, dynamic> otherUser =
        await _chatMethods.getUserInfo(otherUid);

    Call call = await _callMethods.initiateCall(
      callerId: _currentUid,
      callerName: user.username,
      callerPhotoUrl: user.photoUrl,
      receiverId: otherUid,
      receiverName: otherUser['username'] ?? 'Unknown',
      receiverPhotoUrl: otherUser['photoUrl'] ?? '',
      chatRoomId: widget.chatRoomId,
      type: CallType.voice,
    );

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VoiceCallScreen(call: call, isCaller: true),
        ),
      );
    }
  }

  void _startVideoCall() async {
    if (widget.isGroup) {
      showSnackBar(context, 'Group calls coming soon!');
      return;
    }

    final user = Provider.of<UserProvider>(context, listen: false).getUser;

    DocumentSnapshot chatDoc = await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .get();
    Map<String, dynamic> chatData = chatDoc.data() as Map<String, dynamic>;
    List<String> members = List<String>.from(chatData['members'] ?? []);
    String otherUid = members.firstWhere((uid) => uid != _currentUid);
    Map<String, dynamic> otherUser =
        await _chatMethods.getUserInfo(otherUid);

    Call call = await _callMethods.initiateCall(
      callerId: _currentUid,
      callerName: user.username,
      callerPhotoUrl: user.photoUrl,
      receiverId: otherUid,
      receiverName: otherUser['username'] ?? 'Unknown',
      receiverPhotoUrl: otherUser['photoUrl'] ?? '',
      chatRoomId: widget.chatRoomId,
      type: CallType.video,
    );

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(call: call, isCaller: true),
        ),
      );
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      _showStickerPicker = false;
      if (_showEmojiPicker) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _toggleStickerPicker() {
    setState(() {
      _showStickerPicker = !_showStickerPicker;
      _showEmojiPicker = false;
      if (_showStickerPicker) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chatBackgroundColor,
      appBar: AppBar(
        backgroundColor: lineGreenColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[800],
              backgroundImage: widget.chatPhotoUrl.isNotEmpty
                  ? NetworkImage(widget.chatPhotoUrl)
                  : null,
              child: widget.chatPhotoUrl.isEmpty
                  ? Icon(
                      widget.isGroup ? Icons.group : Icons.person,
                      color: Colors.white,
                      size: 20,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.chatName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: _startVoiceCall,
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: _startVideoCall,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatMethods.getMessages(widget.chatRoomId),
              builder: (context, snapshot) {
                _chatMethods.markAsRead(widget.chatRoomId, _currentUid);

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.waving_hand,
                          size: 60,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Say hello!',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    Message message =
                        Message.fromSnap(snapshot.data!.docs[index]);

                    // Skip messages deleted for current user
                    Map<String, dynamic> rawData = snapshot.data!.docs[index]
                        .data() as Map<String, dynamic>;
                    List deletedFor =
                        rawData['deletedFor'] as List? ?? [];
                    if (deletedFor.contains(_currentUid)) {
                      return const SizedBox.shrink();
                    }

                    // Show date separator
                    bool showDate = false;
                    if (index == snapshot.data!.docs.length - 1) {
                      showDate = true;
                    } else {
                      Message nextMessage =
                          Message.fromSnap(snapshot.data!.docs[index + 1]);
                      showDate = !_isSameDay(
                          message.timestamp, nextMessage.timestamp);
                    }

                    return Column(
                      children: [
                        if (showDate) _buildDateSeparator(message.timestamp),
                        _buildMessageBubble(message),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Input area
          _buildInputArea(),
          // Emoji picker
          if (_showEmojiPicker)
            SizedBox(
              height: 280,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _messageController.text += emoji.emoji;
                  _messageController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _messageController.text.length),
                  );
                },
                onBackspacePressed: () {
                  _messageController
                    ..text =
                        _messageController.text.characters.skipLast(1).string
                    ..selection = TextSelection.fromPosition(
                      TextPosition(offset: _messageController.text.length),
                    );
                },
                config: Config(
                  height: 280,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 7,
                    emojiSizeMax: 28 *
                        (foundation.defaultTargetPlatform ==
                                TargetPlatform.iOS
                            ? 1.30
                            : 1.0),
                    backgroundColor: mobileBackgroundColor,
                  ),
                  categoryViewConfig: const CategoryViewConfig(
                    backgroundColor: mobileBackgroundColor,
                    indicatorColor: lineGreenColor,
                    iconColorSelected: lineGreenColor,
                  ),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    backgroundColor: mobileBackgroundColor,
                  ),
                  searchViewConfig: const SearchViewConfig(
                    backgroundColor: mobileBackgroundColor,
                  ),
                ),
              ),
            ),
          // Sticker picker
          if (_showStickerPicker)
            StickerPickerWidget(
              onStickerSelected: _sendSticker,
            ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    String dateText;
    DateTime now = DateTime.now();
    if (_isSameDay(date, now)) {
      dateText = 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('MMM d, yyyy').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        dateText,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    // Recalled message
    if (message.isRecalled) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: message.senderId == _currentUid
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Icon(Icons.undo, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              message.senderId == _currentUid
                  ? 'You recalled a message'
                  : '${message.senderName} recalled a message',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    if (message.type == MessageType.system) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.white60, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Sticker message
    if (message.type == MessageType.sticker) {
      return _buildStickerBubble(message);
    }

    bool isMe = message.senderId == _currentUid;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            top: 2,
            bottom: 2,
            left: isMe ? 60 : 0,
            right: isMe ? 0 : 60,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe && widget.isGroup)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey[700],
                    backgroundImage: message.senderPhotoUrl.isNotEmpty
                        ? NetworkImage(message.senderPhotoUrl)
                        : null,
                    child: message.senderPhotoUrl.isEmpty
                        ? const Icon(Icons.person,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe && widget.isGroup)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 2),
                        child: Text(
                          message.senderName,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ),
                    Container(
                      padding: message.type == MessageType.image
                          ? const EdgeInsets.all(4)
                          : const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? lineGreenColor : chatBubbleOtherColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (message.type == MessageType.image &&
                              message.imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                message.imageUrl!,
                                width: 200,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const SizedBox(
                                    width: 200,
                                    height: 150,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: lineGreenColor,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (message.type == MessageType.text)
                            Text(
                              message.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('HH:mm').format(message.timestamp),
                                style: TextStyle(
                                  color: isMe
                                      ? Colors.white60
                                      : Colors.grey[600],
                                  fontSize: 10,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 3),
                                Icon(
                                  message.readBy.length > 1
                                      ? Icons.done_all
                                      : Icons.done,
                                  size: 14,
                                  color: message.readBy.length > 1
                                      ? Colors.lightBlueAccent
                                      : Colors.white60,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickerBubble(Message message) {
    bool isMe = message.senderId == _currentUid;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: isMe ? 60 : 0,
            right: isMe ? 0 : 60,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe && widget.isGroup)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    message.senderName,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ),
              Text(
                message.stickerEmoji ?? '',
                style: const TextStyle(fontSize: 72),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 3),
                    Icon(
                      message.readBy.length > 1
                          ? Icons.done_all
                          : Icons.done,
                      size: 14,
                      color: message.readBy.length > 1
                          ? Colors.lightBlueAccent
                          : Colors.white60,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: mobileBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey[900]!, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Sticker button
            IconButton(
              icon: Icon(
                _showStickerPicker
                    ? Icons.keyboard
                    : Icons.emoji_emotions_outlined,
                color: _showStickerPicker ? lineGreenColor : Colors.grey[500],
              ),
              onPressed: _toggleStickerPicker,
              iconSize: 24,
            ),
            // Camera button
            IconButton(
              icon: Icon(Icons.camera_alt, color: Colors.grey[500]),
              onPressed: _sendImage,
              iconSize: 24,
            ),
            // Text input
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        onTap: () {
                          setState(() {
                            _showEmojiPicker = false;
                            _showStickerPicker = false;
                          });
                        },
                        maxLines: null,
                      ),
                    ),
                    // Emoji toggle
                    GestureDetector(
                      onTap: _toggleEmojiPicker,
                      child: Icon(
                        _showEmojiPicker
                            ? Icons.keyboard
                            : Icons.sentiment_satisfied_alt,
                        color: _showEmojiPicker
                            ? lineGreenColor
                            : Colors.grey[500],
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Send button
            Container(
              decoration: const BoxDecoration(
                color: lineGreenColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
