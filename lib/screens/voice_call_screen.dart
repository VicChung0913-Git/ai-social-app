import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter/models/call.dart';
import 'package:instagram_clone_flutter/resources/call_methods.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceCallScreen extends StatefulWidget {
  final Call call;
  final bool isCaller;

  const VoiceCallScreen({
    Key? key,
    required this.call,
    required this.isCaller,
  }) : super(key: key);

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  final CallMethods _callMethods = CallMethods();
  late RtcEngine _engine;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isConnected = false;
  Timer? _callTimer;
  int _callDuration = 0;
  StreamSubscription? _callSubscription;

  @override
  void initState() {
    super.initState();
    _initAgora();
    _listenCallStatus();
  }

  Future<void> _initAgora() async {
    // Request microphone permission
    await Permission.microphone.request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: CallMethods.agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        setState(() => _isConnected = true);
        _startTimer();
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        setState(() => _isConnected = true);
      },
      onUserOffline:
          (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        _endCall();
      },
    ));

    await _engine.enableAudio();
    await _engine.setEnableSpeakerphone(false);

    await _engine.joinChannel(
      token: '', // Use token server in production
      channelId: widget.call.channelId,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeAudio: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  void _listenCallStatus() {
    _callSubscription =
        _callMethods.getCallStream(widget.call.callId).listen((snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        String status = data['status'] ?? '';
        if (status == CallStatus.ended.name ||
            status == CallStatus.declined.name) {
          _navigateBack();
        }
      }
    });
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _callDuration++);
      }
    });
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _engine.muteLocalAudioStream(_isMuted);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeaker = !_isSpeaker);
    _engine.setEnableSpeakerphone(_isSpeaker);
  }

  void _endCall() async {
    await _callMethods.endCall(widget.call.callId);
    _navigateBack();
  }

  void _navigateBack() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _callSubscription?.cancel();
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String otherName = widget.isCaller
        ? widget.call.receiverName
        : widget.call.callerName;
    String otherPhoto = widget.isCaller
        ? widget.call.receiverPhotoUrl
        : widget.call.callerPhotoUrl;

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Avatar
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[700],
              backgroundImage:
                  otherPhoto.isNotEmpty ? NetworkImage(otherPhoto) : null,
              child: otherPhoto.isEmpty
                  ? const Icon(Icons.person, size: 60, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 24),
            // Name
            Text(
              otherName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Status
            Text(
              _isConnected
                  ? _formatDuration(_callDuration)
                  : 'Connecting...',
              style: TextStyle(
                color: _isConnected ? lineGreenColor : Colors.white60,
                fontSize: 16,
              ),
            ),
            const Spacer(flex: 3),
            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mute
                _buildControlButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  label: _isMuted ? 'Unmute' : 'Mute',
                  onTap: _toggleMute,
                  isActive: _isMuted,
                ),
                // End call
                _buildControlButton(
                  icon: Icons.call_end,
                  label: 'End',
                  onTap: _endCall,
                  backgroundColor: Colors.red,
                  iconColor: Colors.white,
                ),
                // Speaker
                _buildControlButton(
                  icon: _isSpeaker ? Icons.volume_up : Icons.volume_down,
                  label: 'Speaker',
                  onTap: _toggleSpeaker,
                  isActive: _isSpeaker,
                ),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? iconColor,
    bool isActive = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor ??
                  (isActive ? Colors.white : Colors.white.withOpacity(0.2)),
            ),
            child: Icon(
              icon,
              color: iconColor ?? (isActive ? Colors.black : Colors.white),
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}
