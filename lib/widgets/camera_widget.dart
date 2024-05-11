import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data'; // For Uint8List
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';

class CameraView extends ConsumerWidget {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watches the videoFrameProvider and rebuilds the widget whenever the state changes.
    final videoFrame = ref.watch(videoFrameProvider);

    // Check if the imageData is not empty
    if (videoFrame.data.isNotEmpty) {
      return Image.memory(
        Uint8List.fromList(videoFrame.data),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(child: Text('Failed to load image')),
      );
    } else {
      return const Center(child: Text('No Video Data'));
    }
  }
}
