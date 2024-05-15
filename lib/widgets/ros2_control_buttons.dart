import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/utils/github_helper.dart';
import 'package:sailbot_telemetry_flutter/utils/startup_manager.dart';
import 'dart:developer' as dev;

class ROS2ControlButtons extends ConsumerWidget {
  const ROS2ControlButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ros2NetworkComms = ref.watch(ros2NetworkCommsProvider);

    return Row( children: <Widget>[
      FloatingActionButton(
        child: const Icon(Icons.play_arrow),
        onPressed: () {
          ros2NetworkComms?.startLaunch("sailbot path_test_vf_fake.py");
          ros2NetworkComms?.streamLogs();
      }),
      FloatingActionButton(
        child: const Icon(Icons.stop),
        onPressed: () {
          ros2NetworkComms?.stopLaunch();
      })
    ],);
  }
}
