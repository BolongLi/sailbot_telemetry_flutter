import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/camera_widget.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_camera_widget.dart';

final videoSourceProvider =
    StateProvider<String>((ref) => 'COLOR');

class VideoSourceSelect extends ConsumerWidget {
  VideoSourceSelect({super.key});
    final Map<String, String> _cameraSourceDropdownOptions = {
      'COLOR': 'Color',
      'MASK': 'Mask',
      'DEPTH': 'Depth',
    };
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMapVisible = ref.watch(cameraToggleProvider);
    final networkComms = ref.watch(networkCommsProvider);
    final selectedVideoSource = ref.watch(videoSourceProvider);
    return isMapVisible ? const Text("") : DropdownButton<String>(
      value: selectedVideoSource,
      dropdownColor: const Color.fromARGB(255, 255, 255, 255),
      onChanged: (String? newValue) {
        networkComms?.setCameraSource(newValue!);
        ref.read(videoSourceProvider.notifier).state = newValue!;
      },
      items: _cameraSourceDropdownOptions.entries
          .map<DropdownMenuItem<String>>(
              (MapEntry<String, String> entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value),
        );
      }).toList(),
    );
  }
}