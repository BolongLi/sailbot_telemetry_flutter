import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/camera_widget.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';

final cameraToggleProvider =
    StateProvider<bool>((ref) => true); // true for camera, false for map

class MapCameraToggle extends ConsumerWidget {
  const MapCameraToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMapVisible = ref.watch(cameraToggleProvider);
    final networkComms = ref.watch(networkCommsProvider);
    return ToggleButtons(
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
    );
  }
}

class MapCameraWidget extends ConsumerWidget {
  const MapCameraWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMapVisible = ref.watch(cameraToggleProvider);
    return isMapVisible ? const MapView() : const CameraView();
  }
}
