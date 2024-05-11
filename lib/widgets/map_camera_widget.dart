import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/camera_widget.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';

final cameraToggleProvider = StateProvider<bool>((ref) => true); // true for camera, false for map

class MapCameraWidget extends ConsumerWidget {
  const MapCameraWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMapVisible = ref.watch(cameraToggleProvider);
    final networkComms = ref.watch(networkCommsProvider);
    return Expanded( child: Stack (
      children: [
        isMapVisible ? const MapView() : const CameraView(),
        Align(
              alignment: Alignment.centerRight, child: ToggleButtons(
          isSelected: [isMapVisible, !isMapVisible],
          onPressed: (index) {
            ref.read(cameraToggleProvider.notifier).state = index == 0;
            if (index == 0) {
              networkComms?.cancelVideoStreaming();
            } else {
              networkComms?.startVideoStreaming();
            }
          },
          children: const [Icon(Icons.map), Icon(Icons.camera)],
        )),
      ],
    ));
  }
}