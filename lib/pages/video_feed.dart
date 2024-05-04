import 'package:grpc/grpc.dart';
import 'dart:async';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/video.pbgrpc.dart';
import 'dart:developer' as dev; //log() conflicts with math
import 'dart:typed_data';

import 'package:flutter/material.dart';

class VideoFeedPage extends StatefulWidget {
  final String serverAddress;
  const VideoFeedPage({Key? key, required this.serverAddress})
      : super(key: key);
  @override
  State<VideoFeedPage> createState() => _VideoFeedPageState();
}

class _VideoFeedPageState extends State<VideoFeedPage> {
  late ClientChannel channel;
  late VideoStreamerClient stub;
  StreamSubscription? _subscription;
  Uint8List? _latestFrame;

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  void _initializeStream() {
    channel = ClientChannel(
      widget.serverAddress,
      port: 50051,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    stub = VideoStreamerClient(channel);

    // Start listening to the stream
    _startListening();
  }

  void _startListening() {
    _subscription = stub.streamVideo(VideoRequest()).listen(
      (frame) {
        setState(() {
          _latestFrame = frame.data as Uint8List?;
        });
      },
      onError: (error) {
        dev.log("Error receiving frames: $error");
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    channel.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Provide a default placeholder until the first frame is received
      child: _latestFrame == null
          ? const Center(child: CircularProgressIndicator())
          : Image.memory(_latestFrame!),
    );
  }
}
