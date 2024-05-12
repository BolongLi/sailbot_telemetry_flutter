import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/widgets/autonomous_mode_selector.dart';

final ballastPositionProvider = StateProvider<double>((ref) => 0.0);
final ballastTimeProvider = StateProvider<int>((ref) => 0);

class BallastSlider extends ConsumerWidget {
  const BallastSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkComms = ref.watch(networkCommsProvider);
    final autonomousMode = ref.watch(autonomousModeProvider);
    final ballastPosition = ref.watch(ballastPositionProvider);
    final autoBallast = autonomousMode == 'BALLAST' ||
        autonomousMode == 'FULL' ||
        autonomousMode == 'TRIMTAB';
    return Slider(
        inactiveColor: const Color.fromARGB(255, 100, 100, 100),
        activeColor: const Color.fromARGB(255, 0, 100, 255),
        value: ballastPosition,
        max: 1.0,
        min: -1.0,
        onChanged: autoBallast
            ? null
            : (value) {
                ref.read(ballastPositionProvider.notifier).state = value;
                var time = DateTime.now().millisecondsSinceEpoch;
                int lastBallastTime =
                    ref.read(ballastTimeProvider.notifier).state;
                if (time - lastBallastTime > 50) {
                  networkComms?.setBallastPosition(value);
                  ref.read(ballastTimeProvider.notifier).state = time;
                }
              });
  }
}
