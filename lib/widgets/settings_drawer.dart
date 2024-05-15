import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/utils/github_helper.dart';
import 'package:sailbot_telemetry_flutter/widgets/cv_settings.dart';
import 'dart:developer' as dev;

final vfForwardMagnitudeProvider = StateProvider<String>((ref) => '1.0');
final rudderKPProvider = StateProvider<String>((ref) => '1.0');

class SettingsDrawer extends ConsumerWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watchers
    final networkComms = ref.watch(networkCommsProvider);

    final lastVFForwardMagnitude = ref.watch(vfForwardMagnitudeProvider);
    final lastRudderKP = ref.watch(rudderKPProvider);

    return Drawer(
      child: ListView(
        children: [
          ListTile(
            title: const Text("VF forward magnitude"),
            subtitle: TextField(
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: lastVFForwardMagnitude),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              onSubmitted: ((String value) {
                ref.read(vfForwardMagnitudeProvider.notifier).state = value;
                networkComms?.setVFForwardMagnitude(double.parse(value));
              }),
            ),
          ),
          ListTile(
            title: const Text("Rudder KP"),
            subtitle: TextField(
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: lastRudderKP),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              onSubmitted: ((String value) {
                ref.read(rudderKPProvider.notifier).state = value;
                networkComms?.setRudderKP(double.parse(value));
              }),
            ),
          ),
          const CVSettings(),
        ],
      ),
    );
  }
  Server? findMatchingServer(List<Server> servers, Server? currentValue) {
  if (currentValue == null) return null;

  try {
    return servers.firstWhere((server) => server.address == currentValue.address);
  } catch (e) {
    // No matching server found
    return null;
  }
}
}
