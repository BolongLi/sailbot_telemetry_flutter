import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_camera_widget.dart';

class PathPoint extends ConsumerWidget {
  const PathPoint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watches the videoFrameProvider and rebuilds the widget whenever the state changes.
    final mapState = ref.watch(mapStateProvider);
    final isMapVisible = ref.watch(cameraToggleProvider);

   return mapState.showPathButton && isMapVisible ? Positioned(
      top: (mapState.mapPressPosition?.global.dy)! - 5.0,
      left: (mapState.mapPressPosition?.global.dx)! - 5.0,
      child: Container(
        width: 10, // Circle diameter
        height: 10, // Circle diameter
        decoration: const BoxDecoration(
          color: Colors.red, // Circle color
          shape: BoxShape.circle,
        ),
      )) : const Text("");
  }
}