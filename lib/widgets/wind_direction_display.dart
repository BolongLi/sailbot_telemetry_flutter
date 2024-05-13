import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/utils/utils.dart';
import 'package:sailbot_telemetry_flutter/widgets/speed_compass_gauges.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';

import 'dart:math';

class WindDirectionDisplay extends ConsumerWidget {
  const WindDirectionDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boatState = ref.watch(boatStateProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text("True wind"),
        SizedBox(
            width: min(displayHeight(context) / 3, 150),
            height: min(displayHeight(context) / 3, 150),
            child: buildCompassGauge(boatState.trueWind.direction)),
        const Text("Apparent wind"),
        SizedBox(
            width: min(displayHeight(context) / 3, 150),
            height: min(displayHeight(context) / 3, 150),
            child: buildApparentHeadingGague(boatState.apparentWind.direction)),
      ],
    );
  }
}
