import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';


class DrawerIconWidget extends ConsumerWidget {
  const DrawerIconWidget(this._scaffoldState, {super.key});

  final GlobalKey<ScaffoldState> _scaffoldState;

  final Color _colorOk = const Color.fromARGB(255, 0, 0, 0);
  final Color _colorWarn = const Color.fromARGB(255, 255, 129, 10);
  final Color _colorError = const Color.fromARGB(255, 255, 0, 0);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watchers
    final boatState = ref.watch(boatStateProvider);

    Color menuIconColor = _colorOk;

    bool allOk = true;
    bool error = false;
    bool warn = false;
    for (NodeInfo status in boatState.nodeStates) {
      if (status.status == NodeStatus.NODE_STATUS_ERROR) {
        allOk = false;
        error = true;
      }
      if (status.status == NodeStatus.NODE_STATUS_WARN) {
        allOk = false;
        warn = true;
      }
    }
    if (allOk) {
      menuIconColor = _colorOk;
    } else {
      if (warn) menuIconColor = _colorWarn;
      if (error) menuIconColor = _colorError;
    }

    return IconButton(
            icon: const Icon(Icons.menu),
            color: menuIconColor,
            onPressed: () {
              _scaffoldState.currentState?.openDrawer();
            },
          );
  }
}