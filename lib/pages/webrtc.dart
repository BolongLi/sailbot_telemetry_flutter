import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCVideoView extends StatefulWidget {
  static const String route = '/webrtc';

  const WebRTCVideoView({super.key});

  @override
  _WebRTCVideoViewState createState() => _WebRTCVideoViewState();
}

class _WebRTCVideoViewState extends State<WebRTCVideoView> {
  late RTCPeerConnection _peerConnection;
  late MediaStream _remoteStream;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    initRenderer();
    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });
  }

  Future<void> initRenderer() async {
    await _remoteRenderer.initialize();
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    RTCPeerConnection pc =
        await createPeerConnection(configuration, offerSdpConstraints);

    pc.onTrack = (event) {
      if (event.track.kind == 'video') {
        setState(() {
          _remoteStream = event.streams[0];
          _remoteRenderer.srcObject = _remoteStream;
        });
      }
    };

    // Here, you should implement your signaling to exchange SDP and ICE candidates
    // For example, after creating an offer:
    // RTCSessionDescription offer = await pc.createOffer();
    // await pc.setLocalDescription(offer);
    // Then send the offer to the server and listen for an answer...

    return pc;
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebRTC Stream'),
      ),
      body: Container(
        child: RTCVideoView(_remoteRenderer),
        decoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
