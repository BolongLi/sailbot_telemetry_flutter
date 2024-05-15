import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';
import 'package:sailbot_telemetry_flutter/utils/utils.dart';
import 'package:sailbot_telemetry_flutter/widgets/server_select.dart';
import 'package:sailbot_telemetry_flutter/widgets/ros2_control_buttons.dart';


class NodesDrawer extends ConsumerWidget {
  const NodesDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watchers
    final networkComms = ref.watch(networkCommsProvider);

    void clearPath() {
      var newWaypoints = WaypointPath();
      networkComms?.setWaypoints(newWaypoints);
    }

    final boatState = ref.watch(boatStateProvider);

    final nodeStates = boatState.nodeStates;

    var nodeStatusWidgets = <Widget>[];
    const Color colorUnknown = Color.fromARGB(255, 255, 255, 255);
    const Color colorConfiguring = Color.fromARGB(255, 162, 50, 168);
    const Color colorInactive = Color.fromARGB(255, 46, 76, 209);
    const Color colorActivating = Color.fromARGB(255, 46, 209, 206);
    const Color colorActive = Color.fromARGB(255, 32, 216, 32);
    const Color colorOk = Color.fromARGB(255, 32, 216, 32);
    const Color colorWarn = Color.fromARGB(255, 255, 129, 10);
    const Color colorError = Color.fromARGB(255, 255, 0, 0);
    for (NodeInfo nodeInfo in nodeStates) {
      Color color = colorUnknown;
      switch (nodeInfo.lifecycleState) {
        case NodeLifecycleState.NODE_LIFECYCLE_STATE_CONFIGURING:
          color = colorConfiguring;
        case NodeLifecycleState.NODE_LIFECYCLE_STATE_INACTIVE:
          color = colorInactive;
        case NodeLifecycleState.NODE_LIFECYCLE_STATE_ACTIVATING:
          color = colorActivating;
        case NodeLifecycleState.NODE_LIFECYCLE_STATE_ACTIVE:
          color = colorActive;
        default:
      }

      switch (nodeInfo.status) {
        case NodeStatus.NODE_STATUS_WARN:
          color = colorWarn;
        case NodeStatus.NODE_STATUS_ERROR:
          color = colorError;
        default:
      }

      Widget newWidget = DecoratedBox(
        decoration: BoxDecoration(
            color: color, border: Border.all(color: Colors.black)),
        child: SizedBox(
          height: displayHeight(context) / 20,
          child: PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: nodeInfo.name, child: Text("Restart ${nodeInfo.name}"))
            ],
            child: Text(
              nodeInfo.name,
              textAlign: TextAlign.center,
            ),
            onSelected: (String value) {
              networkComms?.restartNode(value);
            },
          ),
        ),
      );
      nodeStatusWidgets.add(newWidget);
    }

    return Drawer(
      child: Column(children: [
        const ServerSelect(),
        const ROS2ControlButtons(),
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(
                  child: ListView(
                children: nodeStatusWidgets,
              )),
            ],
          ),
        ),
        FloatingActionButton(
          onPressed: () {
            _showclearPathFormDialog(context, clearPath);
          },
          child: const Text(textAlign: TextAlign.center, "Clear path"),
        )
      ]),
    );
  }
}

Widget _buildMenuItem(
  BuildContext context,
  Widget title,
  String routeName,
  String currentRoute, {
  Widget? icon,
}) {
  final isSelected = routeName == currentRoute;

  return ListTile(
    title: title,
    leading: icon,
    selected: isSelected,
    onTap: () {
      if (isSelected) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, routeName);
      }
    },
  );
}

void _showclearPathFormDialog(BuildContext context, Function clearCallback) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text(textAlign: TextAlign.center, 'Confirm clear path'),
        content: const Form(
          child: Text(
              textAlign: TextAlign.center,
              "If the boat is path-following,\nit will switch to station-keeping."),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Clear'),
            onPressed: () {
              clearCallback();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(textAlign: TextAlign.center, 'Cleared path'),
                ),
              );
            },
          ),
        ],
      );
    },
  );
}
