import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/utils/github_helper.dart';
import 'dart:developer' as dev;

final vfForwardMagnitudeProvider = StateProvider<String>((ref) => '1.0');
final rudderKPProvider = StateProvider<String>((ref) => '1.0');

class SettingsDrawer extends ConsumerWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watchers
    final networkComms = ref.watch(networkCommsProvider);
    // Watching the server list provider here
    final serverListAsyncValue = ref.watch(serverListProvider);

    final lastVFForwardMagnitude = ref.watch(vfForwardMagnitudeProvider);
    final lastRudderKP = ref.watch(rudderKPProvider);

    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text('Drawer Header'),
          ),
          ListTile(
            title: Row(children: <Widget>[
              serverListAsyncValue.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (err, stack) => Text('Error: $err'),
                  data: (List<Server> servers) {
                    return DropdownButton<Server>(
                      value: ref.watch(selectedServerProvider),
                      onChanged: (Server? newValue) {
                        if (newValue != null) {
                          ref.read(selectedServerProvider.notifier).state =
                              newValue;
                        }
                      },
                      items: servers
                          .map<DropdownMenuItem<Server>>((Server server) {
                        return DropdownMenuItem<Server>(
                          value: server,
                          child: Text(server.name),
                        );
                      }).toList(),
                    );
                  }),
            ]),
          ),
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
        ],
      ),
    );
  }
}
