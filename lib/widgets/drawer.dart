import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:sailbot_telemetry_flutter/pages/map.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';
import 'package:sailbot_telemetry_flutter/utils/utils.dart';

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

Drawer buildDrawer(
    BuildContext context,
    String currentRoute,
    List<NodeInfo> nodeStates,
    Function nodeRestartCallback,
    Function clearPathCallback) {
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
      decoration:
          BoxDecoration(color: color, border: Border.all(color: Colors.black)),
      child: SizedBox(
        height: displayHeight(context) / 20,
        child: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
                value: nodeInfo.name, child: Text("Restart " + nodeInfo.name))
          ],
          child: Text(
            nodeInfo.name,
            textAlign: TextAlign.center,
          ),
          onSelected: (value) {
            nodeRestartCallback(value);
          },
        ),
      ),
    );
    nodeStatusWidgets.add(newWidget);
  }

  return Drawer(
    child: Column(children: [
      Expanded(
        child: Row(
          children: <Widget>[
            Expanded(
              child: ListView(
                children: <Widget>[
                  _buildMenuItem(
                    context,
                    const Text('Map'),
                    MapPage.route,
                    currentRoute,
                    icon: const Icon(Icons.home),
                  ),
                ],
              ),
            ),
            Expanded(
                child: ListView(
              children: nodeStatusWidgets,
            )),
          ],
        ),
      ),
      FloatingActionButton(
        onPressed: () {
          _showclearPathFormDialog(context, clearPathCallback);
        },
        child: Text(textAlign: TextAlign.center, "Clear path"),
      )
    ]),
  );
}

void _showclearPathFormDialog(BuildContext context, Function clearCallback) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(textAlign: TextAlign.center, 'Confirm clear path'),
        content: Form(
          child: Text(
              textAlign: TextAlign.center,
              "If the boat is path-following,\nit will switch to station-keeping."),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('Clear'),
            onPressed: () {
              clearCallback();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
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
