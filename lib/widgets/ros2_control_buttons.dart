import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/utils/github_helper.dart';
import 'package:sailbot_telemetry_flutter/utils/startup_manager.dart';
import 'dart:developer' as dev;

// The StateProvider to hold the currently selected string
final selectedLaunchfileProvider = StateProvider<String?>((ref) => null);

class LaunchfileDropdown extends ConsumerWidget {
  const LaunchfileDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final launchfileList = ref.watch(launchfileListProvider);
    final selectedLaunchfile = ref.watch(selectedLaunchfileProvider);

    return launchfileList == null
        ? const CircularProgressIndicator()
        : DropdownButton<String>(
            value: selectedLaunchfile,
            hint: const Text('Select a launchfile'),
            onChanged: (String? newValue) {
              ref.read(selectedLaunchfileProvider.notifier).state = newValue;
            },
            items: launchfileList.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          );
  }
}

class ROS2ControlButtons extends ConsumerWidget {
  const ROS2ControlButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ros2NetworkComms = ref.watch(ros2NetworkCommsProvider);
    final launchfile = ref.watch(selectedLaunchfileProvider);
    return Row( children: <Widget>[
      FloatingActionButton(
        child: const Icon(Icons.play_arrow),
        onPressed: () {
          ros2NetworkComms?.startLaunch(launchfile ?? "");
      }),
      FloatingActionButton(
        child: const Icon(Icons.stop),
        onPressed: () {
          ros2NetworkComms?.stopLaunch();
      }),
      const Padding(padding: EdgeInsets.all(4.0)),
      const LaunchfileDropdown(),
    ],);
  }
}
