import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/utils/github_helper.dart';
import 'dart:developer' as dev;

class ServerSelect extends ConsumerWidget {
  const ServerSelect({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    // Watching the server list provider here
    final serverListAsyncValue = ref.watch(serverListProvider);

    return serverListAsyncValue.when(
        loading: () => const CircularProgressIndicator(),
        error: (err, stack) => Text('Error: $err'),
        data: (List<Server> servers) {
          final currentServer = ref.watch(selectedServerProvider);
          Server? selectedServer;

          if (currentServer == null) {
            // Automatically select the first server if the current server is null
            selectedServer = servers.first;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedServerProvider.notifier).state = selectedServer;
              dev.log("1. Setting current server to: ${selectedServer?.name}");
            });
            return const Text("Loading...");
          } else {
            //dev.log("current server is ${currentServer.name}"); // ?
            if (currentServer.name == "") {
              return const Text("Loading...");
            }
          }
          return DropdownButton<Server>(
            value: currentServer,
            onChanged: (Server? newValue) {
              if (newValue != null) {
                ref.read(selectedServerProvider.notifier).state = newValue;
                dev.log("2. Setting current server to: ${newValue.name}");
              }
            },
            items: servers.map<DropdownMenuItem<Server>>((Server server) {
              return DropdownMenuItem<Server>(
                value: server,
                child: Text(server.name),
              );
            }).toList(),
          );
        });
  }
}
