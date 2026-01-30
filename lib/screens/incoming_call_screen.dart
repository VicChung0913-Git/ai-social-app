import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter/models/call.dart';
import 'package:instagram_clone_flutter/resources/call_methods.dart';
import 'package:instagram_clone_flutter/screens/video_call_screen.dart';
import 'package:instagram_clone_flutter/screens/voice_call_screen.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';

class IncomingCallScreen extends StatefulWidget {
  final Call call;

  const IncomingCallScreen({Key? key, required this.call}) : super(key: key);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  final CallMethods _callMethods = CallMethods();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription? _callSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Listen for call status changes (e.g., caller cancels)
    _callSubscription =
        _callMethods.getCallStream(widget.call.callId).listen((snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        String status = data['status'] ?? '';
        if (status == CallStatus.ended.name ||
            status == CallStatus.declined.name) {
          if (mounted) Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _callSubscription?.cancel();
    super.dispose();
  }

  void _acceptCall() async {
    await _callMethods.answerCall(widget.call.callId);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => widget.call.type == CallType.video
              ? VideoCallScreen(call: widget.call, isCaller: false)
              : VoiceCallScreen(call: widget.call, isCaller: false),
        ),
      );
    }
  }

  void _declineCall() async {
    await _callMethods.declineCall(widget.call.callId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    bool isVideo = widget.call.type == CallType.video;

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Call type indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: lineGreenColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVideo ? Icons.videocam : Icons.phone,
                    color: lineGreenColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
                    style: const TextStyle(
                      color: lineGreenColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Pulsing avatar
            ScaleTransition(
              scale: _pulseAnimation,
              child: CircleAvatar(
                radius: 70,
                backgroundColor: lineGreenColor.withOpacity(0.3),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[700],
                  backgroundImage:
                      widget.call.callerPhotoUrl.isNotEmpty
                          ? NetworkImage(widget.call.callerPhotoUrl)
                          : null,
                  child: widget.call.callerPhotoUrl.isEmpty
                      ? const Icon(Icons.person,
                          size: 60, color: Colors.white)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Caller name
            Text(
              widget.call.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'is calling you...',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 16,
              ),
            ),
            const Spacer(flex: 3),
            // Accept / Decline buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _declineCall,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Decline',
                        style: TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                    ],
                  ),
                  // Accept
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _acceptCall,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: lineGreenColor,
                          ),
                          child: Icon(
                            isVideo ? Icons.videocam : Icons.phone,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Accept',
                        style: TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
