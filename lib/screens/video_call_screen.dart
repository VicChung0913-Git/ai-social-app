import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter/models/call.dart';
import 'package:instagram_clone_flutter/resources/call_methods.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoCallScreen extends StatefulWidget {
  final Call call;
  final bool isCaller;

  const VideoCallScreen({
    Key? key,
    required this.call,
    required this.isCaller,
  }) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final CallMethods _callMethods = CallMethods();
  late RtcEngine _engine;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  bool _isConnected = false;
  int? _remoteUid;
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
    await [Permission.microphone, Permission.camera].request();

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
        setState(() {
          _remoteUid = remoteUid;
          _isConnected = true;
        });
      },
      onUserOffline:
          (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        setState(() => _remoteUid = null);
        _endCall();
      },
    ));

    await _engine.enableVideo();
    await _engine.enableAudio();
    await _engine.startPreview();

    await _engine.joinChannel(
      token: '', // Use token server in production
      channelId: widget.call.channelId,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        publishCameraTrack: true,
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

  void _toggleCamera() {
    setState(() => _isCameraOff = !_isCameraOff);
    _engine.muteLocalVideoStream(_isCameraOff);
  }

  void _switchCamera() {
    _engine.switchCamera();
    setState(() => _isFrontCamera = !_isFrontCamera);
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          _remoteUid != null
              ? AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _engine,
                    canvas: VideoCanvas(uid: _remoteUid!),
                    connection:
                        RtcConnection(channelId: widget.call.channelId),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[700],
                        backgroundImage:
                            (widget.isCaller
                                        ? widget.call.receiverPhotoUrl
                                        : widget.call.callerPhotoUrl)
                                    .isNotEmpty
                                ? NetworkImage(widget.isCaller
                                    ? widget.call.receiverPhotoUrl
                                    : widget.call.callerPhotoUrl)
                                : null,
                        child: const Icon(Icons.person,
                            size: 50, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.isCaller
                            ? widget.call.receiverName
                            : widget.call.callerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isConnected ? 'Connected' : 'Connecting...',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

          // Local video (small, top-right)
          Positioned(
            top: 60,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 120,
                height: 160,
                child: _isCameraOff
                    ? Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(Icons.videocam_off,
                              color: Colors.white54, size: 32),
                        ),
                      )
                    : AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: _engine,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      ),
              ),
            ),
          ),

          // Call duration
          if (_isConnected)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatDuration(_callDuration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

          // Control buttons at bottom
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  onTap: _toggleMute,
                  isActive: _isMuted,
                ),
                _buildControlButton(
                  icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                  onTap: _toggleCamera,
                  isActive: _isCameraOff,
                ),
                _buildControlButton(
                  icon: Icons.call_end,
                  onTap: _endCall,
                  backgroundColor: Colors.red,
                  iconColor: Colors.white,
                ),
                _buildControlButton(
                  icon: Icons.cameraswitch,
                  onTap: _switchCamera,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? iconColor,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor ??
              (isActive ? Colors.white : Colors.white.withOpacity(0.2)),
        ),
        child: Icon(
          icon,
          color: iconColor ?? (isActive ? Colors.black : Colors.white),
          size: 26,
        ),
      ),
    );
  }
}
